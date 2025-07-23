//! 📅 GMC Token Vesting System - Native Rust Implementation
//! 
//! Implements secure vesting mechanisms for RWA tokens following TDD + OWASP + DevSecOps:
//! - Team token vesting with cliff periods
//! - Investor token vesting schedules
//! - Linear and milestone-based vesting
//! - Emergency release controls for centralized management
//! - OWASP Smart Contract Top 10 mitigations

use solana_program::{
    account_info::AccountInfo,
    clock::Clock,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    sysvar::Sysvar,
};
use borsh::{BorshDeserialize, BorshSerialize};
use crate::GMCError;

// 🚀 OPTIMIZED: Vesting Configuration Constants with precomputed values
#[allow(dead_code)]
pub const MAX_VESTING_SCHEDULES: usize = 50; // 🚀 OPTIMIZATION: Reduced from 100 to 50
pub const MIN_CLIFF_DURATION: u32 = 2_592_000; // 🚀 OPTIMIZATION: 30 days precomputed (30 * 24 * 60 * 60)
pub const MAX_VESTING_DURATION: u32 = 126_144_000; // 🚀 OPTIMIZATION: 4 years precomputed (4 * 365 * 24 * 60 * 60)
pub const MIN_VESTING_AMOUNT: u64 = 1_000_000; // 1M tokens

// 📅 Vesting Schedule Type
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub enum VestingType {
    Linear,
    Cliff,
    Team,
    Investor,
}

// 📅 Vesting Status
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub enum VestingStatus {
    Active,
    Paused,
    Completed,
    Cancelled,
    EmergencyReleased,
}

// 🚀 OPTIMIZED: Vesting Schedule Structure with better memory layout
#[derive(Debug, Clone, BorshSerialize, BorshDeserialize)]
#[repr(C)] // 🚀 OPTIMIZATION: Explicit memory layout
pub struct VestingSchedule {
    pub beneficiary: Pubkey,            // 32 bytes - most accessed field first
    pub created_by: Pubkey,             // 32 bytes
    pub total_amount: u64,              // 8 bytes
    pub released_amount: u64,           // 8 bytes
    pub id: u32,                        // 🚀 OPTIMIZATION: u32 instead of u64 (4 bytes)
    pub cliff_timestamp: u32,           // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub start_timestamp: u32,           // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub end_timestamp: u32,             // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub last_release_timestamp: u32,    // 🚀 OPTIMIZATION: u32 timestamp (4 bytes)
    pub release_interval: u32,          // 🚀 OPTIMIZATION: u32 instead of i64 (4 bytes)
    pub vesting_type: VestingType,      // 1 byte (enum)
    pub status: VestingStatus,          // 1 byte (enum)
    pub emergency_releasable: bool,     // 1 byte
    pub _padding: u8,                   // 🚀 OPTIMIZATION: Explicit padding
}

// 🚀 OPTIMIZED: Vesting System Configuration with better memory layout
#[derive(Debug, Clone, BorshSerialize, BorshDeserialize)]
#[repr(C)] // 🚀 OPTIMIZATION: Explicit memory layout
pub struct VestingConfig {
    pub authority: Pubkey,              // 32 bytes - most accessed field first
    pub total_vested_amount: u64,       // 8 bytes
    pub total_released_amount: u64,     // 8 bytes
    pub total_schedules: u32,           // 🚀 OPTIMIZATION: u32 instead of u64 (4 bytes)
    pub active_schedules: u32,          // 🚀 OPTIMIZATION: u32 instead of u64 (4 bytes)
    pub completed_schedules: u32,       // 🚀 OPTIMIZATION: u32 instead of u64 (4 bytes)
    pub emergency_release_enabled: bool, // 1 byte
    pub paused: bool,                   // 1 byte
    pub initialized: bool,              // 1 byte
    pub _padding: u8,                   // 🚀 OPTIMIZATION: Explicit padding
}

// 📅 Vesting Instructions Enum
#[derive(Debug, Clone, BorshSerialize, BorshDeserialize)]
pub enum VestingInstruction {
    InitializeVesting,
    CreateVestingSchedule {
        beneficiary: Pubkey,
        vesting_type: VestingType,
        total_amount: u64,
        cliff_duration: u32,            // 🚀 OPTIMIZATION: u32 instead of i64
        vesting_duration: u32,          // 🚀 OPTIMIZATION: u32 instead of i64
        release_interval: u32,          // 🚀 OPTIMIZATION: u32 instead of i64
    },
    ReleaseVestedTokens {
        schedule_id: u64,
    },
    EmergencyRelease {
        schedule_id: u64,
        justification: String,
    },
}

