//! GMC Vesting Program
//!
// ---
// EN: This program manages vesting schedules (programmed release) for the GMC ecosystem.
//     It includes:
//     - Linear schedules with cliff periods.
//     - Programmed release of tokens.
//     - Management of multiple beneficiaries.
//     - Security validations and access control.
//     - An audit system via events.
// PT: Este programa gerencia cronogramas de vesting (liberação programada) para o ecossistema GMC.
//     Inclui:
//     - Cronogramas lineares com períodos de cliff.
//     - Liberação programada de tokens.
//     - Gestão de múltiplos beneficiários.
//     - Validações de segurança e controle de acesso.
//     - Sistema de auditoria via eventos.
// ---

use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

// EN: Unique identifier for the Vesting program.
// PT: Identificador único para o programa de Vesting.
declare_id!("8xef742EHoWyB6eJFeY9qD8nsVadsXvLByL8J6Lhvtz3");

// EN: Defines constant seeds for PDAs to ensure deterministic addresses.
// PT: Define as sementes constantes para PDAs para garantir endereços determinísticos.
mod constants {
    pub const VESTING_STATE_SEED: &[u8] = b"vesting_state";
    pub const VESTING_VAULT_SEED: &[u8] = b"vesting_vault";
    pub const VESTING_SCHEDULE_SEED: &[u8] = b"vesting_schedule";
}

#[program]
pub mod gmc_vesting {
    use super::*;

    // ---
    // EN: Initializes the global state of the vesting system. Must be called once by the authority.
    // PT: Inicializa o estado global do sistema de vesting. Deve ser chamada uma vez pela autoridade.
    // ---
    pub fn initialize_vesting(ctx: Context<InitializeVesting>) -> Result<()> {
        let vesting_state = &mut ctx.accounts.vesting_state;
        
        vesting_state.authority = ctx.accounts.authority.key();
        vesting_state.total_schedules = 0;
        vesting_state.total_vested_amount = 0;
        vesting_state.total_released_amount = 0;
        vesting_state.created_at = Clock::get()?.unix_timestamp;
        vesting_state.bump = ctx.bumps.vesting_state;

        emit!(VestingInitialized {
            authority: vesting_state.authority,
            timestamp: vesting_state.created_at,
        });

        Ok(())
    }

    // ---
    // EN: Creates a new vesting schedule for a beneficiary. Only the authority can call this.
    // PT: Cria um novo cronograma de vesting para um beneficiário. Apenas a autoridade pode chamar esta função.
    // ---
    pub fn create_vesting_schedule(
        ctx: Context<CreateVestingSchedule>,
        beneficiary: Pubkey,
        total_amount: u64,
        start_timestamp: i64,
        duration_seconds: i64,
        cliff_seconds: i64,
    ) -> Result<()> {
        // EN: Input validations.
        // PT: Validações de entrada.
        require!(total_amount > 0, VestingError::InvalidAmount);
        require!(duration_seconds > 0, VestingError::InvalidDuration);
        require!(cliff_seconds <= duration_seconds, VestingError::InvalidCliff);
        require!(start_timestamp >= Clock::get()?.unix_timestamp, VestingError::InvalidStartTime);

        let vesting_schedule = &mut ctx.accounts.vesting_schedule;
        let vesting_state = &mut ctx.accounts.vesting_state;

        // EN: Configure the schedule.
        // PT: Configura o cronograma.
        vesting_schedule.beneficiary = beneficiary;
        vesting_schedule.total_amount = total_amount;
        vesting_schedule.start_timestamp = start_timestamp;
        vesting_schedule.duration_seconds = duration_seconds;
        vesting_schedule.cliff_seconds = cliff_seconds;
        vesting_schedule.amount_released = 0;
        vesting_schedule.is_active = true;
        vesting_schedule.created_at = Clock::get()?.unix_timestamp;
        vesting_schedule.bump = ctx.bumps.vesting_schedule;

        // EN: Update the global state.
        // PT: Atualiza o estado global.
        vesting_state.total_schedules = vesting_state.total_schedules.checked_add(1).ok_or(VestingError::ArithmeticOverflow)?;
        vesting_state.total_vested_amount = vesting_state.total_vested_amount.checked_add(total_amount).ok_or(VestingError::ArithmeticOverflow)?;

        emit!(VestingScheduleCreated {
            beneficiary,
            total_amount,
            start_timestamp,
            duration_seconds,
            cliff_seconds,
            schedule_pubkey: vesting_schedule.key(),
        });

        Ok(())
    }

