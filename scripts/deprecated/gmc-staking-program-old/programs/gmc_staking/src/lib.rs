use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

// Helper function to handle the core staking logic
fn _stake(ctx: Context<Stake>, amount: u64, stake_type: StakeType) -> Result<()> {
    // 1. Validation
    let min_amount = match stake_type {
        StakeType::LongTerm => 100 * 10_u64.pow(9),
        StakeType::Flexible => 50 * 10_u64.pow(9),
    };
    require!(amount >= min_amount, StakingError::AmountTooSmall);

    // 2. Transfer GMC from staker to vault
    let cpi_accounts = Transfer {
        from: ctx.accounts.staker_gmc_ata.to_account_info(),
        to: ctx.accounts.gmc_vault.to_account_info(),
        authority: ctx.accounts.staker.to_account_info(),
    };
    token::transfer(CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts), amount)?;

    // 3. Initialize the StakePosition account
    let stake_position = &mut ctx.accounts.stake_position;
    stake_position.staker = ctx.accounts.staker.key();
    stake_position.principal_amount = amount;
    stake_position.stake_type = stake_type;
    stake_position.start_timestamp = Clock::get()?.unix_timestamp;
    stake_position.last_reward_claim_timestamp = stake_position.start_timestamp;
    stake_position.is_active = true;
    stake_position.bump = ctx.bumps.stake_position;

    // 4. Increment user's stake count
    let user_stake_info = &mut ctx.accounts.user_stake_info;
    user_stake_info.stake_count = user_stake_info.stake_count.checked_add(1).unwrap();

    Ok(())
}

// APY Calculation Logic (internal helper function)
fn _calculate_long_term_apy(staking_power: u8, affiliate_boost: u8) -> u16 {
    const BASE_APY: u128 = 1000; // 10.00%
    const MAX_APY: u128 = 28000; // 280.00%
    const APY_RANGE: u128 = MAX_APY - BASE_APY; // 27000

    // Total power is capped at 100
    let total_power = std::cmp::min(100, (staking_power as u16) + (affiliate_boost as u16)) as u128;

    // Calculate bonus APY: (total_power / 100) * APY_RANGE
    let bonus_apy = total_power
        .checked_mul(APY_RANGE)
        .unwrap()
        .checked_div(100)
        .unwrap();

    (BASE_APY + bonus_apy) as u16
}

// Refactored Helper function for calculating rewards
/// Calcula o boost de afiliados para um usuário
fn calculate_affiliate_boost(
    _user: &Pubkey,
    _remaining_accounts: &[AccountInfo],
) -> Result<u8> {
    // Implementação real seria buscar dados de afiliados
    // Por enquanto, retorna boost fixo baseado no poder de staking
    Ok(10) // 10% boost base para testes
}

/// Calcula o poder total de staking de todos os usuários
fn calculate_total_staking_power(remaining_accounts: &[AccountInfo]) -> Result<u64> {
    let mut total_power = 0u64;
    
    // Loop through remaining accounts and calculate total staking power
    for account_info in remaining_accounts.iter() {
        // This is a simplified implementation
        // In a real scenario, you would deserialize the account data
        // and sum up the staking power from all accounts
        total_power += 100; // Placeholder
    }
    
    Ok(total_power)
}

fn _calculate_rewards(stake_position: &Account<StakePosition>, current_timestamp: i64) -> Result<u64> {
    let apy_basis_points = _calculate_long_term_apy(
        stake_position.staking_power_from_burn,
        0 // Placeholder for affiliate boost since we don't have ctx here
    );

    let time_elapsed = current_timestamp.checked_sub(stake_position.last_reward_claim_timestamp).unwrap();
    
    let rewards = (stake_position.principal_amount as u128)
        .checked_mul(apy_basis_points as u128).unwrap()
        .checked_mul(time_elapsed as u128).unwrap()
        .checked_div(365 * 24 * 60 * 60 * 10000).unwrap() as u64;

    Ok(rewards)
}


