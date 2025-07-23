// Simulação Completa do Ecossistema GMC Token - 100.000 Usuários
// Validação de todas as regras de negócio em escala real

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};
use rand::{Rng, SeedableRng};
use rand::rngs::StdRng;

// Estruturas de dados para simulação
#[derive(Debug, Clone)]
#[allow(dead_code)]
struct User {
    id: u32,
    gmc_balance: u64,
    usdt_balance: u64,
    staking_records: Vec<StakeRecord>,
    affiliate_level: u8,
    referrals: Vec<u32>,
    referrer: Option<u32>,
    ranking_score: u64,
    last_activity: u64,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
struct StakeRecord {
    amount: u64,
    stake_type: StakeType,
    start_time: u64,
    lock_duration: u64,
    apy_rate: u16, // em basis points (10000 = 100%)
    rewards_claimed: u64,
    is_active: bool,
}

#[derive(Debug, Clone, PartialEq)]
enum StakeType {
    LongTerm,    // 12 meses
    Flexible,    // 30 dias
}

#[derive(Debug)]
struct EcosystemState {
    users: HashMap<u32, User>,
    total_gmc_supply: u64,
    total_gmc_burned: u64,
    total_gmc_staked: u64,
    staking_pool_balance: u64,
    ranking_pool_balance: u64,
    team_treasury_balance: u64,
    current_timestamp: u64,
    daily_transactions: u32,
}

// Constantes do sistema
const INITIAL_GMC_SUPPLY: u64 = 1_000_000_000_000_000_000; // 1B GMC (9 decimals)
const MIN_BURN_LIMIT: u64 = 12_000_000_000_000_000; // 12M GMC (9 decimals)
const TRANSFER_FEE_RATE: u16 = 50; // 0.5% em basis points
const SECONDS_PER_DAY: u64 = 86400;
const SECONDS_PER_YEAR: u64 = 365 * SECONDS_PER_DAY;

// Taxas de distribuição
const BURN_PERCENTAGE: u16 = 5000; // 50%
const STAKING_PERCENTAGE: u16 = 4000; // 40%
const RANKING_PERCENTAGE: u16 = 1000; // 10%

// Configurações de staking
const LONG_TERM_BASE_APY: u16 = 1000; // 10%
const LONG_TERM_MAX_APY: u16 = 28000; // 280%
const FLEXIBLE_BASE_APY: u16 = 500; // 5%
const FLEXIBLE_MAX_APY: u16 = 7000; // 70%

// Configurações de afiliados
const AFFILIATE_COMMISSION_RATES: [u16; 6] = [500, 300, 200, 150, 100, 50]; // 5%, 3%, 2%, 1.5%, 1%, 0.5%

impl EcosystemState {
    fn new() -> Self {
        Self {
            users: HashMap::new(),
            total_gmc_supply: INITIAL_GMC_SUPPLY,
            total_gmc_burned: 0,
            total_gmc_staked: 0,
            staking_pool_balance: 0,
            ranking_pool_balance: 0,
            team_treasury_balance: 0,
            current_timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            daily_transactions: 0,
        }
    }

    // Simular transferência com taxa
    fn simulate_transfer(&mut self, from_id: u32, to_id: u32, amount: u64) -> Result<(), String> {
        let from_user = self.users.get_mut(&from_id).ok_or("Usuário remetente não encontrado")?;
        
        if from_user.gmc_balance < amount {
            return Err("Saldo insuficiente".to_string());
        }

        // Calcular taxa de transferência (0.5%)
        let fee = (amount * TRANSFER_FEE_RATE as u64) / 10000;
        let net_amount = amount - fee;

        // Distribuir taxa: 50% burn, 40% staking, 10% ranking
        let burn_amount = (fee * BURN_PERCENTAGE as u64) / 10000;
        let staking_amount = (fee * STAKING_PERCENTAGE as u64) / 10000;
        let ranking_amount = (fee * RANKING_PERCENTAGE as u64) / 10000;

        // Aplicar burn (se não exceder limite)
        if self.total_gmc_supply - burn_amount >= MIN_BURN_LIMIT {
            self.total_gmc_supply -= burn_amount;
            self.total_gmc_burned += burn_amount;
        } else {
            // Se não pode queimar, redistribui para staking
            let remaining_burn = burn_amount;
            self.staking_pool_balance += remaining_burn;
        }

        // Distribuir para pools
        self.staking_pool_balance += staking_amount;
        self.ranking_pool_balance += ranking_amount;

        // Executar transferência
        from_user.gmc_balance -= amount;
        
        let to_user = self.users.get_mut(&to_id).ok_or("Usuário destinatário não encontrado")?;
        to_user.gmc_balance += net_amount;

        self.daily_transactions += 1;
        Ok(())
    }

