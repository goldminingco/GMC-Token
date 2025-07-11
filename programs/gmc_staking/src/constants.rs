//! Constants module for the staking contract.
//! Centralizing these values improves readability and maintenance.
//!
//! Módulo para constantes usadas no contrato de staking.
//! Centralizar esses valores melhora a legibilidade e a manutenção.

// =====================================================
// EN: PDA Seeds - Used to generate deterministic addresses
// PT: Sementes PDA - Usadas para gerar endereços determinísticos
// =====================================================
pub const GLOBAL_STATE_SEED: &[u8] = b"global_state";
pub const USER_STAKE_INFO_SEED: &[u8] = b"user_stake_info";
pub const STAKE_POSITION_SEED: &[u8] = b"stake_position";
pub const STAKING_VAULT_SEED: &[u8] = b"staking_vault";

// =====================================================
// EN: Staking Parameters - Minimum amounts and lock periods
// PT: Parâmetros de Staking - Quantidades mínimas e períodos de bloqueio
// =====================================================
pub const MIN_STAKE_LONG_TERM: u64 = 100 * 1_000_000_000; // EN: 100 GMC | PT: 100 GMC
pub const MIN_STAKE_FLEXIBLE: u64 = 50 * 1_000_000_000;  // EN: 50 GMC | PT: 50 GMC

pub const LOCK_PERIOD_LONG_TERM: i64 = 365 * 24 * 60 * 60; // EN: 12 months in seconds | PT: 12 meses em segundos
pub const REWARD_CLAIM_INTERVAL_FLEXIBLE: i64 = 30 * 24 * 60 * 60; // EN: 30 days in seconds | PT: 30 dias em segundos

// =====================================================
// EN: APY Rates (in percentage)
// PT: Taxas APY (em percentual)
// =====================================================
pub const BASE_APY_LONG_TERM: u16 = 10;   // EN: 10% base APY for long-term | PT: 10% APY base para long-term
pub const BASE_APY_FLEXIBLE: u16 = 5;     // EN: 5% base APY for flexible | PT: 5% APY base para flexível
pub const MAX_APY_LONG_TERM: u16 = 280;   // EN: 280% maximum APY for long-term | PT: 280% APY máximo para long-term
pub const MAX_APY_FLEXIBLE: u16 = 70;     // EN: 70% maximum APY for flexible | PT: 70% APY máximo para flexível

pub const MAX_BURN_BOOST_PERCENTAGE: u16 = 270; // EN: 270% maximum burn boost (280% - 10%) | PT: 270% de boost máximo do burn (280% - 10%)
pub const MAX_STAKING_POWER: u8 = 100;          // EN: 100% maximum staking power | PT: 100% poder de staking máximo

// =====================================================
// EN: Burn-for-Boost Configuration
// PT: Configuração Burn-for-Boost
// =====================================================
pub const BURN_FEE_USDT: u64 = 800_000; // EN: 0.8 USDT (assuming 6 decimals) | PT: 0.8 USDT (assumindo 6 decimais)
pub const BURN_FOR_BOOST_FEE_USDT: u64 = 800_000; // EN: 0.8 USDT (assuming 6 decimals) | PT: 0.8 USDT (assumindo 6 decimais)
pub const BURN_FOR_BOOST_GMC_FEE_BASIS_POINTS: u16 = 1000; // EN: 10% in basis points | PT: 10% em basis points

// =====================================================
// EN: Affiliate System Parameters
// PT: Parâmetros do Sistema de Afiliados
// =====================================================
pub const MAX_AFFILIATE_LEVELS: u8 = 6;
pub const MAX_AFFILIATE_BOOST: u8 = 50; // EN: 50% maximum boost | PT: 50% boost máximo
pub const MAX_AFFILIATE_BOOST_LONG_TERM: u8 = 50; // EN: 50% maximum boost for long-term | PT: 50% boost máximo para long-term
pub const MAX_AFFILIATE_BOOST_FLEXIBLE: u8 = 35;  // EN: 35% maximum boost for flexible | PT: 35% boost máximo para flexível

