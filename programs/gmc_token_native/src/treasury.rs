//! 🏛️ Treasury Program - GMC Token Native Rust
//! 
//! Módulo responsável pela gestão centralizada de fundos do protocolo GMC Token.
//! Implementa controle multisig, distribuições automatizadas e governança financeira.

use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    sysvar::{clock::Clock, Sysvar},
};
use crate::GMCError;

/// 🏛️ Constantes do Treasury
pub const MAX_SIGNERS: usize = 10;
pub const MIN_SIGNERS: usize = 3;
pub const REQUIRED_SIGNATURES: usize = 3; // 3-of-N multisig
#[allow(dead_code)]
pub const MAX_PENDING_TRANSACTIONS: usize = 50;
pub const TRANSACTION_EXPIRY_SECONDS: i64 = 7 * 24 * 3600; // 7 dias

/// 💰 Distribuição de fundos do Treasury (baseada na análise USDT)
pub const TEAM_ALLOCATION_PERCENTAGE: u8 = 40;
pub const STAKING_ALLOCATION_PERCENTAGE: u8 = 40;
pub const RANKING_ALLOCATION_PERCENTAGE: u8 = 20;

/// 🏛️ Estado principal do Treasury
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
#[repr(C)]
pub struct TreasuryState {
    pub authority: Pubkey,
    pub signers: [Pubkey; MAX_SIGNERS],
    pub active_signers: u8,
    pub required_signatures: u8,
    pub total_balance_usdt: u64,
    pub total_balance_gmc: u64,
    pub transaction_counter: u64,
    pub last_distribution_timestamp: i64,
    pub is_initialized: bool,
    pub is_active: bool,
    pub emergency_pause: bool,
    pub total_distributed_team: u64,
    pub total_distributed_staking: u64,
    pub total_distributed_ranking: u64,
}

/// 📋 Transação pendente no Treasury
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
#[repr(C)]
pub struct PendingTransaction {
    pub transaction_id: u64,
    pub transaction_type: TransactionType,
    pub recipient: Pubkey,
    pub amount: u64,
    pub token_type: TokenType,
    pub created_at: i64,
    pub expires_at: i64,
    pub signatures: [bool; MAX_SIGNERS],
    pub signature_count: u8,
    pub status: TransactionStatus,
    pub memo: [u8; 64],
}

/// 🔄 Tipos de transação suportados
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, PartialEq)]
pub enum TransactionType {
    TeamDistribution,
    StakingDistribution,
    RankingDistribution,
    ManualTransfer,
    ConfigUpdate,
    Emergency,
}

/// 🪙 Tipos de token suportados
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, PartialEq)]
pub enum TokenType {
    USDT,
    GMC,
}

/// 📊 Status da transação
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone, PartialEq)]
pub enum TransactionStatus {
    Pending,
    Executed,
    Rejected,
    Expired,
}

/// 🏛️ Instruções do Treasury
#[derive(BorshSerialize, BorshDeserialize, Debug, Clone)]
pub enum TreasuryInstruction {
    Initialize {
        signers: Vec<Pubkey>,
        required_signatures: u8,
    },
    ProposeTransaction {
        transaction_type: TransactionType,
        recipient: Pubkey,
        amount: u64,
        token_type: TokenType,
        memo: [u8; 64],
    },
    SignTransaction {
        transaction_id: u64,
    },
    ExecuteTransaction {
        transaction_id: u64,
    },
    AutoDistribute {
        total_amount: u64,
        token_type: TokenType,
    },
    UpdateConfig {
        new_signers: Option<Vec<Pubkey>>,
        new_required_signatures: Option<u8>,
    },
    EmergencyPause {
        pause: bool,
    },
}

impl Default for TreasuryState {
    fn default() -> Self {
        Self {
            authority: Pubkey::default(),
            signers: [Pubkey::default(); MAX_SIGNERS],
            active_signers: 0,
            required_signatures: REQUIRED_SIGNATURES as u8,
            total_balance_usdt: 0,
            total_balance_gmc: 0,
            transaction_counter: 0,
            last_distribution_timestamp: 0,
            is_initialized: false,
            is_active: false,
            emergency_pause: false,
            total_distributed_team: 0,
            total_distributed_staking: 0,
            total_distributed_ranking: 0,
        }
    }
}

