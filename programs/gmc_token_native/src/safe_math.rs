// 🟢 GREEN PHASE: Implementação mínima das funções de matemática segura
// Objetivo: Fazer os testes passarem sem alterar regras de negócio

use solana_program::program_error::ProgramError;

/// 🛡️ MATEMÁTICA SEGURA - Proteção contra Integer Overflow/Underflow
/// Implementação TDD para corrigir 1,826 operações matemáticas não verificadas

// 🟢 GREEN: Adição segura
pub fn safe_add(a: u64, b: u64) -> Result<u64, ProgramError> {
    a.checked_add(b).ok_or(ProgramError::ArithmeticOverflow)
}

// 🟢 GREEN: Multiplicação segura
pub fn safe_mul(a: u64, b: u64) -> Result<u64, ProgramError> {
    a.checked_mul(b).ok_or(ProgramError::ArithmeticOverflow)
}

// 🟢 GREEN: Subtração segura
pub fn safe_sub(a: u64, b: u64) -> Result<u64, ProgramError> {
    a.checked_sub(b).ok_or(ProgramError::ArithmeticOverflow)
}

// 🟢 GREEN: Divisão segura
pub fn safe_div(a: u64, b: u64) -> Result<u64, ProgramError> {
    if b == 0 {
        return Err(ProgramError::InvalidArgument);
    }
    a.checked_div(b).ok_or(ProgramError::ArithmeticOverflow)
}

// 🟢 GREEN: Cálculo de percentual seguro
pub fn safe_percentage(amount: u64, percentage: u64) -> Result<u64, ProgramError> {
    if percentage > 100 {
        return Err(ProgramError::InvalidArgument);
    }
    
    // Usar multiplicação e divisão seguras
    let result = safe_mul(amount, percentage)?;
    safe_div(result, 100)
}

// 🟢 GREEN: Cálculo de APY seguro (regra de negócio: 10-280% APY)
pub fn calculate_apy_rewards_safe(principal: u64, apy: u64) -> Result<u64, ProgramError> {
    // Validar APY dentro dos limites das regras de negócio
    if apy < 10 || apy > 280 {
        return Err(ProgramError::InvalidArgument);
    }
    
    // Cálculo seguro: (principal * apy) / 100
    let rewards = safe_mul(principal, apy)?;
    safe_div(rewards, 100)
}

// 🟢 GREEN: Distribuição de taxas USDT segura (regra de negócio: 40/40/20)
pub fn distribute_usdt_fees_safe(total_fee: u64) -> Result<(u64, u64, u64), ProgramError> {
    let team_share = safe_percentage(total_fee, 40)?;      // 40% equipe
    let staking_share = safe_percentage(total_fee, 40)?;   // 40% staking
    let ranking_share = safe_percentage(total_fee, 20)?;   // 20% ranking
    
    // Verificar que a soma está correta (preservar regra de negócio)
    let total_distributed = safe_add(safe_add(team_share, staking_share)?, ranking_share)?;
    
    if total_distributed != total_fee {
        return Err(ProgramError::InvalidArgument);
    }
    
    Ok((team_share, staking_share, ranking_share))
}

// 🟢 GREEN: Cálculo de supply seguro (regra de negócio: 100M GMC)
pub fn calculate_supply_distribution_safe() -> Result<(u64, u64, u64, u64, u64, u64, u64), ProgramError> {
    let total_supply = 100_000_000u64; // 100M GMC (regra de negócio)
    
    // Distribuição conforme tokenomics aprovado
    let staking_pool = safe_percentage(total_supply, 70)?;    // 70M
    let presale = safe_percentage(total_supply, 8)?;          // 8M
    let strategic_reserve = safe_percentage(total_supply, 10)?; // 10M
    let marketing = safe_percentage(total_supply, 6)?;        // 6M
    let airdrop = safe_percentage(total_supply, 2)?;          // 2M
    let team = safe_percentage(total_supply, 2)?;             // 2M
    let treasury = safe_percentage(total_supply, 2)?;         // 2M
    
    // Verificar que soma é 100M (preservar regra de negócio)
    let total_distributed = safe_add(
        safe_add(
            safe_add(staking_pool, presale)?,
            safe_add(strategic_reserve, marketing)?
        )?,
        safe_add(
            safe_add(airdrop, team)?,
            treasury
        )?
    )?;
    
    if total_distributed != total_supply {
        return Err(ProgramError::InvalidArgument);
    }
    
    Ok((staking_pool, presale, strategic_reserve, marketing, airdrop, team, treasury))
}

// 🟢 GREEN: Cálculo de rewards de staking seguro
pub fn calculate_staking_rewards_safe(stake_amount: u64, apy: u64, days: u64) -> Result<u64, ProgramError> {
    // Validar APY dentro dos limites (regra de negócio)
    if apy < 10 || apy > 280 {
        return Err(ProgramError::InvalidArgument);
    }
    
    // Cálculo seguro de taxa diária
    let daily_rate = safe_div(apy, 365)?;
    
    // Cálculo seguro de rewards diários
    let daily_rewards = safe_div(
        safe_mul(stake_amount, daily_rate)?,
        100
    )?;
    
    // Cálculo seguro de rewards totais
    safe_mul(daily_rewards, days)
}

// 🟢 GREEN: Cálculo de taxa de transferência seguro (regra de negócio: 0.5%)
pub fn calculate_transfer_fee_safe(amount: u64) -> Result<(u64, u64, u64, u64), ProgramError> {
    // Taxa total: 0.5% (regra de negócio)
    let total_fee = safe_div(safe_mul(amount, 5)?, 1000)?; // 0.5% = 5/1000
    
    // Distribuição: 50% queima, 40% staking, 10% ranking (regra de negócio)
    let burn_amount = safe_percentage(total_fee, 50)?;
    let staking_amount = safe_percentage(total_fee, 40)?;
    let ranking_amount = safe_percentage(total_fee, 10)?;
    
    // Valor líquido transferido
    let net_amount = safe_sub(amount, total_fee)?;
    
    Ok((net_amount, burn_amount, staking_amount, ranking_amount))
}

// 🟢 GREEN: Funções de conveniência para operações matemáticas seguras
// (Macro removida devido a limitações do Rust - usando funções diretas)

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_safe_operations_basic() {
        assert_eq!(safe_add(100, 200).unwrap(), 300);
        assert_eq!(safe_mul(10, 20).unwrap(), 200);
        assert_eq!(safe_sub(300, 100).unwrap(), 200);
        assert_eq!(safe_div(100, 10).unwrap(), 10);
    }

    #[test]
    fn test_overflow_detection() {
        assert!(safe_add(u64::MAX, 1).is_err());
        assert!(safe_mul(u64::MAX, 2).is_err());
        assert!(safe_sub(0, 1).is_err());
        assert!(safe_div(100, 0).is_err());
    }

    #[test]
    fn test_business_rules_preserved() {
        // Testar que regras de negócio estão preservadas
        let (team, staking, ranking) = distribute_usdt_fees_safe(1000).unwrap();
        assert_eq!(team, 400);     // 40%
        assert_eq!(staking, 400);  // 40%
        assert_eq!(ranking, 200);  // 20%
        
        // Testar supply distribution
        let (staking_pool, presale, strategic, marketing, airdrop, team, treasury) = 
            calculate_supply_distribution_safe().unwrap();
        assert_eq!(staking_pool, 70_000_000);  // 70M
        assert_eq!(presale, 8_000_000);        // 8M
        assert_eq!(strategic, 10_000_000);     // 10M
    }
}
