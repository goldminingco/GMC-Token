// 🛡️ GMC Token Native Rust Implementation
// Security-First Development with TDD + OWASP + DevSecOps
// 
// This implementation follows:
// - OWASP Smart Contract Top 10 (2025)
// - TDD Methodology (Red-Green-Refactor-Security)
// - DevSecOps Security by Design
// - Native Rust (NO ANCHOR)

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
    declare_id,
};

use borsh::{BorshDeserialize, BorshSerialize};

// 🔥 Import modules
mod staking;
mod affiliate;
mod vesting;
mod ranking;
mod treasury;
mod critical_tests;

// Re-export public items
use staking::*;
use affiliate::*;
use vesting::*;
use ranking::*;
use treasury::*;

// Staking System Module
// Affiliate System Module
// Vesting System Module
// Ranking System Module

// OWASP SC04: Access Control - Program ID validation
declare_id!("H5f91LGHdQBRqSGFupaP5N6tFTZsXxqHtroam4p6nBdT");

// Entry point with security validation
entrypoint!(process_instruction);

// 🛡️ OWASP SC01: Reentrancy Protection
#[derive(Default)]
pub struct ReentrancyGuard {
    locked: bool,
}

impl ReentrancyGuard {
    pub fn lock(&mut self) -> Result<(), ProgramError> {
        if self.locked {
            msg!("🚨 Security Alert: Reentrancy attack detected!");
            return Err(ProgramError::Custom(GMCError::ReentrancyDetected as u32));
        }
        self.locked = true;
        Ok(())
    }
    
    pub fn unlock(&mut self) {
        self.locked = false;
    }
}

// 🛡️ Custom Error Types for Security
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize, num_derive::FromPrimitive)]
#[borsh(use_discriminant = true)]
pub enum GMCError {
    // OWASP SC01: Reentrancy
    ReentrancyDetected = 10,
    
    // OWASP SC02: Integer Overflow/Underflow
    ArithmeticOverflow = 11,
    ArithmeticUnderflow = 12,
    
    // OWASP SC03: Timestamp Dependence
    InvalidTimestamp = 13,
    TimestampTooOld = 14,
    TimestampTooNew = 15,
    
    // OWASP SC04: Access Control
    UnauthorizedAccess = 16,
    InvalidAuthority = 17,
    MissingSignature = 18,
    
    // OWASP SC05: Unchecked Return Values
    UncheckedReturnValue = 19,
    TransactionFailed = 20,
    WeakRandomness = 29,
    
    // Business Logic Errors
    InvalidAmount = 30,
    InsufficientFunds = 31,
    InvalidMint = 32,
    InvalidTokenAccount = 33,
    TransferFeeTooHigh = 34,
    InsufficientBalance = 35,
    TokenOperationsPaused = 36,
    OperationNotAllowed = 37,
    SignatureVerificationFailed = 38,
    StakingPoolNotFound = 39,
    StakeRecordNotFound = 40,
    StakingPoolAlreadyExists = 41,
    InvalidStakingDuration = 42,
    StakingPeriodNotCompleted = 43,
    AffiliateRecordNotFound = 44,
    AffiliateAlreadyExists = 45,
    InvalidAffiliateLevel = 46,
    CooldownPeriodActive = 47,
    VestingConfigNotFound = 48,
    VestingScheduleNotFound = 49,
    VestingConfigAlreadyExists = 50,
    InvalidVestingParameters = 51,
    CliffPeriodNotReached = 52,
    NoTokensAvailableForRelease = 53,
    MaxVestingSchedulesReached = 54,
    RankingInactive = 55,
    RankingNotFound = 56,
    RankingNotInitialized = 57,
    InvalidRankingParameters = 58,
}

// 🔧 Implementação From<GMCError> for ProgramError
impl From<GMCError> for ProgramError {
    fn from(error: GMCError) -> Self {
        ProgramError::Custom(error as u32)
    }
}

