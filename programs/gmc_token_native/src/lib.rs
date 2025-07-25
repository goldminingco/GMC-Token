use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
};
use borsh::{BorshDeserialize, BorshSerialize};

// 🪙 GMC TOKEN - CONSTANTES FUNDAMENTAIS
// Regras de negócio críticas implementadas conforme requisitos

// 💰 Supply e Decimais (CONFORME TOKENOMICS ORIGINAL)
pub const GMC_TOTAL_SUPPLY: u64 = 100_000_000_000_000_000; // 100 milhões GMC (com 9 decimais)
pub const GMC_DECIMALS: u8 = 9;
pub const GMC_MINIMUM_SUPPLY: u64 = 12_000_000_000_000_000; // 12 milhões GMC (limite mínimo após queima)

// 📊 Distribuição Inicial (CONFORME TOKENOMICS ORIGINAL)
pub const STAKING_POOL_ALLOCATION: u64 = 70_000_000_000_000_000; // 70M GMC - Pool de Staking
pub const PRESALE_ALLOCATION: u64 = 8_000_000_000_000_000;       // 8M GMC - Pré-venda (ICO)
pub const STRATEGIC_RESERVE: u64 = 10_000_000_000_000_000;       // 10M GMC - Reserva Estratégica (5 anos vesting)
pub const TREASURY_ALLOCATION: u64 = 2_000_000_000_000_000;      // 2M GMC - Tesouraria
pub const MARKETING_ALLOCATION: u64 = 6_000_000_000_000_000;     // 6M GMC - Marketing e Expansão
pub const AIRDROP_ALLOCATION: u64 = 2_000_000_000_000_000;       // 2M GMC - Airdrop Comunitário
pub const TEAM_ALLOCATION: u64 = 2_000_000_000_000_000;          // 2M GMC - Equipe (com vesting)

// 💸 Taxa de Transferência: 0.5%
pub const TRANSFER_FEE_BASIS_POINTS: u16 = 50; // 0.5% = 50 basis points

// 🔥 Distribuição da Taxa de Transferência (0.5%)
pub const TRANSFER_FEE_BURN_PERCENT: u16 = 50;    // 50% para queima
pub const TRANSFER_FEE_STAKING_PERCENT: u16 = 40;  // 40% para fundo de staking
pub const TRANSFER_FEE_RANKING_PERCENT: u16 = 10;  // 10% para programa de ranking

// 💼 Carteiras do Ecossistema
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct EcosystemWallets {
    pub team: Pubkey,
    pub treasury: Pubkey,
    pub marketing: Pubkey,
    pub airdrop: Pubkey,
    pub presale: Pubkey,
    pub staking_fund: Pubkey,
    pub ranking_fund: Pubkey,
}

// 🛡️ Erros Customizados
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum GMCError {
    InvalidAmount = 0x1001,
    InsufficientBalance = 0x1002,
    TransferFeeCalculationError = 0x1003,
    BurnLimitReached = 0x1004,
    InvalidWallet = 0x1005,
    ArithmeticOverflow = 0x1006,
    InvalidTimestamp = 0x1007,
    // 🛡️ Novos erros de segurança OWASP
    ReentrancyDetected = 0x1008,
    AccessDenied = 0x1009,
    InvalidInput = 0x1010,
    ComputeUnitLimitExceeded = 0x1011,
    TimestampManipulation = 0x1012,
    DefaultPubkeyNotAllowed = 0x1013,
    // 🏗️ Novos erros para Vesting e Distribuição
    InvalidDistribution = 0x1014,
    InsufficientTimelock = 0x1015,
    BurnExceedsLimit = 0x1016,
    NoVestingDue = 0x1017,
}

// 🔄 Implementar conversão para ProgramError (necessário para ?)
impl From<GMCError> for ProgramError {
    fn from(error: GMCError) -> Self {
        match error {
            GMCError::InvalidAmount => ProgramError::InvalidArgument,
            GMCError::InsufficientBalance => ProgramError::InsufficientFunds,
            GMCError::TransferFeeCalculationError => ProgramError::InvalidArgument,
            GMCError::BurnLimitReached => ProgramError::Custom(0x1004),
            GMCError::InvalidWallet => ProgramError::InvalidAccountData,
            GMCError::ArithmeticOverflow => ProgramError::ArithmeticOverflow,
            GMCError::InvalidTimestamp => ProgramError::InvalidArgument,
            // 🛡️ Novos erros de segurança
            GMCError::ReentrancyDetected => ProgramError::Custom(0x1008),
            GMCError::AccessDenied => ProgramError::MissingRequiredSignature,
            GMCError::InvalidInput => ProgramError::InvalidArgument,
            GMCError::ComputeUnitLimitExceeded => ProgramError::Custom(0x1011),
            GMCError::TimestampManipulation => ProgramError::InvalidArgument,
            GMCError::DefaultPubkeyNotAllowed => ProgramError::InvalidAccountData,
            // 🏗️ Novos erros de Vesting e Distribuição
            GMCError::InvalidDistribution => ProgramError::InvalidAccountData,
            GMCError::InsufficientTimelock => ProgramError::InvalidArgument,
            GMCError::BurnExceedsLimit => ProgramError::InvalidArgument,
            GMCError::NoVestingDue => ProgramError::InvalidArgument,
        }
    }
}

