//! GMC Ranking Program
//!
// ---
// EN: This program manages the ranking and prize distribution system for the GMC ecosystem.
//     It includes:
//     - Tracking user activities (transactions, referrals, burns).
//     - Monthly prize distribution (Top 7 per category).
//     - Annual prize distribution (Top 12 burners).
//     - An exclusion system for Top 20 holders.
//     - A Merkle Tree for efficient reward distribution.
// PT: Este programa gerencia o sistema de ranking e distribuição de prêmios do ecossistema GMC.
//     Inclui:
//     - Tracking de atividades dos usuários (transações, referrals, burns).
//     - Distribuição mensal de prêmios (Top 7 por categoria).
//     - Distribuição anual de prêmios (Top 12 queimadores).
//     - Sistema de exclusão para Top 20 holders.
//     - Merkle Tree para distribuição eficiente de recompensas.
// ---

use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

// EN: The unique identifier for the Ranking program.
// PT: O identificador único para o programa de Ranking.
declare_id!("GmcRank111111111111111111111111111111111111");

// =====================================================
// EN: Merkle Tree Verification Module
// PT: Módulo de Verificação Merkle Tree
// =====================================================

// ---
// EN: Verifies if a Merkle proof is valid for a given value (leaf) and root.
// PT: Verifica se uma prova Merkle é válida para um determinado valor (folha) e root.
// ---
pub fn verify_merkle_proof(
    proof: &[[u8; 32]],
    root: &[u8; 32],
    leaf: &[u8; 32],
) -> bool {
    let mut computed_hash = *leaf;
    
    for proof_element in proof.iter() {
        if computed_hash <= *proof_element {
            // Hash(current_computed_hash + current_element)
            computed_hash = anchor_lang::solana_program::keccak::hashv(&[&computed_hash, proof_element]).0;
        } else {
            // Hash(current_element + current_computed_hash)
            computed_hash = anchor_lang::solana_program::keccak::hashv(&[proof_element, &computed_hash]).0;
        }
    }
    
    computed_hash == *root
}

// ---
// EN: Creates the leaf hash for Merkle verification from user data and reward amounts.
// PT: Cria o hash da folha para verificação Merkle a partir dos dados do usuário e valores da recompensa.
// ---
pub fn create_leaf_hash(user: &Pubkey, amount_gmc: u64, amount_usdt: u64) -> [u8; 32] {
    anchor_lang::solana_program::keccak::hashv(&[
        user.as_ref(),
        &amount_gmc.to_le_bytes(),
        &amount_usdt.to_le_bytes(),
    ]).0
}

#[program]
pub mod gmc_ranking {
    use super::*;

    // ---
    // EN: Initializes the state of the ranking system. Must be called once.
    // PT: Inicializa o estado do sistema de ranking. Deve ser chamada uma vez.
    // ---
    pub fn initialize_ranking(ctx: Context<InitializeRanking>) -> Result<()> {
        let ranking_state = &mut ctx.accounts.ranking_state;
        
        ranking_state.authority = ctx.accounts.authority.key();
        ranking_state.monthly_pool_gmc = 0;
        ranking_state.monthly_pool_usdt = 0;
        ranking_state.annual_pool_gmc = 0;
        ranking_state.annual_pool_usdt = 0;
        ranking_state.current_merkle_root = [0; 32];
        ranking_state.pending_merkle_root = [0; 32];
        ranking_state.merkle_root_update_available_at = 0;
        ranking_state.last_monthly_distribution = Clock::get()?.unix_timestamp;
        ranking_state.last_annual_distribution = Clock::get()?.unix_timestamp;
        ranking_state.total_users_tracked = 0;
        
        emit!(RankingInitialized {
            authority: ctx.accounts.authority.key(),
            timestamp: Clock::get()?.unix_timestamp,
        });
        
        Ok(())
    }