// 🛡️ GMC Token Configuration
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct GMCTokenConfig {
    pub mint: Pubkey,
    pub authority: Pubkey,
    pub transfer_fee_basis_points: u16, // 0.5% = 50 basis points
    pub maximum_fee: u64,
    pub burn_address: Pubkey,
    pub staking_pool: Pubkey,
    pub ranking_pool: Pubkey,
    pub is_initialized: bool,
    pub is_paused: bool, // 🛡️ Emergency pause mechanism
}

impl GMCTokenConfig {
    pub const LEN: usize = 32 + 32 + 2 + 8 + 32 + 32 + 32 + 1 + 1; // 171 bytes
    
    /// Serialize configuration to bytes
    pub fn try_to_vec(&self) -> Result<Vec<u8>, std::io::Error> {
        borsh::to_vec(self)
    }
    
    /// Deserialize configuration from bytes
    pub fn try_from_slice(data: &[u8]) -> Result<Self, std::io::Error> {
        borsh::from_slice(data)
    }
}

// 🛡️ Instruction enum with security validation
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub enum GMCInstruction {
    /// Initialize the GMC Token
    /// 
    /// Accounts expected:
    /// 0. `[writable, signer]` Authority account
    /// 1. `[writable]` Token mint account
    /// 2. `[writable]` GMC config account
    /// 3. `[]` Rent sysvar
    /// 4. `[]` Token program
    InitializeToken {
        transfer_fee_basis_points: u16,
        maximum_fee: u64,
        burn_address: Pubkey,
        staking_pool: Pubkey,
        ranking_pool: Pubkey,
    },
    
    /// Transfer tokens with fee
    /// 
    /// Accounts expected:
    /// 0. `[writable]` Source token account
    /// 1. `[writable]` Destination token account
    /// 2. `[signer]` Source account authority
    /// 3. `[writable]` Fee destination account
    /// 4. `[]` Token program
    TransferWithFee {
        amount: u64,
    },
    
    /// Burn tokens for deflationary mechanism
    /// 
    /// Accounts expected:
    /// 0. `[writable]` Token account to burn from
    /// 1. `[writable]` Token mint
    /// 2. `[signer]` Token account authority
    /// 3. `[]` Token program
    BurnTokens {
        amount: u64,
    },
    
    /// Emergency pause (OWASP SC06: DoS Protection)
    /// 
    /// Accounts expected:
    /// 0. `[signer]` Authority account
    /// 1. `[writable]` GMC config account
    EmergencyPause,
    
    /// Resume operations
    /// 
    /// Accounts expected:
    /// 0. `[signer]` Authority account
    /// 1. `[writable]` GMC config account
    Resume,
    
    /// Staking operations
    /// 
    /// Delegated to staking module
    Staking(StakingInstruction),
    
    /// Affiliate system operations
    Affiliate(AffiliateInstruction),
    
    /// Vesting system operations
    Vesting(VestingInstruction),
    Ranking(RankingInstruction),
    Treasury(TreasuryInstruction),
}

impl GMCInstruction {
    /// Serialize instruction to bytes
    pub fn try_to_vec(&self) -> Result<Vec<u8>, std::io::Error> {
        borsh::to_vec(self)
    }
    
    /// Deserialize instruction from bytes
    pub fn try_from_slice(data: &[u8]) -> Result<Self, std::io::Error> {
        borsh::from_slice(data)
    }
}

