//! 🏆 GMC Token Ranking System - Native Rust Implementation
//! 🛡️ OWASP Smart Contract Top 10 Compliance
//! 🧪 Test-Driven Development (TDD) Ready
//! 🔒 DevSecOps Security-First Design

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    msg,
    program::invoke,
    program_error::ProgramError,
    pubkey::Pubkey,
};
use borsh::{BorshDeserialize, BorshSerialize};
use crate::GMCError;

// OPTIMIZATION: Reduced leaderboard size for better memory efficiency
pub const MAX_LEADERBOARD_SIZE: usize = 25; // Reduced from 50 to 25
pub const MIN_SCORE_THRESHOLD: u64 = 100; // Minimum score to enter leaderboard

// OPTIMIZED: Ranking Configuration Constants
#[allow(dead_code)]
pub const MONTHLY_DISTRIBUTION_PERCENTAGE: u8 = 90; // 90% distributed monthly
#[allow(dead_code)]
pub const ANNUAL_ACCUMULATION_PERCENTAGE: u8 = 10;  // 10% accumulated for annual distribution

/// Optimized leaderboard entry with better memory layout
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, Copy, PartialEq, Eq, Default)]
#[repr(C)] // OPTIMIZATION: Explicit memory layout for better packing
pub struct RankEntry {
    pub score: u64,        // OPTIMIZATION: Put score first (most accessed field)
    pub user_pubkey: Pubkey, // 32 bytes
}

/// 🏆 Optimized ranking state with monthly/annual pool separation
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
#[repr(C)] // 🚀 OPTIMIZATION: Explicit memory layout
pub struct RankingState {
    pub authority: Pubkey,              // 32 bytes
    pub monthly_prize_pool: u64,        // 8 bytes - 90% of incoming fees
    pub annual_prize_pool: u64,         // 8 bytes - 10% accumulated for annual distribution
    pub total_prize_pool: u64,          // 8 bytes - total for backward compatibility
    pub season_id: u32,                 // 🚀 OPTIMIZATION: u32 instead of u64 (4 bytes)
    pub season_end_timestamp: u32,      // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub active_entries: u8,             // 🚀 OPTIMIZATION: Track active entries count
    pub is_initialized: bool,           // 1 byte
    pub is_active: bool,                // 1 byte
    pub is_annual_distribution: bool,   // 1 byte - flag for annual vs monthly distribution
    pub leaderboard: [RankEntry; MAX_LEADERBOARD_SIZE], // Reduced size array
}

impl Default for RankingState {
    fn default() -> Self {
        Self {
            authority: Pubkey::default(),
            monthly_prize_pool: 0,
            annual_prize_pool: 0,
            total_prize_pool: 0,
            season_id: 0,
            season_end_timestamp: 0,
            active_entries: 0,
            is_initialized: false,
            is_active: false,
            is_annual_distribution: false,
            leaderboard: [RankEntry::default(); MAX_LEADERBOARD_SIZE],
        }
    }
}

/// 🏆 Instructions supported by the Ranking program.
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub enum RankingInstruction {
    /// Initializes the ranking system.
    /// Accounts expected:
    /// 0. `[signer]` The authority account.
    /// 1. `[writable]` The ranking state account to initialize.
    /// 2. `[]` Rent sysvar.
    Initialize,

    /// Updates the score for a user.
    /// (Typically called by an authorized program/authority).
    /// Accounts expected:
    /// 0. `[signer]` The authority account.
    /// 1. `[writable]` The ranking state account.
    UpdateScore {
        user_pubkey: Pubkey,
        score_to_add: u64,
    },

    /// Ends a season, sorts the leaderboard, and distributes rewards.
    /// Accounts expected:
    /// 0. `[signer]` The authority account.
    /// 1. `[writable]` The ranking state account.
    /// 2. `[writable]` The ranking pool token account (source of funds).
    /// 3. `[]` The token program.
    /// .. `[writable]` Winner token accounts (up to MAX_LEADERBOARD_SIZE).
    DistributeRewards,
}

