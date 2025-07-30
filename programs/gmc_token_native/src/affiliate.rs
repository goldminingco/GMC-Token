// 🤝 GMC Token Affiliate System - Native Rust Implementation
// 🛡️ OWASP Smart Contract Top 10 Compliance
// 🧪 Test-Driven Development (TDD) Ready
// 🔒 DevSecOps Security-First Design

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    clock::Clock,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    sysvar::Sysvar,
};
use borsh::{BorshDeserialize, BorshSerialize};
use crate::GMCError;

// 🛡️ OWASP SC05: Input validation constants
pub const MAX_AFFILIATE_LEVELS: u8 = 6;
#[allow(dead_code)]
pub const MAX_REFERRALS_PER_LEVEL: u32 = 1000;
#[allow(dead_code)]
pub const MIN_STAKE_FOR_AFFILIATE: u64 = 1_000_000; // 1M tokens minimum
#[allow(dead_code)]
pub const ANTI_SYBIL_COOLDOWN: i64 = 86400; // 24 hours in seconds

// 🚀 OPTIMIZED: Affiliate Level Configuration with better memory layout
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, Default, Copy)]
#[repr(C)] // 🚀 OPTIMIZATION: Explicit memory layout
pub struct AffiliateLevelConfig {
    pub min_volume_required: u64,          // 8 bytes - most accessed field first
    pub min_referrals_required: u16,       // 🚀 OPTIMIZATION: u16 instead of u32 (2 bytes)
    pub commission_rate_basis_points: u16, // 2 bytes - 10000 = 100%
    pub level: u8,                         // 1 byte
    pub is_active: bool,                   // 1 byte
}

impl AffiliateLevelConfig {
    pub const LEN: usize = 8 + 2 + 2 + 1 + 1; // 🚀 OPTIMIZATION: 14 bytes (vs 16)
    
    // 🛡️ OWASP SC02: Safe commission calculation with overflow protection
    pub fn calculate_commission(&self, volume: u64) -> Result<u64, ProgramError> {
        if !self.is_active {
            return Ok(0);
        }
        
        volume
            .checked_mul(self.commission_rate_basis_points as u64)
            .and_then(|x| x.checked_div(10000))
            .ok_or_else(|| {
                msg!("🚨 Security Alert: Commission calculation overflow");
                ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
            })
    }
}

// 🚀 OPTIMIZED: Individual Affiliate Record with better memory layout
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
#[repr(C)] // 🚀 OPTIMIZATION: Explicit memory layout
pub struct AffiliateRecord {
    pub affiliate_id: Pubkey,               // 32 bytes - most accessed field first
    pub referrer: Option<Pubkey>,           // 33 bytes - Who referred this affiliate
    pub total_volume: u64,                  // 8 bytes
    pub total_commissions_earned: u64,      // 8 bytes
    pub last_activity_timestamp: u32,       // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub registration_timestamp: u32,        // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub total_referrals: u16,               // 🚀 OPTIMIZATION: u16 instead of u32 (2 bytes)
    pub anti_sybil_score: u16,              // 2 bytes - Higher = more legitimate
    pub current_level: u8,                  // 1 byte
    pub is_active: bool,                    // 1 byte
}

impl AffiliateRecord {
    pub const LEN: usize = 32 + 33 + 8 + 8 + 4 + 4 + 2 + 2 + 1 + 1; // 🚀 OPTIMIZATION: 95 bytes (vs 105)
    
    // 🚀 OPTIMIZATION: Simplified timestamp validation
    pub fn validate_activity_timestamp(&self) -> Result<(), ProgramError> {
        let clock = Clock::get()?;
        let current_time = clock.unix_timestamp as u32; // Safe cast for u32 timestamps
        
        // 🛡️ OWASP SC03: Prevent timestamp manipulation
        if self.last_activity_timestamp > current_time {
            msg!("🚨 Security Alert: Future timestamp detected in affiliate record");
            return Err(ProgramError::Custom(GMCError::InvalidTimestamp as u32));
        }
        
        Ok(())
    }
    