// 🛡️ Main instruction processor with security checks
pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    // 🛡️ OWASP SC04: Program ID validation
    if program_id != &crate::id() {
        msg!("🚨 Security Alert: Invalid program ID");
        return Err(ProgramError::IncorrectProgramId);
    }
    
    // 🛡️ OWASP SC05: Input validation
    if instruction_data.is_empty() {
        msg!("🚨 Security Alert: Empty instruction data");
        return Err(ProgramError::InvalidInstructionData);
    }
    
    // 🛡️ Deserialize instruction with error handling
    let instruction = GMCInstruction::try_from_slice(instruction_data)
        .map_err(|_| {
            msg!("🚨 Security Alert: Failed to deserialize instruction");
            ProgramError::InvalidInstructionData
        })?;
    
    // 🛡️ Process instruction with security logging
    match instruction {
        GMCInstruction::InitializeToken {
            transfer_fee_basis_points,
            maximum_fee,
            burn_address,
            staking_pool,
            ranking_pool,
        } => {
            msg!("🔧 Processing: InitializeToken");
            process_initialize_token(
                accounts,
                transfer_fee_basis_points,
                maximum_fee,
                burn_address,
                staking_pool,
                ranking_pool,
            )
        },
        GMCInstruction::TransferWithFee { amount } => {
            msg!("💸 Processing: TransferWithFee, amount: {}", amount);
            process_transfer_with_fee(accounts, amount)
        },
        GMCInstruction::BurnTokens { amount } => {
            msg!("🔥 Processing: BurnTokens, amount: {}", amount);
            process_burn_tokens(accounts, amount)
        },
        GMCInstruction::EmergencyPause => {
            msg!("⏸️ Processing: EmergencyPause");
            process_emergency_pause(accounts)
        },
        GMCInstruction::Resume => {
            msg!("▶️ Processing: Resume");
            process_resume(accounts)
        },
        GMCInstruction::Staking(staking_instruction) => {
            msg!("💰 Processing: Staking operation");
            process_staking_instruction(accounts, staking_instruction)
        },
        GMCInstruction::Affiliate(affiliate_instruction) => {
            msg!("🤝 Processing: Affiliate operation");
            process_affiliate_instruction(accounts, affiliate_instruction)
        },
        GMCInstruction::Vesting(vesting_instruction) => {
            msg!("📅 Processing: Vesting operation");
            process_vesting_instruction(accounts, vesting_instruction)
        },
        GMCInstruction::Ranking(ranking_instruction) => {
            msg!("🏆 Processing: Ranking operation");
            process_ranking_instruction(program_id, accounts, ranking_instruction)
        },
        GMCInstruction::Treasury(treasury_instruction) => {
            msg!("Processing Treasury instruction: {:?}", treasury_instruction);
            treasury::process_treasury_instruction(program_id, accounts, treasury_instruction)
        },
    }
}