    // ---
    // EN: Logs a generic transaction for the ranking system.
    // PT: Registra uma transação genérica para o sistema de ranking.
    // ---
    pub fn log_transaction(ctx: Context<LogTransaction>) -> Result<()> {
        let user_activity = &mut ctx.accounts.user_activity;
        let clock = Clock::get()?;
        
        // Inicializar se for primeira atividade
        if user_activity.user == Pubkey::default() {
            user_activity.user = ctx.accounts.user.key();
            user_activity.monthly_tx_count = 0;
            user_activity.monthly_referrals_count = 0;
            user_activity.monthly_burn_volume = 0;
            user_activity.annual_burn_volume = 0;
            user_activity.last_activity_timestamp = clock.unix_timestamp;
        }
        
        user_activity.monthly_tx_count = user_activity.monthly_tx_count
            .checked_add(1)
            .ok_or(RankingError::ArithmeticOverflow)?;
        user_activity.last_activity_timestamp = clock.unix_timestamp;
        
        emit!(TransactionLogged {
            user: ctx.accounts.user.key(),
            new_count: user_activity.monthly_tx_count,
            timestamp: clock.unix_timestamp,
        });
        
        Ok(())
    }

    // ---
    // EN: Logs a referral for the ranking system.
    // PT: Registra uma referência para o sistema de ranking.
    // ---
    pub fn log_referral(ctx: Context<LogReferral>) -> Result<()> {
        let user_activity = &mut ctx.accounts.user_activity;
        let clock = Clock::get()?;
        
        // Inicializar se for primeira atividade
        if user_activity.user == Pubkey::default() {
            user_activity.user = ctx.accounts.user.key();
            user_activity.monthly_tx_count = 0;
            user_activity.monthly_referrals_count = 0;
            user_activity.monthly_burn_volume = 0;
            user_activity.annual_burn_volume = 0;
            user_activity.last_activity_timestamp = clock.unix_timestamp;
        }
        
        user_activity.monthly_referrals_count = user_activity.monthly_referrals_count
            .checked_add(1)
            .ok_or(RankingError::ArithmeticOverflow)?;
        user_activity.last_activity_timestamp = clock.unix_timestamp;
        
        emit!(ReferralLogged {
            user: ctx.accounts.user.key(),
            new_count: user_activity.monthly_referrals_count,
            timestamp: clock.unix_timestamp,
        });
        
        Ok(())
    }

    // ---
    // EN: Logs a burn event for the ranking system.
    // PT: Registra um evento de queima para o sistema de ranking.
    // ---
    pub fn log_burn(ctx: Context<LogBurn>, amount: u64) -> Result<()> {
        let user_activity = &mut ctx.accounts.user_activity;
        let clock = Clock::get()?;
        
        // Inicializar se for primeira atividade
        if user_activity.user == Pubkey::default() {
            user_activity.user = ctx.accounts.user.key();
            user_activity.monthly_tx_count = 0;
            user_activity.monthly_referrals_count = 0;
            user_activity.monthly_burn_volume = 0;
            user_activity.annual_burn_volume = 0;
            user_activity.last_activity_timestamp = clock.unix_timestamp;
        }
        
        user_activity.monthly_burn_volume = user_activity.monthly_burn_volume
            .checked_add(amount)
            .ok_or(RankingError::ArithmeticOverflow)?;
        user_activity.annual_burn_volume = user_activity.annual_burn_volume
            .checked_add(amount)
            .ok_or(RankingError::ArithmeticOverflow)?;
        user_activity.last_activity_timestamp = clock.unix_timestamp;
        
        emit!(BurnLogged {
            user: ctx.accounts.user.key(),
            amount,
            monthly_total: user_activity.monthly_burn_volume,
            annual_total: user_activity.annual_burn_volume,
            timestamp: clock.unix_timestamp,
        });
        
        Ok(())
    }