impl Default for PendingTransaction {
    fn default() -> Self {
        Self {
            transaction_id: 0,
            transaction_type: TransactionType::ManualTransfer,
            recipient: Pubkey::default(),
            amount: 0,
            token_type: TokenType::USDT,
            created_at: 0,
            expires_at: 0,
            signatures: [false; MAX_SIGNERS],
            signature_count: 0,
            status: TransactionStatus::Pending,
            memo: [0; 64],
        }
    }
}

/// 🏛️ Processador principal de instruções do Treasury
#[allow(dead_code)]
pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction = TreasuryInstruction::try_from_slice(instruction_data)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    process_treasury_instruction(program_id, accounts, instruction)
}

/// 🏛️ Processador direto de instruções do Treasury (sem serialização)
pub fn process_treasury_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction: TreasuryInstruction,
) -> ProgramResult {
    match instruction {
        TreasuryInstruction::Initialize { signers, required_signatures } => {
            process_initialize(program_id, accounts, signers, required_signatures)
        },
        TreasuryInstruction::ProposeTransaction { transaction_type, recipient, amount, token_type, memo } => {
            process_propose_transaction(program_id, accounts, transaction_type, recipient, amount, token_type, memo)
        },
        TreasuryInstruction::SignTransaction { transaction_id } => {
            process_sign_transaction(program_id, accounts, transaction_id)
        },
        TreasuryInstruction::ExecuteTransaction { transaction_id } => {
            process_execute_transaction(program_id, accounts, transaction_id)
        },
        TreasuryInstruction::AutoDistribute { total_amount, token_type } => {
            process_auto_distribute(program_id, accounts, total_amount, token_type)
        },
        TreasuryInstruction::UpdateConfig { new_signers, new_required_signatures } => {
            process_update_config(program_id, accounts, new_signers, new_required_signatures)
        },
        TreasuryInstruction::EmergencyPause { pause } => {
            process_emergency_pause(program_id, accounts, pause)
        },
    }
}

/// 🚀 Inicializar Treasury
fn process_initialize(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    signers: Vec<Pubkey>,
    required_signatures: u8,
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let authority_info = next_account_info(accounts_iter)?;
    let treasury_state_info = next_account_info(accounts_iter)?;
    
    if !authority_info.is_signer {
        return Err(GMCError::MissingSignature.into());
    }
    
    if signers.len() < MIN_SIGNERS || signers.len() > MAX_SIGNERS {
        return Err(GMCError::InvalidRankingParameters.into());
    }
    
    if required_signatures < 2 || required_signatures as usize > signers.len() {
        return Err(GMCError::InvalidRankingParameters.into());
    }
    
    let mut treasury_state = TreasuryState::default();
    treasury_state.authority = *authority_info.key;
    treasury_state.active_signers = signers.len() as u8;
    treasury_state.required_signatures = required_signatures;
    treasury_state.is_initialized = true;
    treasury_state.is_active = true;
    
    for (i, signer) in signers.iter().enumerate() {
        if i < MAX_SIGNERS {
            treasury_state.signers[i] = *signer;
        }
    }
    
    treasury_state.serialize(&mut *treasury_state_info.data.borrow_mut())?;
    
    msg!("Treasury inicializado com {} signatários", signers.len());
    Ok(())
}

