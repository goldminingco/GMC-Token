// ---
// EN: GMC Treasury Program - Simplified Version
//     This program manages the ecosystem's treasury, allowing for deposits and withdrawals
//     by an authorized entity. It's a simplified contract for fund management.
// PT: Programa de Tesouraria GMC - Versão Simplificada
//     Este programa gerencia a tesouraria do ecossistema, permitindo depósitos e saques
//     por uma entidade autorizada. É um contrato simplificado para gerenciamento de fundos.
// ---
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

// EN: Unique identifier for the Treasury program.
// PT: Identificador único para o programa de Tesouraria.
declare_id!("3WXR2fF1yHZAaehuxk39p95MNMh3nn3CiSsvzB8QMk9X");

/// GMC Treasury Program - Simplified Version
#[program]
pub mod gmc_treasury {
    use super::*;

    // ---
    // EN: Initializes the treasury state with an authority. Must be called once.
    // PT: Inicializa o estado da tesouraria com uma autoridade. Deve ser chamada uma vez.
    // ---
    /// Initialize treasury
    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let treasury_state = &mut ctx.accounts.treasury_state;
        treasury_state.authority = ctx.accounts.authority.key();
        treasury_state.total_funds = 0;
        
        msg!("🏦 Treasury initialized");
        Ok(())
    }

    // ---
    // EN: Deposits funds into the treasury vault.
    // PT: Deposita fundos no cofre da tesouraria.
    // ---
    /// Deposit funds to treasury
    pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {
        let treasury_state = &mut ctx.accounts.treasury_state;
        
        // EN: Transfer tokens to the treasury vault.
        // PT: Transfere tokens para o cofre da tesouraria.
        // Transfer tokens to treasury vault
        let cpi_accounts = Transfer {
            from: ctx.accounts.source_account.to_account_info(),
            to: ctx.accounts.treasury_vault.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
        };
        
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, amount)?;
        
        treasury_state.total_funds = treasury_state.total_funds.checked_add(amount).unwrap();
        
        msg!("💰 Deposited {} tokens to treasury", amount);
        Ok(())
    }

    // ---
    // EN: Withdraws funds from the treasury. Can only be called by the authority.
    // PT: Saca fundos da tesouraria. Só pode ser chamada pela autoridade.
    // ---
    /// Withdraw funds from treasury (admin only)
    pub fn withdraw(ctx: Context<Withdraw>, amount: u64) -> Result<()> {
        let treasury_state = &mut ctx.accounts.treasury_state;
        
        // EN: Verify that only the authority can withdraw funds.
        // PT: Verifica que apenas a autoridade pode sacar fundos.
        require!(
            ctx.accounts.authority.key() == treasury_state.authority,
            TreasuryError::Unauthorized
        );
        
        // EN: Transfer tokens from the treasury vault.
        // PT: Transfere tokens do cofre da tesouraria.
        // Transfer tokens from treasury vault
        let cpi_accounts = Transfer {
            from: ctx.accounts.treasury_vault.to_account_info(),
            to: ctx.accounts.destination_account.to_account_info(),
            authority: ctx.accounts.treasury_vault.to_account_info(),
        };
        
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, amount)?;
        
        treasury_state.total_funds = treasury_state.total_funds.checked_sub(amount).unwrap();
        
        msg!("💸 Withdrew {} tokens from treasury", amount);
        Ok(())
    }
}

// --- Account Structures ---
// EN: Defines the accounts required for each instruction.
// PT: Define as contas necessárias para cada instrução.
// ---

// Account Structures
#[derive(Accounts)]
pub struct Initialize<'info> {
    // EN: The treasury state account that stores the authority and total funds.
    // PT: A conta de estado da tesouraria que armazena a autoridade e fundos totais.
    #[account(
        init,
        payer = authority,
        space = 8 + TreasuryState::INIT_SPACE
    )]
    pub treasury_state: Account<'info, TreasuryState>,
    
    // EN: The authority that can manage the treasury.
    // PT: A autoridade que pode gerenciar a tesouraria.
    #[account(mut)]
    pub authority: Signer<'info>,
    
    // EN: The system program, required for account initialization.
    // PT: O programa do sistema, necessário para a inicialização de contas.
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    // EN: The treasury state account.
    // PT: A conta de estado da tesouraria.
    #[account(mut)]
    pub treasury_state: Account<'info, TreasuryState>,
    
    // EN: The source token account to deposit from.
    // PT: A conta de token de origem para depositar.
    #[account(mut)]
    pub source_account: Account<'info, TokenAccount>,
    
    // EN: The treasury vault where tokens are stored.
    // PT: O cofre da tesouraria onde os tokens são armazenados.
    #[account(mut)]
    pub treasury_vault: Account<'info, TokenAccount>,
    
    // EN: The authority making the deposit.
    // PT: A autoridade fazendo o depósito.
    pub authority: Signer<'info>,
    
    // EN: The token program, required for token transfers.
    // PT: O programa de token, necessário para transferências de token.
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    // EN: The treasury state account.
    // PT: A conta de estado da tesouraria.
    #[account(mut)]
    pub treasury_state: Account<'info, TreasuryState>,
    
    // EN: The treasury vault where tokens are stored.
    // PT: O cofre da tesouraria onde os tokens são armazenados.
    #[account(mut)]
    pub treasury_vault: Account<'info, TokenAccount>,
    
    // EN: The destination token account to withdraw to.
    // PT: A conta de token de destino para sacar.
    #[account(mut)]
    pub destination_account: Account<'info, TokenAccount>,
    
    // EN: The authority making the withdrawal.
    // PT: A autoridade fazendo o saque.
    pub authority: Signer<'info>,
    
    // EN: The token program, required for token transfers.
    // PT: O programa de token, necessário para transferências de token.
    pub token_program: Program<'info, Token>,
}

// --- Data Structures ---
// EN: Defines the data structures used in the program.
// PT: Define as estruturas de dados usadas no programa.
// ---

// Data Structures
#[account]
#[derive(InitSpace)]
pub struct TreasuryState {
    // EN: The public key of the authority that can manage the treasury.
    // PT: A chave pública da autoridade que pode gerenciar a tesouraria.
    pub authority: Pubkey,
    // EN: The total amount of funds currently in the treasury.
    // PT: A quantidade total de fundos atualmente na tesouraria.
    pub total_funds: u64,
}

// --- Errors ---
// EN: Custom errors for the treasury program.
// PT: Erros personalizados para o programa de tesouraria.
// ---

// Errors
#[error_code]
pub enum TreasuryError {
    // EN: Thrown when an unauthorized user tries to perform a restricted action.
    // PT: Lançado quando um usuário não autorizado tenta realizar uma ação restrita.
    #[msg("Unauthorized access")]
    Unauthorized,
}
