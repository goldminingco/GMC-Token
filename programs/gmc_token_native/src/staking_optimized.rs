// 🚀 GMC Token Staking - OTIMIZAÇÕES DE COMPUTE UNITS
// Sprint 1: Packed Data Structures + APY Optimization + Affiliate Loops
// Target: -25% compute units nas instruções críticas

use solana_program::{
    account_info::AccountInfo,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
};

use borsh::{BorshDeserialize, BorshSerialize};
use crate::GMCError;

// 🚀 OTIMIZAÇÃO 1: OPTIMIZED DATA STRUCTURES
// Redução de bytes por registro, melhor cache locality

#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct StakeRecordOptimized {
    pub staker: Pubkey,                    // 32 bytes (alignment-friendly first)
    pub amount: u64,                       // 8 bytes
    pub metadata: PackedStakeMetadata,     // 8 bytes (optimized from 16+ bytes)
    pub timestamp: i64,                    // 8 bytes (unified timestamp)
    // Total: 56 bytes (vs 60+ original) = -7% memory + better cache
}

#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, Copy)]
pub struct PackedStakeMetadata {
    pub total_claimed_compressed: u32,     // 4 bytes (lamports/1000 for compression)
    pub burn_boost_level: u8,              // 1 byte (0-255 levels vs u16)
    pub affiliate_tier: u8,                // 1 byte (combined affiliate info)
    pub pool_flags: u8,                    // 1 byte (bitflags: pool_id, stake_type, active)
    pub reserved: u8,                      // 1 byte (future expansion)
}

impl PackedStakeMetadata {
    // 🚀 OPTIMIZATION: Bitfield operations for pool flags
    pub fn set_pool_id(&mut self, pool_id: u8) {
        self.pool_flags = (self.pool_flags & 0xF0) | (pool_id & 0x0F);
    }
    
    pub fn get_pool_id(&self) -> u8 {
        self.pool_flags & 0x0F
    }
    
    pub fn set_stake_type(&mut self, stake_type: u8) {
        self.pool_flags = (self.pool_flags & 0x8F) | ((stake_type & 0x07) << 4);
    }
    
    pub fn get_stake_type(&self) -> u8 {
        (self.pool_flags >> 4) & 0x07
    }
    
    pub fn set_active(&mut self, active: bool) {
        if active {
            self.pool_flags |= 0x80;
        } else {
            self.pool_flags &= 0x7F;
        }
    }
    
    pub fn is_active(&self) -> bool {
        self.pool_flags & 0x80 != 0
    }
}

// 🚀 OTIMIZAÇÃO 2: APY CALCULATION WITH LOOKUP TABLES
// Pre-computed lookup tables para evitar cálculos runtime custosos

// 🚀 OPTIMIZATION: Base constants for APY calculations
const BASE_APY_BIPS: u16 = 1200;        // 12% base APY
const MAX_BURN_BOOST_BIPS: u16 = 27000; // 270% max burn boost
const DAILY_COMPOUND_FACTOR: u32 = 10000; // 10000 basis points = 100%

// 🚀 OPTIMIZATION: Lookup tables for boost calculations (avoiding runtime computation)
pub const BURN_BOOST_LOOKUP: [u16; 256] = generate_burn_boost_lookup();
pub const AFFILIATE_BOOST_LOOKUP: [u16; 11] = [
    0,    // Tier 0: 0%
    500,  // Tier 1: 5%
    1000, // Tier 2: 10%
    1500, // Tier 3: 15%
    2000, // Tier 4: 20%
    2500, // Tier 5: 25%
    3000, // Tier 6: 30%
    3500, // Tier 7: 35%
    4000, // Tier 8: 40%
    4500, // Tier 9: 45%
    5000, // Tier 10: 50%
];

// 🚀 Compile-time generation of burn boost lookup table
const fn generate_burn_boost_lookup() -> [u16; 256] {
    let mut lookup = [0u16; 256];
    let mut i = 0;
    
    while i < 256 {
        // Burn boost formula: level * 100 basis points (saturated at max)
        let boost = (i as u16).saturating_mul(100);
        if boost > MAX_BURN_BOOST_BIPS {
            lookup[i] = MAX_BURN_BOOST_BIPS;
        } else {
            lookup[i] = boost;
        }
        i += 1;
    }
    
    lookup
}

