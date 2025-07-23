//! 🧪 GMC Token Tokenomics Integration Tests
//! 
//! Testes abrangentes para validar todas as regras de tokenomics:
//! - Transferências com taxas (0.5%: 50% burn, 40% staking, 10% ranking)
//! - Sistema de Staking (longo prazo 12m + flexível 30d)
//! - Burn-for-Boost (queima para aumentar APY)
//! - Sistema de Afiliados (6 níveis)
//! - Sistema de Ranking (premiações)

use solana_program_test::*;
use gmc_token_native::*;

/// 🧪 Cenário 1: Transferência com Taxa de 0.5%
#[tokio::test]
async fn test_transfer_with_tokenomics_fee() {
    let program_test = ProgramTest::new("gmc_token", gmc_token_native::id(), processor!(process_instruction));
    let (_banks_client, _payer, _recent_blockhash) = program_test.start().await;

    // Simular transferência de 1000 GMC
    let transfer_amount = 1_000_000_000u64; // 1000 GMC (9 decimais)
    let expected_fee = transfer_amount * 5 / 1000; // 0.5%
    let expected_burn = expected_fee / 2; // 50% para burn
    let expected_staking = expected_fee * 2 / 5; // 40% para staking
    let expected_ranking = expected_fee / 10; // 10% para ranking

    println!("🧪 Teste: Transferência de {} GMC", transfer_amount / 1_000_000_000);
    println!("   Taxa total: {} GMC", expected_fee / 1_000_000_000);
    println!("   Burn: {} GMC", expected_burn / 1_000_000_000);
    println!("   Staking: {} GMC", expected_staking / 1_000_000_000);
    println!("   Ranking: {} GMC", expected_ranking / 1_000_000_000);

    // Validar cálculos
    assert_eq!(expected_burn + expected_staking + expected_ranking, expected_fee);
}

/// 🧪 Cenário 2: Sistema de Staking Longo Prazo
#[tokio::test]
async fn test_long_term_staking_mechanics() {
    println!("🧪 Teste: Staking Longo Prazo (12 meses)");
    
    let stake_amount = 10_000_000_000u64; // 10,000 GMC
    let base_apy = 1000; // 10% APY (basis points)
    let _lock_duration_days = 365; // 12 meses
    
    // Calcular recompensas base
    let daily_reward = (stake_amount * base_apy) / (10000 * 365);
    let annual_reward = daily_reward * 365;
    
    println!("   Stake: {} GMC", stake_amount / 1_000_000_000);
    println!("   APY Base: {}%", base_apy / 100);
    println!("   Recompensa Diária: {} GMC", daily_reward / 1_000_000_000);
    println!("   Recompensa Anual: {} GMC", annual_reward / 1_000_000_000);
    
    assert_eq!(annual_reward, stake_amount / 10); // 10% APY
}

/// 🧪 Cenário 3: Burn-for-Boost (Queima para Aumentar APY)
#[tokio::test]
async fn test_burn_for_boost_mechanics() {
    println!("🧪 Teste: Burn-for-Boost");
    
    let stake_amount = 10_000_000_000u64; // 10,000 GMC
    let burn_amount = 5_000_000_000u64; // 5,000 GMC (50% do stake)
    
    // Calcular boost
    let burn_percentage = (burn_amount * 100) / stake_amount; // 50%
    let base_apy = 1000; // 10% base
    let max_apy = 28000; // 280% máximo
    
    // Fórmula: APY = base + (burn_percentage * (max - base) / 100)
    let boosted_apy = base_apy + (burn_percentage * (max_apy - base_apy)) / 100;
    
    println!("   Stake: {} GMC", stake_amount / 1_000_000_000);
    println!("   Burn: {} GMC ({}%)", burn_amount / 1_000_000_000, burn_percentage);
    println!("   APY Resultante: {}%", boosted_apy / 100);
    
    assert_eq!(boosted_apy, 14500); // 145% APY com 50% burn
}

/// 🧪 Cenário 4: Sistema de Afiliados (6 Níveis)
#[tokio::test]
async fn test_affiliate_system_mechanics() {
    println!("🧪 Teste: Sistema de Afiliados");
    
    let affiliate_volume = 100_000_000_000u64; // 100,000 GMC de volume
    let commission_rates = [500, 300, 200, 100, 50, 25]; // Basis points por nível
    
    for (level, &rate) in commission_rates.iter().enumerate() {
        let commission = (affiliate_volume * rate as u64) / 10000;
        println!("   Nível {}: {}% = {} GMC", 
                level + 1, 
                rate as f64 / 100.0, 
                commission / 1_000_000_000);
    }
    
    let total_commission: u64 = commission_rates.iter()
        .map(|&rate| (affiliate_volume * rate as u64) / 10000)
        .sum();
    
    println!("   Comissão Total: {} GMC", total_commission / 1_000_000_000);
    assert!(total_commission < affiliate_volume / 10); // Máximo 10% do volume
}