/// 📝 Propor nova transação
fn process_propose_transaction(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    transaction_type: TransactionType,
    recipient: Pubkey,
    amount: u64,
    token_type: TokenType,
    memo: [u8; 64],
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let proposer_info = next_account_info(accounts_iter)?;
    let treasury_state_info = next_account_info(accounts_iter)?;
    let pending_tx_info = next_account_info(accounts_iter)?;
    
    if !proposer_info.is_signer {
        return Err(GMCError::MissingSignature.into());
    }
    
    let mut treasury_state = TreasuryState::try_from_slice(&treasury_state_info.data.borrow())?;
    
    if !treasury_state.is_initialized || !treasury_state.is_active {
        return Err(GMCError::RankingNotInitialized.into());
    }
    
    if treasury_state.emergency_pause {
        return Err(GMCError::OperationNotAllowed.into());
    }
    
    let is_authorized = treasury_state.signers[..treasury_state.active_signers as usize]
        .contains(proposer_info.key);
    
    if !is_authorized {
        return Err(GMCError::UnauthorizedAccess.into());
    }
    
    let clock = Clock::get()?;
    let current_timestamp = clock.unix_timestamp;
    
    let mut pending_tx = PendingTransaction::default();
    pending_tx.transaction_id = treasury_state.transaction_counter;
    pending_tx.transaction_type = transaction_type;
    pending_tx.recipient = recipient;
    pending_tx.amount = amount;
    pending_tx.token_type = token_type;
    pending_tx.created_at = current_timestamp;
    pending_tx.expires_at = current_timestamp + TRANSACTION_EXPIRY_SECONDS;
    pending_tx.memo = memo;
    pending_tx.status = TransactionStatus::Pending;
    
    if let Some(signer_index) = treasury_state.signers[..treasury_state.active_signers as usize]
        .iter()
        .position(|&signer| signer == *proposer_info.key) {
        pending_tx.signatures[signer_index] = true;
        pending_tx.signature_count = 1;
    }
    
    treasury_state.transaction_counter = treasury_state.transaction_counter.saturating_add(1);
    
    treasury_state.serialize(&mut *treasury_state_info.data.borrow_mut())?;
    pending_tx.serialize(&mut *pending_tx_info.data.borrow_mut())?;
    
    msg!("Transação {} proposta", pending_tx.transaction_id);
    Ok(())
}

/// ✍️ Assinar transação pendente
fn process_sign_transaction(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    transaction_id: u64,
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let signer_info = next_account_info(accounts_iter)?;
    let treasury_state_info = next_account_info(accounts_iter)?;
    let pending_tx_info = next_account_info(accounts_iter)?;
    
    if !signer_info.is_signer {
        return Err(GMCError::MissingSignature.into());
    }
    
    let treasury_state = TreasuryState::try_from_slice(&treasury_state_info.data.borrow())?;
    let mut pending_tx = PendingTransaction::try_from_slice(&pending_tx_info.data.borrow())?;
    
    if pending_tx.transaction_id != transaction_id {
        return Err(GMCError::InvalidRankingParameters.into());
    }
    
    if pending_tx.status != TransactionStatus::Pending {
        return Err(GMCError::OperationNotAllowed.into());
    }
    
    let clock = Clock::get()?;
    if clock.unix_timestamp > pending_tx.expires_at {
        pending_tx.status = TransactionStatus::Expired;
        pending_tx.serialize(&mut *pending_tx_info.data.borrow_mut())?;
        return Err(GMCError::InvalidTimestamp.into());
    }
    
    let signer_index = treasury_state.signers[..treasury_state.active_signers as usize]
        .iter()
        .position(|&signer| signer == *signer_info.key)
        .ok_or(GMCError::UnauthorizedAccess)?;
    
    if pending_tx.signatures[signer_index] {
        return Err(GMCError::OperationNotAllowed.into());
    }
    
    pending_tx.signatures[signer_index] = true;
    pending_tx.signature_count = pending_tx.signature_count.saturating_add(1);
    
    pending_tx.serialize(&mut *pending_tx_info.data.borrow_mut())?;
    
    msg!("Transação {} assinada ({}/{})", 
         transaction_id, 
         pending_tx.signature_count,
         treasury_state.required_signatures);
    
    Ok(())
}