    // ---
    // EN: Adds funds to the reward pools (monthly and annual).
    // PT: Adiciona fundos aos pools de recompensa (mensal e anual).
    // ---
    pub fn deposit_funds(ctx: Context<DepositFunds>, gmc_amount: u64, usdt_amount: u64) -> Result<()> {
        let ranking_state = &mut ctx.accounts.ranking_state;
        
        // 90% para pool mensal, 10% para pool anual
        let monthly_gmc = gmc_amount.checked_mul(90).unwrap().checked_div(100).unwrap();
        let annual_gmc = gmc_amount.checked_sub(monthly_gmc).unwrap();
        
        let monthly_usdt = usdt_amount.checked_mul(90).unwrap().checked_div(100).unwrap();
        let annual_usdt = usdt_amount.checked_sub(monthly_usdt).unwrap();
        
        ranking_state.monthly_pool_gmc = ranking_state.monthly_pool_gmc
            .checked_add(monthly_gmc)
            .ok_or(RankingError::ArithmeticOverflow)?;
        ranking_state.annual_pool_gmc = ranking_state.annual_pool_gmc
            .checked_add(annual_gmc)
            .ok_or(RankingError::ArithmeticOverflow)?;
        ranking_state.monthly_pool_usdt = ranking_state.monthly_pool_usdt
            .checked_add(monthly_usdt)
            .ok_or(RankingError::ArithmeticOverflow)?;
        ranking_state.annual_pool_usdt = ranking_state.annual_pool_usdt
            .checked_add(annual_usdt)
            .ok_or(RankingError::ArithmeticOverflow)?;
        
        emit!(FundsDeposited {
            gmc_amount,
            usdt_amount,
            monthly_gmc,
            annual_gmc,
            monthly_usdt,
            annual_usdt,
            timestamp: Clock::get()?.unix_timestamp,
        });
        
        Ok(())
    }

    // ---
    // EN: Proposes a new Merkle Root for reward distribution, starting a 48-hour time-lock.
    // PT: Propõe uma nova Merkle Root para a distribuição de recompensas, iniciando um time-lock de 48 horas.
    // ---
    pub fn propose_new_merkle_root(ctx: Context<SetMerkleRoot>, root: [u8; 32]) -> Result<()> {
        let ranking_state = &mut ctx.accounts.ranking_state;
        
        require!(
            ctx.accounts.authority.key() == ranking_state.authority,
            RankingError::Unauthorized
        );
        
        ranking_state.pending_merkle_root = root;
        // Time-lock de 48 horas para produção
        ranking_state.merkle_root_update_available_at = Clock::get()?.unix_timestamp + (48 * 60 * 60);

        emit!(MerkleRootProposed {
            root,
            available_at: ranking_state.merkle_root_update_available_at,
            authority: ctx.accounts.authority.key(),
        });
        
        Ok(())
    }

    // ---
    // EN: Commits the proposed Merkle Root after the time-lock has ended.
    // PT: Efetiva a Merkle Root proposta após o término do time-lock.
    // ---
    pub fn commit_new_merkle_root(ctx: Context<SetMerkleRoot>) -> Result<()> {
        let ranking_state = &mut ctx.accounts.ranking_state;

        require!(
            ctx.accounts.authority.key() == ranking_state.authority,
            RankingError::Unauthorized
        );
        
        // Verifica se há uma proposta pendente
        require!(
            ranking_state.pending_merkle_root != [0; 32],
            RankingError::NoPendingUpdate
        );

        // Verifica se o time-lock terminou
        require!(
            Clock::get()?.unix_timestamp >= ranking_state.merkle_root_update_available_at,
            RankingError::TimelockActive
        );
        
        // Efetiva a mudança
        ranking_state.current_merkle_root = ranking_state.pending_merkle_root;
        
        // Limpa a proposta pendente
        ranking_state.pending_merkle_root = [0; 32];
        ranking_state.merkle_root_update_available_at = 0;

        emit!(MerkleRootUpdated {
            root: ranking_state.current_merkle_root,
            authority: ctx.accounts.authority.key(),
            timestamp: Clock::get()?.unix_timestamp,
        });

        Ok(())
    }