    // ---
    // EN: Releases available vested tokens to the beneficiary.
    // PT: Libera os tokens disponíveis do vesting para o beneficiário.
    // ---
    pub fn release_vested_tokens(ctx: Context<ReleaseVestedTokens>) -> Result<()> {
        let vesting_schedule = &mut ctx.accounts.vesting_schedule;
        let vesting_state = &mut ctx.accounts.vesting_state;
        
        // EN: Validations.
        // PT: Validações.
        require!(vesting_schedule.is_active, VestingError::ScheduleInactive);
        require!(vesting_schedule.beneficiary == ctx.accounts.beneficiary.key(), VestingError::UnauthorizedBeneficiary);

        // EN: Calculate the amount available for release.
        // PT: Calcula a quantidade disponível para liberação.
        let current_time = Clock::get()?.unix_timestamp;
        let vested_amount = calculate_vested_amount_internal(vesting_schedule, current_time)?;
        let releasable_amount = vested_amount.checked_sub(vesting_schedule.amount_released).ok_or(VestingError::ArithmeticUnderflow)?;

        require!(releasable_amount > 0, VestingError::NoTokensToRelease);

        // EN: Update schedule state.
        // PT: Atualiza o estado do cronograma.
        vesting_schedule.amount_released = vesting_schedule.amount_released.checked_add(releasable_amount).ok_or(VestingError::ArithmeticOverflow)?;
        
        // EN: Update global state.
        // PT: Atualiza o estado global.
        vesting_state.total_released_amount = vesting_state.total_released_amount.checked_add(releasable_amount).ok_or(VestingError::ArithmeticOverflow)?;

        // EN: Transfer tokens from the vault to the beneficiary.
        // PT: Transfere tokens do cofre para o beneficiário.
        let authority_seeds = &[constants::VESTING_STATE_SEED, &[vesting_state.bump]];
        let signer_seeds = &[&authority_seeds[..]];

        let transfer_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.vesting_vault.to_account_info(),
                to: ctx.accounts.beneficiary_token_account.to_account_info(),
                authority: vesting_state.to_account_info(),
            },
            signer_seeds,
        );

        token::transfer(transfer_ctx, releasable_amount)?;

        // EN: Check if the schedule is fully released.
        // PT: Verifica se o cronograma foi completamente liberado.
        if vesting_schedule.amount_released == vesting_schedule.total_amount {
            vesting_schedule.is_active = false;
        }

        emit!(TokensReleased {
            beneficiary: vesting_schedule.beneficiary,
            amount: releasable_amount,
            total_released: vesting_schedule.amount_released,
            schedule_pubkey: vesting_schedule.key(),
            timestamp: current_time,
        });

        Ok(())
    }

    // ---
    // EN: Calculates the amount of tokens available for release (view function).
    // PT: Calcula a quantidade de tokens disponíveis para liberação (função de visualização).
    // ---
    pub fn calculate_vested_amount(ctx: Context<CalculateVestedAmount>) -> Result<u64> {
        let vesting_schedule = &ctx.accounts.vesting_schedule;
        let current_time = Clock::get()?.unix_timestamp;
        
        let vested_amount = calculate_vested_amount_internal(vesting_schedule, current_time)?;
        
        msg!("Vested amount: {}", vested_amount);
        Ok(vested_amount)
    }

    // ---
    // EN: Deactivates a vesting schedule (admin only).
    // PT: Desativa um cronograma de vesting (somente admin).
    // ---
    pub fn deactivate_schedule(ctx: Context<DeactivateSchedule>) -> Result<()> {
        let vesting_schedule = &mut ctx.accounts.vesting_schedule;
        
        require!(vesting_schedule.is_active, VestingError::ScheduleInactive);
        
        vesting_schedule.is_active = false;

        emit!(VestingScheduleDeactivated {
            beneficiary: vesting_schedule.beneficiary,
            schedule_pubkey: vesting_schedule.key(),
            timestamp: Clock::get()?.unix_timestamp,
        });

        Ok(())
    }
}

