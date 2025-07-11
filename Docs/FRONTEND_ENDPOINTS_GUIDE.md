# 🎯 GMC Ecosystem - Frontend Development Guide

## 📋 Program IDs

```typescript
const PROGRAM_IDS = {
  GMC_TOKEN: "9cxPbpRkTkoWqs2gj6B84ojM41DUfLWKodmUjd5KaYCx",
  GMC_STAKING: "9xef742EHoWyB6eJFeY9qD8nsVadsXvLByL8J6Lhvtz1",
  GMC_RANKING: "CUM2m3SXR1S8Yg8rPBUVv7fWEN2n5JzR3W3vA1Xv2b7b",
  GMC_TREASURY: "GMCm26i3oB35nCHfswhN5aXgx1sxyxxa9f5c4hL3p8v",
  GMC_VESTING: "6PSoDRr6cMMY2db3d1y37tcLNp8uWFWd2kH7CjXqey7U"
};
```

## 🏦 GMC Token Program

### Endpoints

| **Endpoint** | **Type** | **Description** | **Parameters** | **Access** |
|-------------|----------|-----------------|----------------|------------|
| `initialize_mint_with_fee` | Instruction | Creates GMC mint with 0.5% transfer fee | `fee_basis_points: u16, maximum_fee: u64` | Admin |
| `mint_initial_supply` | Instruction | Mints initial supply of 100M GMC | `amount: u64` | Admin |
| `disable_mint_authority` | Instruction | Permanently disables mint authority | None | Admin |
| `collect_and_distribute_fees` | Instruction | Distributes fees: 50% burn, 40% staking, 10% ranking | None | Admin |

### Key Data Structures

```typescript
interface FeeDistributionEvent {
  total_collected: number;
  burn_amount: number;
  staking_amount: number;
  ranking_amount: number;
  timestamp: number;
}
```

## 🔒 GMC Staking Program

### Core Endpoints

| **Endpoint** | **Type** | **Description** | **Parameters** | **Access** |
|-------------|----------|-----------------|----------------|------------|
| `initialize_staking` | Instruction | Initialize staking system | `team_wallet: PublicKey, ranking_contract: PublicKey, burn_address: PublicKey` | Admin |
| `register_referrer` | Instruction | Register referrer for affiliate system | `referrer: PublicKey` | User |
| `stake_long_term` | Instruction | 12-month lock, 10%-280% APY | `amount: u64` (min 100 GMC) | User |
| `stake_flexible` | Instruction | Flexible staking, 5%-70% APY | `amount: u64` (min 50 GMC) | User |
| `burn_for_boost` | Instruction | Burn GMC to boost APY | `amount_to_burn: u64` | User |
| `withdraw_principal_long` | Instruction | Withdraw after 12 months | None | User |
| `emergency_unstake_long` | Instruction | Emergency unstake with penalties | None | User |
| `withdraw_flexible` | Instruction | Withdraw flexible with 2.5% fee | `amount_to_withdraw: u64` | User |
| `calculate_apy` | View | Calculate dynamic APY | None | Public |
| `calculate_affiliate_boost` | View | Calculate affiliate boost | None | Public |
| `claim_rewards` | Instruction | Claim GMC rewards with 1% fee | None | User |
| `claim_usdt_rewards` | Instruction | Claim USDT rewards with 0.3% fee | None | User |

### Key Data Structures

```typescript
interface StakePosition {
  owner: PublicKey;
  stake_type: "LongTerm" | "Flexible";
  principal_amount: number;
  start_timestamp: number;
  last_reward_claim_timestamp: number;
  is_active: boolean;
  position_id: number;
  long_term_data?: {
    total_gmc_burned_for_boost: number;
    staking_power_from_burn: number;
    affiliate_power_boost: number;
  };
}

interface UserStakeInfo {
  owner: PublicKey;
  referrer: PublicKey;
  total_positions: number;
  active_positions: number;
}

interface GlobalState {
  authority: PublicKey;
  team_wallet: PublicKey;
  ranking_contract: PublicKey;
  burn_address: PublicKey;
  total_staked_long_term: number;
  total_staked_flexible: number;
  total_rewards_distributed: number;
  is_paused: boolean;
}
```

### Events

```typescript
interface BurnForBoostEvent {
  user: PublicKey;
  stake_position: PublicKey;
  gmc_burned: number;
  new_staking_power: number;
  previous_apy: number;
  new_apy: number;
}
```

## 🏆 GMC Ranking Program

### Endpoints