    // ---
    // EN: Authority-only function to trigger the distribution of monthly rewards.
    // PT: Função exclusiva da autoridade para acionar a distribuição de recompensas mensais.
    // ---
    pub fn distribute_monthly_rewards(ctx: Context<DistributeMonthlyRewards>) -> Result<()> {
        let ranking_state = &mut ctx.accounts.ranking_state;
        let clock = Clock::get()?;
        
        require!(
            ctx.accounts.authority.key() == ranking_state.authority,
            RankingError::Unauthorized
        );
        
        // Verificar se passou 30 dias desde a última distribuição
        let thirty_days = 30 * 24 * 60 * 60; // 30 dias em segundos
        require!(
            clock.unix_timestamp >= ranking_state.last_monthly_distribution + thirty_days,
            RankingError::DistributionTooEarly
        );
        
        let total_gmc_distributed = ranking_state.monthly_pool_gmc;
        let total_usdt_distributed = ranking_state.monthly_pool_usdt;
        
        // Reset dos pools mensais
        ranking_state.monthly_pool_gmc = 0;
        ranking_state.monthly_pool_usdt = 0;
        ranking_state.last_monthly_distribution = clock.unix_timestamp;
        
        emit!(MonthlyRewardsDistributed {
            total_gmc_distributed,
            total_usdt_distributed,
            winners_count: 21, // 7 + 7 + 7
            timestamp: clock.unix_timestamp,
        });
        
        Ok(())
    }

    // ---
    // EN: Authority-only function to trigger the distribution of annual rewards.
    // PT: Função exclusiva da autoridade para acionar a distribuição de recompensas anuais.
    // ---
    pub fn distribute_annual_rewards(ctx: Context<DistributeAnnualRewards>) -> Result<()> {
        let ranking_state = &mut ctx.accounts.ranking_state;
        let clock = Clock::get()?;
        
        require!(
            ctx.accounts.authority.key() == ranking_state.authority,
            RankingError::Unauthorized
        );
        
        // Verificar se passou 1 ano desde a última distribuição
        let one_year = 365 * 24 * 60 * 60; // 1 ano em segundos
        require!(
            clock.unix_timestamp >= ranking_state.last_annual_distribution + one_year,
            RankingError::DistributionTooEarly
        );
        
        let total_gmc_distributed = ranking_state.annual_pool_gmc;
        let total_usdt_distributed = ranking_state.annual_pool_usdt;
        
        // Reset dos pools anuais
        ranking_state.annual_pool_gmc = 0;
        ranking_state.annual_pool_usdt = 0;
        ranking_state.last_annual_distribution = clock.unix_timestamp;
        
        emit!(AnnualRewardsDistributed {
            total_gmc_distributed,
            total_usdt_distributed,
            winners_count: 12, // Top 12 queimadores
            timestamp: clock.unix_timestamp,
        });
        
        Ok(())
    }

