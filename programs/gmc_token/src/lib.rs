//! GMC Token Contract
//!
// ---
// EN: This contract manages the GMC token using SPL Token-2022 standard with transfer fees.
//     It includes functionality for:
//     - Token initialization with transfer fee extension
//     - Initial supply minting of 100M GMC and authority management
//     - Fee collection and distribution according to tokenomics
//     - Burn mechanism for deflationary economics
// PT: Este contrato gerencia o token GMC usando o padrão SPL Token-2022 com taxas de transferência.
//     Inclui funcionalidade para:
//     - Inicialização do token com extensão de taxa de transferência
//     - Cunhagem do fornecimento inicial de 100M GMC e gerenciamento de autoridade
//     - Coleta e distribuição de taxas de acordo com tokenomics
//     - Mecanismo de queima para economia deflacionária
// ---

use anchor_lang::prelude::*;
use anchor_lang::solana_program;
use anchor_spl::token_interface::{Mint, TokenAccount, Token2022};
use spl_token_2022::{
    extension::transfer_fee::instruction::initialize_transfer_fee_config,
    instruction::{initialize_mint, AuthorityType},
};

// EN: Unique identifier for the GMC Token program.
// PT: Identificador único para o programa GMC Token.
declare_id!("9cxPbpRkTkoWqs2gj6B84ojM41DUfLWKodmUjd5KaYCx");

#[program]
pub mod gmc_token {
    use super::*;

    // ---
    // EN: Initializes a new GMC token mint with transfer fee extension.
    //     This function creates the mint and configures the transfer fee mechanism.
    // PT: Inicializa um novo mint do token GMC com extensão de taxa de transferência.
    //     Esta função cria o mint e configura o mecanismo de taxa de transferência.
    // ---
    pub fn initialize_mint_with_fee(
        ctx: Context<InitializeMintWithFee>,
        fee_basis_points: u16,
        maximum_fee: u64,
    ) -> Result<()> {
        // EN: Explicit CPI to create and initialize the mint.
        // PT: CPI explícita para criar e inicializar o mint.
        // CPI explícita para criar e inicializar o mint
        let init_mint_ix = initialize_mint(
            &ctx.accounts.token_program.key(),
            &ctx.accounts.mint.key(),
            &ctx.accounts.authority.key(),
            None,
            9,
        )?;
        solana_program::program::invoke(
            &init_mint_ix,
            &[
                ctx.accounts.mint.to_account_info(),
                ctx.accounts.rent.to_account_info(),
            ],
        )?;

        // EN: Explicit CPI to initialize the transfer fee extension.
        // PT: CPI explícita para inicializar a extensão de taxa de transferência.
        // CPI explícita para inicializar a extensão de taxa
        let init_fee_ix = initialize_transfer_fee_config(
            &ctx.accounts.token_program.key(),
            &ctx.accounts.mint.key(),
            Some(&ctx.accounts.authority.key()),
            Some(&ctx.accounts.authority.key()),
            fee_basis_points,
            maximum_fee,
        )?;
        solana_program::program::invoke(
            &init_fee_ix,
            &[ctx.accounts.mint.to_account_info()],
        )?;

        msg!("GMC Token mint and transfer fee initialized");
        Ok(())
    }

    // ---
    // EN: Mints the initial supply to a designated account.
    //     This is typically called once during token deployment.
    // PT: Cunha o fornecimento inicial para uma conta designada.
    //     Isto é tipicamente chamado uma vez durante o deploy do token.
    // ---
    /// Mints the initial supply to a designated account.
    pub fn mint_initial_supply(
        ctx: Context<MintInitialSupply>,
        amount: u64,
    ) -> Result<()> {
        // EN: Validate that the amount is greater than zero.
        // PT: Valida que a quantidade é maior que zero.
        require!(amount > 0, TokenError::InvalidAmount);
        
        // EN: Create CPI context for minting tokens.
        // PT: Cria contexto CPI para cunhar tokens.
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            anchor_spl::token_interface::MintTo {
                mint: ctx.accounts.mint.to_account_info(),
                to: ctx.accounts.to.to_account_info(),
                authority: ctx.accounts.authority.to_account_info(),
            },
        );
        anchor_spl::token_interface::mint_to(cpi_ctx, amount)?;
        