    // Simular staking
    fn simulate_stake(&mut self, user_id: u32, amount: u64, stake_type: StakeType) -> Result<(), String> {
        let user = self.users.get_mut(&user_id).ok_or("Usuário não encontrado")?;
        
        if user.gmc_balance < amount {
            return Err("Saldo insuficiente para staking".to_string());
        }

        let (lock_duration, base_apy) = match stake_type {
            StakeType::LongTerm => (365 * SECONDS_PER_DAY, LONG_TERM_BASE_APY),
            StakeType::Flexible => (30 * SECONDS_PER_DAY, FLEXIBLE_BASE_APY),
        };

        // Calcular APY com boost de afiliados (se aplicável)
        let mut apy_rate = base_apy;
        if stake_type == StakeType::Flexible && user.referrals.len() > 0 {
            let affiliate_boost = std::cmp::min(user.referrals.len() as u16 * 500, 5000); // Max 50% boost
            apy_rate = std::cmp::min(apy_rate + affiliate_boost, FLEXIBLE_MAX_APY);
        }

        let stake_record = StakeRecord {
            amount,
            stake_type,
            start_time: self.current_timestamp,
            lock_duration,
            apy_rate,
            rewards_claimed: 0,
            is_active: true,
        };

        user.gmc_balance -= amount;
        user.staking_records.push(stake_record);
        self.total_gmc_staked += amount;

        // Processar comissões de afiliados se usuário tem referrer
        if let Some(referrer_id) = user.referrer {
            self.process_affiliate_commissions(referrer_id, amount)?;
        }

        Ok(())
    }

    // Processar comissões de afiliados
    fn process_affiliate_commissions(&mut self, referrer_id: u32, stake_amount: u64) -> Result<(), String> {
        let mut current_referrer = Some(referrer_id);
        let mut level = 0;

        while let Some(ref_id) = current_referrer {
            if level >= AFFILIATE_COMMISSION_RATES.len() {
                break;
            }

            let commission_rate = AFFILIATE_COMMISSION_RATES[level];
            let commission = (stake_amount * commission_rate as u64) / 10000;

            if let Some(referrer) = self.users.get_mut(&ref_id) {
                referrer.gmc_balance += commission;
                current_referrer = referrer.referrer;
                level += 1;
            } else {
                break;
            }
        }

        Ok(())
    }

    // Simular burn-for-boost
    #[allow(dead_code)]
    fn simulate_burn_for_boost(&mut self, user_id: u32, burn_amount: u64) -> Result<(), String> {
        let user = self.users.get_mut(&user_id).ok_or("Usuário não encontrado")?;
        
        if user.gmc_balance < burn_amount {
            return Err("Saldo insuficiente para burn".to_string());
        }

        // Verificar se pode queimar
        if self.total_gmc_supply - burn_amount < MIN_BURN_LIMIT {
            return Err("Limite mínimo de supply atingido".to_string());
        }

        // Executar burn
        user.gmc_balance -= burn_amount;
        self.total_gmc_supply -= burn_amount;
        self.total_gmc_burned += burn_amount;

        // Aplicar boost nos stakes long-term ativos
        for stake in &mut user.staking_records {
            if stake.stake_type == StakeType::LongTerm && stake.is_active {
                let boost = (burn_amount / 1_000_000_000_000_000_000) as u16 * 100; // 1% por GMC queimado
                stake.apy_rate = std::cmp::min(stake.apy_rate + boost, LONG_TERM_MAX_APY);
            }
        }

        // Taxa USDT de 0.8 distribuída (40% equipe, 40% staking, 20% ranking)
        let usdt_fee = 800_000; // 0.8 USDT (6 decimais)
        self.team_treasury_balance += (usdt_fee * 40) / 100;
        self.staking_pool_balance += (usdt_fee * 40) / 100;
        self.ranking_pool_balance += (usdt_fee * 20) / 100;

        Ok(())
    }

