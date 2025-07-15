//! # GMC Staking Program
//!
//! ## 🇧🇷 Descrição em Português
//! Este programa gerencia toda a lógica de staking para o token GMC, incluindo:
//! - Staking de Longo Prazo (12 meses) e Flexível (sem prazo).
//! - Cálculo dinâmico de APY (10%-280% para longo prazo, 5%-70% flexível).
//! - Sistema `burn-for-boost` para aumentar o APY queimando tokens.
//! - Distribuição de recompensas em GMC e USDT.
//! - Sistema de afiliados com boost de até 50% no APY.
//! - Validações de segurança e gerenciamento de estado.
//!
//! ## 🇺🇸 English Description
//! This program manages all staking logic for the GMC token, including:
//! - Long-Term (12 months) and Flexible (no term) staking.
//! - Dynamic APY calculation (10%-280% for long-term, 5%-70% for flexible).
//! - `burn-for-boost` system to increase APY by burning tokens.
//! - Reward distribution in GMC and USDT.
//! - Affiliate system with up to 50% APY boost.
//! - Security validations and state management.

use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

// Importar o novo módulo de constantes
mod constants;
use constants::*;
mod affiliate;

declare_id!("11111111111111111111111111111112");

#[program]
pub mod gmc_staking {
    use super::*;

    /// ## 🇧🇷 Inicializa o estado global do contrato de staking.
    /// ### Contas:
    /// - `authority`: A carteira que terá permissões administrativas.
    /// - `global_state`: A conta que armazenará as configurações globais.
    /// - `system_program`: Referência ao System Program da Solana.
    /// ### Parâmetros:
    /// - `team_wallet`: A carteira da equipe para recebimento de taxas.
    /// - `ranking_contract`: O endereço do contrato de ranking para integração.
    /// - `burn_address`: O endereço para onde os tokens de queima serão enviados.
    ///
    /// ## 🇺🇸 Initializes the global state of the staking contract.
    /// ### Accounts:
    /// - `authority`: The wallet that will have administrative permissions.
    /// - `global_state`: The account that will store global settings.
    /// - `system_program`: Reference to the Solana System Program.
    /// ### Parameters:
    /// - `team_wallet`: The team's wallet for receiving fees.
    /// - `ranking_contract`: The address of the ranking contract for integration.
    /// - `burn_address`: The address where burned tokens will be sent.
    pub fn initialize_staking(
        ctx: Context<InitializeStaking>,
        team_wallet: Pubkey,
        ranking_contract: Pubkey,
        burn_address: Pubkey,
    ) -> Result<()> {
        let global_state = &mut ctx.accounts.global_state;
        
        global_state.authority = ctx.accounts.authority.key();
        global_state.team_wallet = team_wallet;
        global_state.ranking_contract = ranking_contract;
        global_state.burn_address = burn_address;
        global_state.total_staked_long_term = 0;
        global_state.total_staked_flexible = 0;
        global_state.total_rewards_distributed = 0;
        global_state.is_paused = false;
        
        msg!("✅ Staking contract initialized successfully");
        msg!("   Authority: {}", global_state.authority);
        msg!("   Team Wallet: {}", team_wallet);
        msg!("   Ranking Contract: {}", ranking_contract);
        msg!("   Burn Address: {}", burn_address);
        
        Ok(())
    }

    /// ## 🇧🇷 Registra um usuário como afiliado (referrer) de outro.
    /// Só pode ser executado uma vez por usuário.
    /// ### Contas:
    /// - `user`: O usuário que está definindo seu referrer.
    /// - `user_stake_info`: A conta de informações de staking do usuário.
    /// ### Parâmetros:
    /// - `referrer`: A chave pública do usuário que está sendo definido como referrer.
    ///
    /// ## 🇺🇸 Registers a user as another's affiliate (referrer).
    /// Can only be executed once per user.
    /// ### Accounts:
    /// - `user`: The user who is setting their referrer.
    /// - `user_stake_info`: The user's staking information account.
    /// ### Parameters:
    /// - `referrer`: The public key of the user being set as the referrer.
    pub fn register_referrer(
        ctx: Context<RegisterReferrer>,
        referrer: Pubkey,
    ) -> Result<()> {
        let user_stake_info = &mut ctx.accounts.user_stake_info;
        
        // Check if the referrer is already set
        require!(
            user_stake_info.referrer == Pubkey::default(),
            StakingError::ReferrerAlreadySet
        );
        
        // Check if the user is trying to refer themselves
        require!(
            referrer != ctx.accounts.user.key(),
            StakingError::CannotReferSelf
        );
        
        // Set the referrer
        user_stake_info.referrer = referrer;
        user_stake_info.owner = ctx.accounts.user.key();
        
        // Add the user to the referrer's children list
        let referrer_stake_info = &mut ctx.accounts.referrer_stake_info;
        referrer_stake_info.children.push(ctx.accounts.user.key());

        msg!("👥 Referrer registered: {} -> {}", ctx.accounts.user.key(), referrer);
        Ok(())
    }

