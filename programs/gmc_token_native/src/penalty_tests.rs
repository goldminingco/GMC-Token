// ⚖️ TDD TESTS - REGRAS DE PENALIDADES
// Metodologia: Red-Green-Refactor-Security
// Foco: Cancelamento Flexível, Taxa Saque Juros, Taxa Saque USDT

#[cfg(test)]
mod penalty_tests {
    use super::*;
    use solana_program::pubkey::Pubkey;
    use crate::{
        calculate_flexible_cancellation_penalty, calculate_interest_withdrawal_fee,
        calculate_usdt_withdrawal_fee, PenaltyDistribution, GMCError
    };

    // 🔴 RED: Teste de Penalidade de Cancelamento Flexível (2.5%)
    #[test]
    fn test_flexible_cancellation_penalty_basic() {
        // Arrange
        let stake_amount = 10_000_000_000_000; // 10,000 GMC
        let expected_penalty = 250_000_000_000; // 2.5% = 250 GMC
        
        // Act
        let penalty = calculate_flexible_cancellation_penalty(stake_amount).unwrap();
        
        // Assert
        assert_eq!(penalty.penalty_amount, expected_penalty);
        assert_eq!(penalty.penalty_percentage, 250); // 2.5% = 250 basis points
        assert_eq!(penalty.net_amount, stake_amount - expected_penalty);
    }

    #[test]
    fn test_flexible_cancellation_penalty_edge_cases() {
        // Teste com valores pequenos
        let small_amount = 1_000_000_000; // 1 GMC
        let penalty_small = calculate_flexible_cancellation_penalty(small_amount).unwrap();
        assert_eq!(penalty_small.penalty_amount, 25_000_000); // 0.025 GMC
        
        // Teste com zero (deve falhar)
        let penalty_zero = calculate_flexible_cancellation_penalty(0);
        assert!(penalty_zero.is_err());
        
        // Teste proteção overflow
        let max_safe = u64::MAX / 10000;
        let penalty_max = calculate_flexible_cancellation_penalty(max_safe);
        assert!(penalty_max.is_ok());
    }

    // 🔴 RED: Teste de Taxa de Saque de Juros (1%)
    #[test]
    fn test_interest_withdrawal_fee_basic() {
        // Arrange
        let interest_amount = 5_000_000_000_000; // 5,000 GMC de juros
        let expected_fee = 50_000_000_000; // 1% = 50 GMC
        
        // Act
        let fee_distribution = calculate_interest_withdrawal_fee(interest_amount).unwrap();
        
        // Assert
        assert_eq!(fee_distribution.total_fee, expected_fee);
        assert_eq!(fee_distribution.net_amount, interest_amount - expected_fee);
        
        // Verificar distribuição da taxa (40% equipe, 40% staking, 20% ranking)
        let expected_team = expected_fee * 40 / 100;
        let expected_staking = expected_fee * 40 / 100;
        let expected_ranking = expected_fee * 20 / 100;
        
        assert_eq!(fee_distribution.team_amount, expected_team);
        assert_eq!(fee_distribution.staking_amount, expected_staking);
        assert_eq!(fee_distribution.ranking_amount, expected_ranking);
    }

    #[test]
    fn test_interest_withdrawal_fee_precision() {
        // Teste precisão com valores pequenos
        let small_interest = 100_000_000; // 0.1 GMC
        let fee_small = calculate_interest_withdrawal_fee(small_interest).unwrap();
        
        // 1% de 0.1 GMC = 0.001 GMC
        assert_eq!(fee_small.total_fee, 1_000_000);
        
        // Verificar que soma das partes = total
        let sum_parts = fee_small.team_amount + fee_small.staking_amount + fee_small.ranking_amount;
        assert_eq!(sum_parts, fee_small.total_fee);
    }

    // 🔴 RED: Teste de Taxa de Saque USDT (0.3%)
    #[test]
    fn test_usdt_withdrawal_fee_basic() {
        // Arrange - valores em USDT (6 decimais)
        let usdt_amount = 1000_000_000; // 1000 USDT
        let expected_fee = 3_000_000; // 0.3% = 3 USDT
        
        // Act
        let fee_distribution = calculate_usdt_withdrawal_fee(usdt_amount).unwrap();
        
        // Assert
        assert_eq!(fee_distribution.total_fee, expected_fee);
        assert_eq!(fee_distribution.net_amount, usdt_amount - expected_fee);
        
        // Verificar distribuição (40% equipe, 40% staking, 20% ranking)
        let expected_team = expected_fee * 40 / 100;
        let expected_staking = expected_fee * 40 / 100;
        let expected_ranking = expected_fee * 20 / 100;
        
        assert_eq!(fee_distribution.team_amount, expected_team);
        assert_eq!(fee_distribution.staking_amount, expected_staking);
        assert_eq!(fee_distribution.ranking_amount, expected_ranking);
    }