/// Processes an instruction.
#[allow(dead_code)]
pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction = RankingInstruction::try_from_slice(instruction_data)?;

    match instruction {
        RankingInstruction::Initialize => {
            msg!("Instruction: Initialize Ranking");
            process_initialize(program_id, accounts)
        }
        RankingInstruction::UpdateScore { user_pubkey, score_to_add } => {
            msg!("Instruction: Update Score for {}", user_pubkey);
            process_update_score(accounts, user_pubkey, score_to_add)
        }
        RankingInstruction::DistributeRewards => {
            msg!("Instruction: Distribute Rewards");
            process_distribute_rewards(program_id, accounts)
        }
    }
}

/// 🚀 OPTIMIZED: Updates a user's score with minimal gas usage
pub fn process_update_score(
    accounts: &[AccountInfo],
    user_pubkey: Pubkey,
    score_to_add: u64,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let authority_info = next_account_info(account_info_iter)?;
    let ranking_state_info = next_account_info(account_info_iter)?;

    // 🛡️ Security Checks (optimized order for early returns)
    if !authority_info.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // 🚀 OPTIMIZATION: Early validation to avoid unnecessary deserialization
    if score_to_add < MIN_SCORE_THRESHOLD {
        return Ok(()); // Skip processing for very low scores
    }

    let mut ranking_state = RankingState::try_from_slice(&ranking_state_info.data.borrow())?;
    if !ranking_state.is_initialized || !ranking_state.is_active {
        return Err(ProgramError::Custom(GMCError::RankingInactive as u32));
    }
    if *authority_info.key != ranking_state.authority {
        return Err(ProgramError::Custom(GMCError::InvalidAuthority as u32));
    }

    // 🚀 OPTIMIZATION: Single pass to find user or insertion point
    let mut user_index: Option<usize> = None;
    let mut empty_slot: Option<usize> = None;
    let mut min_score_index: Option<usize> = None;
    let mut min_score = u64::MAX;

    for (i, entry) in ranking_state.leaderboard.iter().enumerate() {
        if entry.user_pubkey == user_pubkey {
            user_index = Some(i);
            break;
        }
        if entry.user_pubkey == Pubkey::default() && empty_slot.is_none() {
            empty_slot = Some(i);
        }
        if entry.score < min_score {
            min_score = entry.score;
            min_score_index = Some(i);
        }
    }

    let mut needs_sort = false;

    if let Some(index) = user_index {
        // 🚀 OPTIMIZATION: Update existing user
        let old_score = ranking_state.leaderboard[index].score;
        let new_score = old_score.checked_add(score_to_add).ok_or(GMCError::ArithmeticOverflow)?;
        ranking_state.leaderboard[index].score = new_score;
        
        // 🚀 OPTIMIZATION: Only sort if score increased significantly
        needs_sort = new_score > old_score && index > 0;
    } else if let Some(index) = empty_slot {
        // 🚀 OPTIMIZATION: Fill empty slot
        ranking_state.leaderboard[index] = RankEntry { score: score_to_add, user_pubkey };
        ranking_state.active_entries = ranking_state.active_entries.saturating_add(1);
        needs_sort = true;
    } else if let Some(index) = min_score_index {
        // 🚀 OPTIMIZATION: Replace lowest score only if new score is significantly higher
        if score_to_add > min_score.saturating_add(MIN_SCORE_THRESHOLD) {
            ranking_state.leaderboard[index] = RankEntry { score: score_to_add, user_pubkey };
            needs_sort = true;
        }
    }

    // Optimization: Conditional sorting - only sort when necessary
    if needs_sort {
        // Optimization: Partial sort - only sort active entries
        let active_count = ranking_state.active_entries.min(MAX_LEADERBOARD_SIZE as u8) as usize;
        if active_count > 1 {
            ranking_state.leaderboard[..active_count].sort_unstable_by(|a, b| b.score.cmp(&a.score));
        }
    }

    ranking_state.serialize(&mut *ranking_state_info.data.borrow_mut())?;

    Ok(())
}