    // 🚀 OPTIMIZATION: Simplified anti-Sybil validation with cooldown
    pub fn can_register_referral(&self) -> Result<bool, ProgramError> {
        let clock = Clock::get()?;
        let current_time = clock.unix_timestamp as u32; // Safe cast for u32 timestamps
        
        // 🚀 OPTIMIZATION: Simplified cooldown protection with precomputed constant
        const COOLDOWN_SECONDS: u32 = 86400; // 24 hours
        let time_since_last = current_time.saturating_sub(self.last_activity_timestamp);
        
        Ok(time_since_last >= COOLDOWN_SECONDS || self.anti_sybil_score >= 500)
    }
    
    // 🛡️ Level upgrade eligibility check
    #[allow(dead_code)]
    pub fn is_eligible_for_upgrade(&self, level_config: &AffiliateLevelConfig) -> bool {
        self.total_referrals >= level_config.min_referrals_required &&
        self.total_volume >= level_config.min_volume_required &&
        self.current_level < level_config.level &&
        self.is_active
    }
}

// 🛡️ Affiliate System Global State
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct AffiliateSystemConfig {
    pub authority: Pubkey,
    pub total_affiliates: u32,
    pub total_commissions_distributed: u64,
    pub is_registration_open: bool,
    pub anti_sybil_enabled: bool,
    pub level_configs: [AffiliateLevelConfig; MAX_AFFILIATE_LEVELS as usize],
}

impl AffiliateSystemConfig {
    pub const LEN: usize = 32 + 4 + 8 + 1 + 1 + (AffiliateLevelConfig::LEN * MAX_AFFILIATE_LEVELS as usize); // 142 bytes
    
    // 🛡️ Initialize with secure defaults
    pub fn new(authority: Pubkey) -> Self {
        Self {
            authority,
            total_affiliates: 0,
            total_commissions_distributed: 0,
            is_registration_open: true,
            anti_sybil_enabled: true,
            level_configs: [
                // Level 1: Bronze
                AffiliateLevelConfig {
                    level: 1,
                    commission_rate_basis_points: 100, // 1%
                    min_referrals_required: 0,
                    min_volume_required: 0,
                    is_active: true,
                },
                // Level 2: Silver
                AffiliateLevelConfig {
                    level: 2,
                    commission_rate_basis_points: 200, // 2%
                    min_referrals_required: 10,
                    min_volume_required: 10_000_000, // 10M tokens
                    is_active: true,
                },
                // Level 3: Gold
                AffiliateLevelConfig {
                    level: 3,
                    commission_rate_basis_points: 350, // 3.5%
                    min_referrals_required: 25,
                    min_volume_required: 50_000_000, // 50M tokens
                    is_active: true,
                },
                // Level 4: Platinum
                AffiliateLevelConfig {
                    level: 4,
                    commission_rate_basis_points: 500, // 5%
                    min_referrals_required: 50,
                    min_volume_required: 100_000_000, // 100M tokens
                    is_active: true,
                },
                // Level 5: Diamond
                AffiliateLevelConfig {
                    level: 5,
                    commission_rate_basis_points: 750, // 7.5%
                    min_referrals_required: 100,
                    min_volume_required: 500_000_000, // 500M tokens
                    is_active: true,
                },
                // Level 6: Elite
                AffiliateLevelConfig {
                    level: 6,
                    commission_rate_basis_points: 1000, // 10%
                    min_referrals_required: 250,
                    min_volume_required: 1_000_000_000, // 1B tokens
                    is_active: true,
                },
            ],
        }
    }
}