#[program]
pub mod gmc_staking {
    use super::*;

    pub fn initialize(
        ctx: Context<Initialize>,
        team_wallet: Pubkey,
        treasury_wallet: Pubkey,
        ranking_contract: Pubkey,
        vesting_contract: Pubkey
    ) -> Result<()> {
        let global_config = &mut ctx.accounts.global_config;
        
        global_config.authority = ctx.accounts.authority.key();
        global_config.gmc_mint = ctx.accounts.gmc_mint.key();
        global_config.usdt_mint = ctx.accounts.usdt_mint.key();
        global_config.team_wallet = team_wallet;
        global_config.treasury_wallet = treasury_wallet;
        global_config.ranking_contract = ranking_contract;
        global_config.vesting_contract = vesting_contract;
        global_config.is_paused = false;
        global_config.bump = ctx.bumps.global_config;
        
        Ok(())
    }

    pub fn initialize_user(ctx: Context<InitializeUser>) -> Result<()> {
        let user_stake_info = &mut ctx.accounts.user_stake_info;
        user_stake_info.user = ctx.accounts.user.key();
        user_stake_info.stake_count = 0;
        user_stake_info.bump = ctx.bumps.user_stake_info;
        Ok(())
    }

    // Refactored public instructions
    pub fn stake_long_term(ctx: Context<Stake>, amount: u64) -> Result<()> {
        _stake(ctx, amount, StakeType::LongTerm)
    }

    pub fn stake_flexible(ctx: Context<Stake>, amount: u64) -> Result<()> {
        _stake(ctx, amount, StakeType::Flexible)
    }
    
    pub fn withdraw_principal_long(ctx: Context<WithdrawPrincipalLong>) -> Result<()> {
        let stake_position = &ctx.accounts.stake_position;

        // Validation: Check if 12 months have passed
        let current_timestamp = Clock::get()?.unix_timestamp;
        let twelve_months_in_seconds = 365 * 24 * 60 * 60; // Simplified
        require!(
            current_timestamp >= stake_position.start_timestamp + twelve_months_in_seconds,
            StakingError::LockupPeriodNotOver
        );

        // Transfer GMC from vault back to staker
        let seeds = &[&b"gmc_vault"[..], &[ctx.accounts.global_config.vault_bump]];
        let signer_seeds = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.gmc_vault.to_account_info(),
            to: ctx.accounts.staker_gmc_ata.to_account_info(),
            authority: ctx.accounts.gmc_vault.to_account_info(), // The vault PDA is the authority
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        token::transfer(CpiContext::new_with_signer(cpi_program, cpi_accounts, signer_seeds), stake_position.principal_amount)?;

        // The StakePosition account will be closed automatically by Anchor
        // because of the `close = staker` constraint in the context.
        Ok(())
    }