// EN: Percentages per affiliate level (in percentage)
// PT: Percentuais por nível de afiliado (em percentual)
pub const AFFILIATE_LEVEL_1_PERCENTAGE: u8 = 20;
pub const AFFILIATE_LEVEL_2_PERCENTAGE: u8 = 15;
pub const AFFILIATE_LEVEL_3_PERCENTAGE: u8 = 8;
pub const AFFILIATE_LEVEL_4_PERCENTAGE: u8 = 4;
pub const AFFILIATE_LEVEL_5_PERCENTAGE: u8 = 2;
pub const AFFILIATE_LEVEL_6_PERCENTAGE: u8 = 1;

// EN: Array to facilitate iteration
// PT: Array para facilitar iteração
pub const AFFILIATE_LEVEL_PERCENTAGES: [u8; 6] = [
    AFFILIATE_LEVEL_1_PERCENTAGE,
    AFFILIATE_LEVEL_2_PERCENTAGE,
    AFFILIATE_LEVEL_3_PERCENTAGE,
    AFFILIATE_LEVEL_4_PERCENTAGE,
    AFFILIATE_LEVEL_5_PERCENTAGE,
    AFFILIATE_LEVEL_6_PERCENTAGE,
];

pub const AFFILIATE_PERCENTAGES: [u8; 6] = [
    AFFILIATE_LEVEL_1_PERCENTAGE,
    AFFILIATE_LEVEL_2_PERCENTAGE,
    AFFILIATE_LEVEL_3_PERCENTAGE,
    AFFILIATE_LEVEL_4_PERCENTAGE,
    AFFILIATE_LEVEL_5_PERCENTAGE,
    AFFILIATE_LEVEL_6_PERCENTAGE,
];

// =====================================================
// EN: Penalties and Fees (in basis points where applicable)
// PT: Penalidades e Taxas (em basis points onde aplicável)
// =====================================================
pub const EMERGENCY_UNSTAKE_FEE_USDT: u64 = 5_000_000; // EN: 5 USDT (assuming 6 decimals) | PT: 5 USDT (assumindo 6 decimais)
pub const EMERGENCY_UNSTAKE_CAPITAL_PENALTY_BASIS_POINTS: u16 = 5000; // EN: 50% | PT: 50%
pub const EMERGENCY_UNSTAKE_INTEREST_PENALTY_BASIS_POINTS: u16 = 8000; // EN: 80% | PT: 80%

pub const FLEXIBLE_CANCELLATION_FEE_BASIS_POINTS: u16 = 250; // EN: 2.5% | PT: 2.5%

pub const CLAIM_REWARDS_GMC_FEE_BASIS_POINTS: u16 = 100; // EN: 1% | PT: 1%
pub const CLAIM_REWARDS_USDT_FEE_BASIS_POINTS: u16 = 30; // EN: 0.3% | PT: 0.3%

// =====================================================
// EN: Distribution Percentages (in basis points for precision)
// PT: Percentuais de Distribuição (em basis points para precisão)
// =====================================================

// EN: GMC transaction fee (0.5%)
// PT: Taxa de transação GMC (0.5%)
pub const TRANSACTION_FEE_BURN_BASIS_POINTS: u16 = 5000; // EN: 50% of fee (0.25% of total) | PT: 50% da taxa (0.25% do total)
pub const TRANSACTION_FEE_STAKING_BASIS_POINTS: u16 = 4000; // EN: 40% of fee (0.20% of total) | PT: 40% da taxa (0.20% do total)
pub const TRANSACTION_FEE_RANKING_BASIS_POINTS: u16 = 1000; // EN: 10% of fee (0.05% of total) | PT: 10% da taxa (0.05% do total)

// EN: Staking entry fee (USDT)
// PT: Fee de entrada no staking (USDT)
pub const ENTRY_FEE_TEAM_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const ENTRY_FEE_STAKING_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const ENTRY_FEE_RANKING_BASIS_POINTS: u16 = 2000; // EN: 20% | PT: 20%