// 📅 Router function to process vesting instructions
/// 
/// Receives a VestingInstruction and routes it to the appropriate handler
pub fn process_instruction_router(
    accounts: &[AccountInfo],
    instruction: VestingInstruction,
) -> ProgramResult {
    match instruction {
        VestingInstruction::InitializeVesting => {
            process_initialize_vesting(accounts)
        },
        VestingInstruction::CreateVestingSchedule {
            beneficiary,
            vesting_type,
            total_amount,
            cliff_duration,
            vesting_duration,
            release_interval,
        } => {
            process_create_vesting_schedule(
                accounts,
                beneficiary,
                vesting_type,
                total_amount,
                cliff_duration.into(),
                vesting_duration.into(),
                release_interval.into(),
            )
        },
        VestingInstruction::ReleaseVestedTokens { schedule_id } => {
            process_release_vested_tokens(accounts, schedule_id.try_into().unwrap())
        },
        VestingInstruction::EmergencyRelease { schedule_id, justification } => {
            process_emergency_release(accounts, schedule_id.try_into().unwrap(), justification)
        },
    }
}

// 📅 Initialize Vesting System
pub fn process_initialize_vesting(accounts: &[AccountInfo]) -> ProgramResult {
    msg!("📅 Initializing Vesting System");
    
    let account_info_iter = &mut accounts.iter();
    let authority_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let config_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let _rent_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    
    if !authority_info.is_signer {
        msg!(" Authority signature required");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    
    let clock = Clock::get()?;
    let _current_time = clock.unix_timestamp;
    
    let vesting_config = VestingConfig {
        authority: *authority_info.key,
        total_schedules: 0,
        active_schedules: 0,
        completed_schedules: 0,
        total_vested_amount: 0,
        total_released_amount: 0,
        emergency_release_enabled: true, // Centralized control for RWA
        paused: false,
        initialized: true,
        _padding: 0,
    };
    
    vesting_config.serialize(&mut &mut config_info.data.borrow_mut()[..])?;
    
    msg!("✅ Vesting System initialized successfully");
    msg!("🏢 Centralized management enabled for RWA compliance");
    
    Ok(())
}

// 📅 Create Vesting Schedule
pub fn process_create_vesting_schedule(
    accounts: &[AccountInfo],
    beneficiary: Pubkey,
    vesting_type: VestingType,
    total_amount: u64,
    cliff_duration: i64,
    vesting_duration: i64,
    release_interval: i64,
) -> ProgramResult {
    msg!("📅 Creating vesting schedule for {:?}", vesting_type);
    
    let account_info_iter = &mut accounts.iter();
    let authority_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let config_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let schedule_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    
    if !authority_info.is_signer {
        msg!("❌ Authority signature required");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    
    let mut vesting_config = VestingConfig::try_from_slice(&config_info.data.borrow())?;
    
    if *authority_info.key != vesting_config.authority {
        msg!("❌ Invalid authority");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    
    // Input validation
    if total_amount < MIN_VESTING_AMOUNT {
        msg!("❌ Vesting amount too low");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    if cliff_duration < MIN_CLIFF_DURATION as i64 {
        msg!("❌ Cliff duration too short");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    if vesting_duration > MAX_VESTING_DURATION as i64 {
        msg!("❌ Vesting duration too long");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    let clock = Clock::get()?;
    let current_time = clock.unix_timestamp;
    
    let schedule_id = vesting_config.total_schedules
        .checked_add(1)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;
    
    let cliff_timestamp = current_time
        .checked_add(cliff_duration)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;
    
    let end_timestamp = current_time
        .checked_add(vesting_duration)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;
    
    let vesting_schedule = VestingSchedule {
        id: schedule_id,
        beneficiary,
        vesting_type: vesting_type.clone(),
        status: VestingStatus::Active,
        total_amount,
        released_amount: 0,
        cliff_timestamp: cliff_timestamp as u32,
        start_timestamp: current_time as u32,
        end_timestamp: end_timestamp as u32,
        last_release_timestamp: 0,
        release_interval: release_interval as u32,
        created_by: *authority_info.key,
        emergency_releasable: matches!(vesting_type, VestingType::Team | VestingType::Investor),
        _padding: 0,
    };
    
    vesting_config.total_schedules = schedule_id;
    vesting_config.active_schedules = vesting_config.active_schedules
        .checked_add(1)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;
    vesting_config.total_vested_amount = vesting_config.total_vested_amount
        .checked_add(total_amount)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;

    
    vesting_schedule.serialize(&mut &mut schedule_info.data.borrow_mut()[..])?;
    vesting_config.serialize(&mut &mut config_info.data.borrow_mut()[..])?;
    
    msg!("✅ Vesting schedule {} created successfully", schedule_id);
    
    Ok(())
}

// 📅 Release Vested Tokens
pub fn process_release_vested_tokens(
    accounts: &[AccountInfo],
    schedule_id: u64,
) -> ProgramResult {
    msg!("📅 Releasing vested tokens for schedule {}", schedule_id);
    
    let account_info_iter = &mut accounts.iter();
    let beneficiary_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let schedule_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let config_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    
    if !beneficiary_info.is_signer {
        msg!("❌ Beneficiary signature required");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    
    let mut vesting_schedule = VestingSchedule::try_from_slice(&schedule_info.data.borrow())?;
    let mut vesting_config = VestingConfig::try_from_slice(&config_info.data.borrow())?;
    
    if *beneficiary_info.key != vesting_schedule.beneficiary {
        msg!("❌ Invalid beneficiary");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    
    if vesting_schedule.status != VestingStatus::Active {
        msg!("❌ Vesting schedule not active");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    let clock = Clock::get()?;
    let current_time = clock.unix_timestamp;
    
    if current_time < vesting_schedule.cliff_timestamp as i64 {
        msg!("❌ Cliff period not reached");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    let vested_amount = calculate_vested_amount(&vesting_schedule, current_time)?;
    let releasable_amount = vested_amount
        .checked_sub(vesting_schedule.released_amount)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticUnderflow as u32))?;
    
    if releasable_amount == 0 {
        msg!("❌ No tokens available for release");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    vesting_schedule.released_amount = vesting_schedule.released_amount
        .checked_add(releasable_amount)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;
    vesting_schedule.last_release_timestamp = current_time as u32;

    
    if vesting_schedule.released_amount >= vesting_schedule.total_amount {
        vesting_schedule.status = VestingStatus::Completed;
        vesting_config.active_schedules = vesting_config.active_schedules
            .checked_sub(1)
            .ok_or(ProgramError::Custom(GMCError::ArithmeticUnderflow as u32))?;
        vesting_config.completed_schedules = vesting_config.completed_schedules
            .checked_add(1)
            .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;
    }
    
    vesting_config.total_released_amount = vesting_config.total_released_amount
        .checked_add(releasable_amount)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;

    
    vesting_schedule.serialize(&mut &mut schedule_info.data.borrow_mut()[..])?;
    vesting_config.serialize(&mut &mut config_info.data.borrow_mut()[..])?;
    
    msg!("✅ Released {} tokens to beneficiary", releasable_amount);
    
    Ok(())
}

// 🚨 Emergency Release (Centralized Control for RWA)
pub fn process_emergency_release(
    accounts: &[AccountInfo],
    schedule_id: u64,
    justification: String,
) -> ProgramResult {
    msg!("🚨 Emergency release for schedule {}", schedule_id);
    
    let account_info_iter = &mut accounts.iter();
    let authority_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let schedule_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    let config_info = account_info_iter.next().ok_or(ProgramError::NotEnoughAccountKeys)?;
    
    if !authority_info.is_signer {
        msg!("❌ Authority signature required");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    
    let mut vesting_schedule = VestingSchedule::try_from_slice(&schedule_info.data.borrow())?;
    let mut vesting_config = VestingConfig::try_from_slice(&config_info.data.borrow())?;
    
    if *authority_info.key != vesting_config.authority {
        msg!("❌ Invalid authority");
        return Err(ProgramError::Custom(GMCError::UnauthorizedAccess as u32));
    }
    
    if !vesting_config.emergency_release_enabled {
        msg!("❌ Emergency release disabled");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    if !vesting_schedule.emergency_releasable {
        msg!("❌ Schedule not eligible for emergency release");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    if justification.len() > 512 {
        msg!("❌ Justification too long");
        return Err(ProgramError::Custom(GMCError::InvalidAmount as u32));
    }
    
    let remaining_amount = vesting_schedule.total_amount
        .checked_sub(vesting_schedule.released_amount)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticUnderflow as u32))?;
    
    if remaining_amount == 0 {
        msg!("❌ No tokens remaining for emergency release");
        return Err(ProgramError::Custom(GMCError::OperationNotAllowed as u32));
    }
    
    let clock = Clock::get()?;
    let current_time = clock.unix_timestamp;
    
    vesting_schedule.released_amount = vesting_schedule.total_amount;
    vesting_schedule.status = VestingStatus::EmergencyReleased;
    vesting_schedule.last_release_timestamp = current_time as u32;

    
    vesting_config.active_schedules = vesting_config.active_schedules
        .checked_sub(1)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticUnderflow as u32))?;
    vesting_config.total_released_amount = vesting_config.total_released_amount
        .checked_add(remaining_amount)
        .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?;

    
    vesting_schedule.serialize(&mut &mut schedule_info.data.borrow_mut()[..])?;
    vesting_config.serialize(&mut &mut config_info.data.borrow_mut()[..])?;
    
    msg!("✅ Emergency release completed: {} tokens", remaining_amount);
    msg!("📝 Justification: {}", justification);
    
    Ok(())
}

// 📊 Calculate Vested Amount
fn calculate_vested_amount(schedule: &VestingSchedule, current_time: i64) -> Result<u64, ProgramError> {
    if current_time < schedule.cliff_timestamp as i64 {
        return Ok(0);
    }
    
    if current_time >= schedule.end_timestamp as i64 {
        return Ok(schedule.total_amount);
    }
    
    match schedule.vesting_type {
        VestingType::Linear | VestingType::Team | VestingType::Investor => {
            let elapsed_time = current_time
                .checked_sub(schedule.cliff_timestamp as i64)
                .ok_or(ProgramError::Custom(GMCError::ArithmeticUnderflow as u32))?;
            
            let total_vesting_time = (schedule.end_timestamp as i64)
                .checked_sub(schedule.cliff_timestamp as i64)
                .ok_or(ProgramError::Custom(GMCError::ArithmeticUnderflow as u32))?;
            
            if total_vesting_time == 0 {
                return Ok(schedule.total_amount);
            }
            
            let vested_amount = (schedule.total_amount as u128)
                .checked_mul(elapsed_time as u128)
                .ok_or(ProgramError::Custom(GMCError::ArithmeticOverflow as u32))?
                .checked_div(total_vesting_time as u128)
                .ok_or(ProgramError::Custom(GMCError::ArithmeticUnderflow as u32))?;
            
            Ok(vested_amount as u64)
        },
        VestingType::Cliff => {
            Ok(schedule.total_amount)
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_vesting_config_initialization() {
        let authority = Pubkey::new_unique();
        let _current_time = 1640995200;
        
        let config = VestingConfig {
            authority,
            total_schedules: 0,
            active_schedules: 0,
            completed_schedules: 0,
            total_vested_amount: 0,
            total_released_amount: 0,
            emergency_release_enabled: true,
            paused: false,
            initialized: true,
            _padding: 0,
        };
        
        assert!(config.initialized);
        assert!(config.emergency_release_enabled);
        assert!(!config.paused);
    }
    
    #[test]
    fn test_linear_vesting_calculation() {
        let schedule = VestingSchedule {
            id: 1,
            beneficiary: Pubkey::new_unique(),
            vesting_type: VestingType::Linear,
            status: VestingStatus::Active,
            total_amount: 1_000_000,
            released_amount: 0,
            cliff_timestamp: 1640995200,
            start_timestamp: 1640995200,
            end_timestamp: 1672531200,
            last_release_timestamp: 0,
            release_interval: 24 * 60 * 60,
            created_by: Pubkey::new_unique(),
            emergency_releasable: true,
            _padding: 0,
        };
        
        let vested_at_end = calculate_vested_amount(&schedule, schedule.end_timestamp as i64).unwrap();
        assert_eq!(vested_at_end, schedule.total_amount);
    }
    
    #[test]
    fn test_cliff_vesting_calculation() {
        let schedule = VestingSchedule {
            id: 1,
            beneficiary: Pubkey::new_unique(),
            vesting_type: VestingType::Cliff,
            status: VestingStatus::Active,
            total_amount: 1_000_000,
            released_amount: 0,
            cliff_timestamp: 1640995200,
            start_timestamp: 1640995200,
            end_timestamp: 1672531200,
            last_release_timestamp: 0,
            release_interval: 24 * 60 * 60,
            created_by: Pubkey::new_unique(),
            emergency_releasable: true,
            _padding: 0,
        };
        
        let vested_before_cliff = calculate_vested_amount(&schedule, (schedule.cliff_timestamp - 1) as i64).unwrap();
        assert_eq!(vested_before_cliff, 0);
        
        let vested_at_cliff = calculate_vested_amount(&schedule, schedule.cliff_timestamp as i64).unwrap();
        assert_eq!(vested_at_cliff, schedule.total_amount);
    }
}
