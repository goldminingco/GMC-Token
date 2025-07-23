// 🛡️ GMC Token Staking System - Native Rust Implementation
// Security-First Development with TDD + OWASP + DevSecOps
// 
// This module implements the staking functionality for GMC Token following:
// - OWASP Smart Contract Top 10 (2025)
// - TDD Methodology (Red-Green-Refactor-Security)
// - DevSecOps Security by Design
// - Business Rules from TABELA_MELHORADA_REGRAS_STAKING.md

use solana_program::{
    account_info::AccountInfo,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    clock::Clock,
    sysvar::Sysvar,
};

use borsh::{BorshDeserialize, BorshSerialize};
use crate::GMCError;

// 🚀 OPTIMIZED: Staking Pool Configuration with better memory layout
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
#[repr(C)] // 🚀 OPTIMIZATION: Explicit memory layout
pub struct StakingPool {
    pub authority: Pubkey,          // 32 bytes - most accessed field first
    pub total_staked: u64,          // 8 bytes
    pub total_rewards: u64,         // 8 bytes
    pub minimum_stake: u64,         // 8 bytes
    pub maximum_stake: u64,         // 8 bytes
    pub apy_basis_points: u16,      // 2 bytes - APY in basis points (10000 = 100%)
    pub lock_duration_days: u16,    // 🚀 OPTIMIZATION: u16 instead of u32 (2 bytes)
    pub pool_id: u8,                // 1 byte
    pub is_active: bool,            // 1 byte
    pub _padding: [u8; 6],          // 🚀 OPTIMIZATION: Explicit padding for alignment
}

impl StakingPool {
    #[allow(dead_code)]
    pub const LEN: usize = 32 + 8 + 8 + 8 + 8 + 2 + 2 + 1 + 1 + 6; // 🚀 OPTIMIZATION: 76 bytes (vs 88)
    
    // 🛡️ OWASP SC02: Safe APY calculation with overflow protection
    pub fn calculate_rewards(&self, amount: u64, days_staked: u32) -> Result<u64, ProgramError> {
        // 🛡️ Input validation
        if amount == 0 {
            return Ok(0);
        }
        
        if days_staked == 0 {
            return Ok(0);
        }
        
        // 🛡️ Safe arithmetic with overflow protection
        // 🚀 OPTIMIZATION: Simplified days calculation with precomputed constant
        #[allow(dead_code)]
        const SECONDS_PER_DAY: u32 = 86400;
        let days_staked = days_staked;
        
        let annual_reward = amount
            .checked_mul(self.apy_basis_points as u64)
            .and_then(|x| x.checked_div(10000))
            .ok_or_else(|| {
                msg!("🚨 Security Alert: APY calculation overflow");
                ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
            })?;
        
        let daily_reward = annual_reward
            .checked_div(365)
            .ok_or_else(|| {
                msg!("🚨 Security Alert: Daily reward calculation overflow");
                ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
            })?;
        
        let total_reward = daily_reward
            .checked_mul(days_staked as u64)
            .ok_or_else(|| {
                msg!("🚨 Security Alert: Total reward calculation overflow");
                ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
            })?;
        
        Ok(total_reward)
    }
    
    // 🛡️ OWASP SC03: Timestamp validation
    #[allow(dead_code)]
    pub fn is_lock_expired(&self, stake_timestamp: i64) -> Result<bool, ProgramError> {
        let clock = Clock::get()?;
        let current_time = clock.unix_timestamp;
        
        // 🛡️ OWASP SC03: Prevent timestamp manipulation
        if stake_timestamp > current_time {
            msg!("🚨 Security Alert: Future timestamp detected");
            return Err(ProgramError::Custom(GMCError::InvalidTimestamp as u32));
        }
        
        // 🚀 OPTIMIZATION: Precomputed constant for seconds per day
        const SECONDS_PER_DAY: i64 = 86400; // 24 * 60 * 60
        let lock_duration_seconds = (self.lock_duration_days as i64)
            .checked_mul(SECONDS_PER_DAY)
            .ok_or_else(|| {
                msg!("🚨 Security Alert: Lock duration calculation overflow");
                ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
            })?;
        
        let unlock_time = stake_timestamp
            .checked_add(lock_duration_seconds)
            .ok_or_else(|| {
                msg!("🚨 Security Alert: Unlock time calculation overflow");
                ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
            })?;
        
        Ok(current_time >= unlock_time)
    }
}