// EN: Emergency withdrawal penalty
// PT: Penalidade de saque antecipado
pub const EMERGENCY_PENALTY_BURN_BASIS_POINTS: u16 = 3000; // EN: 30% | PT: 30%
pub const EMERGENCY_PENALTY_STAKING_BASIS_POINTS: u16 = 5000; // EN: 50% | PT: 50%
pub const EMERGENCY_PENALTY_RANKING_BASIS_POINTS: u16 = 2000; // EN: 20% | PT: 20%

// EN: Flexible cancellation fee
// PT: Taxa de cancelamento flexível
pub const CANCELLATION_FEE_TEAM_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const CANCELLATION_FEE_STAKING_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const CANCELLATION_FEE_RANKING_BASIS_POINTS: u16 = 2000; // EN: 20% | PT: 20%

// EN: GMC interest withdrawal fee
// PT: Taxa de saque de juros GMC
pub const CLAIM_GMC_BURN_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const CLAIM_GMC_STAKING_BASIS_POINTS: u16 = 5000; // EN: 50% | PT: 50%
pub const CLAIM_GMC_RANKING_BASIS_POINTS: u16 = 1000; // EN: 10% | PT: 10%

// EN: Burn-for-boost fee (USDT)
// PT: Fee para burn-for-boost (USDT)
pub const BURN_BOOST_FEE_TEAM_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const BURN_BOOST_FEE_STAKING_BASIS_POINTS: u16 = 5000; // EN: 50% | PT: 50%
pub const BURN_BOOST_FEE_RANKING_BASIS_POINTS: u16 = 1000; // EN: 10% | PT: 10%

// EN: USDT reward withdrawal fee
// PT: Taxa de saque de recompensas USDT
pub const CLAIM_USDT_TEAM_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const CLAIM_USDT_STAKING_BASIS_POINTS: u16 = 4000; // EN: 40% | PT: 40%
pub const CLAIM_USDT_RANKING_BASIS_POINTS: u16 = 2000; // EN: 20% | PT: 20%

// =====================================================
// EN: Utility Constants
// PT: Constantes Utilitárias
// =====================================================
pub const BASIS_POINTS_DIVISOR: u16 = 10000; // EN: For basis points conversions | PT: Para conversões de basis points
pub const SECONDS_PER_DAY: i64 = 24 * 60 * 60;
pub const SECONDS_PER_YEAR: i64 = 365 * SECONDS_PER_DAY;

// EN: Default decimals
// PT: Decimais padrão
pub const GMC_DECIMALS: u8 = 9;
pub const USDT_DECIMALS: u8 = 6;

// =====================================================
// EN: Entry Fee Tiers (in GMC, values in lamports)
// PT: Níveis de Taxa de Entrada (em GMC, valores em lamports)
// =====================================================
pub const ENTRY_FEE_TIER_1_LIMIT: u64 = 1_000 * 1_000_000_000; // EN: 1,000 GMC | PT: 1.000 GMC
pub const ENTRY_FEE_TIER_2_LIMIT: u64 = 10_000 * 1_000_000_000; // EN: 10,000 GMC | PT: 10.000 GMC
pub const ENTRY_FEE_TIER_3_LIMIT: u64 = 100_000 * 1_000_000_000; // EN: 100,000 GMC | PT: 100.000 GMC
pub const ENTRY_FEE_TIER_4_LIMIT: u64 = 500_000 * 1_000_000_000; // EN: 500,000 GMC | PT: 500.000 GMC

// EN: Fee percentages per tier (in basis points to calculate USDT)
// PT: Percentuais de taxa por tier (em basis points para calcular USDT)
pub const ENTRY_FEE_TIER_1_PERCENTAGE: u16 = 1000; // EN: 10% | PT: 10%
pub const ENTRY_FEE_TIER_2_PERCENTAGE: u16 = 500;  // EN: 5% | PT: 5%
pub const ENTRY_FEE_TIER_3_PERCENTAGE: u16 = 250;  // EN: 2.5% | PT: 2.5%
pub const ENTRY_FEE_TIER_4_PERCENTAGE: u16 = 100;  // EN: 1% | PT: 1%
pub const ENTRY_FEE_TIER_5_PERCENTAGE: u16 = 50;   // EN: 0.5% | PT: 0.5%