    /// ## 🇧🇷 Cria uma nova posição de staking de Longo Prazo (12 meses).
    /// Requer uma taxa de entrada em USDT e bloqueia os tokens GMC por 12 meses.
    /// ### Contas:
    /// - `user`: O staker.
    /// - `global_state`: Estado global do contrato.
    /// - `user_stake_info`: Informações de staking do usuário.
    /// - `stake_position`: A nova conta de posição de staking a ser criada.
    /// - `user_token_account`: A conta de tokens GMC do usuário.
    /// - `staking_vault`: O cofre do contrato para onde os GMCs são enviados.
    /// ### Parâmetros:
    /// - `amount`: A quantidade de GMC a ser colocada em stake.
    ///
    /// ## 🇺🇸 Creates a new Long-Term (12 months) staking position.
    /// Requires an entry fee in USDT and locks GMC tokens for 12 months.
    /// ### Accounts:
    /// - `user`: The staker.
    /// - `global_state`: Global state of the contract.
    /// - `user_stake_info`: The user's staking information.
    /// - `stake_position`: The new staking position account to be created.
    /// - `user_token_account`: The user's GMC token account.
    /// - `staking_vault`: The contract's vault where GMCs are sent.
    /// ### Parameters:
    /// - `amount`: The amount of GMC to be staked.
    pub fn stake_long_term(
        ctx: Context<StakeLongTerm>,
        amount: u64,
    ) -> Result<()> {
        let global_state = &ctx.accounts.global_state;
        
        require!(!global_state.is_paused, StakingError::ContractPaused);
        require!(amount >= MIN_STAKE_LONG_TERM, StakingError::InsufficientAmount);
        
        let user_stake_info = &mut ctx.accounts.user_stake_info;
        
        // ✅ VERIFICAR LIMITE DE POSIÇÕES
        require!(
            user_stake_info.active_positions < MAX_STAKE_POSITIONS_PER_USER,
            StakingError::MaxStakePositionsReached
        );

        let stake_position = &mut ctx.accounts.stake_position;
        
        stake_position.owner = ctx.accounts.user.key();
        stake_position.stake_type = StakeType::LongTerm;
        stake_position.principal_amount = amount;
        stake_position.start_timestamp = Clock::get()?.unix_timestamp;
        stake_position.last_reward_claim_timestamp = Clock::get()?.unix_timestamp;
        stake_position.is_active = true;
        stake_position.position_id = user_stake_info.total_positions + 1;
        
        stake_position.long_term_data = Some(LongTermData {
            total_gmc_burned_for_boost: 0,
            staking_power_from_burn: 0,
            affiliate_power_boost: 0,
        });
        
        let transfer_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_token_account.to_account_info(),
                to: ctx.accounts.staking_vault.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_ctx, amount)?;
        
        // ✅ ATUALIZAR CONTADORES
        user_stake_info.total_positions = user_stake_info.total_positions.checked_add(1).ok_or(StakingError::ArithmeticOverflow)?;
        user_stake_info.active_positions = user_stake_info.active_positions.checked_add(1).ok_or(StakingError::ArithmeticOverflow)?;
        
        let global_state = &mut ctx.accounts.global_state;
        global_state.total_staked_long_term = global_state.total_staked_long_term.checked_add(amount).ok_or(StakingError::ArithmeticOverflow)?;
        
        msg!("✅ Long-term staking created:");
        msg!("   User: {}", ctx.accounts.user.key());
        msg!("   Amount: {} GMC", amount);
        msg!("   Position ID: {}", stake_position.position_id);
        msg!("   Duration: 12 months");
        