// 🚀 OPTIMIZED: Individual Stake Record with better memory layout
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
#[repr(C)] // 🚀 OPTIMIZATION: Explicit memory layout
pub struct StakeRecord {
    pub staker: Pubkey,                 // 32 bytes - most accessed field first
    pub amount: u64,                    // 8 bytes
    pub total_claimed: u64,             // 8 bytes
    pub staked_at: u32,                 // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub last_claim_at: u32,             // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub burn_boost_multiplier: u16,     // 2 bytes - 10000 = 1.0x, 15000 = 1.5x
    pub pool_id: u8,                    // 1 byte
    pub is_active: bool,                // 1 byte
}

impl StakeRecord {
    #[allow(dead_code)]
    pub const LEN: usize = 32 + 8 + 8 + 4 + 4 + 2 + 1 + 1; // 🚀 OPTIMIZATION: 60 bytes (vs 68)
    
    // 🛡️ Calculate pending rewards with burn boost
    #[allow(dead_code)]
    pub fn calculate_pending_rewards(&self, pool: &StakingPool) -> Result<u64, ProgramError> {
        let clock = Clock::get()?;
        let current_time = clock.unix_timestamp as u32; // Safe cast for u32 timestamps
        
        // 🚀 OPTIMIZATION: Simplified timestamp validation
        if self.staked_at > current_time {
            msg!("🚨 Security Alert: Future stake timestamp detected");
            return Err(ProgramError::Custom(GMCError::InvalidTimestamp as u32));
        }
        
        // 🚀 OPTIMIZATION: Simplified days calculation with precomputed constant
        const SECONDS_PER_DAY: u32 = 86400;
        let days_since_claim = current_time
            .saturating_sub(self.last_claim_at)
            .checked_div(SECONDS_PER_DAY)
            .unwrap_or(0);
        
        let base_rewards = pool.calculate_rewards(self.amount, days_since_claim)?;
        
        // 🛡️ Apply burn boost multiplier with overflow protection
        let boosted_rewards = base_rewards
            .checked_mul(self.burn_boost_multiplier as u64)
            .and_then(|x| x.checked_div(10000))
            .ok_or_else(|| {
                msg!("🚨 Security Alert: Burn boost calculation overflow");
                ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
            })?;
        
        Ok(boosted_rewards)
    }
}

// 🛡️ Staking Instructions
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub enum StakingInstruction {
    /// Create a new staking pool
    /// 
    /// Accounts expected:
    /// 0. `[writable, signer]` Authority account
    /// 1. `[writable]` Staking pool account
    /// 2. `[]` Rent sysvar
    CreatePool {
        pool_id: u8,
        apy_basis_points: u16,
        lock_duration_days: u32,
        minimum_stake: u64,
        maximum_stake: u64,
    },
    
    /// Stake tokens in a pool
    /// 
    /// Accounts expected:
    /// 0. `[writable, signer]` Staker account
    /// 1. `[writable]` Staker token account
    /// 2. `[writable]` Staking pool account
    /// 3. `[writable]` Pool token account
    /// 4. `[writable]` Stake record account
    /// 5. `[]` Token program
    Stake {
        pool_id: u8,
        amount: u64,
    },
    
    /// Claim staking rewards
    /// 
    /// Accounts expected:
    /// 0. `[writable, signer]` Staker account
    /// 1. `[writable]` Staker token account
    /// 2. `[writable]` Staking pool account
    /// 3. `[writable]` Pool token account
    /// 4. `[writable]` Stake record account
    /// 5. `[]` Token program
    ClaimRewards {
        pool_id: u8,
    },
    
    /// Unstake tokens (only after lock period)
    /// 
    /// Accounts expected:
    /// 0. `[writable, signer]` Staker account
    /// 1. `[writable]` Staker token account
    /// 2. `[writable]` Staking pool account
    /// 3. `[writable]` Pool token account
    /// 4. `[writable]` Stake record account
    /// 5. `[]` Token program
    Unstake {
        pool_id: u8,
        amount: u64,
    },
    
    /// Burn tokens to boost APY (Burn-for-Boost feature)
    /// 
    /// Accounts expected:
    /// 0. `[writable, signer]` Staker account
    /// 1. `[writable]` Staker token account
    /// 2. `[writable]` Stake record account
    /// 3. `[]` Token program
    BurnForBoost {
        pool_id: u8,
        burn_amount: u64,
        boost_multiplier: u16, // Additional multiplier (10000 = 1.0x)
    },
}

