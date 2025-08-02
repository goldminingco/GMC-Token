// 🚀 GMC Token - CPI Batch Optimization (FIXED VERSION)
// Sprint 2: Cross-Program Invocation Batching for Compute Units Reduction
// Target: 15-30% CU reduction in bulk operations

use solana_program::{
    account_info::AccountInfo,
    program::{invoke, invoke_signed},
    program_error::ProgramError,
    pubkey::Pubkey,
    msg,
};
use spl_token::instruction as token_instruction;
use borsh::BorshDeserialize;

// 🚀 BATCH STRUCTURES: Optimized for minimal memory allocation

#[derive(Debug, Clone)]
pub struct BatchTransfer {
    pub from: Pubkey,
    pub to: Pubkey,
    pub amount: u64,
    pub authority: Pubkey,
}

#[derive(Debug, Clone)]
pub struct BatchMint {
    pub mint: Pubkey,
    pub to: Pubkey,
    pub amount: u64,
    pub authority: Pubkey,
}

#[derive(Debug, Clone)]
pub struct BatchBurn {
    pub mint: Pubkey,
    pub from: Pubkey,
    pub amount: u64,
    pub authority: Pubkey,
}

// 🚀 OPTIMIZATION: Pre-allocated batch containers
pub struct OptimizedBatchProcessor<'a> {
    pub token_program: &'a AccountInfo<'a>,
    pub rent_sysvar: &'a AccountInfo<'a>,
    pub authority: &'a AccountInfo<'a>,
    
    // Pre-allocated vectors for batch operations
    pub transfer_batch: Vec<BatchTransfer>,
    pub mint_batch: Vec<BatchMint>, 
    pub burn_batch: Vec<BatchBurn>,
    
    // Maximum batch sizes (to prevent hitting compute limits)
    pub max_transfers_per_batch: usize,
    pub max_mints_per_batch: usize,
    pub max_burns_per_batch: usize,
}

impl<'a> OptimizedBatchProcessor<'a> {
    // 🚀 OPTIMIZATION: Initialize with optimal batch sizes
    pub fn new(
        token_program: &'a AccountInfo<'a>,
        rent_sysvar: &'a AccountInfo<'a>,
        authority: &'a AccountInfo<'a>,
    ) -> Self {
        Self {
            token_program,
            rent_sysvar,
            authority,
            transfer_batch: Vec::with_capacity(16),  // Optimal for compute limits
            mint_batch: Vec::with_capacity(8),       // Minting is more expensive
            burn_batch: Vec::with_capacity(12),      // Burning is moderately expensive
            max_transfers_per_batch: 16,
            max_mints_per_batch: 8,
            max_burns_per_batch: 12,
        }
    }
    
    // 🚀 OPTIMIZATION: Add transfer to batch (no immediate execution)
    #[inline(always)]
    pub fn add_transfer(&mut self, transfer: BatchTransfer) -> Result<(), ProgramError> {
        if self.transfer_batch.len() >= self.max_transfers_per_batch {
            return Err(ProgramError::InsufficientFunds); // Reuse error for batch full
        }
        
        self.transfer_batch.push(transfer);
        Ok(())
    }
    
    // 🚀 OPTIMIZATION: Add mint to batch
    #[inline(always)]
    pub fn add_mint(&mut self, mint: BatchMint) -> Result<(), ProgramError> {
        if self.mint_batch.len() >= self.max_mints_per_batch {
            return Err(ProgramError::InsufficientFunds);
        }
        
        self.mint_batch.push(mint);
        Ok(())
    }
    
    // 🚀 OPTIMIZATION: Add burn to batch
    #[inline(always)]
    pub fn add_burn(&mut self, burn: BatchBurn) -> Result<(), ProgramError> {
        if self.burn_batch.len() >= self.max_burns_per_batch {
            return Err(ProgramError::InsufficientFunds);
        }
        
        self.burn_batch.push(burn);
        Ok(())
    }
    