    #[test]
    fn test_usdt_withdrawal_fee_edge_cases() {
        // Teste com valores pequenos USDT
        let small_usdt = 10_000_000; // 10 USDT
        let fee_small = calculate_usdt_withdrawal_fee(small_usdt).unwrap();
        assert_eq!(fee_small.total_fee, 30_000); // 0.03 USDT
        
        // Teste com valor mínimo
        let min_usdt = 1_000_000; // 1 USDT
        let fee_min = calculate_usdt_withdrawal_fee(min_usdt).unwrap();
        assert_eq!(fee_min.total_fee, 3_000); // 0.003 USDT
        
        // Teste proteção overflow
        let max_safe_usdt = u64::MAX / 10000;
        let fee_max = calculate_usdt_withdrawal_fee(max_safe_usdt);
        assert!(fee_max.is_ok());
    }

    // 🔴 RED: Teste de Integração - Penalidades Combinadas
    #[test]
    fn test_combined_penalties_scenario() {
        // Cenário: usuário cancela staking flexível e saca juros
        let stake_amount = 50_000_000_000_000; // 50,000 GMC
        let interest_earned = 2_500_000_000_000; // 2,500 GMC juros
        
        // Calcular penalidade de cancelamento
        let cancellation_penalty = calculate_flexible_cancellation_penalty(stake_amount).unwrap();
        
        // Calcular taxa de saque de juros
        let interest_fee = calculate_interest_withdrawal_fee(interest_earned).unwrap();
        
        // Verificar valores corretos
        assert_eq!(cancellation_penalty.penalty_amount, 1_250_000_000_000); // 2.5%
        assert_eq!(interest_fee.total_fee, 25_000_000_000); // 1%
        
        // Valor líquido final
        let final_amount = cancellation_penalty.net_amount + interest_fee.net_amount;
        let expected_final = stake_amount + interest_earned - cancellation_penalty.penalty_amount - interest_fee.total_fee;
        assert_eq!(final_amount, expected_final);
    }

    // 🔴 RED: Teste de Segurança - Proteção contra Manipulação
    #[test]
    fn test_penalty_security_validations() {
        // Teste valores inválidos
        assert!(calculate_flexible_cancellation_penalty(0).is_err());
        assert!(calculate_interest_withdrawal_fee(0).is_err());
        assert!(calculate_usdt_withdrawal_fee(0).is_err());
        
        // Teste overflow protection
        let overflow_value = u64::MAX;
        assert!(calculate_flexible_cancellation_penalty(overflow_value).is_err());
        assert!(calculate_interest_withdrawal_fee(overflow_value).is_err());
        assert!(calculate_usdt_withdrawal_fee(overflow_value).is_err());
    }

    // 🔴 RED: Teste de Distribuição Correta das Taxas
    #[test]
    fn test_penalty_distribution_accuracy() {
        let test_amount = 10_000_000_000; // 10 GMC ou 10 USDT
        
        // Testar distribuição de taxa de juros
        let interest_fee = calculate_interest_withdrawal_fee(test_amount).unwrap();
        let total_distributed = interest_fee.team_amount + interest_fee.staking_amount + interest_fee.ranking_amount;
        assert_eq!(total_distributed, interest_fee.total_fee);
        
        // Verificar proporções corretas (40/40/20)
        assert_eq!(interest_fee.team_amount, interest_fee.total_fee * 40 / 100);
        assert_eq!(interest_fee.staking_amount, interest_fee.total_fee * 40 / 100);
        assert_eq!(interest_fee.ranking_amount, interest_fee.total_fee * 20 / 100);
        
        // Testar distribuição de taxa USDT
        let usdt_fee = calculate_usdt_withdrawal_fee(test_amount).unwrap();
        let total_usdt_distributed = usdt_fee.team_amount + usdt_fee.staking_amount + usdt_fee.ranking_amount;
        assert_eq!(total_usdt_distributed, usdt_fee.total_fee);
    }
}