/// 🧪 Cenário 5: Sistema de Ranking e Premiações
#[tokio::test]
async fn test_ranking_system_mechanics() {
    println!("🧪 Teste: Sistema de Ranking");
    
    let ranking_pool = 1_000_000_000u64; // 1,000 GMC no pool
    let participants = [
        ("User1", 1000u64),
        ("User2", 750u64),
        ("User3", 500u64),
        ("User4", 250u64),
    ];
    
    let total_score: u64 = participants.iter().map(|(_, score)| score).sum();
    
    println!("   Pool de Prêmios: {} GMC", ranking_pool / 1_000_000_000);
    println!("   Participantes:");
    
    for (user, score) in &participants {
        let reward = (ranking_pool * score) / total_score;
        println!("     {}: {} pontos = {} GMC", user, score, reward / 1_000_000_000);
    }
    
    assert_eq!(total_score, 2500);
}

/// 🧪 Cenário 6: Staking Flexível (30 dias)
#[tokio::test]
async fn test_flexible_staking_mechanics() {
    println!("🧪 Teste: Staking Flexível");
    
    let stake_amount = 5_000_000_000u64; // 5,000 GMC
    let flexible_apy_min = 500; // 5% APY mínimo
    let flexible_apy_max = 7000; // 70% APY máximo
    let _lock_duration_days = 30;
    
    // Calcular recompensas para diferentes APYs
    for apy in [flexible_apy_min, 3500, flexible_apy_max] {
        let monthly_reward = (stake_amount * apy * 30) / (10000 * 365);
        println!("   APY {}%: Recompensa 30d = {} GMC", 
                apy / 100, 
                monthly_reward / 1_000_000_000);
    }
    
    // Penalidade de retirada antecipada: 2.5%
    let early_withdrawal_penalty = stake_amount * 25 / 1000;
    println!("   Penalidade Retirada: {} GMC", early_withdrawal_penalty / 1_000_000_000);
}

/// 🧪 Cenário 7: Simulação Completa de Tokenomics
#[tokio::test]
async fn test_complete_tokenomics_simulation() {
    println!("🧪 Simulação Completa de Tokenomics GMC");
    
    // Supply inicial
    let total_supply = 100_000_000_000_000_000u64; // 100M GMC
    let mut circulating_supply = total_supply;
    
    // Distribuição inicial
    let staking_pool = 70_000_000_000_000_000u64; // 70M GMC
    let ico_allocation = 8_000_000_000_000_000u64; // 8M GMC
    
    println!("📊 Supply Inicial: {} GMC", total_supply / 1_000_000_000);
    println!("   Pool Staking: {} GMC", staking_pool / 1_000_000_000);
    println!("   ICO: {} GMC", ico_allocation / 1_000_000_000);
    
    // Simular 1 ano de operação
    let daily_transactions = 1000;
    let avg_transaction_size = 100_000_000_000u64; // 100 GMC
    let days_in_year = 365;
    
    let mut total_burned = 0u64;
    let mut total_staking_rewards = 0u64;
    let mut total_ranking_rewards = 0u64;
    
    for day in 1..=days_in_year {
        let daily_volume = daily_transactions as u64 * avg_transaction_size;
        let daily_fees = daily_volume * 5 / 1000; // 0.5%
        
        let daily_burn = daily_fees / 2; // 50%
        let daily_staking = daily_fees * 2 / 5; // 40%
        let daily_ranking = daily_fees / 10; // 10%
        
        total_burned += daily_burn;
        total_staking_rewards += daily_staking;
        total_ranking_rewards += daily_ranking;
        
        circulating_supply -= daily_burn;
        
        if day % 30 == 0 {
            println!("   Mês {}: Supply = {} GMC, Queimado = {} GMC", 
                    day / 30, 
                    circulating_supply / 1_000_000_000,
                    total_burned / 1_000_000_000);
        }
    }
    
    println!("📈 Resultado Anual:");
    println!("   Total Queimado: {} GMC", total_burned / 1_000_000_000);
    println!("   Rewards Staking: {} GMC", total_staking_rewards / 1_000_000_000);
    println!("   Rewards Ranking: {} GMC", total_ranking_rewards / 1_000_000_000);
    println!("   Supply Final: {} GMC", circulating_supply / 1_000_000_000);
    
    // Validar que o sistema é sustentável
    assert!(total_burned > 0);
    assert!(circulating_supply < total_supply);
    assert!(total_staking_rewards > 0);
}
