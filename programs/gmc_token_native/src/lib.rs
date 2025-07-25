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
    pub admin: Pubkey,
    pub is_initialized: bool,
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