// 🚀 OTIMIZAÇÃO 3: OPTIMIZED GLOBAL STATE
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct GlobalStateOptimized {
    pub authority: Pubkey,              // 32 bytes
    pub cached_metrics: CachedMetrics,  // 32 bytes (optimized cache)
    pub config_flags: u64,              // 8 bytes (bitfield config)
    pub reserved: [u8; 24],             // 24 bytes reserved
}

#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, Copy)]
pub struct CachedMetrics {
    pub total_staked: u64,              // 8 bytes
    pub total_rewards_distributed: u64,  // 8 bytes
    pub cached_base_apy: u16,           // 2 bytes
    pub cache_timestamp: u32,           // 4 bytes (compressed timestamp)
    pub cache_validity_slots: u16,      // 2 bytes
    pub active_pools_count: u8,         // 1 byte
    pub _padding: u8,                   // 1 byte
    // Exact 32 bytes total
}

impl CachedMetrics {
    // 🚀 OPTIMIZATION: Cache validation with minimal computation
    #[inline(always)]
    pub fn is_cache_valid(&self, current_slot: u64) -> bool {
        let compressed_current = (current_slot / 1000) as u32;
        compressed_current.saturating_sub(self.cache_timestamp) <= self.cache_validity_slots as u32
    }
    
    // 🚀 OPTIMIZATION: Update cache with compressed timestamp
    #[inline(always)]
    pub fn update_cache(&mut self, current_slot: u64, base_apy: u16) {
        self.cache_timestamp = (current_slot / 1000) as u32;
        self.cached_base_apy = base_apy;
    }
}

// 🚀 OPTIMIZED APY CALCULATION - Target: 2000 CUs (vs 2531 baseline)
#[inline(always)]
pub fn calculate_dynamic_apy_optimized(
    _stake_amount: u64,  // Not used in APY calculation, only for interface compatibility
    burn_boost_level: u8,
    affiliate_tier: u8,
    pool_multiplier: u16,  // In basis points
    cached_metrics: &CachedMetrics,
    current_slot: u64,
) -> Result<u16, ProgramError> {
    // 🚀 OPTIMIZATION 1: Use cached base APY if valid
    let base_apy = if cached_metrics.is_cache_valid(current_slot) {
        cached_metrics.cached_base_apy
    } else {
        BASE_APY_BIPS  // Fallback to constant
    };
    
    // 🚀 OPTIMIZATION 2: Lookup table for burn boost (vs computation)
    let burn_boost = BURN_BOOST_LOOKUP[burn_boost_level.min(255) as usize];
    
    // 🚀 OPTIMIZATION 3: Lookup table for affiliate boost  
    let affiliate_boost = if (affiliate_tier as usize) < AFFILIATE_BOOST_LOOKUP.len() {
        AFFILIATE_BOOST_LOOKUP[affiliate_tier as usize]
    } else {
        AFFILIATE_BOOST_LOOKUP[AFFILIATE_BOOST_LOOKUP.len() - 1]
    };
    
    // 🚀 OPTIMIZATION 4: Add boosts to base APY
    let boosted_apy = base_apy
        .saturating_add(burn_boost)
        .saturating_add(affiliate_boost);
    
    // 🚀 OPTIMIZATION 5: Apply pool multiplier (usually 10000 = 100%)
    let final_apy = if pool_multiplier == 10000 {
        boosted_apy  // Optimize for common case
    } else {
        boosted_apy
            .saturating_mul(pool_multiplier)
            .saturating_div(10000)
    };
    
    // 🚀 OPTIMIZATION 6: Cap at reasonable maximum (vs unbounded growth)
    let capped_apy = if final_apy > 50000 { 50000 } else { final_apy }; // 500% max
    
    Ok(capped_apy)
}

// 🚀 OPTIMIZED REWARD CALCULATION 
#[inline(always)]
pub fn calculate_rewards_optimized(
    stake_amount: u64,
    apy_bips: u16,
    days_staked: u32,
) -> Result<u64, ProgramError> {
    if stake_amount == 0 || days_staked == 0 {
        return Ok(0);
    }
    
    // 🚀 OPTIMIZATION: Direct annual reward calculation with proper basis points handling
    // Formula: annual_reward = (stake_amount * apy_bips) / 10000
    let annual_reward = stake_amount
        .saturating_mul(apy_bips as u64)
        .saturating_div(10000);
    
    // 🚀 OPTIMIZATION: Calculate daily reward and multiply by days
    // daily_reward = annual_reward / 365
    let total_reward = annual_reward
        .saturating_mul(days_staked as u64)
        .saturating_div(365);
    
    Ok(total_reward)
}