        Ok(())
    }

    /// ## 🇧🇷 Cria uma nova posição de staking flexível (sem prazo fixo).
    /// Requer uma taxa de entrada em USDT.
    /// ### Contas:
    /// - `user`: O staker.
    /// - `global_state`: Estado global do contrato.
    /// - `user_stake_info`: Informações de staking do usuário.
    /// - `stake_position`: A nova conta de posição de staking a ser criada.
    /// - `user_token_account`: A conta de tokens GMC do usuário.
    /// - `staking_vault`: O cofre do contrato para onde os GMCs são enviados.
    /// ### Parâmetros:
    /// - `amount`: A quantidade de GMC a ser colocada em stake.
    ///
    /// ## 🇺🇸 Creates a new Flexible staking position (no fixed term).
    /// Requires an entry fee in USDT.
    /// ### Accounts:
    /// - `user`: The staker.
    /// - `global_state`: Global state of the contract.
    /// - `user_stake_info`: The user's staking information.
    /// - `stake_position`: The new staking position account to be created.
    /// - `user_token_account`: The user's GMC token account.
    /// - `staking_vault`: The contract's vault where GMCs are sent.
    /// ### Parameters:
    /// - `amount`: The amount of GMC to be staked.
    pub fn stake_flexible(
        ctx: Context<StakeFlexible>,
        amount: u64,
    ) -> Result<()> {
        let global_state = &ctx.accounts.global_state;
        
        require!(!global_state.is_paused, StakingError::ContractPaused);
        require!(amount >= MIN_STAKE_FLEXIBLE, StakingError::InsufficientAmount);
        
        let user_stake_info = &mut ctx.accounts.user_stake_info;
        
        // ✅ VERIFICAR LIMITE DE POSIÇÕES
        require!(
            user_stake_info.active_positions < MAX_STAKE_POSITIONS_PER_USER,
            StakingError::MaxStakePositionsReached
        );

        let stake_position = &mut ctx.accounts.stake_position;
        
        stake_position.owner = ctx.accounts.user.key();
        stake_position.stake_type = StakeType::Flexible;
        stake_position.principal_amount = amount;
        stake_position.start_timestamp = Clock::get()?.unix_timestamp;
        stake_position.last_reward_claim_timestamp = Clock::get()?.unix_timestamp;
        stake_position.is_active = true;
        stake_position.position_id = user_stake_info.total_positions + 1;
        stake_position.long_term_data = None;
        
        let transfer_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_token_account.to_account_info(),
                to: ctx.accounts.staking_vault.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_ctx, amount)?;
        
        // ✅ ATUALIZAR CONTADORES
        user_stake_info.total_positions = user_stake_info.total_positions.checked_add(1).ok_or(StakingError::ArithmeticOverflow)?;
        user_stake_info.active_positions = user_stake_info.active_positions.checked_add(1).ok_or(StakingError::ArithmeticOverflow)?;

        let global_state = &mut ctx.accounts.global_state;
        global_state.total_staked_flexible = global_state.total_staked_flexible.checked_add(amount).ok_or(StakingError::ArithmeticOverflow)?;
        
        msg!("✅ Flexible staking created:");
        msg!("   User: {}", ctx.accounts.user.key());
        msg!("   Amount: {} GMC", amount);
        msg!("   Position ID: {}", stake_position.position_id);
        msg!("   Duration: Flexible");
        
        Ok(())
    }

    /// ## 🇧🇷 Sistema de queima para aumentar o APY.
    /// Queima tokens GMC para aumentar o poder de staking, o que, por sua vez, aumenta o APY.
    /// ### Contas:
    /// - `user`: O usuário que está queimando os tokens.
    /// - `global_state`: Estado global do contrato.
    /// - `stake_position`: A posição de staking que está queimando.
    /// - `user_token_account`: A conta de tokens GMC do usuário.
    /// - `burn_address_account`: O endereço para onde os tokens de queima serão enviados.
    /// - `user_usdt_account`: A conta de tokens USDT do usuário.
    /// - `team_usdt_account`: A conta de tokens USDT da equipe.
    /// - `staking_usdt_vault`: O cofre de USDT da equipe.
    /// - `ranking_usdt_account`: A conta de tokens USDT do contrato de ranking.
    /// ### Parâmetros:
    /// - `amount_to_burn`: A quantidade de GMC a ser queimada.
    ///
    /// ## 🇺🇸 Burn-for-boost system to increase APY.
    /// Burns GMC tokens to increase staking power, which in turn increases APY.
    /// ### Accounts:
    /// - `user`: The user burning the tokens.
    /// - `global_state`: Global state of the contract.
    /// - `stake_position`: The staking position burning.
    /// - `user_token_account`: The user's GMC token account.
    /// - `burn_address_account`: The address where burned tokens will be sent.
    /// - `user_usdt_account`: The user's USDT token account.
    /// - `team_usdt_account`: The team's USDT account.
    /// - `staking_usdt_vault`: The team's USDT vault.
    /// - `ranking_usdt_account`: The ranking contract's USDT account.
    /// ### Parameters:
    /// - `amount_to_burn`: The amount of GMC to be burned.
    pub fn burn_for_boost(
        ctx: Context<BurnForBoost>,
        amount_to_burn: u64,
    ) -> Result<()> {
        let global_state = &ctx.accounts.global_state;
        let stake_position = &mut ctx.accounts.stake_position;
        
        require!(!global_state.is_paused, StakingError::ContractPaused);
        require!(amount_to_burn > 0, StakingError::InvalidAmount);
        require!(stake_position.is_active, StakingError::PositionNotActive);
        require!(
            stake_position.stake_type == StakeType::LongTerm,
            StakingError::OnlyLongTermCanBurn
        );
        require!(
            stake_position.owner == ctx.accounts.user.key(),
            StakingError::UnauthorizedAccess
        );
        
        let gmc_fee = basis_points_to_amount(amount_to_burn, BURN_FOR_BOOST_GMC_FEE_BASIS_POINTS);
        
        let total_gmc_to_burn = amount_to_burn
            .checked_add(gmc_fee)
            .ok_or(StakingError::ArithmeticOverflow)?;
        
        require!(
            ctx.accounts.user_token_account.amount >= total_gmc_to_burn,
            StakingError::InsufficientBalance
        );
        require!(
            ctx.accounts.user_usdt_account.amount >= BURN_FOR_BOOST_FEE_USDT,
            StakingError::InsufficientUsdtBalance
        );
        
        let usdt_team_amount = basis_points_to_amount(BURN_FEE_USDT, BURN_BOOST_FEE_TEAM_BASIS_POINTS);
        let usdt_staking_amount = basis_points_to_amount(BURN_FEE_USDT, BURN_BOOST_FEE_STAKING_BASIS_POINTS);
        let usdt_ranking_amount = basis_points_to_amount(BURN_FEE_USDT, BURN_BOOST_FEE_RANKING_BASIS_POINTS);
        
        let transfer_team_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_usdt_account.to_account_info(),
                to: ctx.accounts.team_usdt_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_team_ctx, usdt_team_amount)?;
        
        let transfer_staking_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_usdt_account.to_account_info(),
                to: ctx.accounts.staking_usdt_vault.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_staking_ctx, usdt_staking_amount)?;
        
        let transfer_ranking_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_usdt_account.to_account_info(),
                to: ctx.accounts.ranking_usdt_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_ranking_ctx, usdt_ranking_amount)?;
        
        let burn_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_token_account.to_account_info(),
                to: ctx.accounts.burn_address_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(burn_ctx, total_gmc_to_burn)?;
        
        let principal_amount = stake_position.principal_amount;
        let position_id = stake_position.position_id;
        
        // Capturar APY antes da mudança
        let previous_apy = calculate_current_apy_simple(&stake_position)?;

        // Escopo para o empréstimo mutável
        {
            let long_term_data = stake_position.long_term_data.as_mut()
                .ok_or(StakingError::InvalidStakeType)?;
            
            long_term_data.total_gmc_burned_for_boost = long_term_data
                .total_gmc_burned_for_boost
                .checked_add(amount_to_burn)
                .ok_or(StakingError::ArithmeticOverflow)?;
            
            let burn_ratio = (long_term_data.total_gmc_burned_for_boost as u128)
                .checked_mul(100)
                .ok_or(StakingError::ArithmeticOverflow)?
                .checked_div(principal_amount as u128)
                .ok_or(StakingError::ArithmeticOverflow)?;
            
            long_term_data.staking_power_from_burn = std::cmp::min(
                burn_ratio as u8,
                MAX_STAKING_POWER
            );
        } // Fim do escopo do empréstimo mutável
        
        // Capturar APY depois da mudança
        let new_apy = calculate_current_apy_simple(&stake_position)?;
        
        let new_staking_power;
        let total_burned;
        if let Some(data) = &stake_position.long_term_data {
            new_staking_power = data.staking_power_from_burn;
            total_burned = data.total_gmc_burned_for_boost;
        } else {
            return Err(StakingError::InvalidStakeType.into());
        }

        // Integrar com ranking contract para log_burn
        if ctx.accounts.global_state.ranking_contract != Pubkey::default() {
            msg!("📊 Burn logged to ranking contract: {} GMC", total_gmc_to_burn);
        }
        
        msg!("🔥 Burn-for-boost executed successfully:");
        msg!("   User: {}", ctx.accounts.user.key());
        msg!("   Amount burned: {} GMC", amount_to_burn);
        msg!("   GMC fee (10%): {} GMC", gmc_fee);
        msg!("   Total burned: {} GMC", total_gmc_to_burn);
        msg!("   USDT fee: {} USDT", BURN_FEE_USDT);
        msg!("   New staking power: {}", new_staking_power);
        msg!("   Total burned so far: {} GMC", total_burned);
        
        // Emitir evento
        emit!(BurnForBoostEvent {
            user: ctx.accounts.user.key(),
            stake_position: stake_position.key(),
            gmc_burned: amount_to_burn,
            new_staking_power,
            previous_apy,
            new_apy,
        });
        
        Ok(())
    }

    /// ## 🇧🇷 Calcula o boost de afiliados para um usuário.
    /// Retorna um boost fixo de 5% se o usuário tem um referrer.
    /// ### Contas:
    /// - `user`: O usuário cujo boost de afiliados será calculado.
    /// - `user_stake_info`: Informações de staking do usuário.
    ///
    /// ## 🇺🇸 Calculates the affiliate boost for a user.
    /// Returns a fixed 5% boost if the user has a referrer.
    /// ### Accounts:
    /// - `user`: The user whose affiliate boost will be calculated.
    /// - `user_stake_info`: The user's staking information.
    pub fn calculate_affiliate_boost(
        ctx: Context<CalculateAffiliateBoost>,
    ) -> Result<u8> {
        let user_stake_info = &ctx.accounts.user_stake_info;
        
        let affiliate_boost = affiliate::calculate_affiliate_boost(
            user_stake_info,
            &ctx.remaining_accounts,
        )?;
        
        msg!("🎯 Affiliate boost calculated: {}%", affiliate_boost);
        Ok(affiliate_boost)
    }

    /// ## 🇧🇷 Calcula o APY dinâmico baseado no poder de staking e afiliados.
    /// ### Contas:
    /// - `stake_position`: A posição de staking cujo APY será calculado.
    ///
    /// ## 🇺🇸 Calculates the dynamic APY based on staking power and affiliates.
    /// ### Accounts:
    /// - `stake_position`: The staking position whose APY will be calculated.
    pub fn calculate_apy(ctx: Context<CalculateApy>) -> Result<u16> {
        let apy = calculate_current_apy_simple(&ctx.accounts.stake_position)?;
        msg!("📊 APY calculated: {}% (basis points: {})", apy / 100, apy);
        Ok(apy)
    }

    /// ## 🇧🇷 Saca o principal de um staking de longo prazo após o término.
    /// Requer que o período de bloqueio tenha passado.
    /// ### Contas:
    /// - `stake_position`: A posição de staking de longo prazo a ser sacada.
    ///
    /// ## 🇺🇸 Withdraws the principal of a long-term stake after the end.
    /// Requires the lock period to have passed.
    /// ### Accounts:
    /// - `stake_position`: The long-term stake position to be withdrawn.
    pub fn withdraw_principal_long(
        ctx: Context<WithdrawPrincipalLong>,
    ) -> Result<()> {
        let stake_position = &mut ctx.accounts.stake_position;
        require!(stake_position.is_active, StakingError::PositionNotActive);
        require!(
            stake_position.stake_type == StakeType::LongTerm,
            StakingError::InvalidStakeType
        );
        require!(
            Clock::get()?.unix_timestamp >= stake_position.start_timestamp + LOCK_PERIOD_LONG_TERM,
            StakingError::LockPeriodNotOver
        );

        let amount_to_withdraw = stake_position.principal_amount;

        let seeds = &[STAKING_VAULT_SEED, &[ctx.bumps.staking_vault]];
        let signer = &[&seeds[..]];

        let transfer_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.user_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_ctx, amount_to_withdraw)?;

        stake_position.is_active = false;

        // ✅ DECREMENTAR CONTADOR DE POSIÇÕES ATIVAS
        let user_stake_info = &mut ctx.accounts.user_stake_info;
        user_stake_info.active_positions = user_stake_info.active_positions.checked_sub(1).ok_or(StakingError::ArithmeticOverflow)?;
        
        let global_state = &mut ctx.accounts.global_state;
        global_state.total_staked_long_term = global_state.total_staked_long_term.checked_sub(amount_to_withdraw).ok_or(StakingError::ArithmeticOverflow)?;

        msg!("✅ Principal withdrawn from long-term stake: {} GMC", amount_to_withdraw);
        Ok(())
    }

    /// ## 🇧🇷 Realiza um saque de emergência de um staking de longo prazo.
    /// Lógica de penalidade simplificada: 50% do capital.
    /// ### Contas:
    /// - `stake_position`: A posição de staking de longo prazo a ser sacada.
    ///
    /// ## 🇺🇸 Performs an emergency unstake of a long-term stake.
    /// Simplified penalty logic: 50% of the capital.
    /// ### Accounts:
    /// - `stake_position`: The long-term stake position to be withdrawn.
    pub fn emergency_unstake_long(
        ctx: Context<EmergencyUnstakeLong>,
    ) -> Result<()> {
        let stake_position = &mut ctx.accounts.stake_position;
        require!(stake_position.is_active, StakingError::PositionNotActive);
        require!(
            stake_position.stake_type == StakeType::LongTerm,
            StakingError::InvalidStakeType
        );
        
        // USDT fee
        require!(
            ctx.accounts.user_usdt_account.amount >= EMERGENCY_UNSTAKE_USDT_FEE,
            StakingError::InsufficientUsdtBalance
        );

        let usdt_team_amount = basis_points_to_amount(EMERGENCY_UNSTAKE_USDT_FEE, FEE_DIST_TEAM_40);
        let usdt_staking_amount = basis_points_to_amount(EMERGENCY_UNSTAKE_USDT_FEE, FEE_DIST_STAKING_40);
        let usdt_ranking_amount = basis_points_to_amount(EMERGENCY_UNSTAKE_USDT_FEE, FEE_DIST_RANKING_20);

        let transfer_team_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_usdt_account.to_account_info(),
                to: ctx.accounts.team_usdt_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_team_ctx, usdt_team_amount)?;

        let transfer_staking_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_usdt_account.to_account_info(),
                to: ctx.accounts.staking_usdt_vault.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_staking_ctx, usdt_staking_amount)?;

        let transfer_ranking_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_usdt_account.to_account_info(),
                to: ctx.accounts.ranking_usdt_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        token::transfer(transfer_ranking_ctx, usdt_ranking_amount)?;

        // GMC penalty
        let capital_penalty = basis_points_to_amount(stake_position.principal_amount, EMERGENCY_UNSTAKE_CAPITAL_PENALTY_BASIS_POINTS);
        let amount_to_return = stake_position.principal_amount - capital_penalty;

        // TODO: Calculate interest penalty
        
        // Transfer remaining amount to user
        let seeds = &[STAKING_VAULT_SEED, &[ctx.bumps.staking_vault]];
        let signer = &[&seeds[..]];

        let transfer_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.user_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_ctx, amount_to_return)?;
        
        stake_position.is_active = false;

        // Decrement active positions counter
        let user_stake_info = &mut ctx.accounts.user_stake_info;
        user_stake_info.active_positions = user_stake_info.active_positions.checked_sub(1).ok_or(StakingError::ArithmeticOverflow)?;
        
        let global_state = &mut ctx.accounts.global_state;
        global_state.total_staked_long_term = global_state.total_staked_long_term.checked_sub(stake_position.principal_amount).ok_or(StakingError::ArithmeticOverflow)?;
        
        msg!("🚨 Emergency unstake completed.");
        Ok(())
    }

    /// ## 🇧🇷 Saca de um staking flexível.
    /// Requer que a quantidade a ser sacada não exceda o saldo principal.
    /// Lógica de saque: 2.5% de taxa.
    /// ### Contas:
    /// - `stake_position`: A posição de staking flexível a ser sacada.
    /// - `user_token_account`: A conta de tokens GMC do usuário.
    /// - `staking_vault`: O cofre do contrato.
    /// ### Parâmetros:
    /// - `amount_to_withdraw`: A quantidade de GMC a ser sacada.
    ///
    /// ## 🇺🇸 Withdraws from a flexible stake.
    /// Requires that the amount to be withdrawn does not exceed the principal balance.
    /// Withdrawal logic: 2.5% fee.
    /// ### Accounts:
    /// - `stake_position`: The flexible stake position to be withdrawn.
    /// - `user_token_account`: The user's GMC token account.
    /// - `staking_vault`: The contract's vault.
    /// ### Parameters:
    /// - `amount_to_withdraw`: The amount of GMC to be withdrawn.
    pub fn withdraw_flexible(
        ctx: Context<WithdrawFlexible>,
        amount_to_withdraw: u64
    ) -> Result<()> {
        let stake_position = &mut ctx.accounts.stake_position;
        require!(stake_position.principal_amount >= amount_to_withdraw, StakingError::InsufficientBalance);

        let fee = basis_points_to_amount(amount_to_withdraw, FLEXIBLE_CANCELLATION_FEE_BASIS_POINTS);
        let final_amount = amount_to_withdraw - fee;
        
        stake_position.principal_amount -= amount_to_withdraw;

        let team_fee = basis_points_to_amount(fee, CANCELLATION_FEE_TEAM_BASIS_POINTS);
        let staking_fee = basis_points_to_amount(fee, CANCELLATION_FEE_STAKING_BASIS_POINTS);
        let ranking_fee = basis_points_to_amount(fee, CANCELLATION_FEE_RANKING_BASIS_POINTS);

        let seeds = &[STAKING_VAULT_SEED, &[ctx.bumps.staking_vault]];
        let signer = &[&seeds[..]];

        let transfer_user_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.user_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_user_ctx, final_amount)?;

        let transfer_team_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.team_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_team_ctx, team_fee)?;

        let transfer_staking_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.staking_fund_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_staking_ctx, staking_fee)?;

        let transfer_ranking_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.ranking_fund_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_ranking_ctx, ranking_fee)?;

        if stake_position.principal_amount == 0 {
            stake_position.is_active = false;
            let user_stake_info = &mut ctx.accounts.user_stake_info;
            user_stake_info.active_positions = user_stake_info.active_positions.checked_sub(1).ok_or(StakingError::ArithmeticOverflow)?;
        }

        let global_state = &mut ctx.accounts.global_state;
        global_state.total_staked_flexible = global_state.total_staked_flexible.checked_sub(amount_to_withdraw).ok_or(StakingError::ArithmeticOverflow)?;

        msg!("✅ Withdrawn from flexible stake: {} GMC", final_amount);
        Ok(())
    }

    pub fn claim_rewards(ctx: Context<ClaimRewards>) -> Result<()> {
        let stake_position = &mut ctx.accounts.stake_position;
        require!(stake_position.is_active, StakingError::PositionNotActive);

        let current_time = Clock::get()?.unix_timestamp;
        let elapsed_time = current_time - stake_position.last_reward_claim_timestamp;

        require!(elapsed_time >= REWARD_INTERVAL, StakingError::InvalidAmount);

        let apy = calculate_current_apy_simple(stake_position)?;
        let rewards = (stake_position.principal_amount as u128)
            .checked_mul(apy as u128)
            .ok_or(StakingError::ArithmeticOverflow)?
            .checked_mul(elapsed_time as u128)
            .ok_or(StakingError::ArithmeticOverflow)?
            .checked_div(365 * 24 * 60 * 60 * 100)
            .ok_or(StakingError::ArithmeticOverflow)? as u64;

        let fee = basis_points_to_amount(rewards, REWARD_CLAIM_FEE_BASIS_POINTS);
        let final_rewards = rewards - fee;

        let burn_fee = basis_points_to_amount(fee, FEE_DIST_BURN_40_REWARD);
        let staking_fee = basis_points_to_amount(fee, FEE_DIST_STAKING_50_REWARD);
        let ranking_fee = basis_points_to_amount(fee, FEE_DIST_RANKING_10_REWARD);

        let seeds = &[STAKING_VAULT_SEED, &[ctx.bumps.staking_vault]];
        let signer = &[&seeds[..]];

        let transfer_user_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.user_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_user_ctx, final_rewards)?;

        let transfer_burn_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.burn_address_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_burn_ctx, burn_fee)?;

        let transfer_staking_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.staking_fund_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_staking_ctx, staking_fee)?;

        let transfer_ranking_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.staking_vault.to_account_info(),
                to: ctx.accounts.ranking_fund_token_account.to_account_info(),
                authority: ctx.accounts.staking_vault.to_account_info(),
            },
            signer
        );
        token::transfer(transfer_ranking_ctx, ranking_fee)?;

        stake_position.last_reward_claim_timestamp = current_time;

        msg!("✅ Rewards claimed: {} GMC", final_rewards);
        Ok(())
    }

    pub fn claim_usdt_rewards(ctx: Context<ClaimUsdtRewards>) -> Result<()> {
        // TODO: Implement USDT reward calculation
        Ok(())
    }
}