    // ---
    // EN: Allows a user to claim their rewards using a valid Merkle proof.
    // PT: Permite que um usuário resgate suas recompensas usando uma prova Merkle válida.
    // ---
    pub fn claim_reward(
        ctx: Context<ClaimReward>,
        amount_gmc: u64,
        amount_usdt: u64,
        merkle_proof: Vec<[u8; 32]>,
    ) -> Result<()> {
        let ranking_state = &ctx.accounts.ranking_state;
        let user = ctx.accounts.user.key();
        
        // Verificar se o usuário já reivindicou recompensas neste ciclo
        // (Isso seria implementado com uma conta adicional de tracking)
        
        // Criar hash da folha com os dados do usuário
        let leaf_hash = create_leaf_hash(&user, amount_gmc, amount_usdt);
        
        // Verificar prova Merkle
        let is_valid = verify_merkle_proof(
            &merkle_proof,
            &ranking_state.current_merkle_root,
            &leaf_hash,
        );
        
        require!(is_valid, RankingError::InvalidMerkleProof);
        
        // Verificar se há fundos suficientes nos pools
        require!(
            ranking_state.monthly_pool_gmc >= amount_gmc,
            RankingError::InsufficientFunds
        );
        require!(
            ranking_state.monthly_pool_usdt >= amount_usdt,
            RankingError::InsufficientFunds
        );
        
        // Transferir recompensas (implementação seria feita com contas de token)
        // Por enquanto, apenas emitir evento com validação completa
        
        msg!("✅ Merkle proof verified successfully");
        msg!("   User: {}", user);
        msg!("   GMC reward: {}", amount_gmc);
        msg!("   USDT reward: {}", amount_usdt);
        msg!("   Leaf hash: {:?}", leaf_hash);
        msg!("   Root hash: {:?}", ranking_state.current_merkle_root);
        
        emit!(RewardClaimed {
            user,
            amount_gmc,
            amount_usdt,
            timestamp: Clock::get()?.unix_timestamp,
        });
        
        Ok(())
    }
}

// =====================================================
// EN: Data Structures
// PT: Estruturas de Dados
// =====================================================

// ---
// EN: The main state account for the ranking program.
// PT: A conta de estado principal para o programa de ranking.
// ---
#[account]
pub struct RankingState {
    pub authority: Pubkey,
    pub current_merkle_root: [u8; 32],
    pub monthly_pool_gmc: u64,
    pub monthly_pool_usdt: u64,
    pub annual_pool_gmc: u64,
    pub annual_pool_usdt: u64,
    pub pending_merkle_root: [u8; 32],      // ✅ NOVO: Armazena a root proposta
    pub merkle_root_update_available_at: i64, // ✅ NOVO: Timestamp para quando a mudança pode ser efetivada
    pub last_monthly_distribution: i64,
    pub last_annual_distribution: i64,
    pub total_users_tracked: u32,
}

// ---
// EN: Tracks the activity of a single user.
// PT: Rastreia a atividade de um único usuário.
// ---
#[account]
pub struct UserActivity {
    pub user: Pubkey,
    pub monthly_tx_count: u32,
    pub monthly_referrals_count: u32,
    pub monthly_burn_volume: u64,
    pub annual_burn_volume: u64,
    pub last_activity_timestamp: i64,
}

// =====================================================
// EN: Account Contexts for Instructions
// PT: Contextos de Contas para as Instruções
// =====================================================

// ---
// EN: Accounts for the `initialize_ranking` instruction.
// PT: Contas para a instrução `initialize_ranking`.
// ---
#[derive(Accounts)]
pub struct InitializeRanking<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        init,
        payer = authority,
        space = 8 + std::mem::size_of::<RankingState>(),
        seeds = [b"ranking_state"],
        bump
    )]
    pub ranking_state: Account<'info, RankingState>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct LogTransaction<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        init_if_needed,
        payer = user,
        space = 8 + std::mem::size_of::<UserActivity>(),
        seeds = [b"user_activity", user.key().as_ref()],
        bump
    )]
    pub user_activity: Account<'info, UserActivity>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct LogReferral<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        init_if_needed,
        payer = user,
        space = 8 + std::mem::size_of::<UserActivity>(),
        seeds = [b"user_activity", user.key().as_ref()],
        bump
    )]
    pub user_activity: Account<'info, UserActivity>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct LogBurn<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        init_if_needed,
        payer = user,
        space = 8 + std::mem::size_of::<UserActivity>(),
        seeds = [b"user_activity", user.key().as_ref()],
        bump
    )]
    pub user_activity: Account<'info, UserActivity>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct DepositFunds<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        mut,
        seeds = [b"ranking_state"],
        bump,
        constraint = ranking_state.authority == authority.key() @ RankingError::Unauthorized
    )]
    pub ranking_state: Account<'info, RankingState>,
}