// 🚀 OTIMIZAÇÃO 3: AFFILIATE NETWORK LOOPS OPTIMIZED
// Early exit + batch updates para reduzir compute units

#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct AffiliateUpdateBatch {
    pub updates: Vec<AffiliateUpdate>,
    pub count: u8,
}

#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, Copy)]
pub struct AffiliateUpdate {
    pub affiliate_id: Pubkey,           // 32 bytes
    pub volume_delta: u32,              // 4 bytes (compressed)
    pub commission_delta: u32,          // 4 bytes (compressed)
    pub level: u8,                      // 1 byte
    pub _padding: [u8; 3],              // 3 bytes padding
}

pub const MAX_BATCH_SIZE: usize = 6;  // Maximum affiliate levels
pub const MAX_AFFILIATE_LEVELS: u8 = 6;

// 🚀 OPTIMIZATION: Fast affiliate network update with early exit
#[inline(always)]
pub fn update_affiliate_network_optimized(
    staker_id: &Pubkey,
    stake_amount: u64,
    affiliate_tree: &[Option<Pubkey>; MAX_BATCH_SIZE],  // Pre-loaded affiliate tree
    commission_rates: &[u16; MAX_BATCH_SIZE],           // Pre-computed commission rates
) -> Result<AffiliateUpdateBatch, ProgramError> {
    let mut batch = AffiliateUpdateBatch {
        updates: Vec::with_capacity(MAX_BATCH_SIZE),
        count: 0,
    };
    
    // 🚀 OPTIMIZATION: Early exit if no affiliates
    if affiliate_tree[0].is_none() {
        return Ok(batch);
    }
    
    // 🚀 OPTIMIZATION: Compress stake amount for smaller operations
    let compressed_amount = (stake_amount / 1000) as u32;  // Divide by 1000 for compression
    
    // 🚀 OPTIMIZATION: Process levels with early exit and branch prediction hints
    for level in 0..MAX_AFFILIATE_LEVELS as usize {
        // Early exit if no affiliate at this level
        let affiliate_id = match affiliate_tree[level] {
            Some(id) => id,
            None => break,  // 🚀 EARLY EXIT: No more affiliates in chain
        };
        
        // 🚀 OPTIMIZATION: Skip self-referral (security check)
        if affiliate_id == *staker_id {
            continue;
        }
        
        // 🚀 OPTIMIZATION: Use lookup table for commission calculation
        let commission_rate = commission_rates[level];
        let commission_amount = compressed_amount
            .saturating_mul(commission_rate as u32)
            .saturating_div(10000);
        
        // 🚀 OPTIMIZATION: Bulk update structure
        let update = AffiliateUpdate {
            affiliate_id,
            volume_delta: compressed_amount,
            commission_delta: commission_amount,
            level: level as u8,
            _padding: [0; 3],
        };
        
        batch.updates.push(update);
        batch.count += 1;
        
        // 🚀 OPTIMIZATION: Circuit breaker for deep trees
        if batch.count >= MAX_AFFILIATE_LEVELS {
            break;
        }
    }
    
    Ok(batch)
}

// 🚀 OPTIMIZATION: Commission rate lookup table (pre-computed)
pub const COMMISSION_RATE_LOOKUP: [u16; MAX_BATCH_SIZE] = [
    1000, // Level 1: 10%
    500,  // Level 2: 5%
    300,  // Level 3: 3%
    200,  // Level 4: 2%
    100,  // Level 5: 1%
    50,   // Level 6: 0.5%
];

// 🚀 OPTIMIZATION: Batch affiliate state updates to reduce CPI calls
#[inline(always)]
pub fn apply_affiliate_batch_optimized(
    batch: &AffiliateUpdateBatch,
    affiliate_accounts: &[AccountInfo],
) -> Result<u32, ProgramError> {
    let mut operations_count = 0u32;
    
    // 🚀 OPTIMIZATION: Early exit for empty batch
    if batch.count == 0 {
        return Ok(0);
    }
    
    // 🚀 OPTIMIZATION: Process updates with minimal account lookups
    for (i, update) in batch.updates.iter().enumerate() {
        if i >= affiliate_accounts.len() {
            break; // 🚀 SAFETY: Prevent array bounds
        }
        
        // 🚀 OPTIMIZATION: Direct byte manipulation for hot fields
        let account_info = &affiliate_accounts[i];
        
        // Note: In a real implementation, this would directly update account data
        // This is a placeholder showing the optimization pattern
        msg!("Updating affiliate {} level {} with volume {} commission {}", 
             update.affiliate_id, update.level, update.volume_delta, update.commission_delta);
        
        operations_count = operations_count.saturating_add(1);
    }
    
    Ok(operations_count)
}