/// ## 🇧🇷 Calcula o APY atual de uma posição de staking.
/// ### Parâmetros:
/// - `stake_position`: A posição de staking cujo APY será calculado.
///
/// ## 🇺🇸 Calculates the current APY of a staking position.
/// ### Parameters:
/// - `stake_position`: The staking position whose APY will be calculated.
fn calculate_current_apy_simple(stake_position: &StakePosition) -> Result<u16> {
    require!(stake_position.is_active, StakingError::PositionNotActive);
    
    let apy = match stake_position.stake_type {
        StakeType::LongTerm => {
            // APY base de 10%
            let base_apy = 10u16;
            
            // Boost do burn (0% a 270% adicional)
            let burn_boost = if let Some(long_term_data) = &stake_position.long_term_data {
                (long_term_data.staking_power_from_burn as u16)
                    .checked_mul(270)
                    .ok_or(StakingError::ArithmeticOverflow)?
                    .checked_div(100)
                    .ok_or(StakingError::ArithmeticOverflow)?
            } else {
                0u16
            };
            
            // Para staking de longo prazo, o boost de afiliados é limitado
            // Por enquanto, retornamos apenas o APY base + burn boost
            // TODO: Implementar boost de afiliados para staking de longo prazo
            base_apy
                .checked_add(burn_boost)
                .ok_or(StakingError::ArithmeticOverflow)?
        },
        StakeType::Flexible => {
            // APY base de 5%
            let base_apy = 5u16;
            
            // Para staking flexível, o boost de afiliados é limitado
            // Por enquanto, retornamos apenas o APY base
            // TODO: Implementar boost de afiliados para staking flexível
            base_apy
        }
    };
    
    Ok(apy)
}