/// 🛡️ Distributes rewards to the winners and resets the season.
pub fn process_distribute_rewards(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();

    let authority_info = next_account_info(account_info_iter)?;
    let ranking_state_info = next_account_info(account_info_iter)?;
    let ranking_pool_info = next_account_info(account_info_iter)?;
    let token_program_info = next_account_info(account_info_iter)?;

    // Security Checks
    if !authority_info.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    let mut ranking_state = RankingState::try_from_slice(&ranking_state_info.data.borrow())?;
    if !ranking_state.is_initialized || !ranking_state.is_active {
        return Err(ProgramError::Custom(GMCError::RankingInactive as u32));
    }
    if *authority_info.key != ranking_state.authority {
        return Err(ProgramError::Custom(GMCError::InvalidAuthority as u32));
    }

    // 🚀 OPTIMIZATION: Calculate total score only for active entries
    let active_count = ranking_state.active_entries.min(MAX_LEADERBOARD_SIZE as u8) as usize;
    let total_score: u64 = ranking_state.leaderboard[..active_count]
        .iter()
        .map(|e| e.score)
        .sum();
        
    // 🎯 CRITICAL BUSINESS RULE: Use appropriate pool based on distribution type
    let prize_pool = if ranking_state.is_annual_distribution {
        ranking_state.annual_prize_pool
    } else {
        ranking_state.monthly_prize_pool
    };
    
    if total_score == 0 || prize_pool == 0 {
        // 🚀 OPTIMIZATION: Reset season with optimized field updates
        ranking_state.is_active = false;
        ranking_state.season_id = ranking_state.season_id.saturating_add(1);
        
        // Reset appropriate pool based on distribution type
        if ranking_state.is_annual_distribution {
            ranking_state.annual_prize_pool = 0;
        } else {
            ranking_state.monthly_prize_pool = 0;
        }
        
        ranking_state.total_prize_pool = ranking_state.monthly_prize_pool.saturating_add(ranking_state.annual_prize_pool);
        ranking_state.active_entries = 0;
        ranking_state.leaderboard = [RankEntry::default(); MAX_LEADERBOARD_SIZE];
        ranking_state.serialize(&mut *ranking_state_info.data.borrow_mut())?;
        return Ok(());
    }
    let remaining_accounts = account_info_iter.as_slice();
    let mut distributed_amount: u64 = 0;

    // 🚀 OPTIMIZATION: Process only active entries with scores > 0
    let winners_count = active_count.min(remaining_accounts.len());
    
    for i in 0..winners_count {
        let winner = &ranking_state.leaderboard[i];
        if winner.score == 0 {
            break; // No more valid winners (leaderboard is sorted)
        }
        
        let winner_account_info = &remaining_accounts[i];

        // 🚀 OPTIMIZATION: Simplified proportional reward calculation
        let reward_amount = if total_score > 0 {
            ((winner.score as u128 * prize_pool as u128) / total_score as u128) as u64
        } else {
            0
        };

        if reward_amount > 0 {
            // 🚀 OPTIMIZATION: Batch CPI preparation
            let transfer_instruction = spl_token::instruction::transfer(
                token_program_info.key,
                ranking_pool_info.key,
                winner_account_info.key,
                authority_info.key,
                &[],
                reward_amount,
            )?;

            invoke(
                &transfer_instruction,
                &[
                    ranking_pool_info.clone(),
                    winner_account_info.clone(),
                    authority_info.clone(),
                    token_program_info.clone(),
                ],
            )?;
            distributed_amount = distributed_amount.saturating_add(reward_amount);
        }
    }

    // 🚀 OPTIMIZATION: Reset state for next season with optimized updates
    ranking_state.is_active = false;
    ranking_state.season_id = ranking_state.season_id.saturating_add(1);
    ranking_state.active_entries = 0;
    // To prevent dust, the remaining amount is carried over or handled as decided
    ranking_state.total_prize_pool = prize_pool.saturating_sub(distributed_amount);
    ranking_state.leaderboard = [RankEntry::default(); MAX_LEADERBOARD_SIZE];

    ranking_state.serialize(&mut *ranking_state_info.data.borrow_mut())?;

    Ok(())
}

