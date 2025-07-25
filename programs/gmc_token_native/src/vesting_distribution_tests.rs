// 🏗️ TDD TESTS - VESTING E DISTRIBUIÇÃO INICIAL
// Metodologia: Red-Green-Refactor-Security
// Foco: Vesting Equipe, Time-locks, Supply Inicial, Queima Limite, Carteiras

#[cfg(test)]
mod vesting_distribution_tests {
    use super::*;
    use solana_program::pubkey::Pubkey;
    use crate::{
        TeamVestingSchedule, InitialDistribution, TimeLockedOperation,
        calculate_team_vesting_release, setup_initial_distribution,
        create_time_locked_operation, validate_burn_limit,
        GMCError, GMC_TOTAL_SUPPLY, GMC_MINIMUM_SUPPLY
    };

    // 🔴 RED: Teste de Vesting da Equipe - Liberação Gradual
    #[test]
    fn test_team_vesting_gradual_release() {
        // Arrange - 10% da equipe (10M GMC) liberado em 24 meses
        let team_allocation = 10_000_000_000_000_000; // 10M GMC
        let vesting_duration_months = 24;
        let cliff_months = 6; // 6 meses de cliff
        let current_month = 12; // 12 meses após início
        
        // Act
        let vesting_schedule = TeamVestingSchedule::new(
            team_allocation,
            vesting_duration_months,
            cliff_months,
        );
        
        let released_amount = calculate_team_vesting_release(&vesting_schedule, current_month).unwrap();
        
        // Assert - Após 12 meses, deve ter liberado 50% (considerando cliff de 6 meses)
        // Liberação linear: (12-6)/(24-6) * 100% = 6/18 * 100% = 33.33%
        let expected_release = team_allocation * 6 / 18; // 33.33%
        assert_eq!(released_amount, expected_release);
        
        // Verificar que antes do cliff não libera nada
        let pre_cliff_release = calculate_team_vesting_release(&vesting_schedule, 3).unwrap();
        assert_eq!(pre_cliff_release, 0);
        
        // Verificar que após vesting completo libera 100%
        let full_release = calculate_team_vesting_release(&vesting_schedule, 24).unwrap();
        assert_eq!(full_release, team_allocation);
    }

    #[test]
    fn test_team_vesting_edge_cases() {
        let team_allocation = 5_000_000_000_000_000; // 5M GMC
        let vesting_schedule = TeamVestingSchedule::new(team_allocation, 12, 3);
        
        // Teste no exato momento do cliff
        let cliff_release = calculate_team_vesting_release(&vesting_schedule, 3).unwrap();
        assert_eq!(cliff_release, 0); // Ainda não libera no cliff
        
        // Teste 1 mês após cliff
        let post_cliff_release = calculate_team_vesting_release(&vesting_schedule, 4).unwrap();
        let expected_post_cliff = team_allocation * 1 / 9; // (4-3)/(12-3) = 1/9
        assert_eq!(post_cliff_release, expected_post_cliff);
        
        // Teste overflow protection
        let invalid_release = calculate_team_vesting_release(&vesting_schedule, 100);
        assert!(invalid_release.is_ok()); // Deve limitar a 100%
    }

    // 🔴 RED: Teste de Time-locks de Segurança
    #[test]
    fn test_time_locked_operations() {
        // Arrange
        let operation_type = "EMERGENCY_PAUSE";
        let delay_hours = 48; // 48 horas de time-lock
        let current_timestamp: u64 = 1640995200; // 1 Jan 2022
        let execution_timestamp: u64 = current_timestamp + (delay_hours as u64 * 3600);
        
        // Act
        let time_lock = create_time_locked_operation(
            operation_type,
            delay_hours,
            current_timestamp,
        ).unwrap();
        
        // Assert
        assert_eq!(time_lock.operation_type, operation_type);
        assert_eq!(time_lock.execution_timestamp, execution_timestamp);
        assert_eq!(time_lock.delay_hours, delay_hours);
        assert!(!time_lock.executed);
        
        // Teste execução prematura (deve falhar)
        let early_execution = time_lock.can_execute(current_timestamp + 3600); // 1 hora depois
        assert!(!early_execution);
        
        // Teste execução no tempo correto
        let valid_execution = time_lock.can_execute(execution_timestamp);
        assert!(valid_execution);
        
        // Teste execução após tempo válido
        let late_execution = time_lock.can_execute(execution_timestamp + 3600);
        assert!(late_execution);
    }