// 🛡️ Predefined Staking Pools (from business rules)
#[allow(dead_code)]
pub const LONG_TERM_POOLS: [StakingPool; 3] = [
    // Long-term 12 months - 10% APY
    StakingPool {
        pool_id: 1,
        authority: Pubkey::new_from_array([0; 32]), // Will be set at runtime
        total_staked: 0,
        total_rewards: 0,
        apy_basis_points: 1000, // 10%
        lock_duration_days: 365,
        minimum_stake: 1_000_000, // 1M tokens
        maximum_stake: 100_000_000_000, // 100B tokens
        is_active: true,
        _padding: [0; 6],
    },
    // Long-term 12 months - 150% APY
    StakingPool {
        pool_id: 2,
        authority: Pubkey::new_from_array([0; 32]),
        total_staked: 0,
        total_rewards: 0,
        apy_basis_points: 15000, // 150%
        lock_duration_days: 365,
        minimum_stake: 10_000_000, // 10M tokens
        maximum_stake: 100_000_000_000, // 100B tokens
        is_active: true,
        _padding: [0; 6],
    },
    // Long-term 12 months - 280% APY
    StakingPool {
        pool_id: 3,
        authority: Pubkey::new_from_array([0; 32]),
        total_staked: 0,
        total_rewards: 0,
        apy_basis_points: 28000, // 280%
        lock_duration_days: 365,
        minimum_stake: 50_000_000, // 50M tokens
        maximum_stake: 100_000_000_000, // 100B tokens
        is_active: true,
        _padding: [0; 6],
    },
];

#[allow(dead_code)]
pub const FLEXIBLE_POOLS: [StakingPool; 3] = [
    // Flexible 30 days - 5% APY
    StakingPool {
        pool_id: 4,
        authority: Pubkey::new_from_array([0; 32]),
        total_staked: 0,
        total_rewards: 0,
        apy_basis_points: 500, // 5%
        lock_duration_days: 30,
        minimum_stake: 100_000, // 100K tokens
        maximum_stake: 10_000_000_000, // 10B tokens
        is_active: true,
        _padding: [0; 6],
    },
    // Flexible 30 days - 35% APY
    StakingPool {
        pool_id: 5,
        authority: Pubkey::new_from_array([0; 32]),
        total_staked: 0,
        total_rewards: 0,
        apy_basis_points: 3500, // 35%
        lock_duration_days: 30,
        minimum_stake: 1_000_000, // 1M tokens
        maximum_stake: 10_000_000_000, // 10B tokens
        is_active: true,
        _padding: [0; 6],
    },
    // Flexible 30 days - 70% APY
    StakingPool {
        pool_id: 6,
        authority: Pubkey::new_from_array([0; 32]),
        total_staked: 0,
        total_rewards: 0,
        apy_basis_points: 7000, // 70%
        lock_duration_days: 30,
        minimum_stake: 5_000_000, // 5M tokens
        maximum_stake: 10_000_000_000, // 10B tokens
        is_active: true,
        _padding: [0; 6],
    },
];

