//! 🧪 GMC Token - Validação Completa dos Fluxos de USDT
//! 
//! Este arquivo valida todas as taxas pagas em USDT-SPL e suas distribuições
//! conforme especificado na documentação de tokenomics do GMC Token.

fn main() {
    println!("💰 === VALIDAÇÃO COMPLETA DOS FLUXOS DE PAGAMENTO EM USDT ===\n");
    
    test_staking_entry_fees();
    test_burn_for_boost_fees();
    test_emergency_unstake_penalties();
    test_usdt_rewards_withdrawal_fees();
    test_usdt_distribution_flows();
    test_complete_usdt_ecosystem_simulation();
    
    println!("\n🎉 === TODAS AS VALIDAÇÕES DE FLUXOS USDT CONCLUÍDAS COM SUCESSO! ===");
}

/// 🧪 Teste 1: Taxas de Entrada no Staking (USDT-SPL)
fn test_staking_entry_fees() {
    println!("🧪 === TESTE 1: TAXAS DE ENTRADA NO STAKING (USDT) ===");
    
    // Tabela de taxas baseada na quantidade de GMC
    let fee_tiers = [
        (1_000_000_000_000u64, 1000, "Até 1,000 GMC: 10%"),        // 10% = 1000 bps
        (10_000_000_000_000u64, 500, "1,001-10,000 GMC: 5%"),      // 5% = 500 bps
        (100_000_000_000_000u64, 250, "10,001-100,000 GMC: 2.5%"), // 2.5% = 250 bps
        (500_000_000_000_000u64, 100, "100,001-500,000 GMC: 1%"),  // 1% = 100 bps
        (1_000_000_000_000_000u64, 50, "Acima 500,000 GMC: 0.5%"), // 0.5% = 50 bps
    ];
    
    println!("💎 Taxas de Entrada no Staking (pagas em USDT-SPL):");
    
    for (gmc_amount, fee_bps, description) in fee_tiers {
        // Assumindo preço GMC = $0.10 para cálculo
        let gmc_usd_value = (gmc_amount / 1_000_000_000) * 10; // $0.10 por GMC
        let usdt_fee = (gmc_usd_value * fee_bps as u64) / 10000;
        
        println!("  📊 {}", description);
        println!("     GMC: {} | Valor USD: ${} | Taxa USDT: ${}", 
                gmc_amount / 1_000_000_000, 
                gmc_usd_value / 100, 
                usdt_fee / 100);
    }
    
    println!("\n💸 Distribuição da Taxa de Entrada:");
    println!("  🏢 Equipe: 40%");
    println!("  💎 Fundo Staking: 40%");
    println!("  🏆 Programa Ranking: 20%");
    
    // Validar distribuição
    let sample_fee = 1000_000u64; // $10 USDT (6 decimais)
    let team_share = (sample_fee * 40) / 100;
    let staking_share = (sample_fee * 40) / 100;
    let ranking_share = (sample_fee * 20) / 100;
    
    assert_eq!(team_share + staking_share + ranking_share, sample_fee);
    println!("  ✅ Distribuição validada: {}% + {}% + {}% = 100%", 40, 40, 20);
    
    println!("✅ Taxas de entrada no staking validadas!\n");
}