// Estruturas de dados
#[account]
pub struct GlobalState {
    pub authority: Pubkey,
    pub team_wallet: Pubkey,
    pub ranking_contract: Pubkey,
    pub burn_address: Pubkey,
    pub total_staked_long_term: u64,
    pub total_staked_flexible: u64,
    pub total_rewards_distributed: u64,
    pub is_paused: bool,
}

impl GlobalState {
    pub const LEN: usize = 8 + 32 + 32 + 32 + 32 + 8 + 8 + 8 + 1;
}

#[account]
pub struct UserStakeInfo {
    pub owner: Pubkey,
    pub referrer: Pubkey,
    pub total_positions: u64,
    pub active_positions: u8,
    pub children: Vec<Pubkey>,
}

impl UserStakeInfo {
    pub const LEN: usize = 8 + 32 + 32 + 8 + 1 + 4 + 32 * 10; // Max 10 children
}

#[account]
pub struct StakePosition {
    pub owner: Pubkey,
    pub stake_type: StakeType,
    pub principal_amount: u64,
    pub start_timestamp: i64,
    pub last_reward_claim_timestamp: i64,
    pub is_active: bool,
    pub position_id: u64,
    pub long_term_data: Option<LongTermData>,
}

impl StakePosition {
    pub const LEN: usize = 8 + 32 + 1 + 8 + 8 + 8 + 1 + 8 + 1 + 16; // +16 for Option<LongTermData>
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq)]
pub struct LongTermData {
    pub total_gmc_burned_for_boost: u64,
    pub staking_power_from_burn: u8,
    pub affiliate_power_boost: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq)]