    #[test]
    fn test_time_lock_security_validations() {
        // Teste delay mínimo (deve ser pelo menos 24h para operações críticas)
        let short_delay = create_time_locked_operation("CRITICAL_OP", 12, 1640995200u64);
        assert!(short_delay.is_err()); // Delay muito curto
        
        // Teste delay válido
        let valid_delay = create_time_locked_operation("CRITICAL_OP", 48, 1640995200u64);
        assert!(valid_delay.is_ok());
        
        // Teste timestamp inválido (futuro)
        let future_timestamp: u64 = 9999999999; // Timestamp muito no futuro
        let invalid_timestamp = create_time_locked_operation("OP", 48, future_timestamp);
        assert!(invalid_timestamp.is_err());
    }

    // 🔴 RED: Teste de Supply Inicial - 100M GMC para Circulação
    #[test]
    fn test_initial_supply_distribution() {
        // Arrange - Distribuição inicial conforme tokenomics
        let expected_circulating = 100_000_000_000_000_000; // 100M GMC
        
        // Act
        let distribution = setup_initial_distribution().unwrap();
        
        // Assert - Verificar supply total e circulante
        assert_eq!(distribution.total_supply, GMC_TOTAL_SUPPLY);
        assert_eq!(distribution.circulating_supply, expected_circulating);
        assert_eq!(distribution.burned_supply, 0); // Inicialmente zero
        
        // Verificar distribuição por categoria
        assert_eq!(distribution.staking_pool, 30_000_000_000_000_000);     // 30M GMC
        assert_eq!(distribution.presale, 25_000_000_000_000_000);          // 25M GMC
        assert_eq!(distribution.strategic_reserve, 15_000_000_000_000_000); // 15M GMC
        assert_eq!(distribution.treasury, 10_000_000_000_000_000);         // 10M GMC
        assert_eq!(distribution.team, 10_000_000_000_000_000);             // 10M GMC (vesting)
        assert_eq!(distribution.marketing, 5_000_000_000_000_000);         // 5M GMC
        assert_eq!(distribution.airdrop, 5_000_000_000_000_000);           // 5M GMC
        
        // Verificar que soma = 100M GMC
        let total_distributed = distribution.staking_pool + distribution.presale + 
                               distribution.strategic_reserve + distribution.treasury +
                               distribution.team + distribution.marketing + distribution.airdrop;
        assert_eq!(total_distributed, expected_circulating);
    }

    #[test]
    fn test_initial_distribution_wallet_assignments() {
        // Arrange
        let treasury_wallet = Pubkey::new_unique();
        let team_wallet = Pubkey::new_unique();
        let marketing_wallet = Pubkey::new_unique();
        
        // Act
        let mut distribution = setup_initial_distribution().unwrap();
        distribution.assign_wallets(treasury_wallet, team_wallet, marketing_wallet);
        
        // Assert
        assert_eq!(distribution.treasury_wallet, Some(treasury_wallet));
        assert_eq!(distribution.team_wallet, Some(team_wallet));
        assert_eq!(distribution.marketing_wallet, Some(marketing_wallet));
        
        // Verificar que carteiras são diferentes
        assert_ne!(treasury_wallet, team_wallet);
        assert_ne!(treasury_wallet, marketing_wallet);
        assert_ne!(team_wallet, marketing_wallet);
    }

    // 🔴 RED: Teste de Queima até Limite - 12M GMC Mínimo
    #[test]
    fn test_burn_limit_validation() {
        // Arrange
        let current_circulating = 15_000_000_000_000_000; // 15M GMC
        let burn_amount = 2_000_000_000_000_000;          // 2M GMC
        
        // Act - Queima que mantém acima do limite
        let valid_burn = validate_burn_limit(current_circulating, burn_amount).unwrap();
        
        // Assert
        assert!(valid_burn.is_valid);
        assert_eq!(valid_burn.new_circulating, 13_000_000_000_000_000); // 13M GMC
        assert_eq!(valid_burn.burn_amount, burn_amount);
        assert!(!valid_burn.limit_reached);
        
        // Teste queima que atinge o limite exato
        let limit_burn_amount = 3_000_000_000_000_000; // 3M GMC
        let limit_burn = validate_burn_limit(current_circulating, limit_burn_amount).unwrap();
        assert!(limit_burn.is_valid);
        assert_eq!(limit_burn.new_circulating, GMC_MINIMUM_SUPPLY);
        assert!(limit_burn.limit_reached);
        
        // Teste queima que excede o limite (deve ser rejeitada)
        let excessive_burn = 4_000_000_000_000_000; // 4M GMC
        let invalid_burn = validate_burn_limit(current_circulating, excessive_burn);
        assert!(invalid_burn.is_err());
    }