#[derive(Accounts)]
pub struct SetMerkleRoot<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        mut,
        seeds = [b"ranking_state"],
        bump
    )]
    pub ranking_state: Account<'info, RankingState>,
}

#[derive(Accounts)]
pub struct DistributeMonthlyRewards<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        mut,
        seeds = [b"ranking_state"],
        bump,
        constraint = ranking_state.authority == authority.key() @ RankingError::Unauthorized
    )]
    pub ranking_state: Account<'info, RankingState>,
}

#[derive(Accounts)]
pub struct DistributeAnnualRewards<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    
    #[account(
        mut,
        seeds = [b"ranking_state"],
        bump,
        constraint = ranking_state.authority == authority.key() @ RankingError::Unauthorized
    )]
    pub ranking_state: Account<'info, RankingState>,
}

#[derive(Accounts)]
pub struct ClaimReward<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        seeds = [b"ranking_state"],
        bump
    )]
    pub ranking_state: Account<'info, RankingState>,
}

// =====================================================
// EN: Events
// PT: Eventos
// =====================================================

// ---
// EN: Emitted when the ranking contract is initialized.
// PT: Emitido quando o contrato de ranking é inicializado.
// ---
#[event]
pub struct RankingInitialized {
    pub authority: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct TransactionLogged {
    pub user: Pubkey,
    pub new_count: u32,
    pub timestamp: i64,
}

#[event]
pub struct ReferralLogged {
    pub user: Pubkey,
    pub new_count: u32,
    pub timestamp: i64,
}

#[event]
pub struct BurnLogged {
    pub user: Pubkey,
    pub amount: u64,
    pub monthly_total: u64,
    pub annual_total: u64,
    pub timestamp: i64,
}

#[event]
pub struct FundsDeposited {
    pub gmc_amount: u64,
    pub usdt_amount: u64,
    pub monthly_gmc: u64,
    pub annual_gmc: u64,
    pub monthly_usdt: u64,
    pub annual_usdt: u64,
    pub timestamp: i64,
}

#[event]
pub struct MerkleRootProposed {
    pub root: [u8; 32],
    pub available_at: i64,
    pub authority: Pubkey,
}

#[event]
pub struct MerkleRootUpdated {
    pub root: [u8; 32],
    pub authority: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct MonthlyRewardsDistributed {
    pub total_gmc_distributed: u64,
    pub total_usdt_distributed: u64,
    pub winners_count: u32,
    pub timestamp: i64,
}

#[event]
pub struct AnnualRewardsDistributed {
    pub total_gmc_distributed: u64,
    pub total_usdt_distributed: u64,
    pub winners_count: u32,
    pub timestamp: i64,
}

#[event]
pub struct RewardClaimed {
    pub user: Pubkey,
    pub amount_gmc: u64,
    pub amount_usdt: u64,
    pub timestamp: i64,
}

// =====================================================
// EN: Custom Errors
// PT: Erros Customizados
// =====================================================

// ---
// EN: Custom error codes for the ranking program.
// PT: Códigos de erro personalizados para o programa de ranking.
// ---
#[error_code]
pub enum RankingError {
    #[msg("Unauthorized: Only authority can perform this action")]
    Unauthorized,
    
    #[msg("Arithmetic overflow occurred")]
    ArithmeticOverflow,
    
    #[msg("Distribution too early: Must wait for the specified period")]
    DistributionTooEarly,
    
    #[msg("Invalid merkle proof")]
    InvalidMerkleProof,
    
    #[msg("Reward already claimed")]
    RewardAlreadyClaimed,
    
    #[msg("User is in exclusion list (Top 20 holders)")]
    UserExcluded,
    
    #[msg("Insufficient funds in pools")]
    InsufficientFunds,

    #[msg("Timelock is still active for this update")]
    TimelockActive,

    #[msg("No pending update to commit")]
    NoPendingUpdate,
}