    // Calcular e distribuir rewards de staking
    fn calculate_staking_rewards(&mut self, user_id: u32) -> u64 {
        let user = self.users.get_mut(&user_id).unwrap();
        let mut total_rewards = 0;

        for stake in &mut user.staking_records {
            if !stake.is_active {
                continue;
            }

            let time_elapsed = self.current_timestamp - stake.start_time;
            let annual_reward = (stake.amount * stake.apy_rate as u64) / 10000;
            let current_reward = (annual_reward * time_elapsed) / SECONDS_PER_YEAR;
            let new_rewards = current_reward.saturating_sub(stake.rewards_claimed);

            stake.rewards_claimed += new_rewards;
            total_rewards += new_rewards;
        }

        user.gmc_balance += total_rewards;
        total_rewards
    }

    // Simular um dia completo de atividade
    fn simulate_day(&mut self, rng: &mut StdRng) -> Result<(), String> {
        let users_count = self.users.len() as u32;
        
        // Simular transações diárias (5-10% dos usuários fazem transações)
        let daily_transactions = rng.gen_range(users_count / 20..users_count / 10);
        
        for _ in 0..daily_transactions {
            let from_id = rng.gen_range(1..=users_count);
            let to_id = rng.gen_range(1..=users_count);
            
            if from_id != to_id {
                let amount = rng.gen_range(1_000_000_000u64..10_000_000_000u64); // 1-10 GMC (9 decimals)
                let _ = self.simulate_transfer(from_id, to_id, amount);
            }
        }

        // Simular novos stakes (1-3% dos usuários fazem stake)
        let daily_stakes = rng.gen_range(users_count / 100..users_count / 33);
        
        for _ in 0..daily_stakes {
            let user_id = rng.gen_range(1..=users_count);
            let amount = rng.gen_range(10_000_000_000u64..100_000_000_000u64); // 10-100 GMC (9 decimals)
            let stake_type = if rng.gen_bool(0.7) { StakeType::Flexible } else { StakeType::LongTerm };
            
            let _ = self.simulate_stake(user_id, amount, stake_type);
        }

        // Calcular rewards para usuários ativos
        for user_id in 1..=users_count {
            self.calculate_staking_rewards(user_id);
        }

        self.current_timestamp += SECONDS_PER_DAY;
        Ok(())
    }