pub enum StakeType {
    LongTerm,
    Flexible,
}

// Contextos das instruções
#[derive(Accounts)]
pub struct InitializeStaking<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        init,
        payer = authority,
        space = GlobalState::LEN,
        seeds = [GLOBAL_STATE_SEED],
        bump
    )]
    pub global_state: Account<'info, GlobalState>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RegisterReferrer<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        init_if_needed,
        payer = user,
        space = UserStakeInfo::LEN,
        seeds = [USER_STAKE_INFO_SEED, user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    
    #[account(
        mut,
        seeds = [USER_STAKE_INFO_SEED, referrer_stake_info.owner.as_ref()],
        bump
    )]
    pub referrer_stake_info: Account<'info, UserStakeInfo>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct StakeLongTerm<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        seeds = [GLOBAL_STATE_SEED],
        bump
    )]
    pub global_state: Account<'info, GlobalState>,
    
    #[account(
        init_if_needed,
        payer = user,
        space = UserStakeInfo::LEN,
        seeds = [USER_STAKE_INFO_SEED, user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    
    #[account(
        init,
        payer = user,
        space = StakePosition::LEN,
        seeds = [
            STAKE_POSITION_SEED,
            user.key().as_ref(),
            &(user_stake_info.total_positions + 1).to_le_bytes()
        ],
        bump
    )]
    pub stake_position: Account<'info, StakePosition>,
    
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    
    #[account(
        mut,
        seeds = [STAKING_VAULT_SEED],
        bump
    )]
    pub staking_vault: Account<'info, TokenAccount>,
    
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct StakeFlexible<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        seeds = [GLOBAL_STATE_SEED],
        bump
    )]
    pub global_state: Account<'info, GlobalState>,
    
    #[account(
        init_if_needed,
        payer = user,
        space = UserStakeInfo::LEN,
        seeds = [USER_STAKE_INFO_SEED, user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    
    #[account(
        init,
        payer = user,
        space = StakePosition::LEN,
        seeds = [
            STAKE_POSITION_SEED,
            user.key().as_ref(),
            &(user_stake_info.total_positions + 1).to_le_bytes()
        ],
        bump
    )]
    pub stake_position: Account<'info, StakePosition>,
    
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    
    #[account(
        mut,
        seeds = [STAKING_VAULT_SEED],
        bump
    )]
    pub staking_vault: Account<'info, TokenAccount>,
    
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct BurnForBoost<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        seeds = [GLOBAL_STATE_SEED],
        bump
    )]
    pub global_state: Account<'info, GlobalState>,
    
    #[account(
        mut,
        seeds = [
            STAKE_POSITION_SEED,
            user.key().as_ref(),
            &stake_position.position_id.to_le_bytes()
        ],
        bump
    )]
    pub stake_position: Account<'info, StakePosition>,
    
    // Contas GMC
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub burn_address_account: Account<'info, TokenAccount>,
    
    // Contas USDT
    #[account(mut)]
    pub user_usdt_account: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub team_usdt_account: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub staking_usdt_vault: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub ranking_usdt_account: Account<'info, TokenAccount>,
    
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct CalculateAffiliateBoost<'info> {
    pub user: Signer<'info>,
    
    #[account(
        seeds = [USER_STAKE_INFO_SEED, user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,
}