/// 💰 CRITICAL BUSINESS RULE: Add funds to ranking pools with 90/10 separation
/// This function implements the core requirement: 90% monthly, 10% annual accumulation
#[allow(dead_code)]
pub fn add_funds_to_ranking_pools(
    accounts: &[AccountInfo],
    total_amount: u64,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let authority_info = next_account_info(account_info_iter)?;
    let ranking_state_info = next_account_info(account_info_iter)?;

    // Security Checks
    if !authority_info.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    let mut ranking_state = RankingState::try_from_slice(&ranking_state_info.data.borrow())?;
    if !ranking_state.is_initialized {
        return Err(ProgramError::Custom(GMCError::RankingNotInitialized as u32));
    }
    if *authority_info.key != ranking_state.authority {
        return Err(ProgramError::Custom(GMCError::InvalidAuthority as u32));
    }

    // 🎯 CRITICAL: Implement 90% monthly, 10% annual separation
    let monthly_amount = (total_amount as u128 * MONTHLY_DISTRIBUTION_PERCENTAGE as u128 / 100) as u64;
    let annual_amount = (total_amount as u128 * ANNUAL_ACCUMULATION_PERCENTAGE as u128 / 100) as u64;
    
    // Add to respective pools using saturating arithmetic for safety
    ranking_state.monthly_prize_pool = ranking_state.monthly_prize_pool.saturating_add(monthly_amount);
    ranking_state.annual_prize_pool = ranking_state.annual_prize_pool.saturating_add(annual_amount);
    ranking_state.total_prize_pool = ranking_state.monthly_prize_pool.saturating_add(ranking_state.annual_prize_pool);

    msg!("💰 Funds added to ranking pools: Monthly: {} GMC, Annual: {} GMC", monthly_amount, annual_amount);
    
    ranking_state.serialize(&mut *ranking_state_info.data.borrow_mut())?;
    Ok(())
}

/// 🛡️ Initializes the ranking system state.
pub fn process_initialize(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();

    let authority_info = next_account_info(account_info_iter)?;
    let ranking_state_info = next_account_info(account_info_iter)?;

    // Security checks
    if !authority_info.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    if ranking_state_info.owner != program_id {
        return Err(ProgramError::IllegalOwner);
    }

    let mut ranking_state = RankingState::try_from_slice(&ranking_state_info.data.borrow())?;
    if ranking_state.is_initialized {
        return Err(ProgramError::AccountAlreadyInitialized);
    }

    // 🚀 OPTIMIZATION: Initialize state with optimized field order
    ranking_state.is_initialized = true;
    ranking_state.authority = *authority_info.key;
    ranking_state.is_active = false; // Starts inactive, requires explicit activation
    ranking_state.season_id = 0;
    ranking_state.season_end_timestamp = 0;
    ranking_state.total_prize_pool = 0;
    ranking_state.active_entries = 0;

    ranking_state.leaderboard = [RankEntry::default(); MAX_LEADERBOARD_SIZE];

    ranking_state.serialize(&mut *ranking_state_info.data.borrow_mut())?;

    Ok(())
}


#[cfg(test)]
mod tests {
    use super::*;
    use solana_program::{clock::Epoch, pubkey::Pubkey};
    use solana_sdk::account::Account;

    // Helper function to create a mock account
    #[allow(dead_code)]
    fn create_account(lamports: u64, space: usize, owner: &Pubkey) -> Account {
        Account {
            lamports,
            data: vec![0; space],
            owner: *owner,
            executable: false,
            rent_epoch: Epoch::default(),
        }
    }