| **Endpoint** | **Type** | **Description** | **Parameters** | **Access** |
|-------------|----------|-----------------|----------------|------------|
| `initialize_ranking` | Instruction | Initialize ranking system | None | Admin |
| `log_transaction` | Instruction | Log transaction for ranking | None | System |
| `log_referral` | Instruction | Log referral activity | None | System |
| `log_burn` | Instruction | Log burn events | `amount: u64` | System |
| `deposit_funds` | Instruction | Deposit funds to reward pools | `gmc_amount: u64, usdt_amount: u64` | Admin |
| `propose_new_merkle_root` | Instruction | Propose new Merkle root (48h timelock) | `root: [u8; 32]` | Admin |
| `commit_new_merkle_root` | Instruction | Commit Merkle root after timelock | None | Admin |
| `distribute_monthly_rewards` | Instruction | Distribute monthly rewards to top 21 | None | Admin |
| `distribute_annual_rewards` | Instruction | Distribute annual rewards to top 12 | None | Admin |
| `claim_reward` | Instruction | Claim rewards with Merkle proof | `amount_gmc: u64, amount_usdt: u64, merkle_proof: Vec<[u8; 32]>` | User |

### Key Data Structures

```typescript
interface RankingState {
  authority: PublicKey;
  current_merkle_root: number[];
  monthly_pool_gmc: number;
  monthly_pool_usdt: number;
  annual_pool_gmc: number;
  annual_pool_usdt: number;
  pending_merkle_root: number[];
  merkle_root_update_available_at: number;
  last_monthly_distribution: number;
  last_annual_distribution: number;
  total_users_tracked: number;
}

interface UserActivity {
  user: PublicKey;
  monthly_tx_count: number;
  monthly_referrals_count: number;
  monthly_burn_volume: number;
  annual_burn_volume: number;
  last_activity_timestamp: number;
}
```

## 💰 GMC Treasury Program

### Endpoints

| **Endpoint** | **Type** | **Description** | **Parameters** | **Access** |
|-------------|----------|-----------------|----------------|------------|
| `initialize` | Instruction | Initialize treasury | None | Admin |
| `deposit` | Instruction | Deposit funds to treasury | `amount: u64` | Admin |
| `withdraw` | Instruction | Withdraw funds from treasury | `amount: u64` | Admin |

### Key Data Structures

```typescript
interface TreasuryState {
  authority: PublicKey;
  total_funds: number;
}
```

## 📅 GMC Vesting Program

### Endpoints

| **Endpoint** | **Type** | **Description** | **Parameters** | **Access** |
|-------------|----------|-----------------|----------------|------------|
| `initialize_vesting` | Instruction | Initialize vesting system | None | Admin |
| `create_vesting_schedule` | Instruction | Create vesting schedule | `beneficiary: PublicKey, total_amount: u64, start_timestamp: i64, duration_seconds: i64, cliff_seconds: i64` | Admin |
| `release_vested_tokens` | Instruction | Release available vested tokens | None | User |
| `calculate_vested_amount` | View | Calculate available vested amount | None | Public |
| `deactivate_schedule` | Instruction | Deactivate vesting schedule | None | Admin |

### Key Data Structures

```typescript
interface VestingSchedule {
  beneficiary: PublicKey;
  total_amount: number;
  start_timestamp: number;
  duration_seconds: number;
  cliff_seconds: number;
  amount_released: number;
  is_active: boolean;
  created_at: number;
}

interface VestingState {
  authority: PublicKey;
  total_schedules: number;
  total_vested_amount: number;
  total_released_amount: number;
  created_at: number;
}
```

## 📊 Frontend Implementation Guide

### 1. User Dashboard Components

#### Balance Display
```typescript
interface UserBalances {
  gmc_balance: number;
  usdt_balance: number;
  staked_gmc: number;
  available_rewards_gmc: number;
  available_rewards_usdt: number;
  total_burned_gmc: number;
}
```

#### Staking Positions
```typescript
interface StakingPositionDisplay {
  position_id: number;
  type: "Long-Term" | "Flexible";
  principal_amount: number;
  current_apy: number;
  time_remaining: number;
  rewards_earned: number;
  can_withdraw: boolean;
  staking_power: number;
}
```

### 2. Staking Interface Components

#### Stake Form
```typescript
interface StakeFormData {
  amount: number;
  stake_type: "long_term" | "flexible";
  referrer?: PublicKey;
  estimated_apy: number;
  entry_fee: number;
}
```

#### Burn-for-Boost Form
```typescript
interface BurnForBoostData {
  burn_amount: number;
  current_apy: number;
  new_apy: number;
  usdt_fee: number;
  gmc_fee: number;
  position_id: number;
}
```

### 3. Ranking Display Components