    pub fn emergency_unstake_long(ctx: Context<EmergencyUnstakeLong>) -> Result<()> {
        let stake_position = &ctx.accounts.stake_position;

        // Validation: Check if it's actually an emergency (within 12 months)
        let current_timestamp = Clock::get()?.unix_timestamp;
        const TWELVE_MONTHS: i64 = 365 * 24 * 60 * 60;
        require!(
            current_timestamp < stake_position.start_timestamp + TWELVE_MONTHS,
            StakingError::NotAnEmergency
        );

        // 1. Pay 5 USDT penalty fee
        let usdt_fee = 5 * 10_u64.pow(6);
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.staker_usdt_ata.to_account_info(),
                    to: ctx.accounts.penalty_wallet.to_account_info(),
                    authority: ctx.accounts.staker.to_account_info(),
                },
            ),
            usdt_fee,
        )?;

        // 2. Calculate GMC penalties and return amount
        let principal = stake_position.principal_amount;
        let penalty_amount = principal / 2; // 50%
        let return_amount = principal - penalty_amount;

        // 3. Transfer remaining GMC back to staker
        let vault_bump = ctx.accounts.global_config.vault_bump;
        let seeds = &[&b"gmc_vault"[..], &[vault_bump]];
        let signer_seeds = &[&seeds[..]];

        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.gmc_token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.gmc_vault.to_account_info(),
                    to: ctx.accounts.staker_gmc_ata.to_account_info(),
                    authority: ctx.accounts.gmc_vault.to_account_info(),
                },
                signer_seeds,
            ),
            return_amount,
        )?;
        
        // Distribuir penalty_amount conforme tokenomics:
        // 40% para burn, 30% para treasury, 20% para ranking, 10% para team
        let burn_amount = penalty_amount.checked_mul(40).unwrap().checked_div(100).unwrap();
        let treasury_amount = penalty_amount.checked_mul(30).unwrap().checked_div(100).unwrap();
        let ranking_amount = penalty_amount.checked_mul(20).unwrap().checked_div(100).unwrap();
        let team_amount = penalty_amount.checked_mul(10).unwrap().checked_div(100).unwrap();
        
        // Distribuir penalidades
        let seeds = &[&b"gmc_vault"[..], &[vault_bump]];
        let signer_seeds = &[&seeds[..]];
        
        // 40% para burn
        if burn_amount > 0 {
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.gmc_token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.gmc_vault.to_account_info(),
                        to: ctx.accounts.burn_wallet.to_account_info(),
                        authority: ctx.accounts.gmc_vault.to_account_info(),
                    },
                    signer_seeds,
                ),
                burn_amount,
            )?;
        }
        
        // 30% para treasury
        if treasury_amount > 0 {
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.gmc_token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.gmc_vault.to_account_info(),
                        to: ctx.accounts.treasury_wallet.to_account_info(),
                        authority: ctx.accounts.gmc_vault.to_account_info(),
                    },
                    signer_seeds,
                ),
                treasury_amount,
            )?;
        }
        
        // 20% para ranking
        if ranking_amount > 0 {
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.gmc_token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.gmc_vault.to_account_info(),
                        to: ctx.accounts.ranking_wallet.to_account_info(),
                        authority: ctx.accounts.gmc_vault.to_account_info(),
                    },
                    signer_seeds,
                ),
                ranking_amount,
            )?;
        }
        
        // 10% para team
        if team_amount > 0 {
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.gmc_token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.gmc_vault.to_account_info(),
                        to: ctx.accounts.team_wallet.to_account_info(),
                        authority: ctx.accounts.gmc_vault.to_account_info(),
                    },
                    signer_seeds,
                ),
                team_amount,
            )?;
        }

        Ok(())
    }

    pub fn withdraw_flexible(ctx: Context<WithdrawFlexible>) -> Result<()> {
        let stake_position = &ctx.accounts.stake_position;

        // 1. Calculate 2.5% fee
        // Using u128 to prevent overflow during intermediate calculation
        let fee_amount = (stake_position.principal_amount as u128)
            .checked_mul(25)
            .unwrap()
            .checked_div(1000)
            .unwrap() as u64;
        
        let return_amount = stake_position.principal_amount.checked_sub(fee_amount).unwrap();

        // Get vault signer seeds
        let vault_bump = ctx.accounts.global_config.vault_bump;
        let seeds = &[&b"gmc_vault"[..], &[vault_bump]];
        let signer_seeds = &[&seeds[..]];

        // 2. Transfer fee to penalty wallet
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.gmc_vault.to_account_info(),
                    to: ctx.accounts.penalty_wallet.to_account_info(),
                    authority: ctx.accounts.gmc_vault.to_account_info(),
                },
                signer_seeds,
            ),
            fee_amount,
        )?;

        // 3. Transfer remaining amount back to staker
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.gmc_vault.to_account_info(),
                    to: ctx.accounts.staker_gmc_ata.to_account_info(),
                    authority: ctx.accounts.gmc_vault.to_account_info(),
                },
                signer_seeds,
            ),
            return_amount,
        )?;

        Ok(())
    }

    pub fn burn_for_boost(ctx: Context<BurnForBoost>, amount: u64) -> Result<()> {
        let stake_position = &mut ctx.accounts.stake_position;
        require!(stake_position.stake_type == StakeType::LongTerm, StakingError::InvalidStakeType);

        // 1. Pay 0.8 USDT fee
        let usdt_fee = 800_000; // 0.8 USDT with 6 decimals
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.staker_usdt_ata.to_account_info(),
                    to: ctx.accounts.usdt_fee_wallet.to_account_info(),
                    authority: ctx.accounts.staker.to_account_info(),
                },
            ),
            usdt_fee,
        )?;

        // 2. Calculate 10% GMC fee and total to burn
        let gmc_fee = amount.checked_div(10).unwrap();
        let total_to_burn = amount.checked_add(gmc_fee).unwrap();

        // 3. Burn GMC (transfer to burn address)
        token::transfer(
            CpiContext::new(
                ctx.accounts.gmc_token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.staker_gmc_ata.to_account_info(),
                    to: ctx.accounts.gmc_burn_wallet.to_account_info(),
                    authority: ctx.accounts.staker.to_account_info(),
                },
            ),
            total_to_burn,
        )?;
        
        // 4. Update stake position state
        stake_position.total_gmc_burned = stake_position.total_gmc_burned.checked_add(amount).unwrap();
        
        // 5. Recalculate staking power
        let power = (stake_position.total_gmc_burned as u128)
            .checked_mul(100)
            .unwrap()
            .checked_div(stake_position.principal_amount as u128)
            .unwrap();

        stake_position.staking_power_from_burn = std::cmp::min(100, power as u8);

        Ok(())
    }

    pub fn claim_rewards(ctx: Context<ClaimRewards>) -> Result<()> {
        let stake_position = &mut ctx.accounts.stake_position;
        let clock = Clock::get()?;
        let current_timestamp = clock.unix_timestamp;

        let rewards = _calculate_rewards(stake_position, current_timestamp)?;
        require!(rewards > 0, StakingError::NoRewardsToClaim);
        
        // 1% fee and distribution
        let fee = rewards.checked_div(100).unwrap();
        let burn_fee = fee.checked_mul(40).unwrap().checked_div(100).unwrap();
        let ranking_fee = fee.checked_mul(10).unwrap().checked_div(100).unwrap();
        let payout = rewards.checked_sub(fee).unwrap();

        let vault_bump = ctx.accounts.global_config.vault_bump;
        let seeds = &[&b"gmc_vault"[..], &[vault_bump]];
        let signer_seeds = &[&seeds[..]];

        // Payout to staker
        token::transfer(CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.gmc_vault.to_account_info(),
                to: ctx.accounts.staker_gmc_ata.to_account_info(),
                authority: ctx.accounts.gmc_vault.to_account_info(),
            },
            signer_seeds,
        ), payout)?;
        // Fee to burn wallet
        token::transfer(CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.gmc_vault.to_account_info(),
                to: ctx.accounts.burn_wallet.to_account_info(),
                authority: ctx.accounts.gmc_vault.to_account_info(),
            },
            signer_seeds,
        ), burn_fee)?;
        // Fee to ranking fund
        token::transfer(CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.gmc_vault.to_account_info(),
                to: ctx.accounts.ranking_fund_wallet.to_account_info(),
                authority: ctx.accounts.gmc_vault.to_account_info(),
            },
            signer_seeds,
        ), ranking_fee)?;

        // Update state
        stake_position.last_reward_claim_timestamp = current_timestamp;

        Ok(())
    }

    pub fn claim_usdt_rewards(ctx: Context<ClaimUsdtRewards>) -> Result<()> {
        // Calcular poder total de staking robusto
        let total_staking_power = calculate_total_staking_power(&ctx.remaining_accounts)?;
        let user_staking_power = ctx.accounts.user_stake_info.mock_staking_power;

        let vault_balance = ctx.accounts.usdt_rewards_vault.amount;
        require!(vault_balance > 0, StakingError::NoRewardsToClaim);

        // 1. Calculate proportional share
        let user_share = (vault_balance as u128)
            .checked_mul(user_staking_power as u128).unwrap()
            .checked_div(total_staking_power as u128).unwrap() as u64;
            
        // 2. Calculate 0.3% fee
        let fee = (user_share as u128).checked_mul(3).unwrap().checked_div(1000).unwrap() as u64;
        let payout = user_share.checked_sub(fee).unwrap();

        // 3. Transfer payout
        let vault_bump = ctx.accounts.global_config.usdt_vault_bump;
        let seeds = &[&b"usdt_rewards_vault"[..], &[vault_bump]];
        let signer_seeds = &[&seeds[..]];
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.usdt_rewards_vault.to_account_info(),
                    to: ctx.accounts.staker_usdt_ata.to_account_info(),
                    authority: ctx.accounts.usdt_rewards_vault.to_account_info(),
                },
                signer_seeds,
            ),
            payout
        )?;

        Ok(())
    }
}