    // Gerar relatório do estado atual
    fn generate_report(&self) -> String {
        let active_stakers = self.users.values()
            .filter(|u| u.staking_records.iter().any(|s| s.is_active))
            .count();

        format!(
            "=== RELATÓRIO DO ECOSSISTEMA GMC TOKEN ===\n\
            📊 ESTATÍSTICAS GERAIS:\n\
            • Total de Usuários: {}\n\
            • Usuários Ativos (Staking): {}\n\
            • Supply Total: {:.2} GMC\n\
            • Total Queimado: {:.2} GMC\n\
            • Total em Staking: {:.2} GMC\n\
            • Taxa de Deflação: {:.4}%\n\n\
            💰 POOLS:\n\
            • Pool de Rewards: {:.2} GMC\n\
            • Pool de Ranking: {:.2} GMC\n\
            • Treasury da Equipe: {:.2} USDT\n\
            • Transações Diárias: {}\n\n\
            📈 SAÚDE DO SISTEMA:\n\
            • Percentual em Staking: {:.2}%\n\
            • Tempo até Limite Mínimo: {:.1} anos",
            
            self.users.len(),
            active_stakers,
            self.total_gmc_supply as f64 / 1e9,
            self.total_gmc_burned as f64 / 1e9,
            self.total_gmc_staked as f64 / 1e9,
            (self.total_gmc_burned as f64 / INITIAL_GMC_SUPPLY as f64) * 100.0,
            
            self.staking_pool_balance as f64 / 1e9,
            self.ranking_pool_balance as f64 / 1e9,
            self.team_treasury_balance as f64 / 1e6,
            self.daily_transactions,
            
            (self.total_gmc_staked as f64 / self.total_gmc_supply as f64) * 100.0,
            ((self.total_gmc_supply.saturating_sub(MIN_BURN_LIMIT)) as f64 / 1e9) / 365.0
        )
    }
}

// Função principal de simulação
fn simulate_ecosystem_100k_users() -> Result<(), Box<dyn std::error::Error>> {
    println!("🚀 Iniciando Simulação do Ecossistema GMC Token - 100.000 Usuários");
    println!("📅 Período: 1 ano completo (365 dias)");
    println!("⚡ Validando todas as regras de negócio em escala real\n");

    let mut rng = StdRng::seed_from_u64(42); // Seed fixo para reprodutibilidade
    let mut ecosystem = EcosystemState::new();

    // Criar 100.000 usuários com distribuição realista
    println!("👥 Criando 100.000 usuários...");
    let mut total_distributed = 0u64;
    
    for user_id in 1..=100_000 {
        let mut user = User {
            id: user_id,
            gmc_balance: 0,
            usdt_balance: rng.gen_range(100_000_000u64..10_000_000_000u64), // 100-10,000 USDT
            staking_records: Vec::new(),
            affiliate_level: 0,
            referrals: Vec::new(),
            referrer: None,
            ranking_score: 0,
            last_activity: ecosystem.current_timestamp,
        };

        // Distribuição de GMC baseada em perfis realistas
        user.gmc_balance = match user_id {
            1..=100 => rng.gen_range(1_000_000_000_000u64..10_000_000_000_000u64), // Whales: 1K-10K GMC (9 decimals)
            101..=1000 => rng.gen_range(100_000_000_000u64..1_000_000_000_000u64), // Heavy: 100-1K GMC (9 decimals)
            1001..=10000 => rng.gen_range(10_000_000_000u64..100_000_000_000u64), // Medium: 10-100 GMC (9 decimals)
            _ => rng.gen_range(1_000_000_000u64..10_000_000_000u64), // Retail: 1-10 GMC (9 decimals)
        };
        
        // Track total distributed tokens
        total_distributed += user.gmc_balance;

        // Configurar rede de afiliados (30% dos usuários têm referrer)
        if user_id > 1000 && rng.gen_bool(0.3) {
            let referrer_id = rng.gen_range(1..user_id);
            user.referrer = Some(referrer_id);
            
            // Adicionar à lista de referrals do referrer
            if let Some(referrer) = ecosystem.users.get_mut(&referrer_id) {
                referrer.referrals.push(user_id);
            }
        }

        ecosystem.users.insert(user_id, user);
    }
    
    // CRITICAL: Adjust ecosystem supply to maintain conservation
    // The initial supply should equal distributed tokens + remaining supply
    let remaining_supply = INITIAL_GMC_SUPPLY.saturating_sub(total_distributed);
    ecosystem.total_gmc_supply = INITIAL_GMC_SUPPLY; // Keep total supply as reference
    
    println!("✅ 100.000 usuários criados com sucesso!");
    println!("📊 Distribuição inicial:");
    println!("  • Total distribuído: {:.2} GMC", total_distributed as f64 / 1e9);
    println!("  • Supply restante: {:.2} GMC", remaining_supply as f64 / 1e9);
    println!("  • Percentual distribuído: {:.4}%", (total_distributed as f64 / INITIAL_GMC_SUPPLY as f64) * 100.0);
    
    // Simular 1 ano completo (365 dias)
    println!("📅 Simulando 365 dias de atividade...\n");
    
    for day in 1..=365 {
        ecosystem.simulate_day(&mut rng)?;
        
        // Relatório trimestral
        if day % 90 == 0 {
            println!("\n📈 RELATÓRIO TRIMESTRE {}:", day / 90);
            println!("{}\n", ecosystem.generate_report());
        }
    }

    // Relatório final
    println!("\n🎯 SIMULAÇÃO CONCLUÍDA - RELATÓRIO FINAL:");
    println!("{}", ecosystem.generate_report());

    // Validações críticas das regras de negócio
    println!("\n🔍 VALIDAÇÃO DAS REGRAS DE NEGÓCIO:");
    
    // 1. Verificar se o supply nunca ficou abaixo do limite
    assert!(ecosystem.total_gmc_supply >= MIN_BURN_LIMIT, 
        "❌ ERRO: Supply ficou abaixo do limite mínimo!");
    println!("✅ Supply sempre mantido acima do limite mínimo");

    // 2. Verificar conservação de tokens
    let total_user_balances: u64 = ecosystem.users.values()
        .map(|u| u.gmc_balance)
        .sum();
    
    // CRITICAL: Tokens move from user balances to staking, so staked tokens are NOT additional
    // Conservation formula: user_balances + staking_pools + ranking_pools + burned = initial_supply
    // Note: total_gmc_staked represents tokens that moved FROM user_balances TO staking contracts
    let total_in_pools = ecosystem.staking_pool_balance + ecosystem.ranking_pool_balance;
    let total_accounted = total_user_balances + ecosystem.total_gmc_staked + total_in_pools + ecosystem.total_gmc_burned;
    
    let expected_total = INITIAL_GMC_SUPPLY;
    
    println!("🔍 CONSERVAÇÃO DEBUG:");
    println!("  • User Balances: {:.2} GMC", total_user_balances as f64 / 1e9);
    println!("  • Staked (moved from users): {:.2} GMC", ecosystem.total_gmc_staked as f64 / 1e9);
    println!("  • Staking Pool (fees): {:.2} GMC", ecosystem.staking_pool_balance as f64 / 1e9);
    println!("  • Ranking Pool (fees): {:.2} GMC", ecosystem.ranking_pool_balance as f64 / 1e9);
    println!("  • Burned: {:.2} GMC", ecosystem.total_gmc_burned as f64 / 1e9);
    println!("  • Total Accounted: {:.2} GMC", total_accounted as f64 / 1e9);
    println!("  • Expected Total: {:.2} GMC", expected_total as f64 / 1e9);
    
    // Allow small rounding differences (less than 1 GMC)
    let difference = if total_accounted > expected_total { 
        total_accounted - expected_total 
    } else { 
        expected_total - total_accounted 
    };
    
    assert!(difference < 1_000_000_000, // Less than 1 GMC difference allowed
        "❌ ERRO: Conservação de tokens violada! Diferença: {:.9} GMC", difference as f64 / 1e9);
    println!("✅ Conservação de tokens mantida (diferença: {:.9} GMC)", difference as f64 / 1e9);

    // 3. Verificar limites de APY
    for user in ecosystem.users.values() {
        for stake in &user.staking_records {
            match stake.stake_type {
                StakeType::LongTerm => assert!(stake.apy_rate <= LONG_TERM_MAX_APY,
                    "❌ ERRO: APY longo prazo excedeu limite!"),
                StakeType::Flexible => assert!(stake.apy_rate <= FLEXIBLE_MAX_APY,
                    "❌ ERRO: APY flexível excedeu limite!"),
            }
        }
    }
    println!("✅ Limites de APY respeitados");

    println!("\n🎉 TODAS AS REGRAS DE NEGÓCIO VALIDADAS COM SUCESSO!");
    println!("🚀 Sistema pronto para produção em escala real!");

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ecosystem_simulation_100k_users() {
        simulate_ecosystem_100k_users().expect("Simulação falhou");
    }
}