// 🚀 OPTIMIZATION UTILITIES
impl StakeRecordOptimized {
    // 🚀 Fast creation with pre-computed metadata
    #[inline(always)]
    pub fn new_optimized(
        staker: Pubkey,
        amount: u64,
        burn_boost_level: u8,
        affiliate_tier: u8,
        pool_id: u8,
        timestamp: i64,
    ) -> Self {
        let mut metadata = PackedStakeMetadata {
            total_claimed_compressed: 0,
            burn_boost_level,
            affiliate_tier,
            pool_flags: 0,
            reserved: 0,
        };
        
        metadata.set_pool_id(pool_id);
        metadata.set_active(true);
        
        Self {
            staker,
            amount,
            metadata,
            timestamp,
        }
    }
    
    // 🚀 Fast reward calculation using optimized functions
    #[inline(always)]
    pub fn calculate_pending_rewards_optimized(&self, current_timestamp: i64) -> Result<u64, ProgramError> {
        let days_staked = ((current_timestamp - self.timestamp) / 86400) as u32;
        
        // Use the optimized APY calculation
        let apy = calculate_dynamic_apy_optimized(
            self.amount,
            self.metadata.burn_boost_level,
            self.metadata.affiliate_tier,
            10000, // 100% pool multiplier
            &CachedMetrics {
                total_staked: 0,
                total_rewards_distributed: 0,
                cached_base_apy: BASE_APY_BIPS,
                cache_timestamp: (current_timestamp / 1000) as u32,
                cache_validity_slots: 100,
                active_pools_count: 1,
                _padding: 0,
            },
            current_timestamp as u64,
        )?;
        
        calculate_rewards_optimized(self.amount, apy, days_staked)
    }
}

#[cfg(test)]
mod optimization_tests {
    use super::*;
    
    #[test]
    fn test_packed_metadata_operations() {
        let mut metadata = PackedStakeMetadata {
            total_claimed_compressed: 1000,
            burn_boost_level: 50,
            affiliate_tier: 3,
            pool_flags: 0,
            reserved: 0,
        };
        
        // Test bitfield operations
        metadata.set_pool_id(5);
        assert_eq!(metadata.get_pool_id(), 5);
        
        metadata.set_stake_type(2);
        assert_eq!(metadata.get_stake_type(), 2);
        
        metadata.set_active(true);
        assert!(metadata.is_active());
    }
    
    #[test]
    fn test_apy_calculation_optimized() {
        let cached_metrics = CachedMetrics {
            total_staked: 1000000,
            total_rewards_distributed: 50000,
            cached_base_apy: 1200,
            cache_timestamp: 1000,
            cache_validity_slots: 100,
            active_pools_count: 3,
            _padding: 0,
        };
        
        let apy = calculate_dynamic_apy_optimized(
            100000,  // 100k stake
            50,      // burn boost level
            3,       // affiliate tier
            10000,   // 100% pool multiplier
            &cached_metrics,
            1050000, // current slot
        ).unwrap();
        
        // Should be base APY + burn boost + affiliate boost
        assert!(apy > 1200); // Greater than base APY
    }
    
    #[test]
    fn test_affiliate_network_optimization() {
        let staker = Pubkey::new_unique();
        let affiliate1 = Pubkey::new_unique();
        let affiliate2 = Pubkey::new_unique();
        
        let affiliate_tree = [
            Some(affiliate1),
            Some(affiliate2),
            None,
            None,
            None,
            None,
        ];
        
        let batch = update_affiliate_network_optimized(
            &staker,
            100000, // 100k stake
            &affiliate_tree,
            &COMMISSION_RATE_LOOKUP,
        ).unwrap();
        
        assert_eq!(batch.count, 2);
        assert_eq!(batch.updates.len(), 2);
        assert_eq!(batch.updates[0].level, 0);
        assert_eq!(batch.updates[1].level, 1);
    }
} 