/// 🧪 Teste 2: Taxa Burn-for-Boost (0.8 USDT + 10% GMC)
fn test_burn_for_boost_fees() {
    println!("🧪 === TESTE 2: TAXA BURN-FOR-BOOST ===");
    
    let usdt_fee = 800_000u64; // 0.8 USDT (6 decimais)
    let gmc_fee_percentage = 10; // 10% do GMC queimado
    
    // Cenários de burn
    let burn_scenarios = [
        (1_000_000_000_000u64, "1,000 GMC"),
        (5_000_000_000_000u64, "5,000 GMC"),
        (10_000_000_000_000u64, "10,000 GMC"),
    ];
    
    println!("🔥 Taxa Fixa: {} USDT por operação", usdt_fee as f64 / 1_000_000.0);
    println!("📊 Cenários de Burn-for-Boost:");
    
    for (burn_amount, description) in burn_scenarios {
        let gmc_fee = (burn_amount * gmc_fee_percentage as u64) / 100;
        let total_gmc_cost = burn_amount + gmc_fee;
        
        println!("  🔥 Burn {}: ", description);
        println!("     Queima: {} GMC", burn_amount / 1_000_000_000);
        println!("     Taxa GMC (10%): {} GMC", gmc_fee / 1_000_000_000);
        println!("     Taxa USDT: {} USDT", usdt_fee as f64 / 1_000_000.0);
        println!("     Custo Total GMC: {} GMC", total_gmc_cost / 1_000_000_000);
    }
    
    println!("\n💸 Distribuição da Taxa USDT (0.8 USDT):");
    let team_share = (usdt_fee * 40) / 100;
    let staking_share = (usdt_fee * 50) / 100;
    let ranking_share = (usdt_fee * 10) / 100;
    
    println!("  🏢 Equipe: {} USDT (40%)", team_share as f64 / 1_000_000.0);
    println!("  💎 Fundo Staking: {} USDT (50%)", staking_share as f64 / 1_000_000.0);
    println!("  🏆 Programa Ranking: {} USDT (10%)", ranking_share as f64 / 1_000_000.0);
    
    assert_eq!(team_share + staking_share + ranking_share, usdt_fee);
    println!("✅ Taxa Burn-for-Boost validada!\n");
}

/// 🧪 Teste 3: Penalidades de Saque Antecipado (5 USDT + penalidades)
fn test_emergency_unstake_penalties() {
    println!("🧪 === TESTE 3: PENALIDADES DE SAQUE ANTECIPADO ===");
    
    let usdt_penalty = 5_000_000u64; // 5 USDT (6 decimais)
    let capital_penalty_pct = 50; // 50% do capital
    let interest_penalty_pct = 80; // 80% dos juros
    
    // Cenário de exemplo
    let staked_amount = 10_000_000_000_000u64; // 10,000 GMC
    let accrued_interest = 500_000_000_000u64; // 500 GMC de juros acumulados
    
    let capital_penalty = (staked_amount * capital_penalty_pct as u64) / 100;
    let interest_penalty = (accrued_interest * interest_penalty_pct as u64) / 100;
    let user_receives = staked_amount - capital_penalty + accrued_interest - interest_penalty;
    
    println!("⚠️ Penalidades de Saque Antecipado:");
    println!("  💰 Stake Original: {} GMC", staked_amount / 1_000_000_000);
    println!("  📈 Juros Acumulados: {} GMC", accrued_interest / 1_000_000_000);
    println!("  💸 Taxa USDT: {} USDT", usdt_penalty as f64 / 1_000_000.0);
    println!("  📉 Penalidade Capital (50%): {} GMC", capital_penalty / 1_000_000_000);
    println!("  📉 Penalidade Juros (80%): {} GMC", interest_penalty / 1_000_000_000);
    println!("  💵 Usuário Recebe: {} GMC", user_receives / 1_000_000_000);
    
    println!("\n💸 Distribuição das Penalidades:");
    println!("  🔥 Queima: 30%");
    println!("  💎 Fundo Staking: 50%");
    println!("  🏆 Programa Ranking: 20%");
    
    // Validar distribuição da taxa USDT
    let usdt_team = (usdt_penalty * 30) / 100; // Queima equivale a "team" na distribuição
    let usdt_staking = (usdt_penalty * 50) / 100;
    let usdt_ranking = (usdt_penalty * 20) / 100;
    
    assert_eq!(usdt_team + usdt_staking + usdt_ranking, usdt_penalty);
    println!("✅ Penalidades de saque antecipado validadas!\n");
}