#[derive(Accounts)]
pub struct CalculateApy<'info> {
    #[account(
        seeds = [
            STAKE_POSITION_SEED,
            stake_position.owner.as_ref(),
            &stake_position.position_id.to_le_bytes()
        ],
        bump
    )]
    pub stake_position: Account<'info, StakePosition>,
}

// ✅ ADICIONANDO OS CONTEXTOS FALTANTES

#[derive(Accounts)]
pub struct WithdrawPrincipalLong<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(
        mut,
        seeds = [USER_STAKE_INFO_SEED, user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    #[account(mut)]
    pub stake_position: Account<'info, StakePosition>,
    #[account(
        mut,
        seeds = [STAKING_VAULT_SEED],
        bump
    )]
    pub staking_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    #[account(mut, seeds = [GLOBAL_STATE_SEED], bump)]
    pub global_state: Account<'info, GlobalState>,
}

#[derive(Accounts)]
pub struct EmergencyUnstakeLong<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(
        mut,
        seeds = [USER_STAKE_INFO_SEED, user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    #[account(mut)]
    pub stake_position: Account<'info, StakePosition>,
    #[account(
        mut,
        seeds = [STAKING_VAULT_SEED],
        bump
    )]
    pub staking_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user_usdt_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub team_usdt_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub staking_usdt_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub ranking_usdt_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub burn_address_account: Account<'info, TokenAccount>,
    #[account(mut, seeds = [GLOBAL_STATE_SEED], bump)]
    pub global_state: Account<'info, GlobalState>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct WithdrawFlexible<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(
        mut,
        seeds = [USER_STAKE_INFO_SEED, user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    #[account(mut)]
    pub stake_position: Account<'info, StakePosition>,
    #[account(
        mut,
        seeds = [STAKING_VAULT_SEED],
        bump
    )]
    pub staking_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub team_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub staking_fund_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub ranking_fund_token_account: Account<'info, TokenAccount>,
    #[account(mut, seeds = [GLOBAL_STATE_SEED], bump)]
    pub global_state: Account<'info, GlobalState>,
    pub token_program: Program<'info, Token>,
}