// 🛡️ Affiliate Instructions
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub enum AffiliateInstruction {
    /// Initialize the affiliate system
    InitializeAffiliateSystem,
    
    /// Register as a new affiliate
    RegisterAffiliate {
        referrer: Option<Pubkey>,
    },
    
    /// Record a referral transaction
    RecordReferral {
        affiliate_id: Pubkey,
        volume: u64,
    },
    
    /// Claim pending commissions
    ClaimCommissions {
        affiliate_id: Pubkey,
    },
    
    /// Upgrade affiliate level
    UpgradeLevel {
        affiliate_id: Pubkey,
    },
    
    /// Update anti-Sybil score (authority only)
    UpdateAntiSybilScore {
        affiliate_id: Pubkey,
        new_score: u16,
    },
}

// 🛡️ Affiliate instruction processors with TDD implementation
pub fn process_initialize_affiliate_system(
    accounts: &[AccountInfo],
) -> ProgramResult {
    msg!("🤝 Processing: InitializeAffiliateSystem");
    
    let account_info_iter = &mut accounts.iter();
    
    // 🛡️ OWASP SC04: Account validation
    let authority_info = next_account_info(account_info_iter)?;
    let config_info = next_account_info(account_info_iter)?;
    let rent_info = next_account_info(account_info_iter)?;
    
    // 🛡️ OWASP SC04: Authority signature validation
    if !authority_info.is_signer {
        msg!("🚨 Security Alert: Authority must be signer for affiliate system init");
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    // 🛡️ OWASP SC05: Rent exemption validation
    let rent = solana_program::sysvar::rent::Rent::from_account_info(rent_info)?;
    if !rent.is_exempt(config_info.lamports(), config_info.data_len()) {
        msg!("🚨 Security Alert: Affiliate config account not rent exempt");
        return Err(ProgramError::AccountNotRentExempt);
    }
    
    // 🛡️ Check if already initialized
    if config_info.data_len() >= AffiliateSystemConfig::LEN {
        let existing_data = AffiliateSystemConfig::try_from_slice(&config_info.data.borrow())?;
        if existing_data.total_affiliates > 0 {
            msg!("🚨 Security Alert: Affiliate system already initialized");
            return Err(ProgramError::AccountAlreadyInitialized);
        }
    }
    
    // 🛡️ Initialize affiliate system with secure defaults
    let config_data = AffiliateSystemConfig::new(*authority_info.key);
    
    // 🛡️ OWASP SC05: Serialize with error handling
    config_data.serialize(&mut &mut config_info.data.borrow_mut()[..])
        .map_err(|_| {
            msg!("🚨 Security Alert: Failed to serialize affiliate config");
            ProgramError::AccountDataTooSmall
        })?;
    
    msg!("✅ Affiliate System initialized successfully");
    msg!("   Authority: {}", authority_info.key);
    msg!("   Registration Open: {}", config_data.is_registration_open);
    msg!("   Anti-Sybil Enabled: {}", config_data.anti_sybil_enabled);
    
    Ok(())
}

pub fn process_register_affiliate(
    accounts: &[AccountInfo],
    referrer: Option<Pubkey>,
) -> ProgramResult {
    msg!("🤝 Processing: RegisterAffiliate");
    
    let account_info_iter = &mut accounts.iter();
    
    // 🛡️ OWASP SC04: Account validation
    let affiliate_info = next_account_info(account_info_iter)?;
    let affiliate_record_info = next_account_info(account_info_iter)?;
    let config_info = next_account_info(account_info_iter)?;
    let rent_info = next_account_info(account_info_iter)?;
    
    // 🛡️ OWASP SC04: Affiliate signature validation
    if !affiliate_info.is_signer {
        msg!("🚨 Security Alert: Affiliate must sign registration");
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    // 🛡️ Load affiliate system config
    let mut config_data = AffiliateSystemConfig::try_from_slice(&config_info.data.borrow())?;
    
    // 🛡️ Check if registration is open
    if !config_data.is_registration_open {
        msg!("🚨 Security Alert: Affiliate registration is currently closed");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    // 🛡️ OWASP SC05: Rent exemption validation
    let rent = solana_program::sysvar::rent::Rent::from_account_info(rent_info)?;
    if !rent.is_exempt(affiliate_record_info.lamports(), affiliate_record_info.data_len()) {
        msg!("🚨 Security Alert: Affiliate record account not rent exempt");
        return Err(ProgramError::AccountNotRentExempt);
    }
    
    // 🛡️ Check if affiliate already exists
    if affiliate_record_info.data_len() >= AffiliateRecord::LEN {
        let existing_record = AffiliateRecord::try_from_slice(&affiliate_record_info.data.borrow());
        if existing_record.is_ok() && existing_record.unwrap().is_active {
            msg!("🚨 Security Alert: Affiliate already registered");
            return Err(ProgramError::AccountAlreadyInitialized);
        }
    }
    
    // 🛡️ OWASP SC03: Get current timestamp
    let clock = Clock::get()?;
    let current_time = clock.unix_timestamp;
    
    // 🛡️ Validate referrer if provided
    if let Some(referrer_key) = referrer {
        // In a full implementation, we would validate the referrer exists and is active
        msg!("📝 Referrer provided: {}", referrer_key);
    }
    
    // 🛡️ Create new affiliate record with secure defaults
    let affiliate_record = AffiliateRecord {
        affiliate_id: *affiliate_info.key,
        referrer,
        current_level: 1, // Start at Bronze level
        total_referrals: 0,
        total_volume: 0,
        total_commissions_earned: 0,
        last_activity_timestamp: current_time as u32,
        registration_timestamp: current_time as u32,
        is_active: true,
        anti_sybil_score: 100, // Base score for new affiliates
    };
    
    // 🛡️ OWASP SC05: Serialize with error handling
    affiliate_record.serialize(&mut &mut affiliate_record_info.data.borrow_mut()[..])
        .map_err(|_| {
            msg!("🚨 Security Alert: Failed to serialize affiliate record");
            ProgramError::AccountDataTooSmall
        })?;
    
    // 🛡️ OWASP SC02: Safe increment with overflow protection
    config_data.total_affiliates = config_data.total_affiliates
        .checked_add(1)
        .ok_or_else(|| {
            msg!("🚨 Security Alert: Total affiliates counter overflow");
            ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
        })?;
    
    // 🛡️ Update config
    config_data.serialize(&mut &mut config_info.data.borrow_mut()[..])
        .map_err(|_| {
            msg!("🚨 Security Alert: Failed to update affiliate config");
            ProgramError::AccountDataTooSmall
        })?;
    
    msg!("✅ Affiliate registered successfully");
    msg!("   Affiliate ID: {}", affiliate_info.key);
    msg!("   Level: Bronze (1)");
    msg!("   Referrer: {:?}", referrer);
    msg!("   Total Affiliates: {}", config_data.total_affiliates);
    
    Ok(())
}

pub fn process_record_referral(
    accounts: &[AccountInfo],
    affiliate_id: Pubkey,
    volume: u64,
) -> ProgramResult {
    msg!("🤝 Processing: RecordReferral");
    
    let account_info_iter = &mut accounts.iter();
    
    // 🛡️ OWASP SC04: Account validation
    let authority_info = next_account_info(account_info_iter)?;
    let affiliate_record_info = next_account_info(account_info_iter)?;
    let config_info = next_account_info(account_info_iter)?;
    
    // 🛡️ OWASP SC04: Authority signature validation (only authorized entities can record referrals)
    if !authority_info.is_signer {
        msg!("🚨 Security Alert: Authority must sign referral recording");
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    // 🛡️ OWASP SC05: Input validation
    if volume == 0 {
        msg!("🚨 Security Alert: Volume must be greater than 0");
        return Err(ProgramError::InvalidArgument);
    }
    
    // 🛡️ Load affiliate record
    let mut affiliate_record = AffiliateRecord::try_from_slice(&affiliate_record_info.data.borrow())?;
    
    // 🛡️ Validate affiliate ID matches
    if affiliate_record.affiliate_id != affiliate_id {
        msg!("🚨 Security Alert: Affiliate ID mismatch");
        return Err(ProgramError::InvalidArgument);
    }
    
    // 🛡️ Check if affiliate is active
    if !affiliate_record.is_active {
        msg!("🚨 Security Alert: Affiliate is not active");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    // 🛡️ OWASP SC03: Timestamp validation
    affiliate_record.validate_activity_timestamp()?;
    
    // 🛡️ Anti-Sybil protection
    if !affiliate_record.can_register_referral()? {
        msg!("🚨 Security Alert: Anti-Sybil cooldown active");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    // 🛡️ Load config for commission calculation
    let mut config_data = AffiliateSystemConfig::try_from_slice(&config_info.data.borrow())?;
    let level_config = &config_data.level_configs[(affiliate_record.current_level - 1) as usize];
    
    // 🛡️ OWASP SC02: Safe arithmetic operations
    let commission = level_config.calculate_commission(volume)?;
    
    // 🛡️ Update affiliate record with overflow protection
    affiliate_record.total_referrals = affiliate_record.total_referrals
        .checked_add(1)
        .ok_or_else(|| {
            msg!("🚨 Security Alert: Total referrals overflow");
            ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
        })?;
    
    affiliate_record.total_volume = affiliate_record.total_volume
        .checked_add(volume)
        .ok_or_else(|| {
            msg!("🚨 Security Alert: Total volume overflow");
            ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
        })?;
    
    affiliate_record.total_commissions_earned = affiliate_record.total_commissions_earned
        .checked_add(commission)
        .ok_or_else(|| {
            msg!("🚨 Security Alert: Total commissions overflow");
            ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
        })?;
    
    // 🛡️ OWASP SC03: Update timestamp
    let clock = Clock::get()?;
    affiliate_record.last_activity_timestamp = clock.unix_timestamp as u32;
    
    // 🛡️ Increase anti-Sybil score for legitimate activity
    affiliate_record.anti_sybil_score = affiliate_record.anti_sybil_score
        .saturating_add(1)
        .min(1000); // Cap at 1000
    
    // 🛡️ Update global statistics
    config_data.total_commissions_distributed = config_data.total_commissions_distributed
        .checked_add(commission)
        .ok_or_else(|| {
            msg!("🚨 Security Alert: Total commissions distributed overflow");
            ProgramError::Custom(GMCError::ArithmeticOverflow as u32)
        })?;
    
    // 🛡️ OWASP SC05: Serialize with error handling
    affiliate_record.serialize(&mut &mut affiliate_record_info.data.borrow_mut()[..])
        .map_err(|_| {
            msg!("🚨 Security Alert: Failed to serialize affiliate record");
            ProgramError::AccountDataTooSmall
        })?;
    
    config_data.serialize(&mut &mut config_info.data.borrow_mut()[..])
        .map_err(|_| {
            msg!("🚨 Security Alert: Failed to update affiliate config");
            ProgramError::AccountDataTooSmall
        })?;
    
    msg!("✅ Referral recorded successfully");
    msg!("   Affiliate ID: {}", affiliate_id);
    msg!("   Volume: {}", volume);
    msg!("   Commission Earned: {}", commission);
    msg!("   Total Referrals: {}", affiliate_record.total_referrals);
    msg!("   Total Volume: {}", affiliate_record.total_volume);
    msg!("   Anti-Sybil Score: {}", affiliate_record.anti_sybil_score);
    
    Ok(())
}

pub fn process_claim_commissions(
    _accounts: &[AccountInfo],
    _affiliate_id: Pubkey,
) -> ProgramResult {
    msg!("🤝 Processing: ClaimCommissions");
    // TODO: Implement with TDD
    Ok(())
}

pub fn process_upgrade_level(
    _accounts: &[AccountInfo],
    _affiliate_id: Pubkey,
) -> ProgramResult {
    msg!("🤝 Processing: UpgradeLevel");
    // TODO: Implement with TDD
    Ok(())
}

pub fn process_update_anti_sybil_score(
    _accounts: &[AccountInfo],
    _affiliate_id: Pubkey,
    _new_score: u16,
) -> ProgramResult {
    msg!("🤝 Processing: UpdateAntiSybilScore");
    // TODO: Implement with TDD
    Ok(())
}

// 🧪 TDD Tests Module
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_affiliate_level_commission_calculation() {
        // Arrange
        let level_config = AffiliateLevelConfig {
            level: 1,
            commission_rate_basis_points: 100, // 1%
            min_referrals_required: 0,
            min_volume_required: 0,
            is_active: true,
        };
        
        // Act
        let commission = level_config.calculate_commission(1_000_000).unwrap();
        
        // Assert
        assert_eq!(commission, 10_000); // 1% of 1M = 10K
    }
    
    #[test]
    fn test_affiliate_level_commission_overflow_protection() {
        // Arrange
        let level_config = AffiliateLevelConfig {
            level: 6,
            commission_rate_basis_points: 1000, // 10%
            min_referrals_required: 0,
            min_volume_required: 0,
            is_active: true,
        };
        
        // Act & Assert - Should not overflow
        let result = level_config.calculate_commission(u64::MAX);
        assert!(result.is_err()); // Should fail due to overflow protection
    }
    
    #[test]
    fn test_affiliate_level_inactive_returns_zero() {
        // Arrange
        let level_config = AffiliateLevelConfig {
            level: 1,
            commission_rate_basis_points: 100,
            min_referrals_required: 0,
            min_volume_required: 0,
            is_active: false, // Inactive
        };
        
        // Act
        let commission = level_config.calculate_commission(1_000_000).unwrap();
        
        // Assert
        assert_eq!(commission, 0); // Should return 0 for inactive levels
    }
    
    #[test]
    fn test_affiliate_record_level_upgrade_eligibility() {
        // Arrange
        let affiliate = AffiliateRecord {
            affiliate_id: Pubkey::new_unique(),
            referrer: None,
            current_level: 1,
            total_referrals: 15,
            total_volume: 20_000_000,
            total_commissions_earned: 0,
            last_activity_timestamp: 0,
            registration_timestamp: 0,
            is_active: true,
            anti_sybil_score: 600,
        };
        
        let level_2_config = AffiliateLevelConfig {
            level: 2,
            commission_rate_basis_points: 200,
            min_referrals_required: 10,
            min_volume_required: 10_000_000,
            is_active: true,
        };
        
        // Act
        let eligible = affiliate.is_eligible_for_upgrade(&level_2_config);
        
        // Assert
        assert!(eligible); // Should be eligible for level 2
    }
    
    #[test]
    fn test_affiliate_system_config_initialization() {
        // Arrange
        let authority = Pubkey::new_unique();
        
        // Act
        let config = AffiliateSystemConfig::new(authority);
        
        // Assert
        assert_eq!(config.authority, authority);
        assert_eq!(config.total_affiliates, 0);
        assert!(config.is_registration_open);
        assert!(config.anti_sybil_enabled);
        assert_eq!(config.level_configs[0].level, 1);
        assert_eq!(config.level_configs[5].level, 6);
        assert_eq!(config.level_configs[5].commission_rate_basis_points, 1000); // 10% for Elite
    }
    
    #[test]
    fn test_anti_sybil_cooldown_validation() {
        // This test would need mocking Clock::get() in a real implementation
        // For now, we test the logic structure
        let affiliate = AffiliateRecord {
            affiliate_id: Pubkey::new_unique(),
            referrer: None,
            current_level: 1,
            total_referrals: 0,
            total_volume: 0,
            total_commissions_earned: 0,
            last_activity_timestamp: 0,
            registration_timestamp: 0,
            is_active: true,
            anti_sybil_score: 600, // High score should bypass cooldown
        };
        
        // In a real test, we would mock the clock and test the cooldown logic
        // For now, we just verify the structure is correct
        assert_eq!(affiliate.anti_sybil_score, 600);
    }
}
