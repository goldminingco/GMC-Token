# 📊 GMC Ecosystem - System Parameters Summary

## 🏦 Token Configuration

| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **Total Supply** | 100,000,000 GMC | Fixed supply, mint disabled permanently |
| **Decimals** | 9 | GMC token decimals |
| **Transfer Fee** | 0.5% | Automatic fee on all transfers |
| **Fee Distribution** | 50% burn, 40% staking, 10% ranking | Automatic distribution |

## 🔒 Staking Parameters

### Long-Term Staking (12 months)
| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **Minimum Amount** | 100 GMC | Minimum stake amount |
| **Lock Period** | 12 months | Fixed lock period |
| **Base APY** | 10% | Base APY without boosts |
| **Maximum APY** | 280% | Maximum APY with all boosts |
| **Entry Fee Tiers** | 10% → 0.5% | USDT fee based on amount |

### Flexible Staking (No lock)
| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **Minimum Amount** | 50 GMC | Minimum stake amount |
| **Lock Period** | None | No lock period |
| **Base APY** | 5% | Base APY without boosts |
| **Maximum APY** | 70% | Maximum APY with all boosts |
| **Withdrawal Fee** | 2.5% | GMC fee for early withdrawal |

## 🔥 Burn-for-Boost System

| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **USDT Fee** | 0.8 USDT | Fixed USDT fee per burn |
| **GMC Fee** | 10% | Additional GMC fee (burned) |
| **Maximum Boost** | 270% | Maximum boost from burning |
| **Power Calculation** | (Burned / Principal) × 100 | Staking power formula |
| **Max Staking Power** | 100% | Maximum staking power |

## 👥 Affiliate System

| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **Maximum Levels** | 6 | Maximum depth of affiliate tree |
| **Maximum Boost** | 50% | Maximum total affiliate boost |
| **Level 1 Boost** | 20% | Direct referrer boost |
| **Level 2 Boost** | 15% | Second level boost |
| **Level 3 Boost** | 8% | Third level boost |
| **Level 4 Boost** | 4% | Fourth level boost |
| **Level 5 Boost** | 2% | Fifth level boost |
| **Level 6 Boost** | 1% | Sixth level boost |

## 💰 Fee Structure

### Entry Fees (USDT based on GMC amount)
| **Tier** | **GMC Range** | **Fee %** | **Description** |
|-----------|---------------|-----------|-----------------|
| **Tier 1** | 1 - 1,000 GMC | 10% | Small stakes |
| **Tier 2** | 1,001 - 10,000 GMC | 5% | Medium stakes |
| **Tier 3** | 10,001 - 100,000 GMC | 2.5% | Large stakes |
| **Tier 4** | 100,001 - 500,000 GMC | 1% | Very large stakes |
| **Tier 5** | 500,001+ GMC | 0.5% | Whale stakes |

### Transaction Fees
| **Operation** | **Fee** | **Distribution** |
|---------------|---------|------------------|
| **GMC Transfer** | 0.5% | 50% burn, 40% staking, 10% ranking |
| **Burn for Boost** | 0.8 USDT + 10% GMC | 40% team, 50% staking, 10% ranking |
| **Emergency Unstake** | 5 USDT + 50% GMC | 30% burn, 50% staking, 20% ranking |
| **Flexible Withdrawal** | 2.5% GMC | 40% team, 40% staking, 20% ranking |
| **Claim GMC Rewards** | 1% | 40% burn, 50% staking, 10% ranking |
| **Claim USDT Rewards** | 0.3% | 40% team, 40% staking, 20% ranking |

## 🏆 Ranking System

### Monthly Rewards (90% of pools)
| **Category** | **Winners** | **Pool Share** | **Description** |
|--------------|-------------|----------------|-----------------|
| **Top Transactors** | 7 users | 33.33% | Most transactions |
| **Top Recruiters** | 7 users | 33.33% | Most referrals |
| **Top Burners** | 7 users | 33.33% | Most GMC burned |
| **Total Winners** | 21 users | 100% | Monthly distribution |

### Annual Rewards (10% of pools)
| **Category** | **Winners** | **Pool Share** | **Description** |
|--------------|-------------|----------------|-----------------|
| **Top Annual Burners** | 12 users | 100% | Highest annual burn volume |

### Pool Funding
| **Source** | **GMC %** | **USDT %** | **Description** |
|------------|-----------|------------|-----------------|
| **Monthly Pool** | 90% | 90% | Regular monthly rewards |
| **Annual Pool** | 10% | 10% | Annual burner rewards |

## 📅 Vesting Schedules

### Team Vesting
| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **Total Amount** | 15,000,000 GMC | Team allocation (15% of supply) |
| **Vesting Period** | 4 years | Linear vesting |
| **Cliff Period** | 1 year | No tokens released |
| **Release Schedule** | Linear after cliff | Monthly releases |

### Reserve Vesting
| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **Total Amount** | 20,000,000 GMC | Reserve allocation (20% of supply) |
| **Vesting Period** | 5 years | Linear vesting |
| **Cliff Period** | 1 year | No tokens released |
| **Release Schedule** | Linear after cliff | Monthly releases |

## 🔐 Security Parameters

### Validation Limits
| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **Max Positions per User** | 12 | Maximum active staking positions |
| **Max Burn per Transaction** | 1,000,000 GMC | Maximum burn amount |
| **Merkle Root Timelock** | 48 hours | Security delay for updates |
| **Min Stake Long-Term** | 100 GMC | Minimum long-term stake |
| **Min Stake Flexible** | 50 GMC | Minimum flexible stake |

### Emergency Controls
| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| **System Pause** | Yes | Admin can pause system |
| **Emergency Unstake** | Available | 5 USDT + 50% GMC penalty |
| **Authority Controls** | Multi-sig recommended | Admin functions protected |

## 📈 APY Calculation Examples

### Long-Term Staking APY
```
Base APY: 10%
Burn Boost: 0% to 270% (based on burn ratio)
Affiliate Boost: 0% to 50% (based on referrer network)
Total APY: 10% to 280%

Example:
- User stakes 1,000 GMC
- Burns 500 GMC (50% of principal)
- Gets 50% staking power
- Has level 1 referrer with 20% boost
- Total APY: 10% + (50% × 270%) + 20% = 165%
```

### Flexible Staking APY
```
Base APY: 5%
Burn Boost: Not available
Affiliate Boost: 0% to 35% (capped for flexible)
Total APY: 5% to 40%

Example:
- User stakes 1,000 GMC (flexible)
- Has level 1 referrer with 20% boost
- Total APY: 5% + 20% = 25%
```

## 🎯 Key Frontend Integration Points

### Real-time Data Updates
- **Balances**: GMC, USDT, staked amounts
- **APY**: Dynamic calculation based on boosts
- **Rewards**: Available GMC and USDT rewards
- **Rankings**: Monthly and annual leaderboards
- **Vesting**: Available tokens for release

### Transaction Status
- **Pending**: Transaction submitted
- **Confirmed**: Transaction confirmed
- **Failed**: Transaction failed with reason
- **Success**: Transaction completed successfully

### User Experience
- **Estimated Fees**: Show all fees before transaction
- **APY Calculator**: Real-time APY calculation
- **Time Remaining**: Countdown for locked stakes
- **Reward Projections**: Estimated future rewards

Este documento serve como referência completa para todos os parâmetros do sistema GMC, facilitando o desenvolvimento e a integração do frontend com os smart contracts. 