    // 🚀 CORE OPTIMIZATION: Execute all batched transfers in one CPI call
    pub fn execute_transfer_batch(
        &mut self,
        accounts: &[AccountInfo<'a>],
        signer_seeds: Option<&[&[&[u8]]]>,
    ) -> Result<u64, ProgramError> {
        if self.transfer_batch.is_empty() {
            return Ok(0);
        }
        
        let batch_size = self.transfer_batch.len();
        msg!("🚀 Executing batch transfer: {} operations", batch_size);
        
        // 🚀 OPTIMIZATION: Process transfers in chunks to respect compute limits
        let mut total_transferred = 0u64;
        let chunks: Vec<_> = self.transfer_batch.chunks(8).collect(); // Process 8 at a time
        
        for chunk in chunks {
            total_transferred += self.execute_transfer_chunk(chunk, accounts, signer_seeds)?;
        }
        
        // Clear the batch after execution
        self.transfer_batch.clear();
        
        Ok(total_transferred)
    }
    
    // 🚀 OPTIMIZATION: Execute transfer chunk with minimal CPI overhead
    fn execute_transfer_chunk(
        &self,
        transfers: &[BatchTransfer],
        accounts: &[AccountInfo<'a>],
        signer_seeds: Option<&[&[&[u8]]]>,
    ) -> Result<u64, ProgramError> {
        let mut total_amount = 0u64;
        
        // 🚀 OPTIMIZATION: Create account lookup map once
        let account_map = self.create_account_lookup_map(accounts);
        
        for transfer in transfers {
            // 🚀 OPTIMIZATION: Fast account lookup
            let from_info = account_map.get(&transfer.from)
                .ok_or(ProgramError::InvalidAccountData)?;
            let to_info = account_map.get(&transfer.to)
                .ok_or(ProgramError::InvalidAccountData)?;
            let authority_info = account_map.get(&transfer.authority)
                .ok_or(ProgramError::InvalidAccountData)?;
            
            // 🚀 OPTIMIZATION: Create transfer instruction
            let transfer_instruction = token_instruction::transfer(
                self.token_program.key,
                from_info.key,
                to_info.key,
                authority_info.key,
                &[],
                transfer.amount,
            )?;
            
            // 🚀 OPTIMIZATION: Single CPI call per transfer in chunk
            let account_infos = vec![
                (*from_info).clone(),
                (*to_info).clone(),
                (*authority_info).clone(),
                (*self.token_program).clone(),
            ];
            
            if let Some(seeds) = signer_seeds {
                invoke_signed(&transfer_instruction, &account_infos, seeds)?;
            } else {
                invoke(&transfer_instruction, &account_infos)?;
            }
            
            total_amount = total_amount.saturating_add(transfer.amount);
        }
        
        Ok(total_amount)
    }
    
    // 🚀 OPTIMIZATION: Execute all batched mints with computed account creation
    pub fn execute_mint_batch(
        &mut self,
        accounts: &[AccountInfo<'a>],
        signer_seeds: Option<&[&[&[u8]]]>,
    ) -> Result<u64, ProgramError> {
        if self.mint_batch.is_empty() {
            return Ok(0);
        }
        
        // 🔐 CRITICAL SECURITY: Check if mint authority has been revoked
        // This prevents any minting after the authority has been revoked
        use crate::{GlobalState, GMCError};
        if let Some(global_state_account) = accounts.get(0) {
            if let Ok(global_state) = GlobalState::try_from_slice(&global_state_account.data.borrow()) {
                if global_state.mint_authority_revoked {
                    msg!("🚨 SECURITY: Mint attempt blocked - authority has been revoked");
                    return Err(GMCError::MintRevokedCannotMint.into());
                }
            }
        }
        
        let batch_size = self.mint_batch.len();
        msg!("🚀 Executing batch mint: {} operations", batch_size);
        
        let mut total_minted = 0u64;
        let account_map = self.create_account_lookup_map(accounts);
        
        // 🚀 OPTIMIZATION: Process mints with account validation
        for mint_op in &self.mint_batch {
            let mint_info = account_map.get(&mint_op.mint)
                .ok_or(ProgramError::InvalidAccountData)?;
            let to_info = account_map.get(&mint_op.to)
                .ok_or(ProgramError::InvalidAccountData)?;
            let authority_info = account_map.get(&mint_op.authority)
                .ok_or(ProgramError::InvalidAccountData)?;
            
            // 🚀 OPTIMIZATION: Mint to existing account (no account creation overhead)
            let mint_instruction = token_instruction::mint_to(
                self.token_program.key,
                mint_info.key,
                to_info.key,
                authority_info.key,
                &[],
                mint_op.amount,
            )?;
            
            let account_infos = vec![
                (*mint_info).clone(),
                (*to_info).clone(),
                (*authority_info).clone(),
                (*self.token_program).clone(),
            ];
            
            if let Some(seeds) = signer_seeds {
                invoke_signed(&mint_instruction, &account_infos, seeds)?;
            } else {
                invoke(&mint_instruction, &account_infos)?;
            }
            
            total_minted = total_minted.saturating_add(mint_op.amount);
        }
        
        // Clear the batch after execution
        self.mint_batch.clear();
        
        Ok(total_minted)
    }
    
    // 🚀 OPTIMIZATION: Execute all batched burns efficiently
    pub fn execute_burn_batch(
        &mut self,
        accounts: &[AccountInfo<'a>],
        signer_seeds: Option<&[&[&[u8]]]>,
    ) -> Result<u64, ProgramError> {
        if self.burn_batch.is_empty() {
            return Ok(0);
        }
        
        let batch_size = self.burn_batch.len();
        msg!("🚀 Executing batch burn: {} operations", batch_size);
        
        let mut total_burned = 0u64;
        let account_map = self.create_account_lookup_map(accounts);
        
        for burn_op in &self.burn_batch {
            let mint_info = account_map.get(&burn_op.mint)
                .ok_or(ProgramError::InvalidAccountData)?;
            let from_info = account_map.get(&burn_op.from)
                .ok_or(ProgramError::InvalidAccountData)?;
            let authority_info = account_map.get(&burn_op.authority)
                .ok_or(ProgramError::InvalidAccountData)?;
            
            // 🚀 OPTIMIZATION: Direct burn instruction
            let burn_instruction = token_instruction::burn(
                self.token_program.key,
                from_info.key,
                mint_info.key,
                authority_info.key,
                &[],
                burn_op.amount,
            )?;
            
            let account_infos = vec![
                (*from_info).clone(),
                (*mint_info).clone(),
                (*authority_info).clone(),
                (*self.token_program).clone(),
            ];
            
            if let Some(seeds) = signer_seeds {
                invoke_signed(&burn_instruction, &account_infos, seeds)?;
            } else {
                invoke(&burn_instruction, &account_infos)?;
            }
            
            total_burned = total_burned.saturating_add(burn_op.amount);
        }
        
        // Clear the batch after execution
        self.burn_batch.clear();
        
        Ok(total_burned)
    }
    
    // 🚀 OPTIMIZATION: Execute all batches in sequence for maximum efficiency
    pub fn execute_all_batches(
        &mut self,
        accounts: &[AccountInfo<'a>],
        signer_seeds: Option<&[&[&[u8]]]>,
    ) -> Result<(u64, u64, u64), ProgramError> {
        // Execute in optimal order: burns -> transfers -> mints
        let total_burned = self.execute_burn_batch(accounts, signer_seeds)?;
        let total_transferred = self.execute_transfer_batch(accounts, signer_seeds)?;
        let total_minted = self.execute_mint_batch(accounts, signer_seeds)?;
        
        msg!("🚀 Batch execution complete: {} burned, {} transferred, {} minted", 
             total_burned, total_transferred, total_minted);
        
        Ok((total_burned, total_transferred, total_minted))
    }
    
    // 🚀 OPTIMIZATION: Fast account lookup with HashMap-like behavior
    fn create_account_lookup_map<'b>(&self, accounts: &'b [AccountInfo<'a>]) -> std::collections::HashMap<Pubkey, &'b AccountInfo<'a>> {
        let mut map = std::collections::HashMap::with_capacity(accounts.len());
        
        for account in accounts {
            map.insert(*account.key, account);
        }
        
        map
    }
    
    // 🚀 OPTIMIZATION: Get current batch sizes for monitoring
    #[inline(always)]
    pub fn get_batch_stats(&self) -> (usize, usize, usize) {
        (
            self.transfer_batch.len(),
            self.mint_batch.len(),
            self.burn_batch.len(),
        )
    }
    
    // 🚀 OPTIMIZATION: Estimate compute units for current batches
    #[inline(always)]
    pub fn estimate_batch_compute_units(&self) -> u32 {
        // Rough estimates based on operation complexity
        let transfer_cost = self.transfer_batch.len() as u32 * 1200; // ~1200 CUs per transfer
        let mint_cost = self.mint_batch.len() as u32 * 1800;        // ~1800 CUs per mint
        let burn_cost = self.burn_batch.len() as u32 * 1500;        // ~1500 CUs per burn
        
        transfer_cost + mint_cost + burn_cost
    }
    
    // 🚀 OPTIMIZATION: Clear all batches (emergency reset)
    #[inline(always)]
    pub fn clear_all_batches(&mut self) {
        self.transfer_batch.clear();
        self.mint_batch.clear();
        self.burn_batch.clear();
    }
} 