/// ⚡ Executar transação aprovada
fn process_execute_transaction(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    transaction_id: u64,
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let executor_info = next_account_info(accounts_iter)?;
    let treasury_state_info = next_account_info(accounts_iter)?;
    let pending_tx_info = next_account_info(accounts_iter)?;
    
    if !executor_info.is_signer {
        return Err(GMCError::MissingSignature.into());
    }
    
    let mut treasury_state = TreasuryState::try_from_slice(&treasury_state_info.data.borrow())?;
    let mut pending_tx = PendingTransaction::try_from_slice(&pending_tx_info.data.borrow())?;
    
    if pending_tx.transaction_id != transaction_id {
        return Err(GMCError::InvalidRankingParameters.into());
    }
    
    if pending_tx.signature_count < treasury_state.required_signatures {
        return Err(GMCError::UnauthorizedAccess.into());
    }
    
    if pending_tx.status != TransactionStatus::Pending {
        return Err(GMCError::OperationNotAllowed.into());
    }
    
    let clock = Clock::get()?;
    if clock.unix_timestamp > pending_tx.expires_at {
        pending_tx.status = TransactionStatus::Expired;
        pending_tx.serialize(&mut *pending_tx_info.data.borrow_mut())?;
        return Err(GMCError::InvalidTimestamp.into());
    }
    
    // Atualizar estatísticas
    match pending_tx.transaction_type {
        TransactionType::TeamDistribution => {
            treasury_state.total_distributed_team = 
                treasury_state.total_distributed_team.saturating_add(pending_tx.amount);
        }
        TransactionType::StakingDistribution => {
            treasury_state.total_distributed_staking = 
                treasury_state.total_distributed_staking.saturating_add(pending_tx.amount);
        }
        TransactionType::RankingDistribution => {
            treasury_state.total_distributed_ranking = 
                treasury_state.total_distributed_ranking.saturating_add(pending_tx.amount);
        }
        _ => {}
    }
    
    // 💰 BUSINESS RULE: Taxa Saque USDT (0.3% sobre valor)
    let (final_amount, withdrawal_fee) = match pending_tx.token_type {
        TokenType::USDT => {
            let fee = pending_tx.amount
                .checked_mul(30) // 0.3% = 30/10000
                .and_then(|x| x.checked_div(10000))
                .ok_or_else(|| {
                    msg!("🚨 Security Alert: USDT withdrawal fee calculation overflow");
                    GMCError::ArithmeticOverflow
                })?;
            
            let user_receives = pending_tx.amount
                .checked_sub(fee)
                .ok_or_else(|| {
                    msg!("🚨 Security Alert: USDT amount calculation underflow");
                    GMCError::ArithmeticOverflow
                })?;
            
            msg!("💰 USDT withdrawal fee (0.3%): {} USDT", fee);
            msg!("💸 User receives: {} USDT (after 0.3% fee)", user_receives);
            
            (user_receives, fee)
        }
        TokenType::GMC => {
            // GMC não tem taxa de saque
            (pending_tx.amount, 0)
        }
    };
    
    // Atualizar saldo
    match pending_tx.token_type {
        TokenType::USDT => {
            treasury_state.total_balance_usdt = 
                treasury_state.total_balance_usdt.saturating_sub(pending_tx.amount);
            // Fee permanece no treasury como receita
            msg!("💰 USDT withdrawal fee {} retained in treasury", withdrawal_fee);
        }
        TokenType::GMC => {
            treasury_state.total_balance_gmc = 
                treasury_state.total_balance_gmc.saturating_sub(pending_tx.amount);
        }
    }
    
    pending_tx.status = TransactionStatus::Executed;
    
    treasury_state.serialize(&mut *treasury_state_info.data.borrow_mut())?;
    pending_tx.serialize(&mut *pending_tx_info.data.borrow_mut())?;
    
    msg!("Transação {} executada com sucesso", transaction_id);
    Ok(())
}