// ---
// EN: Internal helper function to calculate the amount of vested tokens based on time.
// PT: Função auxiliar interna para calcular a quantidade de tokens liberados com base no tempo.
// ---
fn calculate_vested_amount_internal(schedule: &VestingSchedule, current_time: i64) -> Result<u64> {
    // EN: If the current time is before the start time, no tokens have been released.
    // PT: Se o tempo atual for anterior ao tempo de início, nada foi liberado.
    if current_time < schedule.start_timestamp {
        return Ok(0);
    }

    // EN: Calculate the elapsed time since the start.
    // PT: Calcula o tempo decorrido desde o início.
    let elapsed_time = current_time
        .checked_sub(schedule.start_timestamp)
        .ok_or(VestingError::ArithmeticUnderflow)?;

    // EN: If still within the cliff period, no tokens have been released.
    // PT: Se ainda estiver dentro do período de cliff, nada foi liberado.
    if elapsed_time < schedule.cliff_seconds {
        return Ok(0);
    }

    // EN: If the total duration has passed, release all tokens.
    // PT: Se o tempo total já passou, libera todos os tokens.
    if elapsed_time >= schedule.duration_seconds {
        return Ok(schedule.total_amount);
    }

    // EN: Linear release calculation after the cliff.
    // PT: Cálculo linear da liberação após o cliff.
    let vesting_time = elapsed_time
        .checked_sub(schedule.cliff_seconds)
        .ok_or(VestingError::ArithmeticUnderflow)?;
    
    let vesting_duration = schedule.duration_seconds
        .checked_sub(schedule.cliff_seconds)
        .ok_or(VestingError::ArithmeticUnderflow)?;

    // EN: Proportional calculation: (vesting_time / vesting_duration) * total_amount
    // PT: Cálculo proporcional: (tempo_liberacao / duracao_liberacao) * total_amount
    let vested_amount = (schedule.total_amount as u128)
        .checked_mul(vesting_time as u128)
        .ok_or(VestingError::ArithmeticOverflow)?
        .checked_div(vesting_duration as u128)
        .ok_or(VestingError::DivisionByZero)?;

    Ok(vested_amount as u64)
}

// --- Data Structures ---
// EN: Vesting State Account
// PT: Conta de Estado de Vesting
#[account]
pub struct VestingState {
    pub authority: Pubkey,
    pub total_schedules: u32,
    pub total_vested_amount: u64,
    pub total_released_amount: u64,
    pub created_at: i64,
    pub bump: u8,
}

impl VestingState {
    pub const LEN: usize = 8 + 32 + 4 + 8 + 8 + 8 + 1;
}

// EN: Vesting Schedule Account
// PT: Conta de Cronograma de Vesting
#[account]
pub struct VestingSchedule {
    pub beneficiary: Pubkey,
    pub total_amount: u64,
    pub start_timestamp: i64,
    pub duration_seconds: i64,
    pub cliff_seconds: i64,
    pub amount_released: u64,
    pub is_active: bool,
    pub created_at: i64,
    pub bump: u8,
}

impl VestingSchedule {
    pub const LEN: usize = 8 + 32 + 8 + 8 + 8 + 8 + 8 + 1 + 8 + 1;
}