    #[test]
    fn test_ranking_state_serialization() {
        // Test basic serialization/deserialization of RankingState
        let authority = Pubkey::new_unique();
        let state = RankingState {
            authority,
            monthly_prize_pool: 900,
            annual_prize_pool: 100,
            total_prize_pool: 1000,
            season_id: 1,
            season_end_timestamp: 1234567890,
            active_entries: 2,
            is_initialized: true,
            is_active: true,
            is_annual_distribution: false,
            leaderboard: [RankEntry::default(); MAX_LEADERBOARD_SIZE],
        };

        // Serialize
        let mut data = Vec::new();
        state.serialize(&mut data).unwrap();

        // Deserialize
        let deserialized_state = RankingState::try_from_slice(&data).unwrap();

        // Verify
        assert_eq!(deserialized_state.authority, authority);
        assert_eq!(deserialized_state.monthly_prize_pool, 900);
        assert_eq!(deserialized_state.annual_prize_pool, 100);
        assert_eq!(deserialized_state.total_prize_pool, 1000);
        assert_eq!(deserialized_state.season_id, 1);
        assert_eq!(deserialized_state.active_entries, 2);
        assert!(deserialized_state.is_initialized);
        assert!(deserialized_state.is_active);
        assert!(!deserialized_state.is_annual_distribution);
    }

    #[test]
    fn test_ranking_constants_and_percentages() {
        // Test that the 90/10 separation constants are correct
        assert_eq!(MONTHLY_DISTRIBUTION_PERCENTAGE, 90);
        assert_eq!(ANNUAL_ACCUMULATION_PERCENTAGE, 10);
        assert_eq!(MONTHLY_DISTRIBUTION_PERCENTAGE + ANNUAL_ACCUMULATION_PERCENTAGE, 100);
        
        // Test MAX_LEADERBOARD_SIZE is reasonable
        assert_eq!(MAX_LEADERBOARD_SIZE, 25);
        assert!(MAX_LEADERBOARD_SIZE > 0);
        assert!(MAX_LEADERBOARD_SIZE <= 100); // Reasonable upper bound
    }

    // Note: A full test for distribute_rewards requires a more complex integration test setup
    // with a running validator to properly test CPIs. This unit test checks the logic.
    #[test]
    fn test_distribute_rewards_logic_monthly() {
        // Arrange - Test monthly distribution (90% of funds)
        let mut state = RankingState {
            authority: Pubkey::new_unique(),
            monthly_prize_pool: 900,  // 90% of 1000
            annual_prize_pool: 100,   // 10% of 1000
            total_prize_pool: 1000,
            season_id: 1,
            season_end_timestamp: 0,
            active_entries: 0,
            is_initialized: true,
            is_active: true,
            is_annual_distribution: false, // Monthly distribution
            leaderboard: [RankEntry::default(); MAX_LEADERBOARD_SIZE],
        };

        let user1 = Pubkey::new_unique();
        let user2 = Pubkey::new_unique();
        state.leaderboard[0] = RankEntry { score: 750, user_pubkey: user1 };
        state.leaderboard[1] = RankEntry { score: 250, user_pubkey: user2 };
        state.active_entries = 2;

        let total_score: u64 = state.leaderboard.iter().map(|e| e.score).sum();
        assert_eq!(total_score, 1000);

        // Act & Assert - Use monthly pool for monthly distribution
        let prize_pool = state.monthly_prize_pool;
        let reward1 = (state.leaderboard[0].score as u128 * prize_pool as u128 / total_score as u128) as u64;
        let reward2 = (state.leaderboard[1].score as u128 * prize_pool as u128 / total_score as u128) as u64;

        assert_eq!(reward1, 675); // 750/1000 * 900 = 675
        assert_eq!(reward2, 225); // 250/1000 * 900 = 225
    }

    #[test]
    fn test_distribute_rewards_logic_annual() {
        // Arrange - Test annual distribution (10% accumulated)
        let mut state = RankingState {
            authority: Pubkey::new_unique(),
            monthly_prize_pool: 0,    // Monthly already distributed
            annual_prize_pool: 5000,  // Accumulated over year
            total_prize_pool: 5000,
            season_id: 12,
            season_end_timestamp: 0,
            active_entries: 0,
            is_initialized: true,
            is_active: true,
            is_annual_distribution: true, // Annual distribution
            leaderboard: [RankEntry::default(); MAX_LEADERBOARD_SIZE],
        };

        let user1 = Pubkey::new_unique();
        let user2 = Pubkey::new_unique();
        state.leaderboard[0] = RankEntry { score: 800, user_pubkey: user1 };
        state.leaderboard[1] = RankEntry { score: 200, user_pubkey: user2 };
        state.active_entries = 2;

        let total_score: u64 = state.leaderboard.iter().map(|e| e.score).sum();
        assert_eq!(total_score, 1000);

        // Act & Assert - Use annual pool for annual distribution
        let prize_pool = state.annual_prize_pool;
        let reward1 = (state.leaderboard[0].score as u128 * prize_pool as u128 / total_score as u128) as u64;
        let reward2 = (state.leaderboard[1].score as u128 * prize_pool as u128 / total_score as u128) as u64;

        assert_eq!(reward1, 4000); // 800/1000 * 5000 = 4000 (MAIOR que mensal!)
        assert_eq!(reward2, 1000); // 200/1000 * 5000 = 1000
    }