#### Ranking Tables
```typescript
interface RankingData {
  transactions: {
    user: PublicKey;
    count: number;
    rank: number;
  }[];
  referrals: {
    user: PublicKey;
    count: number;
    rank: number;
  }[];
  burns: {
    user: PublicKey;
    amount: number;
    rank: number;
  }[];
}
```

#### Reward Distribution
```typescript
interface RewardDistribution {
  monthly_pools: {
    gmc: number;
    usdt: number;
  };
  annual_pools: {
    gmc: number;
    usdt: number;
  };
  next_distribution: number;
  user_eligible: boolean;
}
```

### 4. Admin Panel Components

#### Treasury Management
```typescript
interface TreasuryManagement {
  total_funds: number;
  deposit_amount: number;
  withdraw_amount: number;
  recent_transactions: {
    type: "deposit" | "withdraw";
    amount: number;
    timestamp: number;
  }[];
}
```

#### Vesting Management
```typescript
interface VestingManagement {
  schedules: VestingSchedule[];
  create_schedule: {
    beneficiary: PublicKey;
    amount: number;
    start_date: Date;
    duration_years: number;
    cliff_years: number;
  };
}
```

## 🔐 Security Considerations

### Input Validation
- Validate all amounts are positive
- Check minimum stake amounts (100 GMC long-term, 50 GMC flexible)
- Verify user has sufficient balance
- Validate referrer addresses

### Error Handling
- Handle insufficient balance errors
- Manage network timeouts
- Display user-friendly error messages
- Implement retry mechanisms

### State Management
- Cache user data appropriately
- Refresh data after transactions
- Handle concurrent updates
- Implement optimistic updates

## 📈 Performance Optimization

### Data Fetching
- Batch account data requests
- Use WebSocket for real-time updates
- Implement pagination for large datasets
- Cache static data locally

### Transaction Optimization
- Use priority fees for better confirmation
- Implement transaction batching where possible
- Provide transaction status updates
- Handle failed transactions gracefully

## 🎨 UI/UX Recommendations

### Visual Hierarchy
- Highlight APY and rewards prominently
- Use progress bars for time-locked stakes
- Show clear action buttons
- Implement responsive design

### User Experience
- Provide clear transaction previews
- Show estimated gas costs
- Implement loading states
- Provide transaction history

### Accessibility
- Add proper ARIA labels
- Ensure keyboard navigation
- Provide alternative text for images
- Maintain good color contrast

## 📚 Additional Resources

### Constants and Parameters
```typescript
const STAKING_CONSTANTS = {
  MIN_STAKE_LONG_TERM: 100_000_000_000, // 100 GMC
  MIN_STAKE_FLEXIBLE: 50_000_000_000,   // 50 GMC
  LOCK_PERIOD_MONTHS: 12,
  BURN_FOR_BOOST_USDT_FEE: 800_000,     // 0.8 USDT
  BURN_FOR_BOOST_GMC_FEE_PERCENT: 10,
  EMERGENCY_UNSTAKE_USDT_FEE: 5_000_000, // 5 USDT
  EMERGENCY_UNSTAKE_GMC_PENALTY: 50,     // 50%
  FLEXIBLE_WITHDRAWAL_FEE: 2.5,          // 2.5%
  MAX_AFFILIATE_LEVELS: 6,
  MAX_AFFILIATE_BOOST: 50,               // 50%
  CLAIM_REWARDS_GMC_FEE: 1,              // 1%
  CLAIM_REWARDS_USDT_FEE: 0.3,           // 0.3%
};
```

### Utility Functions
```typescript
// Calculate APY based on staking power and affiliate boost
function calculateAPY(stakingPower: number, affiliateBoost: number, isLongTerm: boolean): number {
  const baseAPY = isLongTerm ? 10 : 5;
  const maxAPY = isLongTerm ? 280 : 70;
  const totalPower = Math.min(100, stakingPower + affiliateBoost);
  const bonusAPY = (totalPower / 100) * (maxAPY - baseAPY);
  return baseAPY + bonusAPY;
}

// Convert lamports to human-readable format
function formatGMC(lamports: number): string {
  return (lamports / 1e9).toLocaleString('en-US', { 
    minimumFractionDigits: 2,
    maximumFractionDigits: 2 
  });
}

// Convert USDT from base units
function formatUSDT(amount: number): string {
  return (amount / 1e6).toLocaleString('en-US', { 
    minimumFractionDigits: 2,
    maximumFractionDigits: 2 
  });
}
```

Este guia fornece uma visão completa dos endpoints e estruturas de dados necessárias para desenvolver o front-end do ecossistema GMC. Use-o como referência durante o desenvolvimento para garantir integração correta com todos os contratos. 