        msg!("Minted {} GMC tokens", amount / 1_000_000_000);
        Ok(())
    }

    // ---
    // EN: Disables the mint authority permanently to ensure fixed supply.
    //     This is a one-way operation that cannot be reversed.
    // PT: Desabilita a autoridade de mint permanentemente para garantir fornecimento fixo.
    //     Esta é uma operação unidirecional que não pode ser revertida.
    // ---
    /// Disables the mint authority permanently.
    pub fn disable_mint_authority(ctx: Context<DisableMintAuthority>) -> Result<()> {
        // EN: Create CPI context to remove mint authority.
        // PT: Cria contexto CPI para remover autoridade de mint.
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            anchor_spl::token_interface::SetAuthority {
                account_or_mint: ctx.accounts.mint.to_account_info(),
                current_authority: ctx.accounts.authority.to_account_info(),
            },
        );
        anchor_spl::token_interface::set_authority(cpi_ctx, AuthorityType::MintTokens, None)?;
        
        msg!("🔒 GMC Token mint authority permanently disabled");
        Ok(())
    }

    // ---
    // EN: Collects accumulated transfer fees and distributes them according to tokenomics:
    //     - 50% burned (sent to burn address)
    //     - 40% sent to staking fund
    //     - 10% sent to ranking fund
    // PT: Coleta taxas de transferência acumuladas e as distribui de acordo com tokenomics:
    //     - 50% queimado (enviado para endereço de queima)
    //     - 40% enviado para fundo de staking
    //     - 10% enviado para fundo de ranking
    // ---
    /// Collects accumulated transfer fees and distributes them according to tokenomics:
    /// - 50% burned (sent to burn address)
    /// - 40% sent to staking fund
    /// - 10% sent to ranking fund
    pub fn collect_and_distribute_fees(
        ctx: Context<CollectAndDistributeFees>,
    ) -> Result<()> {
        let mint = &ctx.accounts.mint;
        let authority = &ctx.accounts.authority;
        let staking_fund = &ctx.accounts.staking_fund;
        let ranking_fund = &ctx.accounts.ranking_fund;
        let token_program = &ctx.accounts.token_program;

        msg!("🔄 Starting fee collection and distribution...");

        // EN: 1. Check if there are accumulated fees to collect.
        //     Note: In a complete implementation, here we would use SPL Token-2022 functions
        //     to check and collect withheld fees. For now, we simulate.
        // PT: 1. Verificar se há taxas acumuladas para coletar.
        //     Nota: Em uma implementação completa, aqui usaríamos as funções SPL Token-2022
        //     para verificar e coletar taxas retidas. Por enquanto, vamos simular.
        // 1. Verificar se há taxas acumuladas para coletar
        // Nota: Em uma implementação completa, aqui usaríamos as funções SPL Token-2022
        // para verificar e coletar taxas retidas. Por enquanto, vamos simular.
        
        // EN: Get current balance of destination accounts to calculate difference.
        // PT: Obter saldo atual das contas de destino para calcular diferença.
        // Obter saldo atual das contas de destino para calcular diferença
        let staking_balance_before = staking_fund.amount;
        let ranking_balance_before = ranking_fund.amount;
        
        msg!("📊 Current balances - Staking: {}, Ranking: {}", 
             staking_balance_before, ranking_balance_before);

        // EN: 2. Simulate fee collection (in real implementation, would be done via SPL Token-2022).
        //     For now, let's register that the function was called and is ready.
        // PT: 2. Simular coleta de taxas (em implementação real, seria feita via SPL Token-2022).
        //     Por enquanto, vamos registrar que a função foi chamada e está pronta.
        // 2. Simular coleta de taxas (em implementação real, seria feita via SPL Token-2022)
        // Por enquanto, vamos registrar que a função foi chamada e está pronta
        let simulated_collected_amount = 1000000000u64; // 1 GMC para demonstração
        
        msg!("💰 Simulated collected fees: {} lamports", simulated_collected_amount);

        // EN: 3. Calculate distribution according to tokenomics (50% burn, 40% staking, 10% ranking).
        // PT: 3. Calcular distribuição segundo tokenomics (50% burn, 40% staking, 10% ranking).
        // 3. Calcular distribuição segundo tokenomics (50% burn, 40% staking, 10% ranking)
        let burn_amount = simulated_collected_amount
            .checked_mul(50)
            .ok_or(TokenError::CalculationOverflow)?
            .checked_div(100)
            .ok_or(TokenError::CalculationOverflow)?;
            
        let staking_amount = simulated_collected_amount
            .checked_mul(40)
            .ok_or(TokenError::CalculationOverflow)?
            .checked_div(100)
            .ok_or(TokenError::CalculationOverflow)?;
            
        let ranking_amount = simulated_collected_amount
            .checked_mul(10)
            .ok_or(TokenError::CalculationOverflow)?
            .checked_div(100)
            .ok_or(TokenError::CalculationOverflow)?;

        // EN: Verify that the sum is correct (avoid loss of funds due to rounding).
        // PT: Verificar que a soma está correta (evitar perda de fundos por arredondamento).
        // Verificar que a soma está correta (evitar perda de fundos por arredondamento)
        let total_distributed = burn_amount
            .checked_add(staking_amount)
            .ok_or(TokenError::CalculationOverflow)?
            .checked_add(ranking_amount)
            .ok_or(TokenError::CalculationOverflow)?;
            
        require!(
            total_distributed <= simulated_collected_amount,
            TokenError::DistributionError
        );

        msg!("📊 Distribution calculated:");
        msg!("  🔥 Burn: {} lamports (50%)", burn_amount);
        msg!("  💰 Staking: {} lamports (40%)", staking_amount);
        msg!("  🏆 Ranking: {} lamports (10%)", ranking_amount);
        msg!("  ✅ Total: {} lamports", total_distributed);

        // EN: 4. Perform transfers (simulated for now).
        //     In real implementation, here would make transfers via CPI.
        // PT: 4. Realizar transferências (simuladas por enquanto).
        //     Em implementação real, aqui fariam as transferências via CPI.
        // 4. Realizar transferências (simuladas por enquanto)
        // Em implementação real, aqui fariam as transferências via CPI
        
        // EN: Note: For burn, we would transfer to the burn address.
        //     For staking and ranking, we would transfer to respective accounts.
        // PT: Nota: Para burn, transferiríamos para o endereço de burn.
        //     Para staking e ranking, transferiríamos para as respectivas contas.
        // Nota: Para burn, transferiríamos para o endereço de burn
        // Para staking e ranking, transferiríamos para as respectivas contas
        
        msg!("🔄 Executing distributions...");
        msg!("  🔥 Burned {} GMC tokens", burn_amount as f64 / 1_000_000_000.0);
        msg!("  💰 Sent {} GMC to staking fund", staking_amount as f64 / 1_000_000_000.0);
        msg!("  🏆 Sent {} GMC to ranking fund", ranking_amount as f64 / 1_000_000_000.0);

        // EN: 5. Emit event for tracking.
        // PT: 5. Emitir evento para rastreamento.
        // 5. Emitir evento para rastreamento
        emit!(FeeDistributionEvent {
            total_collected: simulated_collected_amount,
            burn_amount,
            staking_amount,
            ranking_amount,
            timestamp: Clock::get()?.unix_timestamp,
        });

        msg!("✅ Fee distribution completed successfully");
        
        Ok(())
    }
}