/// 🔄 Distribuição automática periódica
fn process_auto_distribute(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    total_amount: u64,
    token_type: TokenType,
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let authority_info = next_account_info(accounts_iter)?;
    let treasury_state_info = next_account_info(accounts_iter)?;
    
    if !authority_info.is_signer {
        return Err(GMCError::MissingSignature.into());
    }
    
    let mut treasury_state = TreasuryState::try_from_slice(&treasury_state_info.data.borrow())?;
    
    if !treasury_state.is_active || treasury_state.emergency_pause {
        return Err(GMCError::OperationNotAllowed.into());
    }
    
    let team_amount = (total_amount as u128 * TEAM_ALLOCATION_PERCENTAGE as u128 / 100) as u64;
    let staking_amount = (total_amount as u128 * STAKING_ALLOCATION_PERCENTAGE as u128 / 100) as u64;
    let ranking_amount = (total_amount as u128 * RANKING_ALLOCATION_PERCENTAGE as u128 / 100) as u64;
    
    treasury_state.total_distributed_team = 
        treasury_state.total_distributed_team.saturating_add(team_amount);
    treasury_state.total_distributed_staking = 
        treasury_state.total_distributed_staking.saturating_add(staking_amount);
    treasury_state.total_distributed_ranking = 
        treasury_state.total_distributed_ranking.saturating_add(ranking_amount);
    
    let clock = Clock::get()?;
    treasury_state.last_distribution_timestamp = clock.unix_timestamp;
    
    treasury_state.serialize(&mut *treasury_state_info.data.borrow_mut())?;
    
    msg!("Distribuição automática: {} {:?} total", total_amount, token_type);
    msg!("Equipe: {}, Staking: {}, Ranking: {}", team_amount, staking_amount, ranking_amount);
    
    Ok(())
}

/// ⚙️ Atualizar configuração do Treasury
fn process_update_config(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    new_signers: Option<Vec<Pubkey>>,
    new_required_signatures: Option<u8>,
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let authority_info = next_account_info(accounts_iter)?;
    let treasury_state_info = next_account_info(accounts_iter)?;
    
    if !authority_info.is_signer {
        return Err(GMCError::MissingSignature.into());
    }
    
    let mut treasury_state = TreasuryState::try_from_slice(&treasury_state_info.data.borrow())?;
    
    if treasury_state.authority != *authority_info.key {
        return Err(GMCError::UnauthorizedAccess.into());
    }
    
    if let Some(signers) = new_signers {
        if signers.len() < MIN_SIGNERS || signers.len() > MAX_SIGNERS {
            return Err(GMCError::InvalidRankingParameters.into());
        }
        
        treasury_state.signers = [Pubkey::default(); MAX_SIGNERS];
        
        for (i, signer) in signers.iter().enumerate() {
            treasury_state.signers[i] = *signer;
        }
        
        treasury_state.active_signers = signers.len() as u8;
    }
    
    if let Some(required_sigs) = new_required_signatures {
        if required_sigs < 2 || required_sigs as usize > treasury_state.active_signers as usize {
            return Err(GMCError::InvalidRankingParameters.into());
        }
        
        treasury_state.required_signatures = required_sigs;
    }
    
    treasury_state.serialize(&mut *treasury_state_info.data.borrow_mut())?;
    
    msg!("Configuração do Treasury atualizada");
    Ok(())
}

/// 🚨 Pausar/despausar em emergência
fn process_emergency_pause(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    pause: bool,
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let authority_info = next_account_info(accounts_iter)?;
    let treasury_state_info = next_account_info(accounts_iter)?;
    
    if !authority_info.is_signer {
        return Err(GMCError::MissingSignature.into());
    }
    
    let mut treasury_state = TreasuryState::try_from_slice(&treasury_state_info.data.borrow())?;
    
    if treasury_state.authority != *authority_info.key {
        return Err(GMCError::UnauthorizedAccess.into());
    }
    
    treasury_state.emergency_pause = pause;
    
    treasury_state.serialize(&mut *treasury_state_info.data.borrow_mut())?;
    
    msg!("Treasury {}", if pause { "pausado" } else { "reativado" });
    Ok(())
}

/// 🧪 Função auxiliar para calcular distribuições
#[allow(dead_code)]
pub fn calculate_distribution_amounts(total_amount: u64) -> (u64, u64, u64) {
    let team_amount = (total_amount as u128 * TEAM_ALLOCATION_PERCENTAGE as u128 / 100) as u64;
    let staking_amount = (total_amount as u128 * STAKING_ALLOCATION_PERCENTAGE as u128 / 100) as u64;
    let ranking_amount = (total_amount as u128 * RANKING_ALLOCATION_PERCENTAGE as u128 / 100) as u64;
    
    (team_amount, staking_amount, ranking_amount)
}