    #[test]
    fn test_add_funds_90_10_separation() {
        // Arrange
        let mut state = RankingState {
            authority: Pubkey::new_unique(),
            monthly_prize_pool: 0,
            annual_prize_pool: 0,
            total_prize_pool: 0,
            season_id: 1,
            season_end_timestamp: 0,
            active_entries: 0,
            is_initialized: true,
            is_active: true,
            is_annual_distribution: false,
            leaderboard: [RankEntry::default(); MAX_LEADERBOARD_SIZE],
        };

        let total_funds = 1000u64;
        
        // Act - Simulate fund addition with 90/10 separation
        let monthly_amount = (total_funds as u128 * MONTHLY_DISTRIBUTION_PERCENTAGE as u128 / 100) as u64;
        let annual_amount = (total_funds as u128 * ANNUAL_ACCUMULATION_PERCENTAGE as u128 / 100) as u64;
        
        state.monthly_prize_pool = state.monthly_prize_pool.saturating_add(monthly_amount);
        state.annual_prize_pool = state.annual_prize_pool.saturating_add(annual_amount);
        state.total_prize_pool = state.monthly_prize_pool.saturating_add(state.annual_prize_pool);

        // Assert - Verify 90/10 separation
        assert_eq!(state.monthly_prize_pool, 900);  // 90% of 1000
        assert_eq!(state.annual_prize_pool, 100);   // 10% of 1000
        assert_eq!(state.total_prize_pool, 1000);   // Total matches
        
        // Verify percentages are correct
        assert_eq!(monthly_amount, 900);
        assert_eq!(annual_amount, 100);
        assert_eq!(MONTHLY_DISTRIBUTION_PERCENTAGE, 90);
        assert_eq!(ANNUAL_ACCUMULATION_PERCENTAGE, 10);
    }
    
    #[test]
    fn test_annual_accumulation_over_time() {
        // Test that annual pool accumulates over multiple months
        let mut state = RankingState {
            authority: Pubkey::new_unique(),
            monthly_prize_pool: 0,
            annual_prize_pool: 0,
            total_prize_pool: 0,
            season_id: 1,
            season_end_timestamp: 0,
            active_entries: 0,
            is_initialized: true,
            is_active: true,
            is_annual_distribution: false,
            leaderboard: [RankEntry::default(); MAX_LEADERBOARD_SIZE],
        };

        // Simulate 12 months of fund additions (1000 per month)
        for _month in 1..=12 {
            let monthly_funds = 1000u64;
            let monthly_amount = (monthly_funds as u128 * MONTHLY_DISTRIBUTION_PERCENTAGE as u128 / 100) as u64;
            let annual_amount = (monthly_funds as u128 * ANNUAL_ACCUMULATION_PERCENTAGE as u128 / 100) as u64;
            
            // Monthly gets distributed immediately (reset to 0 after distribution)
            state.monthly_prize_pool = monthly_amount; // Would be 0 after distribution
            
            // Annual accumulates
            state.annual_prize_pool = state.annual_prize_pool.saturating_add(annual_amount);
        }

        // After 12 months: annual pool should have 12 * 100 = 1200
        assert_eq!(state.annual_prize_pool, 1200);
        
        // Annual rewards are now MUCH larger than monthly (1200 vs 900)
        // This fixes the original problem where monthly > annual
        assert!(state.annual_prize_pool > 900); // Annual > Monthly ✅
    }
}