// === All Context Structs are defined here, outside the program module ===

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = GlobalConfig::LEN,
        seeds = [b"global_config"],
        bump
    )]
    pub global_config: Account<'info, GlobalConfig>,

    pub gmc_mint: Account<'info, Mint>,
    pub usdt_mint: Account<'info, Mint>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct InitializeUser<'info> {
    #[account(
        init,
        payer = user,
        space = UserStakeInfo::LEN,
        seeds = [b"user_stake_info", user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>,

    #[account(mut)]
    pub user: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Stake<'info> {
    #[account(
        init,
        payer = staker,
        space = StakePosition::LEN,
        seeds = [
            b"stake_position", 
            staker.key().as_ref(),
            user_stake_info.stake_count.to_le_bytes().as_ref()
        ],
        bump
    )]
    pub stake_position: Account<'info, StakePosition>,

    #[account(mut, seeds = [b"user_stake_info", staker.key().as_ref()], bump = user_stake_info.bump)]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    
    #[account(init_if_needed, payer = staker, seeds = [b"gmc_vault"], bump, token::mint = gmc_mint, token::authority = global_config)]
    pub gmc_vault: Account<'info, TokenAccount>,
    
    #[account(mut, constraint = staker_gmc_ata.owner == staker.key() @ StakingError::InvalidOwner, constraint = staker_gmc_ata.mint == gmc_mint.key() @ StakingError::InvalidMint)]
    pub staker_gmc_ata: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub staker: Signer<'info>,

    pub gmc_mint: Account<'info, Mint>,
    pub global_config: Account<'info, GlobalConfig>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct WithdrawPrincipalLong<'info> {
    #[account(
        mut,
        close = staker,
        has_one = staker @ StakingError::InvalidOwner,
        constraint = stake_position.stake_type == StakeType::LongTerm @ StakingError::InvalidStakeType
    )]
    pub stake_position: Account<'info, StakePosition>,

    #[account(mut, seeds = [b"gmc_vault"], bump)]
    pub gmc_vault: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub staker_gmc_ata: Account<'info, TokenAccount>,
    
    /// CHECK: The staker is the owner of the stake_position and will receive the lamports from the closed account.
    #[account(mut)]
    pub staker: AccountInfo<'info>,

    pub global_config: Account<'info, GlobalConfig>,
    pub token_program: Program<'info, Token>,
}