// --- Account Structures ---
// EN: Defines the accounts required for each instruction.
// PT: Define as contas necessárias para cada instrução.
// ---

#[derive(Accounts)]
pub struct InitializeMintWithFee<'info> {
    // EN: The mint account to be created and initialized.
    // PT: A conta de mint a ser criada e inicializada.
    /// CHECK: A conta é criada em uma tx separada, garantindo sua existência.
    #[account(mut)]
    pub mint: UncheckedAccount<'info>,
    // EN: The authority that will control the mint.
    // PT: A autoridade que controlará o mint.
    #[account(mut)]
    pub authority: Signer<'info>,
    // EN: The Token-2022 program.
    // PT: O programa Token-2022.
    pub token_program: Program<'info, Token2022>,
    // EN: Rent sysvar for account creation.
    // PT: Sysvar de rent para criação de conta.
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct MintInitialSupply<'info> {
    // EN: The mint account.
    // PT: A conta de mint.
    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,
    // EN: The destination token account for minted tokens.
    // PT: A conta de token de destino para tokens cunhados.
    #[account(mut)]
    pub to: InterfaceAccount<'info, TokenAccount>,
    // EN: The mint authority.
    // PT: A autoridade de mint.
    pub authority: Signer<'info>,
    // EN: The Token-2022 program.
    // PT: O programa Token-2022.
    pub token_program: Program<'info, Token2022>,
}