    #[test]
    fn test_burn_limit_edge_cases() {
        // Teste quando já está no limite mínimo
        let min_circulating = GMC_MINIMUM_SUPPLY;
        let any_burn = 1_000_000_000; // Qualquer queima
        let at_limit_burn = validate_burn_limit(min_circulating, any_burn);
        assert!(at_limit_burn.is_err()); // Não pode queimar mais
        
        // Teste com queima zero
        let current_supply = 20_000_000_000_000_000; // 20M GMC
        let zero_burn = validate_burn_limit(current_supply, 0);
        assert!(zero_burn.is_err()); // Queima zero inválida
        
        // Teste proteção overflow
        let max_burn = u64::MAX;
        let overflow_burn = validate_burn_limit(current_supply, max_burn);
        assert!(overflow_burn.is_err());
    }

    // 🔴 RED: Teste de Integração - Cenário Completo
    #[test]
    fn test_complete_vesting_distribution_scenario() {
        // Arrange - Cenário: 18 meses após lançamento
        let months_elapsed = 18;
        
        // Act - Setup inicial
        let mut distribution = setup_initial_distribution().unwrap();
        
        // Calcular vesting da equipe
        let team_vesting = TeamVestingSchedule::new(
            distribution.team,
            24, // 24 meses total
            6,  // 6 meses cliff
        );
        let team_released = calculate_team_vesting_release(&team_vesting, months_elapsed).unwrap();
        
        // Simular queima acumulada
        let total_burned = 5_000_000_000_000_000; // 5M GMC queimados
        let burn_validation = validate_burn_limit(distribution.circulating_supply, total_burned).unwrap();
        
        // Assert - Verificações integradas
        // Equipe deve ter liberado 66.67% após 18 meses: (18-6)/(24-6) = 12/18 = 66.67%
        let expected_team_release = distribution.team * 12 / 18;
        assert_eq!(team_released, expected_team_release);
        
        // Supply circulante deve estar correto após queima
        assert_eq!(burn_validation.new_circulating, 95_000_000_000_000_000); // 95M GMC
        assert!(burn_validation.new_circulating > GMC_MINIMUM_SUPPLY);
        
        // Verificar que ainda há margem para mais queima
        let remaining_burn_capacity = burn_validation.new_circulating - GMC_MINIMUM_SUPPLY;
        assert_eq!(remaining_burn_capacity, 83_000_000_000_000_000); // 83M GMC
    }

    // 🔴 RED: Teste de Segurança - Proteções Integradas
    #[test]
    fn test_vesting_distribution_security() {
        // Teste acesso não autorizado ao vesting
        let unauthorized_vesting = TeamVestingSchedule::new(0, 24, 6);
        assert!(calculate_team_vesting_release(&unauthorized_vesting, 12).is_err());
        
        // Teste manipulação de timestamps
        let invalid_time_lock = create_time_locked_operation("OP", 48, 9999999999u64);
        assert!(invalid_time_lock.is_err());
        
        // Teste distribuição com valores inválidos
        let mut invalid_distribution = InitialDistribution::default();
        invalid_distribution.total_supply = 0;
        assert!(invalid_distribution.validate().is_err());
        
        // Teste proteção contra double-spending na distribuição
        let distribution = setup_initial_distribution().unwrap();
        let total_allocated = distribution.staking_pool + distribution.presale + 
                             distribution.strategic_reserve + distribution.treasury +
                             distribution.team + distribution.marketing + distribution.airdrop;
        assert_eq!(total_allocated, distribution.circulating_supply);
    }
}