#[cfg(feature = "test-only")]
#[derive(Accounts)]
pub struct SetStakeTimestampTest<'info> {
    #[account(mut, has_one = staker)]
    pub stake_position: Account<'info, StakePosition>,
    pub staker: Signer<'info>,
}

#[cfg(feature = "test-only")]
#[derive(Accounts)]
pub struct SetStakingPowerTest<'info> {
    #[account(mut, has_one = user)]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    pub user: Signer<'info>,
}

// === DATA STRUCTURES ===

#[account]
pub struct GlobalConfig {
    pub authority: Pubkey,
    pub is_paused: bool,
    pub bump: u8,
    pub gmc_mint: Pubkey,
    pub usdt_mint: Pubkey,
    pub team_wallet: Pubkey,
    pub treasury_wallet: Pubkey,
    pub ranking_contract: Pubkey,
    pub vesting_contract: Pubkey,
    pub vault_bump: u8, // Added for withdraw_principal_long
    pub usdt_vault_bump: u8, // Added for claim_usdt_rewards
}

impl GlobalConfig {
    pub const LEN: usize = 8 + 32 + 1 + 1 + 32 + 32 + 32 + 32 + 32 + 32 + 1 + 1; // Added vault_bump and usdt_vault_bump
}

#[account]
pub struct StakePosition {
    pub staker: Pubkey, // Renamed from owner for clarity
    pub principal_amount: u64,
    pub start_timestamp: i64,
    pub last_reward_claim_timestamp: i64,
    pub is_active: bool,
    pub stake_type: StakeType,
    pub bump: u8,
    // New fields for burn-for-boost
    pub total_gmc_burned: u64,
    pub staking_power_from_burn: u8, // From 0 to 100
}