// =====================================================
// EN: Validation Limits
// PT: Limites de Validação
// =====================================================
// EN: Maximum number of active staking positions a user can have
// PT: Número máximo de posições de staking ativas que um usuário pode ter
pub const MAX_STAKE_POSITIONS_PER_USER: u8 = 12;

// EN: Maximum amount of GMC that can be burned in a single burn-for-boost transaction
// PT: Quantidade máxima de GMC que pode ser queimada em uma única transação de burn-for-boost
pub const MAX_BURN_AMOUNT_PER_TRANSACTION: u64 = 1_000_000 * 1_000_000_000; // EN: 1M GMC | PT: 1M GMC

// =====================================================
// EN: Helper Functions
// PT: Funções Auxiliares
// =====================================================

// EN: Calculates the entry fee based on the amount of GMC
// PT: Calcula a taxa de entrada baseada na quantidade de GMC
/// Calcula a taxa de entrada baseada na quantidade de GMC
pub fn calculate_entry_fee_percentage(gmc_amount: u64) -> u16 {
    if gmc_amount <= ENTRY_FEE_TIER_1_LIMIT {
        ENTRY_FEE_TIER_1_PERCENTAGE
    } else if gmc_amount <= ENTRY_FEE_TIER_2_LIMIT {
        ENTRY_FEE_TIER_2_PERCENTAGE
    } else if gmc_amount <= ENTRY_FEE_TIER_3_LIMIT {
        ENTRY_FEE_TIER_3_PERCENTAGE
    } else if gmc_amount <= ENTRY_FEE_TIER_4_LIMIT {
        ENTRY_FEE_TIER_4_PERCENTAGE
    } else {
        ENTRY_FEE_TIER_5_PERCENTAGE
    }
}

// EN: Converts basis points to absolute value
// PT: Converte basis points para valor absoluto
/// Converte basis points para valor absoluto
pub fn basis_points_to_amount(amount: u64, basis_points: u16) -> u64 {
    amount
        .checked_mul(basis_points as u64)
        .unwrap()
        .checked_div(BASIS_POINTS_DIVISOR as u64)
        .unwrap()
}

// EN: Converts percentage to basis points
// PT: Converte percentual para basis points
/// Converte percentual para basis points
pub const fn percentage_to_basis_points(percentage: u16) -> u16 {
    percentage * 100
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_entry_fee_calculation() {
        assert_eq!(calculate_entry_fee_percentage(500 * 1_000_000_000), ENTRY_FEE_TIER_1_PERCENTAGE);
        assert_eq!(calculate_entry_fee_percentage(5_000 * 1_000_000_000), ENTRY_FEE_TIER_2_PERCENTAGE);
        assert_eq!(calculate_entry_fee_percentage(50_000 * 1_000_000_000), ENTRY_FEE_TIER_3_PERCENTAGE);
        assert_eq!(calculate_entry_fee_percentage(200_000 * 1_000_000_000), ENTRY_FEE_TIER_4_PERCENTAGE);
        assert_eq!(calculate_entry_fee_percentage(1_000_000 * 1_000_000_000), ENTRY_FEE_TIER_5_PERCENTAGE);
    }

    #[test]
    fn test_basis_points_conversion() {
        assert_eq!(basis_points_to_amount(1000, 250), 25); // 2.5% de 1000 = 25
        assert_eq!(basis_points_to_amount(10000, 1000), 1000); // 10% de 10000 = 1000
    }

    #[test]
    fn test_affiliate_percentages_sum() {
        let total: u8 = AFFILIATE_PERCENTAGES.iter().sum();
        assert_eq!(total, 50); // 20+15+8+4+2+1 = 50%
    }
} 