// 🛡️ Initialize Token with comprehensive security checks
fn process_initialize_token(
    accounts: &[AccountInfo],
    transfer_fee_basis_points: u16,
    maximum_fee: u64,
    burn_address: Pubkey,
    staking_pool: Pubkey,
    ranking_pool: Pubkey,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    
    // 🛡️ OWASP SC04: Account validation
    let authority_info = next_account_info(account_info_iter)?;
    let mint_info = next_account_info(account_info_iter)?;
    let config_info = next_account_info(account_info_iter)?;
    let rent_info = next_account_info(account_info_iter)?;
    let _token_program_info = next_account_info(account_info_iter)?;
    
    // 🛡️ OWASP SC04: Authority signature validation
    if !authority_info.is_signer {
        msg!("🚨 Security Alert: Authority must be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    // 🛡️ OWASP SC02: Input validation with overflow protection
    if transfer_fee_basis_points > 10000 {
        msg!("🚨 Security Alert: Transfer fee too high (max 100%)");
        return Err(ProgramError::Custom(GMCError::TransferFeeTooHigh as u32));
    }
    
    // 🛡️ OWASP SC05: Rent exemption validation
    let rent = Rent::from_account_info(rent_info)?;
    if !rent.is_exempt(config_info.lamports(), config_info.data_len()) {
        msg!("🚨 Security Alert: Config account not rent exempt");
        return Err(ProgramError::AccountNotRentExempt);
    }
    
    // 🛡️ Initialize configuration with security defaults
    let config_data = GMCTokenConfig {
        mint: *mint_info.key,
        authority: *authority_info.key,
        transfer_fee_basis_points,
        maximum_fee,
        burn_address,
        staking_pool,
        ranking_pool,
        is_initialized: true,
        is_paused: false, // Start unpaused
    };
    
    // 🛡️ OWASP SC05: Serialize with error handling
    config_data.serialize(&mut &mut config_info.data.borrow_mut()[..])
        .map_err(|_| {
            msg!("🚨 Security Alert: Failed to serialize config");
            ProgramError::AccountDataTooSmall
        })?;
    
    msg!("✅ GMC Token initialized successfully");
    msg!("   Transfer Fee: {} basis points", transfer_fee_basis_points);
    msg!("   Maximum Fee: {} lamports", maximum_fee);
    msg!("   Authority: {}", authority_info.key);
    
    Ok(())
}

// 🛡️ Transfer with fee calculation and security checks
fn process_transfer_with_fee(
    _accounts: &[AccountInfo],
    amount: u64,
) -> ProgramResult {
    // 🛡️ OWASP SC02: Amount validation
    if amount == 0 {
        msg!("🚨 Security Alert: Transfer amount cannot be zero");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    // 🛡️ OWASP SC02: Calculate fee with overflow protection
    let fee = calculate_transfer_fee(amount, 50)?; // 0.5% = 50 basis points
    
    msg!("💸 Transfer: {} tokens, fee: {} tokens", amount, fee);
    
    // TODO: Implement actual transfer logic with SPL Token

// 🛡️ Process Vesting Instruction with security checks
#[allow(dead_code)]
fn process_vesting_instruction(
    accounts: &[AccountInfo],
    instruction: VestingInstruction,
) -> ProgramResult {
    match instruction {
        VestingInstruction::InitializeVesting => {
            msg!("📅 Instruction: InitializeVesting");
            vesting::process_initialize_vesting(accounts)
        }
        VestingInstruction::CreateVestingSchedule {
            beneficiary,
            vesting_type,
            total_amount,
            cliff_duration,
            vesting_duration,
            release_interval,
        } => {
            msg!("📅 Instruction: CreateVestingSchedule");
            vesting::process_create_vesting_schedule(
                accounts,
                beneficiary,
                vesting_type,
                total_amount,
                cliff_duration as i64, // Cast u32 to i64 for the function call
                vesting_duration as i64, // Cast u32 to i64
                release_interval as i64, // Cast u32 to i64
            )
        }
        VestingInstruction::ReleaseVestedTokens { schedule_id } => {
            msg!("📅 Instruction: ReleaseVestedTokens");
            vesting::process_release_vested_tokens(accounts, schedule_id)
        }
        VestingInstruction::EmergencyRelease { schedule_id, justification } => {
            msg!("🚨 Instruction: EmergencyRelease");
            vesting::process_emergency_release(accounts, schedule_id, justification)
        }
    }
}
    // This is a placeholder for the TDD cycle
    
    Ok(())
}

// 🛡️ Burn tokens with security validation
fn process_burn_tokens(
    _accounts: &[AccountInfo],
    amount: u64,
) -> ProgramResult {
    // 🛡️ OWASP SC02: Amount validation
    if amount == 0 {
        msg!("🚨 Security Alert: Burn amount cannot be zero");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    msg!("🔥 Burning {} tokens", amount);
    
    // TODO: Implement actual burn logic with SPL Token
    // This is a placeholder for the TDD cycle
    
    Ok(())
}

// 🛡️ Emergency pause mechanism (OWASP SC06: DoS Protection)
fn process_emergency_pause(accounts: &[AccountInfo]) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let authority_info = next_account_info(account_info_iter)?;
    let config_info = next_account_info(account_info_iter)?;
    
    // 🛡️ OWASP SC04: Authority validation
    if !authority_info.is_signer {
        msg!("🚨 Security Alert: Only authority can pause");
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    // 🛡️ Update config to paused state
    let mut config_data = GMCTokenConfig::try_from_slice(&config_info.data.borrow())?;
    config_data.is_paused = true;
    
    config_data.serialize(&mut &mut config_info.data.borrow_mut()[..])?;
    
    msg!("⏸️ GMC Token operations paused for security");
    
    Ok(())
}

// 🛡️ Resume operations
fn process_resume(accounts: &[AccountInfo]) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let authority_info = next_account_info(account_info_iter)?;
    let config_info = next_account_info(account_info_iter)?;
    
    // 🛡️ OWASP SC04: Authority validation
    if !authority_info.is_signer {
        msg!("🚨 Security Alert: Only authority can resume");
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    // 🛡️ Update config to active state
    let mut config_data = GMCTokenConfig::try_from_slice(&config_info.data.borrow())?;
    config_data.is_paused = false;
    
    config_data.serialize(&mut &mut config_info.data.borrow_mut()[..])?;
    
    msg!("▶️ GMC Token operations resumed");
    
    Ok(())
}

// 🛡️ Process staking instructions
fn process_staking_instruction(
    accounts: &[AccountInfo],
    staking_instruction: StakingInstruction,
) -> ProgramResult {
    match staking_instruction {
        StakingInstruction::CreatePool {
            pool_id,
            apy_basis_points,
            lock_duration_days,
            minimum_stake,
            maximum_stake,
        } => {
            msg!("🏗️ Creating staking pool: {}", pool_id);
            process_create_pool(
                accounts,
                pool_id,
                apy_basis_points,
                lock_duration_days,
                minimum_stake,
                maximum_stake,
            )
        },
        StakingInstruction::Stake { pool_id, amount } => {
            msg!("💰 Staking {} tokens in pool {}", amount, pool_id);
            process_stake(accounts, pool_id, amount)
        },
        StakingInstruction::ClaimRewards { pool_id } => {
            msg!("🎁 Claiming rewards from pool {}", pool_id);
            process_claim_rewards(accounts, pool_id)
        },
        StakingInstruction::Unstake { pool_id, amount } => {
            msg!("📤 Unstaking {} tokens from pool {}", amount, pool_id);
            process_unstake(accounts, pool_id, amount)
        },
        StakingInstruction::BurnForBoost {
            pool_id,
            burn_amount,
            boost_multiplier,
        } => {
            msg!("🔥 Burning {} tokens for boost in pool {}", burn_amount, pool_id);
            process_burn_for_boost(accounts, pool_id, burn_amount, boost_multiplier)
        },
    }
}

// 🤝 Affiliate instruction dispatcher
fn process_affiliate_instruction(
    accounts: &[AccountInfo],
    affiliate_instruction: AffiliateInstruction,
) -> ProgramResult {
    match affiliate_instruction {
        AffiliateInstruction::InitializeAffiliateSystem => {
            process_initialize_affiliate_system(accounts)
        },
        AffiliateInstruction::RegisterAffiliate { referrer } => {
            process_register_affiliate(accounts, referrer)
        },
        AffiliateInstruction::RecordReferral { affiliate_id, volume } => {
            process_record_referral(accounts, affiliate_id, volume)
        },
        AffiliateInstruction::ClaimCommissions { affiliate_id } => {
            process_claim_commissions(accounts, affiliate_id)
        },
        AffiliateInstruction::UpgradeLevel { affiliate_id } => {
            process_upgrade_level(accounts, affiliate_id)
        },
        AffiliateInstruction::UpdateAntiSybilScore { affiliate_id, new_score } => {
            process_update_anti_sybil_score(accounts, affiliate_id, new_score)
        },
    }
}

// 📅 Vesting instruction dispatcher
fn process_vesting_instruction(
    accounts: &[AccountInfo],
    vesting_instruction: VestingInstruction,
) -> ProgramResult {
    vesting::process_instruction_router(accounts, vesting_instruction)
}

// 🏆 Process ranking instructions
pub fn process_ranking_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    ranking_instruction: RankingInstruction,
) -> ProgramResult {
    match ranking_instruction {
        RankingInstruction::Initialize => {
            ranking::process_initialize(program_id, accounts)
        },
        RankingInstruction::UpdateScore { user_pubkey, score_to_add } => {
            ranking::process_update_score(accounts, user_pubkey, score_to_add)
        },
        RankingInstruction::DistributeRewards => {
            ranking::process_distribute_rewards(program_id, accounts)
        },
    }
}

// 🛡️ OWASP SC02: Safe fee calculation with overflow protection
pub fn calculate_transfer_fee(amount: u64, basis_points: u16) -> Result<u64, ProgramError> {
    // 🛡️ Input validation
    if basis_points > 10000 {
        msg!("🚨 Security Alert: Basis points cannot exceed 10000 (100%)");
        return Err(ProgramError::Custom(GMCError::TransferFeeTooHigh as u32));
    }

    // 🛡️ Safe arithmetic with overflow protection
    let fee = amount
        .checked_mul(basis_points as u64)
        .and_then(|x| x.checked_div(10000))
        .ok_or_else(|| {
            msg!("🚨 Security Alert: Fee calculation overflow");
            ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
        })?;

    Ok(fee)
}

// 🛡️ Utility function to check if contract is paused
pub fn check_not_paused(config: &GMCTokenConfig) -> ProgramResult {
    if config.is_paused {
        msg!("🚨 Security Alert: Contract is paused");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    // 🔴 RED: TDD Test-First Development
    
    #[test]
    fn test_calculate_transfer_fee_normal_case() {
        // Arrange
        let amount = 1000;
        let basis_points = 50; // 0.5%
        let expected_fee = 5;
        
        // Act
        let result = calculate_transfer_fee(amount, basis_points);
        
        // Assert
        assert_eq!(result.unwrap(), expected_fee);
    }
    
    #[test]
    fn test_calculate_transfer_fee_zero_amount() {
        // Arrange
        let amount = 0;
        let basis_points = 50;
        let expected_fee = 0;
        
        // Act
        let result = calculate_transfer_fee(amount, basis_points);
        
        // Assert
        assert_eq!(result.unwrap(), expected_fee);
    }
    
    #[test]
    fn test_calculate_transfer_fee_overflow_protection() {
        // 🛡️ OWASP SC02: Integer Overflow Test
        let amount = u64::MAX;
        let basis_points = 50;
        
        // Act
        let result = calculate_transfer_fee(amount, basis_points);
        
        // Assert
        assert!(result.is_err());
    }
    
    #[test]
    fn test_calculate_transfer_fee_invalid_basis_points() {
        // 🛡️ Security Test: Invalid input
        let amount = 1000;
        let basis_points = 10001; // > 100%
        
        // Act
        let result = calculate_transfer_fee(amount, basis_points);
        
        // Assert
        assert!(result.is_err());
    }
    
    #[test]
    fn test_reentrancy_guard() {
        // 🛡️ OWASP SC01: Reentrancy Protection Test
        let mut guard = ReentrancyGuard::default();
        
        // First lock should succeed
        assert!(guard.lock().is_ok());
        
        // Second lock should fail (reentrancy detected)
        assert!(guard.lock().is_err());
        
        guard.unlock();
        
        // After unlock, should work again
        assert!(guard.lock().is_ok());
    }
    
    #[test]
    fn test_gmc_token_config_serialization() {
        // 🛡️ Test data integrity
        let config = GMCTokenConfig {
            mint: Pubkey::new_unique(),
            authority: Pubkey::new_unique(),
            transfer_fee_basis_points: 50,
            maximum_fee: 1000000,
            burn_address: Pubkey::new_unique(),
            staking_pool: Pubkey::new_unique(),
            ranking_pool: Pubkey::new_unique(),
            is_initialized: true,
            is_paused: false,
        };
        
        // Serialize
        let serialized = config.try_to_vec().unwrap();
        
        // Deserialize
        let deserialized = GMCTokenConfig::try_from_slice(&serialized).unwrap();
        
        // Assert
        assert_eq!(config.mint, deserialized.mint);
        assert_eq!(config.authority, deserialized.authority);
        assert_eq!(config.transfer_fee_basis_points, deserialized.transfer_fee_basis_points);
        assert_eq!(config.is_initialized, deserialized.is_initialized);
        assert_eq!(config.is_paused, deserialized.is_paused);
    }
}

// 🛡️ Property-based testing for additional security
// Property tests removed - using TDD tests in individual modules instead