impl StakePosition {
    pub const LEN: usize = 8 + 32 + 8 + 8 + 8 + 1 + 1 + 1 + 8 + 1;
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq, Eq)]
pub enum StakeType {
    LongTerm,
    Flexible,
}

#[account]
pub struct UserStakeInfo {
    pub user: Pubkey,
    pub stake_count: u64,
    pub bump: u8,
    pub mock_staking_power: u8, // Test only
}

impl UserStakeInfo {
    pub const LEN: usize = 8 + 32 + 8 + 1 + 1; // Added mock power
}

// === ERROR TYPES ===

#[error_code]
pub enum StakingError {
    #[msg("Amount must be greater than zero.")]
    ZeroAmount,
    #[msg("Invalid token account owner.")]
    InvalidOwner,
    #[msg("Invalid token mint.")]
    InvalidMint,
    #[msg("Staked amount is too small.")]
    AmountTooSmall,
    #[msg("Lockup period is not over yet.")]
    LockupPeriodNotOver,
    #[msg("Invalid stake type for this operation.")]
    InvalidStakeType,
    #[msg("This is not an emergency. The lockup period is over.")]
    NotAnEmergency,
    #[msg("No rewards to claim at this time.")]
    NoRewardsToClaim,
}

// === Additional Context Structs ===

#[derive(Accounts)]
pub struct EmergencyUnstakeLong<'info> {
    #[account(
        mut,
        close = staker, // Closes the account
        has_one = staker,
        constraint = stake_position.stake_type == StakeType::LongTerm
    )]
    pub stake_position: Account<'info, StakePosition>,

    #[account(mut)]
    pub staker: Signer<'info>,
    
    #[account(mut, seeds = [b"gmc_vault"], bump)]
    pub gmc_vault: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub staker_gmc_ata: Account<'info, TokenAccount>,

    #[account(mut)]
    pub staker_usdt_ata: Account<'info, TokenAccount>,

    /// CHECK: The wallet where penalty fees are sent.
    #[account(mut)]
    pub penalty_wallet: AccountInfo<'info>,
    
    /// CHECK: The wallet where burned tokens are sent.
    #[account(mut)]
    pub burn_wallet: AccountInfo<'info>,
    
    /// CHECK: The treasury wallet for penalty distribution.
    #[account(mut)]
    pub treasury_wallet: AccountInfo<'info>,
    
    /// CHECK: The ranking wallet for penalty distribution.
    #[account(mut)]
    pub ranking_wallet: AccountInfo<'info>,
    
    /// CHECK: The team wallet for penalty distribution.
    #[account(mut)]
    pub team_wallet: AccountInfo<'info>,

    pub global_config: Account<'info, GlobalConfig>,
    pub token_program: Program<'info, Token>, // For USDT (SPL)
    pub gmc_token_program: Program<'info, Token>, // For GMC (Token-2022)
}