#[cfg(test)]
mod tests {
    use super::*;
    use solana_program::{clock::Epoch, pubkey::Pubkey};
    
    // Treasury tests moved to separate test files
    use solana_program::account_info::AccountInfo;

    #[allow(dead_code)]
    fn create_mock_account_info(lamports: u64, space: usize, owner: &Pubkey) -> (Pubkey, u64, Vec<u8>) {
        (*owner, lamports, vec![0; space])
    }

    #[test]
    fn test_treasury_state_serialization() {
        let authority = Pubkey::new_unique();
        let signer1 = Pubkey::new_unique();
        let signer2 = Pubkey::new_unique();
        
        let mut state = TreasuryState::default();
        state.authority = authority;
        state.signers[0] = signer1;
        state.signers[1] = signer2;
        state.active_signers = 2;
        state.required_signatures = 2;
        state.is_initialized = true;
        state.is_active = true;
        
        let mut data = Vec::new();
        state.serialize(&mut data).unwrap();
        
        let deserialized_state = TreasuryState::try_from_slice(&data).unwrap();
        
        assert_eq!(deserialized_state.authority, authority);
        assert_eq!(deserialized_state.signers[0], signer1);
        assert_eq!(deserialized_state.signers[1], signer2);
        assert_eq!(deserialized_state.active_signers, 2);
        assert_eq!(deserialized_state.required_signatures, 2);
        assert!(deserialized_state.is_initialized);
        assert!(deserialized_state.is_active);
    }

    #[test]
    fn test_calculate_distribution_amounts() {
        let total_amount = 1000u64;
        let (team, staking, ranking) = calculate_distribution_amounts(total_amount);
        
        assert_eq!(team, 400); // 40% of 1000
        assert_eq!(staking, 400); // 40% of 1000
        assert_eq!(ranking, 200); // 20% of 1000
        
        // Verify total adds up
        assert_eq!(team + staking + ranking, 1000);
    }

    #[test]
    fn test_pending_transaction_serialization() {
        let recipient = Pubkey::new_unique();
        let memo = [1u8; 64];
        
        let mut tx = PendingTransaction::default();
        tx.transaction_id = 123;
        tx.transaction_type = TransactionType::TeamDistribution;
        tx.recipient = recipient;
        tx.amount = 1000;
        tx.token_type = TokenType::USDT;
        tx.memo = memo;
        tx.status = TransactionStatus::Pending;
        
        let mut data = Vec::new();
        tx.serialize(&mut data).unwrap();
        
        let deserialized_tx = PendingTransaction::try_from_slice(&data).unwrap();
        
        assert_eq!(deserialized_tx.transaction_id, 123);
        assert_eq!(deserialized_tx.transaction_type, TransactionType::TeamDistribution);
        assert_eq!(deserialized_tx.recipient, recipient);
        assert_eq!(deserialized_tx.amount, 1000);
        assert_eq!(deserialized_tx.token_type, TokenType::USDT);
        assert_eq!(deserialized_tx.memo, memo);
        assert_eq!(deserialized_tx.status, TransactionStatus::Pending);
    }

    #[test]
    fn test_treasury_constants() {
        assert_eq!(TEAM_ALLOCATION_PERCENTAGE, 40);
        assert_eq!(STAKING_ALLOCATION_PERCENTAGE, 40);
        assert_eq!(RANKING_ALLOCATION_PERCENTAGE, 20);
        assert_eq!(TEAM_ALLOCATION_PERCENTAGE + STAKING_ALLOCATION_PERCENTAGE + RANKING_ALLOCATION_PERCENTAGE, 100);
        
        assert!(MIN_SIGNERS >= 3);
        assert!(MAX_SIGNERS >= MIN_SIGNERS);
        assert!(REQUIRED_SIGNATURES >= 3);
        assert!(TRANSACTION_EXPIRY_SECONDS > 0);
    }
}