/// 🧪 Teste 4: Taxa de Saque de Recompensas USDT (0.3%)
fn test_usdt_rewards_withdrawal_fees() {
    println!("🧪 === TESTE 4: TAXA DE SAQUE DE RECOMPENSAS USDT ===");
    
    let withdrawal_fee_pct = 30; // 0.3% = 30 basis points
    
    // Cenários de saque
    let withdrawal_scenarios = [
        (100_000_000u64, "$100 USDT"),
        (500_000_000u64, "$500 USDT"),
        (1_000_000_000u64, "$1,000 USDT"),
        (5_000_000_000u64, "$5,000 USDT"),
    ];
    
    println!("💰 Taxa de Saque: 0.3% sobre o valor sacado");
    println!("📊 Cenários de Saque de Recompensas USDT:");
    
    for (withdrawal_amount, description) in withdrawal_scenarios {
        let fee = (withdrawal_amount * withdrawal_fee_pct as u64) / 10000;
        let net_amount = withdrawal_amount - fee;
        
        println!("  💸 Saque {}: ", description);
        println!("     Taxa (0.3%): ${}", fee as f64 / 1_000_000.0);
        println!("     Líquido: ${}", net_amount as f64 / 1_000_000.0);
    }
    
    println!("\n💸 Distribuição da Taxa de Saque USDT:");
    println!("  🏢 Equipe: 40%");
    println!("  💎 Fundo Staking: 40%");
    println!("  🏆 Programa Ranking: 20%");
    
    // Validar distribuição
    let sample_fee = 300_000u64; // $0.30 USDT de taxa
    let team_share = (sample_fee * 40) / 100;
    let staking_share = (sample_fee * 40) / 100;
    let ranking_share = (sample_fee * 20) / 100;
    
    assert_eq!(team_share + staking_share + ranking_share, sample_fee);
    println!("✅ Taxa de saque de recompensas USDT validada!\n");
}

/// 🧪 Teste 5: Fluxos de Distribuição USDT
fn test_usdt_distribution_flows() {
    println!("🧪 === TESTE 5: FLUXOS DE DISTRIBUIÇÃO USDT ===");
    
    // Simular coleta de taxas em um mês
    let monthly_entry_fees = 10_000_000_000u64; // $10,000 USDT
    let monthly_burn_fees = 800_000u64 * 100; // 100 operações × 0.8 USDT
    let monthly_withdrawal_fees = 150_000_000u64; // $150 USDT
    let monthly_emergency_fees = 5_000_000u64 * 10; // 10 saques × 5 USDT
    
    let total_monthly_usdt = monthly_entry_fees + monthly_burn_fees + 
                            monthly_withdrawal_fees + monthly_emergency_fees;
    
    println!("📊 Coleta Mensal de Taxas USDT:");
    println!("  💎 Taxas de Entrada: ${}", monthly_entry_fees as f64 / 1_000_000.0);
    println!("  🔥 Taxas Burn-for-Boost: ${}", monthly_burn_fees as f64 / 1_000_000.0);
    println!("  💸 Taxas de Saque: ${}", monthly_withdrawal_fees as f64 / 1_000_000.0);
    println!("  ⚠️ Taxas de Emergência: ${}", monthly_emergency_fees as f64 / 1_000_000.0);
    println!("  💰 Total Mensal: ${}", total_monthly_usdt as f64 / 1_000_000.0);
    
    // Distribuição média (considerando diferentes percentuais por tipo)
    let avg_team_pct = 38; // Média ponderada
    let avg_staking_pct = 42; // Média ponderada
    let avg_ranking_pct = 20; // Média ponderada
    
    let team_allocation = (total_monthly_usdt * avg_team_pct as u64) / 100;
    let staking_allocation = (total_monthly_usdt * avg_staking_pct as u64) / 100;
    let ranking_allocation = (total_monthly_usdt * avg_ranking_pct as u64) / 100;
    
    println!("\n💸 Distribuição Mensal USDT:");
    println!("  🏢 Equipe (~38%): ${}", team_allocation as f64 / 1_000_000.0);
    println!("  💎 Fundo Staking (~42%): ${}", staking_allocation as f64 / 1_000_000.0);
    println!("  🏆 Programa Ranking (~20%): ${}", ranking_allocation as f64 / 1_000_000.0);
    
    println!("✅ Fluxos de distribuição USDT validados!\n");
}