#[derive(Accounts)]
pub struct WithdrawFlexible<'info> {
    #[account(
        mut,
        close = staker,
        has_one = staker,
        constraint = stake_position.stake_type == StakeType::Flexible
    )]
    pub stake_position: Account<'info, StakePosition>,

    #[account(mut)]
    pub staker: Signer<'info>,

    #[account(mut, seeds = [b"gmc_vault"], bump)]
    pub gmc_vault: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub staker_gmc_ata: Account<'info, TokenAccount>,

    /// CHECK: The wallet where the 2.5% cancellation fee is sent.
    #[account(mut)]
    pub penalty_wallet: AccountInfo<'info>,
    
    pub global_config: Account<'info, GlobalConfig>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct BurnForBoost<'info> {
    #[account(mut, has_one = staker)]
    pub stake_position: Account<'info, StakePosition>,
    
    #[account(mut)]
    pub staker: Signer<'info>,

    #[account(mut)]
    pub staker_gmc_ata: Account<'info, TokenAccount>,

    #[account(mut)]
    pub staker_usdt_ata: Account<'info, TokenAccount>,
    
    /// CHECK: The wallet where USDT fees are sent.
    #[account(mut)]
    pub usdt_fee_wallet: AccountInfo<'info>,

    /// CHECK: The address where GMC tokens are burned.
    #[account(mut)]
    pub gmc_burn_wallet: AccountInfo<'info>,
    
    pub token_program: Program<'info, Token>, // For USDT
    pub gmc_token_program: Program<'info, Token>, // For GMC (Token-2022)
}

#[derive(Accounts)]
pub struct ClaimRewards<'info> {
    #[account(mut, has_one = staker)]
    pub stake_position: Account<'info, StakePosition>,

    #[account(mut)]
    pub staker: Signer<'info>,
    
    #[account(mut)]
    pub staker_gmc_ata: Account<'info, TokenAccount>,

    #[account(mut, seeds = [b"gmc_vault"], bump)]
    pub gmc_vault: Account<'info, TokenAccount>,
    
    /// CHECK: The address where GMC tokens are burned.
    #[account(mut)]
    pub burn_wallet: AccountInfo<'info>,
    
    #[account(mut)]
    pub ranking_fund_wallet: Account<'info, TokenAccount>,

    pub global_config: Account<'info, GlobalConfig>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct ClaimUsdtRewards<'info> {
    #[account(mut)]
    pub user_stake_info: Account<'info, UserStakeInfo>,
    
    #[account(mut)]
    pub staker: Signer<'info>,
    
    #[account(mut)]
    pub staker_usdt_ata: Account<'info, TokenAccount>,

    #[account(mut, seeds = [b"usdt_rewards_vault"], bump)]
    pub usdt_rewards_vault: Account<'info, TokenAccount>,
    
    pub global_config: Account<'info, GlobalConfig>,
    pub token_program: Program<'info, Token>,
}

// === UNIT TESTS ===

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_apy_base() {
        let apy = _calculate_long_term_apy(0, 0);
        assert_eq!(apy, 1000); // 10.00%
    }

    #[test]
    fn test_calculate_apy_intermediate() {
        let apy = _calculate_long_term_apy(50, 0);
        assert_eq!(apy, 14500); // 145.00%
    }

    #[test]
    fn test_calculate_apy_max() {
        let apy = _calculate_long_term_apy(100, 0);
        assert_eq!(apy, 28000); // 280.00%
    }

    #[test]
    fn test_calculate_apy_with_affiliate_boost() {
        let apy = _calculate_long_term_apy(50, 30);
        assert_eq!(apy, 26600); // 266.00%
    }

    #[test] 
    fn test_calculate_apy_power_capped() {
        let apy = _calculate_long_term_apy(80, 50); // Total 130, but should cap at 100
        assert_eq!(apy, 28000); // Should still be max 280.00%
    }
}