// Contextos das instruções
#[derive(Accounts)]
pub struct InitializeVesting<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        init,
        payer = authority,
        space = VestingState::LEN,
        seeds = [constants::VESTING_STATE_SEED],
        bump
    )]
    pub vesting_state: Account<'info, VestingState>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(beneficiary: Pubkey)]
pub struct CreateVestingSchedule<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        mut,
        seeds = [constants::VESTING_STATE_SEED],
        bump = vesting_state.bump,
        has_one = authority
    )]
    pub vesting_state: Account<'info, VestingState>,
    
    #[account(
        init,
        payer = authority,
        space = VestingSchedule::LEN,
        seeds = [constants::VESTING_SCHEDULE_SEED, beneficiary.as_ref()],
        bump
    )]
    pub vesting_schedule: Account<'info, VestingSchedule>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ReleaseVestedTokens<'info> {
    #[account(mut)]
    pub beneficiary: Signer<'info>,
    
    #[account(
        mut,
        seeds = [constants::VESTING_STATE_SEED],
        bump = vesting_state.bump
    )]
    pub vesting_state: Account<'info, VestingState>,
    
    #[account(
        mut,
        seeds = [constants::VESTING_SCHEDULE_SEED, beneficiary.key().as_ref()],
        bump = vesting_schedule.bump
    )]
    pub vesting_schedule: Account<'info, VestingSchedule>,
    
    #[account(
        mut,
        seeds = [constants::VESTING_VAULT_SEED],
        bump
    )]
    pub vesting_vault: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub beneficiary_token_account: Account<'info, TokenAccount>,
    
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct CalculateVestedAmount<'info> {
    #[account(
        seeds = [constants::VESTING_SCHEDULE_SEED, vesting_schedule.beneficiary.as_ref()],
        bump = vesting_schedule.bump
    )]
    pub vesting_schedule: Account<'info, VestingSchedule>,
}

#[derive(Accounts)]
pub struct DeactivateSchedule<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        seeds = [constants::VESTING_STATE_SEED],
        bump = vesting_state.bump,
        has_one = authority
    )]
    pub vesting_state: Account<'info, VestingState>,
    
    #[account(
        mut,
        seeds = [constants::VESTING_SCHEDULE_SEED, vesting_schedule.beneficiary.as_ref()],
        bump = vesting_schedule.bump
    )]
    pub vesting_schedule: Account<'info, VestingSchedule>,
}

// Eventos
#[event]
pub struct VestingInitialized {
    pub authority: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct VestingScheduleCreated {
    pub beneficiary: Pubkey,
    pub total_amount: u64,
    pub start_timestamp: i64,
    pub duration_seconds: i64,
    pub cliff_seconds: i64,
    pub schedule_pubkey: Pubkey,
}

#[event]
pub struct TokensReleased {
    pub beneficiary: Pubkey,
    pub amount: u64,
    pub total_released: u64,
    pub schedule_pubkey: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct VestingScheduleDeactivated {
    pub beneficiary: Pubkey,
    pub schedule_pubkey: Pubkey,
    pub timestamp: i64,
}

// Erros
#[error_code]
pub enum VestingError {
    #[msg("Invalid amount: must be greater than 0")]
    InvalidAmount,
    
    #[msg("Invalid duration: must be greater than 0")]
    InvalidDuration,
    
    #[msg("Invalid cliff: cliff period cannot exceed total duration")]
    InvalidCliff,
    
    #[msg("Invalid start time: cannot be in the past")]
    InvalidStartTime,
    
    #[msg("Schedule is inactive")]
    ScheduleInactive,
    
    #[msg("Unauthorized beneficiary")]
    UnauthorizedBeneficiary,
    
    #[msg("No tokens available for release")]
    NoTokensToRelease,
    
    #[msg("Arithmetic overflow")]
    ArithmeticOverflow,
    
    #[msg("Arithmetic underflow")]
    ArithmeticUnderflow,
    
    #[msg("Division by zero")]
    DivisionByZero,
}