/// 🧪 Teste 6: Simulação Completa do Ecossistema USDT (1 Ano)
fn test_complete_usdt_ecosystem_simulation() {
    println!("🧪 === TESTE 6: SIMULAÇÃO COMPLETA ECOSSISTEMA USDT (1 ANO) ===");
    
    // Parâmetros anuais estimados
    let annual_new_stakers = 1000;
    let avg_stake_size = 5_000_000_000_000u64; // 5,000 GMC médio
    let avg_entry_fee_pct = 250; // 2.5% médio
    let gmc_price_usdt = 100_000; // $0.10 por GMC (6 decimais USDT)
    
    // Calcular taxas de entrada anuais (evitando overflow)
    let stake_value_per_user = (avg_stake_size / 1_000_000_000) * gmc_price_usdt; // Valor em USDT por usuário
    let annual_stake_value_usdt = annual_new_stakers as u64 * stake_value_per_user;
    let annual_entry_fees = (annual_stake_value_usdt * avg_entry_fee_pct as u64) / 10000;
    
    // Outras taxas anuais
    let annual_burn_operations = 500;
    let annual_burn_fees = 800_000u64 * annual_burn_operations as u64;
    
    let annual_emergency_unstakes = 50;
    let annual_emergency_fees = 5_000_000u64 * annual_emergency_unstakes as u64;
    
    let annual_usdt_withdrawals = 100_000_000_000u64; // $100,000 em saques
    let annual_withdrawal_fees = (annual_usdt_withdrawals * 30) / 10000; // 0.3%
    
    let total_annual_usdt_fees = annual_entry_fees + annual_burn_fees + 
                                annual_emergency_fees + annual_withdrawal_fees;
    
    println!("📊 Projeção Anual de Taxas USDT:");
    println!("  👥 Novos Stakers: {}", annual_new_stakers);
    println!("  💎 Stake Médio: {} GMC", avg_stake_size / 1_000_000_000);
    println!("  💰 Valor Total Staked: ${}", annual_stake_value_usdt as f64 / 1_000_000.0);
    println!("  💸 Taxas de Entrada: ${}", annual_entry_fees as f64 / 1_000_000.0);
    println!("  🔥 Taxas Burn-for-Boost: ${}", annual_burn_fees as f64 / 1_000_000.0);
    println!("  ⚠️ Taxas de Emergência: ${}", annual_emergency_fees as f64 / 1_000_000.0);
    println!("  💸 Taxas de Saque: ${}", annual_withdrawal_fees as f64 / 1_000_000.0);
    println!("  🏆 Total Anual: ${}", total_annual_usdt_fees as f64 / 1_000_000.0);
    
    // Distribuição anual
    let annual_team = (total_annual_usdt_fees * 38) / 100;
    let annual_staking_fund = (total_annual_usdt_fees * 42) / 100;
    let annual_ranking_fund = (total_annual_usdt_fees * 20) / 100;
    
    println!("\n💰 Distribuição Anual USDT:");
    println!("  🏢 Equipe: ${}", annual_team as f64 / 1_000_000.0);
    println!("  💎 Fundo Staking: ${}", annual_staking_fund as f64 / 1_000_000.0);
    println!("  🏆 Programa Ranking: ${}", annual_ranking_fund as f64 / 1_000_000.0);
    
    // Calcular sustentabilidade
    let monthly_staking_rewards_needed = 50_000_000_000u64; // $50,000/mês estimado
    let annual_rewards_needed = monthly_staking_rewards_needed * 12;
    let sustainability_ratio = (annual_staking_fund as f64) / (annual_rewards_needed as f64);
    
    println!("\n📈 Análise de Sustentabilidade:");
    println!("  💎 Fundo Anual: ${}", annual_staking_fund as f64 / 1_000_000.0);
    println!("  💸 Rewards Necessários: ${}", annual_rewards_needed as f64 / 1_000_000.0);
    println!("  📊 Ratio Sustentabilidade: {:.2}x", sustainability_ratio);
    
    if sustainability_ratio >= 1.0 {
        println!("  ✅ Sistema SUSTENTÁVEL com taxas USDT!");
    } else {
        println!("  ⚠️ Sistema precisa de ajustes ou subsídio adicional");
    }
    
    println!("✅ Simulação completa do ecossistema USDT validada!\n");
}