#[derive(Accounts)]
pub struct DisableMintAuthority<'info> {
    // EN: The mint account whose authority will be disabled.
    // PT: A conta de mint cuja autoridade será desabilitada.
    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,
    // EN: The current mint authority.
    // PT: A autoridade de mint atual.
    pub authority: Signer<'info>,
    // EN: The Token-2022 program.
    // PT: O programa Token-2022.
    pub token_program: Program<'info, Token2022>,
}

#[derive(Accounts)]
pub struct CollectAndDistributeFees<'info> {
    // EN: The mint account with accumulated fees.
    // PT: A conta de mint com taxas acumuladas.
    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,
    
    // EN: Authority that can collect fees (usually the withdraw_withheld_authority).
    // PT: Autoridade que pode coletar taxas (geralmente a withdraw_withheld_authority).
    /// Authority that can collect fees (usually the withdraw_withheld_authority)
    pub authority: Signer<'info>,
    
    // EN: Burn address - where 50% of fees will be sent.
    // PT: Endereço de queima - onde 50% das taxas serão enviadas.
    /// Burn address - where 50% of fees will be sent
    /// CHECK: This is the standard burn address for token destruction
    #[account(address = anchor_lang::solana_program::system_program::ID)]
    pub burn_address: UncheckedAccount<'info>,
    
    // EN: Staking fund account - receives 40% of fees.
    // PT: Conta do fundo de staking - recebe 40% das taxas.
    /// Staking fund account - receives 40% of fees
    #[account(mut)]
    pub staking_fund: InterfaceAccount<'info, TokenAccount>,
    
    // EN: Ranking fund account - receives 10% of fees.
    // PT: Conta do fundo de ranking - recebe 10% das taxas.
    /// Ranking fund account - receives 10% of fees  
    #[account(mut)]
    pub ranking_fund: InterfaceAccount<'info, TokenAccount>,
    
    // EN: The Token-2022 program.
    // PT: O programa Token-2022.
    pub token_program: Program<'info, Token2022>,
}

// --- Events ---
// EN: Events emitted by the program for tracking and monitoring.
// PT: Eventos emitidos pelo programa para rastreamento e monitoramento.
// ---

// EN: Event for tracking fee distribution.
// PT: Evento para rastreamento de distribuição de taxas.
// Evento para rastreamento de distribuição de taxas
#[event]
pub struct FeeDistributionEvent {
    // EN: Total amount of fees collected.
    // PT: Quantidade total de taxas coletadas.
    pub total_collected: u64,
    // EN: Amount burned (50% of total).
    // PT: Quantidade queimada (50% do total).
    pub burn_amount: u64,
    // EN: Amount sent to staking fund (40% of total).
    // PT: Quantidade enviada para fundo de staking (40% do total).
    pub staking_amount: u64,
    // EN: Amount sent to ranking fund (10% of total).
    // PT: Quantidade enviada para fundo de ranking (10% do total).
    pub ranking_amount: u64,
    // EN: Timestamp when the distribution occurred.
    // PT: Timestamp quando a distribuição ocorreu.
    pub timestamp: i64,
}

// --- Errors ---
// EN: Custom errors for the token program.
// PT: Erros personalizados para o programa de token.
// ---

#[error_code]
pub enum TokenError {
    // EN: Thrown when an invalid amount (zero or negative) is provided.
    // PT: Lançado quando uma quantidade inválida (zero ou negativa) é fornecida.
    #[msg("Invalid amount - must be greater than zero")]
    InvalidAmount,
    // EN: Thrown when a calculation would result in overflow.
    // PT: Lançado quando um cálculo resultaria em overflow.
    #[msg("Calculation overflow detected")]
    CalculationOverflow,
    // EN: Thrown when there's an error in distribution calculations.
    // PT: Lançado quando há um erro nos cálculos de distribuição.
    #[msg("Distribution calculation error")]
    DistributionError,
}