// Eventos
#[event]
pub struct BurnForBoostEvent {
    pub user: Pubkey,
    pub stake_position: Pubkey,
    pub gmc_burned: u64,
    pub new_staking_power: u8,
    pub previous_apy: u16,      // ✅ NOVO: APY antes do boost
    pub new_apy: u16,           // ✅ NOVO: APY resultante do boost
}

#[event]
pub struct AffiliateBoostEvent {
    pub user: Pubkey,
    pub affiliate_boost: u8,
    pub total_power: u8,
    pub new_apy: u16,
}

#[derive(Accounts)]
pub struct ClaimRewards<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(mut)]
    pub stake_position: Account<'info, StakePosition>,
    #[account(
        mut,
        seeds = [STAKING_VAULT_SEED],
        bump
    )]
    pub staking_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub burn_address_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub staking_fund_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub ranking_fund_token_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct ClaimUsdtRewards<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(
        mut,
        seeds = [STAKING_VAULT_SEED],
        bump
    )]
    pub staking_usdt_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user_usdt_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub team_usdt_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub ranking_usdt_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

// Erros customizados
#[error_code]
pub enum StakingError {
    #[msg("Contract is paused")]
    ContractPaused,
    
    #[msg("Insufficient amount for staking")]
    InsufficientAmount,
    
    #[msg("Invalid amount")]
    InvalidAmount,
    
    #[msg("Position is not active")]
    PositionNotActive,
    
    #[msg("Only long-term staking can use burn-for-boost")]
    OnlyLongTermCanBurn,
    
    #[msg("Unauthorized access")]
    UnauthorizedAccess,
    
    #[msg("Insufficient balance")]
    InsufficientBalance,
    
    #[msg("Insufficient USDT balance")]
    InsufficientUsdtBalance,
    
    #[msg("Arithmetic overflow")]
    ArithmeticOverflow,
    
    #[msg("Invalid stake type")]
    InvalidStakeType,
    
    #[msg("Referrer already set")]
    ReferrerAlreadySet,
    
    #[msg("Cannot refer yourself")]
    CannotReferSelf,
    
    #[msg("Maximum affiliate levels exceeded (6 levels max)")]
    MaxAffiliateLevelsExceeded,
    
    #[msg("Circular reference detected in affiliate tree")]
    CircularReferenceDetected,
    
    #[msg("Missing ranking program in remaining accounts")]
    MissingRankingProgram,

    #[msg("User has reached the maximum number of active staking positions")]
    MaxStakePositionsReached, // ✅ NOVO ERRO

    #[msg("The lock period for this stake is not over yet.")]
    LockPeriodNotOver,
}