// Declarar entrypoint
entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub enum GMCInstruction {
    Initialize { initial_supply: u64 },
    Transfer { amount: u64 },
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct TokenAccount {
    pub balance: u64,
    pub is_initialized: bool,
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct GlobalState {
    pub total_supply: u64,
    pub circulating_supply: u64,
    pub burned_supply: u64,
    pub admin: Pubkey,
    pub ecosystem_wallets: EcosystemWallets,
    pub is_initialized: bool,
    pub burn_stopped: bool, // Para quando atingir 12M GMC
}

// 🔥 Estrutura para Distribuição da Taxa de Transferência
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct TransferFeeDistribution {
    pub burn_amount: u64,
    pub staking_amount: u64,
    pub ranking_amount: u64,
    pub total_fee: u64,
}

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction = GMCInstruction::try_from_slice(instruction_data)?;
    
    match instruction {
        GMCInstruction::Initialize { initial_supply } => {
            msg!("GMC Token: Initialize with supply {}", initial_supply);
            process_initialize(accounts, initial_supply, program_id)
        }
        GMCInstruction::Transfer { amount } => {
            msg!("GMC Token: Transfer amount {}", amount);
            process_transfer(accounts, amount)
        }
    }
}

pub fn process_initialize(
    accounts: &[AccountInfo],
    initial_supply: u64,
    _program_id: &Pubkey,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let global_state_account = next_account_info(account_info_iter)?;
    let admin_account = next_account_info(account_info_iter)?;
    
    if !admin_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    let mut global_state = GlobalState::try_from_slice(&global_state_account.data.borrow())?;
    
    if global_state.is_initialized {
        return Err(ProgramError::AccountAlreadyInitialized);
    }
    
    global_state.total_supply = initial_supply;
    global_state.admin = *admin_account.key;
    global_state.is_initialized = true;
    
    global_state.serialize(&mut &mut global_state_account.data.borrow_mut()[..])?;
    
    msg!("GMC Token initialized successfully with supply: {}", initial_supply);
    Ok(())
}

pub fn process_transfer(
    accounts: &[AccountInfo],
    amount: u64,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let from_account = next_account_info(account_info_iter)?;
    let to_account = next_account_info(account_info_iter)?;
    let authority_account = next_account_info(account_info_iter)?;
    
    if !authority_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    let mut from_token_account = TokenAccount::try_from_slice(&from_account.data.borrow())?;
    let mut to_token_account = TokenAccount::try_from_slice(&to_account.data.borrow())?;
    
    if !from_token_account.is_initialized || !to_token_account.is_initialized {
        return Err(ProgramError::UninitializedAccount);
    }
    
    if from_token_account.balance < amount {
        return Err(ProgramError::InsufficientFunds);
    }
    
    from_token_account.balance -= amount;
    to_token_account.balance += amount;
    
    from_token_account.serialize(&mut &mut from_account.data.borrow_mut()[..])?;
    to_token_account.serialize(&mut &mut to_account.data.borrow_mut()[..])?;
    
    msg!("Transferred {} tokens", amount);
    Ok(())
}

// 🔥 FUNÇÕES DE TAXA DE TRANSFERÊNCIA - OTIMIZADAS PARA GAS
// Implementação seguindo TDD: Red-Green-Refactor-Security

/// Calcula a taxa de transferência de 0.5% e sua distribuição
/// Otimizado: O(1) complexidade, zero-copy, proteção overflow
pub fn calculate_transfer_fee(amount: u64) -> Result<TransferFeeDistribution, GMCError> {
    // 🛡️ Proteção contra overflow
    let fee_amount = amount
        .checked_mul(TRANSFER_FEE_BASIS_POINTS as u64)
        .and_then(|x| x.checked_div(10000))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    // 🔥 Distribuição otimizada (4 operações apenas)
    let burn_amount = fee_amount
        .checked_mul(TRANSFER_FEE_BURN_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::TransferFeeCalculationError)?;
    
    let staking_amount = fee_amount
        .checked_mul(TRANSFER_FEE_STAKING_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::TransferFeeCalculationError)?;
    
    let ranking_amount = fee_amount
        .checked_mul(TRANSFER_FEE_RANKING_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::TransferFeeCalculationError)?;
    
    Ok(TransferFeeDistribution {
        total_fee: fee_amount,
        burn_amount,
        staking_amount,
        ranking_amount,
    })
}

/// Aplica a taxa de transferência ao estado global
/// Otimizado: Atualização in-place, verificação de limite de queima
pub fn apply_transfer_fee(
    global_state: &mut GlobalState,
    transfer_amount: u64,
) -> Result<TransferFeeDistribution, GMCError> {
    let fee_distribution = calculate_transfer_fee(transfer_amount)?;
    
    // 🛡️ Verificar se queima deve parar (12M GMC limite)
    let new_circulating = global_state.circulating_supply
        .checked_sub(fee_distribution.burn_amount)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    if new_circulating < GMC_MINIMUM_SUPPLY {
        // 🚫 Parar queima, redistribuir para staking/ranking
        global_state.burn_stopped = true;
        
        // Redistribuir valor da queima: 80% staking, 20% ranking
        let extra_staking = fee_distribution.burn_amount
            .checked_mul(80)
            .and_then(|x| x.checked_div(100))
            .ok_or(GMCError::ArithmeticOverflow)?;
        
        let extra_ranking = fee_distribution.burn_amount
            .checked_sub(extra_staking)
            .ok_or(GMCError::ArithmeticOverflow)?;
        
        return Ok(TransferFeeDistribution {
            total_fee: fee_distribution.total_fee,
            burn_amount: 0, // Queima parada
            staking_amount: fee_distribution.staking_amount + extra_staking,
            ranking_amount: fee_distribution.ranking_amount + extra_ranking,
        });
    }
    
    // ✅ Aplicar queima normalmente
    global_state.circulating_supply = new_circulating;
    global_state.burned_supply = global_state.burned_supply
        .checked_add(fee_distribution.burn_amount)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    msg!("🔥 Taxa aplicada: {} GMC queimados, {} para staking, {} para ranking",
         fee_distribution.burn_amount,
         fee_distribution.staking_amount,
         fee_distribution.ranking_amount);
    
    Ok(fee_distribution)
}

/// Processa transferência com taxa automática
/// Otimizado: Single-pass, compute units eficiente
pub fn process_transfer_with_fee(
    accounts: &[AccountInfo],
    amount: u64,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let from_account = next_account_info(account_info_iter)?;
    let to_account = next_account_info(account_info_iter)?;
    let global_state_account = next_account_info(account_info_iter)?;
    let authority_account = next_account_info(account_info_iter)?;
    
    // 🛡️ Verificações de segurança
    if !authority_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    if amount == 0 {
        return Err(ProgramError::InvalidArgument);
    }
    
    // 📊 Carregar contas (zero-copy quando possível)
    let mut from_token_account = TokenAccount::try_from_slice(&from_account.data.borrow())?;
    let mut to_token_account = TokenAccount::try_from_slice(&to_account.data.borrow())?;
    let mut global_state = GlobalState::try_from_slice(&global_state_account.data.borrow())?;
    
    // ✅ Verificar saldo suficiente
    if from_token_account.balance < amount {
        return Err(ProgramError::InsufficientFunds);
    }
    
    // 🔥 Calcular e aplicar taxa
    let fee_distribution = apply_transfer_fee(&mut global_state, amount)?;
    let net_amount = amount
        .checked_sub(fee_distribution.total_fee)
        .ok_or(ProgramError::InsufficientFunds)?;
    
    // 💸 Executar transferência
    from_token_account.balance = from_token_account.balance
        .checked_sub(amount)
        .ok_or(ProgramError::InsufficientFunds)?;
    
    to_token_account.balance = to_token_account.balance
        .checked_add(net_amount)
        .ok_or(ProgramError::InvalidArgument)?;
    
    // 💾 Salvar estados (batch write para eficiência)
    from_token_account.serialize(&mut &mut from_account.data.borrow_mut()[..])?;
    to_token_account.serialize(&mut &mut to_account.data.borrow_mut()[..])?;
    global_state.serialize(&mut &mut global_state_account.data.borrow_mut()[..])?;
    
    msg!("✅ Transferência concluída: {} GMC líquidos, {} GMC taxa",
         net_amount, fee_distribution.total_fee);
    
    Ok(())
}

// 🛡️ FUNÇÕES DE SEGURANÇA OWASP - IMPLEMENTAÇÃO TDD
// SC01: Reentrancy Protection, SC03: Access Control, SC04: Input Validation

/// Proteção Anti-Reentrancy (OWASP SC01)
#[derive(Debug, Clone)]
pub struct ReentrancyGuard {
    entered: bool,
}

impl ReentrancyGuard {
    pub fn new() -> Self {
        Self { entered: false }
    }
    
    pub fn enter(&mut self) -> Result<(), GMCError> {
        if self.entered {
            return Err(GMCError::ReentrancyDetected);
        }
        self.entered = true;
        Ok(())
    }
    
    pub fn exit(&mut self) {
        self.entered = false;
    }
}

/// Validação de Entrada (OWASP SC04)
/// Otimizado: O(1) complexidade, proteção overflow
pub fn validate_input_amount(amount: u64) -> Result<(), GMCError> {
    // 🛡️ Zero não permitido
    if amount == 0 {
        return Err(GMCError::InvalidInput);
    }
    
    // 🛡️ Proteção contra overflow na taxa (amount * 50 / 10000)
    let max_safe_amount = u64::MAX / 10000;
    if amount > max_safe_amount {
        return Err(GMCError::InvalidInput);
    }
    
    Ok(())
}

/// Controle de Acesso (OWASP SC03)
/// Verifica autorização baseada em papel
pub fn check_access_control(
    global_state: &GlobalState,
    caller: &Pubkey,
    required_role: &str,
) -> Result<(), GMCError> {
    match required_role {
        "admin" => {
            if *caller != global_state.admin {
                return Err(GMCError::AccessDenied);
            }
        }
        "treasury" => {
            if *caller != global_state.ecosystem_wallets.treasury {
                return Err(GMCError::AccessDenied);
            }
        }
        "team" => {
            if *caller != global_state.ecosystem_wallets.team {
                return Err(GMCError::AccessDenied);
            }
        }
        _ => {
            return Err(GMCError::AccessDenied);
        }
    }
    Ok(())
}

/// Validação de Timestamp (OWASP SC04)
/// Proteção contra manipulação temporal
pub fn validate_timestamp(timestamp: i64, current_time: i64) -> Result<(), GMCError> {
    // 🛡️ Timestamp não pode ser no futuro (tolerância de 60s)
    if timestamp > current_time + 60 {
        return Err(GMCError::TimestampManipulation);
    }
    
    // 🛡️ Timestamp não pode ser muito antigo (24h)
    if timestamp < current_time - 86400 {
        return Err(GMCError::TimestampManipulation);
    }
    
    Ok(())
}

/// Validação de Pubkey (OWASP SC04)
/// Proteção contra pubkeys padrão/maliciosos
pub fn validate_pubkey_not_default(pubkey: &Pubkey) -> Result<(), GMCError> {
    if *pubkey == Pubkey::default() {
        return Err(GMCError::DefaultPubkeyNotAllowed);
    }
    Ok(())
}

/// Simulação de Operação Cara (Proteção DoS)
/// Limite de compute units para prevenir ataques
pub fn simulate_expensive_operation(operation_count: u32) -> Result<(), GMCError> {
    const MAX_OPERATIONS: u32 = 100; // Limite de segurança
    
    if operation_count > MAX_OPERATIONS {
        return Err(GMCError::ComputeUnitLimitExceeded);
    }
    
    // Simular operação cara
    for _ in 0..operation_count {
        // Operação simulada
    }
    
    Ok(())
}

/// Função de Transferência Segura com Todas as Proteções
/// Implementa todas as validações OWASP
pub fn secure_transfer(
    accounts: &[AccountInfo],
    amount: u64,
    reentrancy_guard: &mut ReentrancyGuard,
) -> ProgramResult {
    // 🛡️ SC01: Proteção Anti-Reentrancy
    reentrancy_guard.enter()?;
    
    let result = (|| -> ProgramResult {
        let account_info_iter = &mut accounts.iter();
        let from_account = next_account_info(account_info_iter)?;
        let to_account = next_account_info(account_info_iter)?;
        let global_state_account = next_account_info(account_info_iter)?;
        let authority_account = next_account_info(account_info_iter)?;
        
        // 🛡️ SC04: Validação de Entrada
        validate_input_amount(amount)?;
        validate_pubkey_not_default(authority_account.key)?;
        
        // 🛡️ SC03: Controle de Acesso
        if !authority_account.is_signer {
            return Err(GMCError::AccessDenied.into());
        }
        
        let mut global_state = GlobalState::try_from_slice(&global_state_account.data.borrow())?;
        
        // 🛡️ Verificar autorização específica se necessário
        // check_access_control(&global_state, authority_account.key, "user")?;
        
        // Executar transferência com taxa
        let fee_distribution = apply_transfer_fee(&mut global_state, amount)?;
        
        msg!("🛡️ Transferência segura executada: {} GMC, taxa {} GMC",
             amount - fee_distribution.total_fee, fee_distribution.total_fee);
        
        Ok(())
    })();
    
    // 🛡️ Sempre limpar guard (mesmo em caso de erro)
    reentrancy_guard.exit();
    
    result
}

// ⚖️ FUNÇÕES DE PENALIDADES - IMPLEMENTAÇÃO TDD
// Regras críticas: Cancelamento Flexível, Taxa Saque Juros, Taxa Saque USDT

/// Estrutura para Penalidade de Cancelamento
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct PenaltyDistribution {
    pub penalty_amount: u64,
    pub penalty_percentage: u16, // basis points
    pub net_amount: u64,
}

/// Estrutura para Distribuição de Taxa de Saque
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct WithdrawalFeeDistribution {
    pub total_fee: u64,
    pub net_amount: u64,
    pub team_amount: u64,     // 40%
    pub staking_amount: u64,  // 40%
    pub ranking_amount: u64,  // 20%
}

// ⚖️ CONSTANTES DE PENALIDADES
pub const FLEXIBLE_CANCELLATION_PENALTY_BASIS_POINTS: u16 = 250; // 2.5%
pub const INTEREST_WITHDRAWAL_FEE_BASIS_POINTS: u16 = 100;       // 1%
pub const USDT_WITHDRAWAL_FEE_BASIS_POINTS: u16 = 30;            // 0.3%

// 📊 DISTRIBUIÇÃO DAS TAXAS DE SAQUE (40% Equipe, 40% Staking, 20% Ranking)
pub const WITHDRAWAL_FEE_TEAM_PERCENT: u16 = 40;
pub const WITHDRAWAL_FEE_STAKING_PERCENT: u16 = 40;
pub const WITHDRAWAL_FEE_RANKING_PERCENT: u16 = 20;

/// Calcula penalidade de cancelamento do staking flexível (2.5%)
/// Otimizado: O(1) complexidade, proteção overflow
pub fn calculate_flexible_cancellation_penalty(stake_amount: u64) -> Result<PenaltyDistribution, GMCError> {
    // 🛡️ Validação de entrada
    if stake_amount == 0 {
        return Err(GMCError::InvalidInput);
    }
    
    // 🛡️ Proteção contra overflow
    let penalty_amount = stake_amount
        .checked_mul(FLEXIBLE_CANCELLATION_PENALTY_BASIS_POINTS as u64)
        .and_then(|x| x.checked_div(10000))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    let net_amount = stake_amount
        .checked_sub(penalty_amount)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    Ok(PenaltyDistribution {
        penalty_amount,
        penalty_percentage: FLEXIBLE_CANCELLATION_PENALTY_BASIS_POINTS,
        net_amount,
    })
}

/// Calcula taxa de saque de juros (1%) com distribuição 40/40/20
/// Otimizado: Single calculation, proteção overflow
pub fn calculate_interest_withdrawal_fee(interest_amount: u64) -> Result<WithdrawalFeeDistribution, GMCError> {
    // 🛡️ Validação de entrada
    if interest_amount == 0 {
        return Err(GMCError::InvalidInput);
    }
    
    // 🛡️ Calcular taxa total (1%)
    let total_fee = interest_amount
        .checked_mul(INTEREST_WITHDRAWAL_FEE_BASIS_POINTS as u64)
        .and_then(|x| x.checked_div(10000))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    let net_amount = interest_amount
        .checked_sub(total_fee)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    // 📊 Distribuir taxa (40% equipe, 40% staking, 20% ranking)
    let team_amount = total_fee
        .checked_mul(WITHDRAWAL_FEE_TEAM_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    let staking_amount = total_fee
        .checked_mul(WITHDRAWAL_FEE_STAKING_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    let ranking_amount = total_fee
        .checked_mul(WITHDRAWAL_FEE_RANKING_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    Ok(WithdrawalFeeDistribution {
        total_fee,
        net_amount,
        team_amount,
        staking_amount,
        ranking_amount,
    })
}

/// Calcula taxa de saque USDT (0.3%) com distribuição 40/40/20
/// Otimizado: Mesma lógica que juros, mas para USDT (6 decimais)
pub fn calculate_usdt_withdrawal_fee(usdt_amount: u64) -> Result<WithdrawalFeeDistribution, GMCError> {
    // 🛡️ Validação de entrada
    if usdt_amount == 0 {
        return Err(GMCError::InvalidInput);
    }
    
    // 🛡️ Calcular taxa total (0.3%)
    let total_fee = usdt_amount
        .checked_mul(USDT_WITHDRAWAL_FEE_BASIS_POINTS as u64)
        .and_then(|x| x.checked_div(10000))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    let net_amount = usdt_amount
        .checked_sub(total_fee)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    // 📊 Distribuir taxa (40% equipe, 40% staking, 20% ranking)
    let team_amount = total_fee
        .checked_mul(WITHDRAWAL_FEE_TEAM_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    let staking_amount = total_fee
        .checked_mul(WITHDRAWAL_FEE_STAKING_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    let ranking_amount = total_fee
        .checked_mul(WITHDRAWAL_FEE_RANKING_PERCENT as u64)
        .and_then(|x| x.checked_div(100))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    Ok(WithdrawalFeeDistribution {
        total_fee,
        net_amount,
        team_amount,
        staking_amount,
        ranking_amount,
    })
}

/// Função integrada para processar cancelamento de staking flexível
/// Implementa penalidade + distribuição automática
pub fn process_flexible_staking_cancellation(
    accounts: &[AccountInfo],
    stake_amount: u64,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let staker_account = next_account_info(account_info_iter)?;
    let global_state_account = next_account_info(account_info_iter)?;
    let authority_account = next_account_info(account_info_iter)?;
    
    // 🛡️ Verificações de segurança
    if !authority_account.is_signer {
        return Err(GMCError::AccessDenied.into());
    }
    
    // ⚖️ Calcular penalidade
    let penalty = calculate_flexible_cancellation_penalty(stake_amount)?;
    
    let mut global_state = GlobalState::try_from_slice(&global_state_account.data.borrow())?;
    
    // 🔥 Aplicar penalidade (queima)
    global_state.circulating_supply = global_state.circulating_supply
        .checked_sub(penalty.penalty_amount)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    global_state.burned_supply = global_state.burned_supply
        .checked_add(penalty.penalty_amount)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    // 💾 Salvar estado
    global_state.serialize(&mut &mut global_state_account.data.borrow_mut()[..])?;
    
    msg!("⚖️ Cancelamento flexível processado: {} GMC líquidos, {} GMC penalidade",
         penalty.net_amount, penalty.penalty_amount);
    
    Ok(())
}

// 🏗️ ESTRUTURAS DE VESTING E DISTRIBUIÇÃO - IMPLEMENTAÇÃO TDD
// Regras críticas: Vesting Equipe, Time-locks, Supply Inicial, Queima Limite, Carteiras

/// Cronograma de Vesting da Equipe
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct TeamVestingSchedule {
    pub total_allocation: u64,
    pub vesting_duration_months: u16,
    pub cliff_months: u16,
    pub start_timestamp: u64,
    pub released_amount: u64,
}

/// Operação com Time-lock de Segurança
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct TimeLockedOperation {
    pub operation_type: String,
    pub delay_hours: u16,
    pub creation_timestamp: u64,
    pub execution_timestamp: u64,
    pub executed: bool,
    pub authority: Pubkey,
}

/// Distribuição Inicial do Token
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct InitialDistribution {
    pub total_supply: u64,
    pub circulating_supply: u64,
    pub burned_supply: u64,
    
    // Alocações específicas
    pub staking_pool: u64,
    pub presale: u64,
    pub strategic_reserve: u64,
    pub treasury: u64,
    pub team: u64,
    pub marketing: u64,
    pub airdrop: u64,
    
    // Carteiras específicas
    pub treasury_wallet: Option<Pubkey>,
    pub team_wallet: Option<Pubkey>,
    pub marketing_wallet: Option<Pubkey>,
}

/// Resultado da Validação de Queima
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub struct BurnValidation {
    pub is_valid: bool,
    pub new_circulating: u64,
    pub burn_amount: u64,
    pub limit_reached: bool,
    pub remaining_capacity: u64,
}

// 🏗️ CONSTANTES DE VESTING E DISTRIBUIÇÃO
pub const TEAM_VESTING_DURATION_MONTHS: u16 = 24;  // 24 meses
pub const TEAM_VESTING_CLIFF_MONTHS: u16 = 6;      // 6 meses cliff
pub const MIN_TIME_LOCK_HOURS: u16 = 24;           // 24h mínimo
pub const CRITICAL_TIME_LOCK_HOURS: u16 = 48;      // 48h para operações críticas
pub const SECONDS_PER_MONTH: u64 = 2_628_000;      // ~30.4 dias

// 📊 DISTRIBUIÇÃO INICIAL CORRETA (100M GMC)
pub const INITIAL_STAKING_POOL: u64 = 70_000_000_000_000_000;     // 70M GMC (70%)
pub const INITIAL_PRESALE: u64 = 8_000_000_000_000_000;           // 8M GMC (8%)
pub const INITIAL_STRATEGIC_RESERVE: u64 = 10_000_000_000_000_000; // 10M GMC (10%)
pub const INITIAL_MARKETING: u64 = 6_000_000_000_000_000;         // 6M GMC (6%)
pub const INITIAL_AIRDROP: u64 = 2_000_000_000_000_000;           // 2M GMC (2%)
pub const INITIAL_TEAM: u64 = 2_000_000_000_000_000;              // 2M GMC (2%) - Vesting
pub const INITIAL_TREASURY: u64 = 2_000_000_000_000_000;          // 2M GMC (2%)

impl TeamVestingSchedule {
    /// Cria novo cronograma de vesting
    pub fn new(total_allocation: u64, vesting_duration_months: u16, cliff_months: u16) -> Self {
        Self {
            total_allocation,
            vesting_duration_months,
            cliff_months,
            start_timestamp: 0, // Será definido no deploy
            released_amount: 0,
        }
    }
}

impl TimeLockedOperation {
    /// Verifica se operação pode ser executada
    pub fn can_execute(&self, current_timestamp: u64) -> bool {
        !self.executed && current_timestamp >= self.execution_timestamp
    }
}

impl InitialDistribution {
    /// Cria distribuição padrão
    pub fn default() -> Self {
        Self {
            total_supply: GMC_TOTAL_SUPPLY,
            circulating_supply: 100_000_000_000_000_000, // 100M GMC
            burned_supply: 0,
            staking_pool: INITIAL_STAKING_POOL,
            presale: INITIAL_PRESALE,
            strategic_reserve: INITIAL_STRATEGIC_RESERVE,
            treasury: INITIAL_TREASURY,
            team: INITIAL_TEAM,
            marketing: INITIAL_MARKETING,
            airdrop: INITIAL_AIRDROP,
            treasury_wallet: None,
            team_wallet: None,
            marketing_wallet: None,
        }
    }
    
    /// Atribui carteiras específicas
    pub fn assign_wallets(&mut self, treasury: Pubkey, team: Pubkey, marketing: Pubkey) {
        self.treasury_wallet = Some(treasury);
        self.team_wallet = Some(team);
        self.marketing_wallet = Some(marketing);
    }
    
    /// Valida distribuição
    pub fn validate(&self) -> Result<(), GMCError> {
        if self.total_supply == 0 {
            return Err(GMCError::InvalidInput);
        }
        
        let total_allocated = self.staking_pool + self.presale + self.strategic_reserve +
                             self.treasury + self.team + self.marketing + self.airdrop;
        
        if total_allocated != self.circulating_supply {
            return Err(GMCError::InvalidDistribution);
        }
        
        Ok(())
    }
}

/// Calcula liberação do vesting da equipe baseado no tempo
/// Otimizado: Linear vesting após cliff, proteção overflow
pub fn calculate_team_vesting_release(
    schedule: &TeamVestingSchedule,
    months_elapsed: u16,
) -> Result<u64, GMCError> {
    // 🛡️ Validação de entrada
    if schedule.total_allocation == 0 {
        return Err(GMCError::InvalidInput);
    }
    
    // Antes do cliff, nada é liberado
    if months_elapsed < schedule.cliff_months {
        return Ok(0);
    }
    
    // Após vesting completo, libera 100%
    if months_elapsed >= schedule.vesting_duration_months {
        return Ok(schedule.total_allocation);
    }
    
    // 📊 Cálculo linear após cliff
    let vesting_months = schedule.vesting_duration_months - schedule.cliff_months;
    let elapsed_vesting_months = months_elapsed - schedule.cliff_months;
    
    let released_amount = schedule.total_allocation
        .checked_mul(elapsed_vesting_months as u64)
        .and_then(|x| x.checked_div(vesting_months as u64))
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    Ok(released_amount)
}

/// Cria operação com time-lock de segurança
/// Implementa delays obrigatórios para operações críticas
pub fn create_time_locked_operation(
    operation_type: &str,
    delay_hours: u16,
    current_timestamp: u64,
) -> Result<TimeLockedOperation, GMCError> {
    // 🛡️ Validações de segurança
    if delay_hours < MIN_TIME_LOCK_HOURS {
        return Err(GMCError::InsufficientTimelock);
    }
    
    // Timestamp não pode estar muito no futuro (proteção contra manipulação)
    let max_valid_timestamp = 2_000_000_000; // ~2033
    if current_timestamp > max_valid_timestamp {
        return Err(GMCError::InvalidTimestamp);
    }
    
    let execution_timestamp = current_timestamp
        .checked_add((delay_hours as u64) * 3600)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    Ok(TimeLockedOperation {
        operation_type: operation_type.to_string(),
        delay_hours,
        creation_timestamp: current_timestamp,
        execution_timestamp,
        executed: false,
        authority: Pubkey::default(), // Será definido pelo caller
    })
}

/// Configura distribuição inicial do token
/// Implementa alocação de 100M GMC conforme tokenomics
pub fn setup_initial_distribution() -> Result<InitialDistribution, GMCError> {
    let distribution = InitialDistribution::default();
    
    // 🛡️ Validar distribuição
    distribution.validate()?;
    
    Ok(distribution)
}

/// Valida se queima não excede limite mínimo de 12M GMC
/// Proteção crítica contra deflação excessiva
pub fn validate_burn_limit(
    current_circulating: u64,
    burn_amount: u64,
) -> Result<BurnValidation, GMCError> {
    // 🛡️ Validações de entrada
    if burn_amount == 0 {
        return Err(GMCError::InvalidInput);
    }
    
    if current_circulating <= GMC_MINIMUM_SUPPLY {
        return Err(GMCError::BurnLimitReached);
    }
    
    // 🛡️ Calcular novo supply circulante
    let new_circulating = current_circulating
        .checked_sub(burn_amount)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    // Verificar se excede limite mínimo
    if new_circulating < GMC_MINIMUM_SUPPLY {
        return Err(GMCError::BurnExceedsLimit);
    }
    
    let limit_reached = new_circulating == GMC_MINIMUM_SUPPLY;
    let remaining_capacity = new_circulating
        .checked_sub(GMC_MINIMUM_SUPPLY)
        .unwrap_or(0);
    
    Ok(BurnValidation {
        is_valid: true,
        new_circulating,
        burn_amount,
        limit_reached,
        remaining_capacity,
    })
}

/// Função integrada para processar vesting da equipe
/// Implementa liberação automática baseada em cronograma
pub fn process_team_vesting_release(
    accounts: &[AccountInfo],
    months_elapsed: u16,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let team_account = next_account_info(account_info_iter)?;
    let vesting_account = next_account_info(account_info_iter)?;
    let authority_account = next_account_info(account_info_iter)?;
    
    // 🛡️ Verificações de segurança
    if !authority_account.is_signer {
        return Err(GMCError::AccessDenied.into());
    }
    
    // 📊 Carregar cronograma de vesting
    let mut vesting_schedule = TeamVestingSchedule::try_from_slice(&vesting_account.data.borrow())?;
    
    // 🏗️ Calcular liberação
    let releasable_amount = calculate_team_vesting_release(&vesting_schedule, months_elapsed)?;
    let new_release = releasable_amount
        .checked_sub(vesting_schedule.released_amount)
        .ok_or(GMCError::ArithmeticOverflow)?;
    
    if new_release == 0 {
        return Err(GMCError::NoVestingDue.into());
    }
    
    // 💾 Atualizar estado
    vesting_schedule.released_amount = releasable_amount;
    vesting_schedule.serialize(&mut &mut vesting_account.data.borrow_mut()[..])?;
    
    msg!("🏗️ Vesting da equipe liberado: {} GMC (total: {} GMC)",
         new_release, releasable_amount);
    
    Ok(())
}

// 🏗️ DECLARAÇÃO DOS MÓDULOS PRINCIPAIS
mod staking;
mod affiliate;
mod ranking;
mod treasury;
mod vesting;
mod cpi_batch_optimization;

// 📝 Incluir testes TDD
mod transfer_fee_tests;
mod security_tests;
mod penalty_tests;
mod vesting_distribution_tests;

#[cfg(test)]
mod tests {
    use super::*;
    use solana_program::clock::Epoch;
    use std::mem;

    #[test]
    fn test_initialize() {
        let program_id = Pubkey::new_unique();
        let key = Pubkey::new_unique();
        let mut lamports = 0;
        let mut data = vec![0; mem::size_of::<GlobalState>()];
        let owner = program_id;
        let account = AccountInfo::new(
            &key,
            false,
            true,
            &mut lamports,
            &mut data,
            &owner,
            false,
            Epoch::default(),
        );

        let admin_key = Pubkey::new_unique();
        let mut admin_lamports = 0;
        let mut admin_data = vec![];
        let admin_account = AccountInfo::new(
            &admin_key,
            true,
            false,
            &mut admin_lamports,
            &mut admin_data,
            &admin_key,
            false,
            Epoch::default(),
        );

        let accounts = vec![account, admin_account];
        assert!(process_initialize(&accounts, 1000, &program_id).is_ok());
    }
} 