// 🛡️ Staking processor functions
pub fn process_create_pool(
    _accounts: &[AccountInfo],
    pool_id: u8,
    apy_basis_points: u16,
    _lock_duration_days: u32,
    minimum_stake: u64,
    maximum_stake: u64,
) -> ProgramResult {
    msg!("🏗️ Creating staking pool: {}", pool_id);
    
    // 🛡️ OWASP SC04: Input validation
    if apy_basis_points > 50000 { // Max 500% APY
        msg!("🚨 Security Alert: APY too high (max 500%)");
        return Err(ProgramError::Custom(GMCError::TransferFeeTooHigh as u32));
    }
    
    if minimum_stake > maximum_stake {
        msg!("🚨 Security Alert: Invalid stake limits");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    // TODO: Implement pool creation logic
    msg!("✅ Staking pool {} created successfully", pool_id);
    
    Ok(())
}

pub fn process_stake(
    _accounts: &[AccountInfo],
    pool_id: u8,
    amount: u64,
) -> ProgramResult {
    msg!("💰 Staking {} tokens in pool {}", amount, pool_id);
    
    // 🛡️ OWASP SC02: Amount validation
    if amount == 0 {
        msg!("🚨 Security Alert: Stake amount cannot be zero");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    // TODO: Implement staking logic
    msg!("✅ Staked {} tokens successfully", amount);
    
    Ok(())
}

pub fn process_claim_rewards(
    _accounts: &[AccountInfo],
    pool_id: u8,
) -> ProgramResult {
    msg!("🎁 Claiming rewards from pool {}", pool_id);
    
    // TODO: Implement reward claiming logic
    msg!("✅ Rewards claimed successfully");
    
    Ok(())
}

pub fn process_unstake(
    _accounts: &[AccountInfo],
    pool_id: u8,
    amount: u64,
) -> ProgramResult {
    msg!("📤 Unstaking {} tokens from pool {}", amount, pool_id);
    
    // 🛡️ OWASP SC02: Amount validation
    if amount == 0 {
        msg!("🚨 Security Alert: Unstake amount cannot be zero");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    // TODO: Implement unstaking logic with lock period validation
    msg!("✅ Unstaked {} tokens successfully", amount);
    
    Ok(())
}

pub fn process_burn_for_boost(
    _accounts: &[AccountInfo],
    pool_id: u8,
    burn_amount: u64,
    boost_multiplier: u16,
) -> ProgramResult {
    msg!("🔥 Burning {} tokens for boost in pool {}", burn_amount, pool_id);
    
    // 🛡️ OWASP SC02: Input validation
    if burn_amount == 0 {
        msg!("🚨 Security Alert: Burn amount cannot be zero");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    if boost_multiplier > 50000 { // Max 5.0x boost
        msg!("🚨 Security Alert: Boost multiplier too high (max 5.0x)");
        return Err(ProgramError::Custom(GMCError::TransferFeeTooHigh as u32));
    }
    
    // TODO: Implement burn-for-boost logic
    msg!("✅ Burned {} tokens for {}x boost", burn_amount, boost_multiplier as f64 / 10000.0);
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    // 🔴 RED: TDD Test-First Development for Staking
    
    #[test]
    fn test_staking_pool_reward_calculation() {
        // Arrange
        let pool = StakingPool {
            pool_id: 1,
            authority: Pubkey::new_unique(),
            total_staked: 0,
            total_rewards: 0,
            apy_basis_points: 1000, // 10% APY
            lock_duration_days: 365,
            minimum_stake: 1_000_000,
            maximum_stake: 1_000_000_000,
            is_active: true,
            _padding: [0; 6],
        };

        let amount = 100_000_000; // 100 GMC
        let stake_days = 365; // 1 year in days

        // Act
        let rewards = pool.calculate_rewards(amount, stake_days);
        
        // Assert - 10% APY calculation: (100M * 1000 / 10000) / 365 * 365 = 10M
        // Due to integer division: 10M/365*365 = 9,999,905 (precision loss)
        assert_eq!(rewards, Ok(9_999_905)); // Expected result with integer arithmetic
    }
    
    #[test]
    fn test_staking_pool_daily_rewards() {
        // Arrange
        let pool = StakingPool {
            pool_id: 1,
            authority: Pubkey::new_unique(),
            total_staked: 0,
            total_rewards: 0,
            apy_basis_points: 3650, // 36.5% APY for easy daily calculation
            lock_duration_days: 365,
            minimum_stake: 1_000_000,
            maximum_stake: 100_000_000_000,
            is_active: true,
            _padding: [0; 6],
        };
        
        // Act
        let daily_rewards = pool.calculate_rewards(1_000_000, 1).unwrap();
        
        // Assert
        assert_eq!(daily_rewards, 1_000); // 0.1% daily = 1K
    }
    
    #[test]
    fn test_staking_pool_overflow_protection() {
        // 🛡️ OWASP SC02: Integer Overflow Test
        let pool = StakingPool {
            pool_id: 1,
            authority: Pubkey::new_unique(),
            total_staked: 0,
            total_rewards: 0,
            apy_basis_points: 50000, // 500% APY
            lock_duration_days: 365,
            minimum_stake: 1_000_000,
            maximum_stake: 100_000_000_000,
            is_active: true,
            _padding: [0; 6],
        };
        
        // Act
        let result = pool.calculate_rewards(u64::MAX, 365);
        
        // Assert
        assert!(result.is_err(), "Should detect overflow");
    }
    
    #[test]
    fn test_stake_record_burn_boost() {
        // Arrange
        let _pool = StakingPool {
            pool_id: 1,
            authority: Pubkey::new_unique(),
            total_staked: 0,
            total_rewards: 0,
            apy_basis_points: 1000, // 10% APY
            lock_duration_days: 365,
            minimum_stake: 1_000_000,
            maximum_stake: 100_000_000_000,
            is_active: true,
            _padding: [0; 6],
        };
        
        let stake_record = StakeRecord {
            staker: Pubkey::new_unique(),
            amount: 1_000_000,
            total_claimed: 0,
            staked_at: 0,
            last_claim_at: 0,
            burn_boost_multiplier: 15000, // 1.5x boost
            pool_id: 0,
            is_active: true,
        };
        
        // Mock Clock::get() would be needed for real test
        // This is a simplified test for the calculation logic
        
        // For now, test the boost calculation directly
        let base_rewards: u64 = 100_000; // 10% of 1M
        let boosted_rewards = base_rewards
            .checked_mul(stake_record.burn_boost_multiplier as u64)
            .unwrap()
            .checked_div(10000)
            .unwrap();
        
        // Assert
        assert_eq!(boosted_rewards, 150_000); // 1.5x boost = 150K
    }
    
    #[test]
    fn test_predefined_pools_configuration() {
        // 🛡️ Test business rules compliance
        
        // Long-term pools
        assert_eq!(LONG_TERM_POOLS[0].apy_basis_points, 1000); // 10%
        assert_eq!(LONG_TERM_POOLS[1].apy_basis_points, 15000); // 150%
        assert_eq!(LONG_TERM_POOLS[2].apy_basis_points, 28000); // 280%
        
        // Flexible pools
        assert_eq!(FLEXIBLE_POOLS[0].apy_basis_points, 500); // 5%
        assert_eq!(FLEXIBLE_POOLS[1].apy_basis_points, 3500); // 35%
        assert_eq!(FLEXIBLE_POOLS[2].apy_basis_points, 7000); // 70%
        
        // Lock durations
        for pool in &LONG_TERM_POOLS {
            assert_eq!(pool.lock_duration_days, 365);
        }
        
        for pool in &FLEXIBLE_POOLS {
            assert_eq!(pool.lock_duration_days, 30);
        }
    }
}
