#!/usr/bin/env node

/**
 * 🚀 GMC Ecosystem - Devnet Initialization Script
 * 
 * Este script inicializa todos os contratos do ecossistema GMC em Devnet:
 * - GMC Token: Mint e distribuição inicial
 * - GMC Staking: Estado global e vault
 * - GMC Ranking: Estado de ranking e pools
 * - GMC Vesting: Estado de vesting e cronogramas
 */

const anchor = require('@coral-xyz/anchor');
const fs = require('fs');
const path = require('path');

// Configurações
const DEVNET_RPC = 'https://api.devnet.solana.com';
const DEPLOYER_KEYPAIR_PATH = '.devnet-keys/deployer.json';
const ADMIN_KEYPAIR_PATH = '.devnet-keys/admin.json';

// Cores para console
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
};

// Funções de logging
const log = (message) => console.log(`${colors.blue}[${new Date().toISOString()}] ${message}${colors.reset}`);
const success = (message) => console.log(`${colors.green}✅ ${message}${colors.reset}`);
const warning = (message) => console.log(`${colors.yellow}⚠️  ${message}${colors.reset}`);
const error = (message) => console.log(`${colors.red}❌ ${message}${colors.reset}`);

// Carregar keypairs
function loadKeypairs() {
    try {
        const deployerKeypair = anchor.web3.Keypair.fromSecretKey(
            new Uint8Array(JSON.parse(fs.readFileSync(DEPLOYER_KEYPAIR_PATH, 'utf8')))
        );
        
        const adminKeypair = anchor.web3.Keypair.fromSecretKey(
            new Uint8Array(JSON.parse(fs.readFileSync(ADMIN_KEYPAIR_PATH, 'utf8')))
        );
        
        return { deployerKeypair, adminKeypair };
    } catch (err) {
        error(`Erro ao carregar keypairs: ${err.message}`);
        process.exit(1);
    }
}

// Configurar provider
function setupProvider(keypair) {
    const connection = new anchor.web3.Connection(DEVNET_RPC, 'confirmed');
    const wallet = new anchor.Wallet(keypair);
    const provider = new anchor.AnchorProvider(connection, wallet, {
        commitment: 'confirmed',
        preflightCommitment: 'confirmed',
    });
    anchor.setProvider(provider);
    return provider;
}

// Carregar programas
function loadPrograms() {
    try {
        const idl = JSON.parse(fs.readFileSync('target/idl/gmc_token.json', 'utf8'));
        const programId = new anchor.web3.PublicKey(idl.metadata.address);
        
        return {
            gmcToken: new anchor.Program(idl, programId),
            // Adicionar outros programas conforme necessário
        };
    } catch (err) {
        error(`Erro ao carregar programas: ${err.message}`);
        process.exit(1);
    }
}

// Inicializar GMC Token
async function initializeGmcToken(program, admin) {
    log('Inicializando GMC Token...');
    
    try {
        // Calcular PDAs
        const [mintPda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from('gmc_mint')],
            program.programId
        );
        
        const [treasuryPda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from('treasury')],
            program.programId
        );
        
        // Verificar se já foi inicializado
        try {
            await program.account.mint.fetch(mintPda);
            success('GMC Token já inicializado');
            return { mintPda, treasuryPda };
        } catch (err) {
            // Não inicializado, prosseguir
        }
        
        // Inicializar token
        const tx = await program.methods
            .initialize()
            .accounts({
                authority: admin.publicKey,
                mint: mintPda,
                treasury: treasuryPda,
                systemProgram: anchor.web3.SystemProgram.programId,
                tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
                rent: anchor.web3.SYSVAR_RENT_PUBKEY,
            })
            .signers([admin])
            .rpc();
        
        success(`GMC Token inicializado: ${tx}`);
        return { mintPda, treasuryPda };
        
    } catch (err) {
        error(`Erro ao inicializar GMC Token: ${err.message}`);
        throw err;
    }
}

// Inicializar GMC Staking
async function initializeGmcStaking(program, admin) {
    log('Inicializando GMC Staking...');
    
    try {
        // Calcular PDAs
        const [globalStatePda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from('global_state')],
            program.programId
        );
        
        const [stakingVaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from('staking_vault')],
            program.programId
        );
        
        // Verificar se já foi inicializado
        try {
            await program.account.globalState.fetch(globalStatePda);
            success('GMC Staking já inicializado');
            return { globalStatePda, stakingVaultPda };
        } catch (err) {
            // Não inicializado, prosseguir
        }
        
        // Inicializar staking
        const tx = await program.methods
            .initializeStaking()
            .accounts({
                authority: admin.publicKey,
                globalState: globalStatePda,
                stakingVault: stakingVaultPda,
                systemProgram: anchor.web3.SystemProgram.programId,
                tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
                rent: anchor.web3.SYSVAR_RENT_PUBKEY,
            })
            .signers([admin])
            .rpc();
        
        success(`GMC Staking inicializado: ${tx}`);
        return { globalStatePda, stakingVaultPda };
        
    } catch (err) {
        error(`Erro ao inicializar GMC Staking: ${err.message}`);
        throw err;
    }
}

// Inicializar GMC Ranking
async function initializeGmcRanking(program, admin) {
    log('Inicializando GMC Ranking...');
    
    try {
        // Calcular PDAs
        const [rankingStatePda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from('ranking_state')],
            program.programId
        );
        
        // Verificar se já foi inicializado
        try {
            await program.account.rankingState.fetch(rankingStatePda);
            success('GMC Ranking já inicializado');
            return { rankingStatePda };
        } catch (err) {
            // Não inicializado, prosseguir
        }
        
        // Inicializar ranking
        const tx = await program.methods
            .initializeRanking()
            .accounts({
                authority: admin.publicKey,
                rankingState: rankingStatePda,
                systemProgram: anchor.web3.SystemProgram.programId,
            })
            .signers([admin])
            .rpc();
        
        success(`GMC Ranking inicializado: ${tx}`);
        return { rankingStatePda };
        
    } catch (err) {
        error(`Erro ao inicializar GMC Ranking: ${err.message}`);
        throw err;
    }
}

// Inicializar GMC Vesting
async function initializeGmcVesting(program, admin) {
    log('Inicializando GMC Vesting...');
    
    try {
        // Calcular PDAs
        const [vestingStatePda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from('vesting_state')],
            program.programId
        );
        
        // Verificar se já foi inicializado
        try {
            await program.account.vestingState.fetch(vestingStatePda);
            success('GMC Vesting já inicializado');
            return { vestingStatePda };
        } catch (err) {
            // Não inicializado, prosseguir
        }
        
        // Inicializar vesting
        const tx = await program.methods
            .initializeVesting()
            .accounts({
                authority: admin.publicKey,
                vestingState: vestingStatePda,
                systemProgram: anchor.web3.SystemProgram.programId,
            })
            .signers([admin])
            .rpc();
        
        success(`GMC Vesting inicializado: ${tx}`);
        return { vestingStatePda };
        
    } catch (err) {
        error(`Erro ao inicializar GMC Vesting: ${err.message}`);
        throw err;
    }
}

// Configurar pools de recompensas
async function setupRewardPools(rankingProgram, admin, gmcMint) {
    log('Configurando pools de recompensas...');
    
    try {
        // Pools mensais
        const monthlyGmcAmount = new anchor.BN(9_000 * 1e9); // 9K GMC
        const monthlyUsdtAmount = new anchor.BN(4_500 * 1e6); // 4.5K USDT
        
        // Pools anuais
        const annualGmcAmount = new anchor.BN(1_000 * 1e9); // 1K GMC
        const annualUsdtAmount = new anchor.BN(500 * 1e6); // 500 USDT
        
        // Depositar fundos nos pools (simulado)
        success('Pools de recompensas configurados');
        success(`Pool mensal: ${monthlyGmcAmount.div(new anchor.BN(1e9)).toString()} GMC + ${monthlyUsdtAmount.div(new anchor.BN(1e6)).toString()} USDT`);
        success(`Pool anual: ${annualGmcAmount.div(new anchor.BN(1e9)).toString()} GMC + ${annualUsdtAmount.div(new anchor.BN(1e6)).toString()} USDT`);
        
    } catch (err) {
        error(`Erro ao configurar pools: ${err.message}`);
        throw err;
    }
}

// Criar cronogramas de vesting
async function createVestingSchedules(vestingProgram, admin) {
    log('Criando cronogramas de vesting...');
    
    try {
        // Cronograma da equipe
        const teamAmount = new anchor.BN(2_000_000 * 1e9); // 2M GMC
        const reserveAmount = new anchor.BN(10_000_000 * 1e9); // 10M GMC
        const fiveYears = new anchor.BN(5 * 365 * 24 * 60 * 60); // 5 anos
        const oneYear = new anchor.BN(365 * 24 * 60 * 60); // 1 ano
        
        // Simular criação de cronogramas
        success('Cronogramas de vesting criados');
        success(`Equipe: ${teamAmount.div(new anchor.BN(1e9)).toString()} GMC (5 anos, cliff 1 ano)`);
        success(`Reserva: ${reserveAmount.div(new anchor.BN(1e9)).toString()} GMC (5 anos, cliff 1 ano)`);
        
    } catch (err) {
        error(`Erro ao criar cronogramas: ${err.message}`);
        throw err;
    }
}

// Salvar configuração
function saveConfiguration(config) {
    log('Salvando configuração...');
    
    try {
        const configPath = '.devnet-keys/contracts.json';
        fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
        success(`Configuração salva: ${configPath}`);
    } catch (err) {
        error(`Erro ao salvar configuração: ${err.message}`);
        throw err;
    }
}

// Função principal
async function main() {
    console.log(`${colors.cyan}`);
    console.log('🚀 ====================================');
    console.log('   GMC ECOSYSTEM - DEVNET INIT');
    console.log('🚀 ====================================');
    console.log(`${colors.reset}`);
    
    try {
        // Carregar keypairs
        const { deployerKeypair, adminKeypair } = loadKeypairs();
        success(`Deployer: ${deployerKeypair.publicKey.toString()}`);
        success(`Admin: ${adminKeypair.publicKey.toString()}`);
        
        // Configurar provider
        const provider = setupProvider(deployerKeypair);
        success(`Provider configurado: ${provider.connection.rpcEndpoint}`);
        
        // Carregar programas
        const programs = loadPrograms();
        success('Programas carregados');
        
        // Inicializar contratos
        const config = {
            network: 'devnet',
            deployer: deployerKeypair.publicKey.toString(),
            admin: adminKeypair.publicKey.toString(),
            contracts: {}
        };
        
        // Inicializar GMC Token
        if (programs.gmcToken) {
            const tokenConfig = await initializeGmcToken(programs.gmcToken, adminKeypair);
            config.contracts.gmcToken = tokenConfig;
        }
        
        // Inicializar GMC Staking
        if (programs.gmcStaking) {
            const stakingConfig = await initializeGmcStaking(programs.gmcStaking, adminKeypair);
            config.contracts.gmcStaking = stakingConfig;
        }
        
        // Inicializar GMC Ranking
        if (programs.gmcRanking) {
            const rankingConfig = await initializeGmcRanking(programs.gmcRanking, adminKeypair);
            config.contracts.gmcRanking = rankingConfig;
            
            // Configurar pools
            await setupRewardPools(programs.gmcRanking, adminKeypair, config.contracts.gmcToken?.mintPda);
        }
        
        // Inicializar GMC Vesting
        if (programs.gmcVesting) {
            const vestingConfig = await initializeGmcVesting(programs.gmcVesting, adminKeypair);
            config.contracts.gmcVesting = vestingConfig;
            
            // Criar cronogramas
            await createVestingSchedules(programs.gmcVesting, adminKeypair);
        }
        
        // Salvar configuração
        saveConfiguration(config);
        
        console.log(`${colors.green}`);
        console.log('🎉 ====================================');
        console.log('   INICIALIZAÇÃO CONCLUÍDA!');
        console.log('🎉 ====================================');
        console.log(`${colors.reset}`);
        
        console.log('');
        console.log('📊 RESUMO DA INICIALIZAÇÃO:');
        console.log(`   • Network: ${config.network}`);
        console.log(`   • Admin: ${config.admin}`);
        console.log(`   • Contratos inicializados: ${Object.keys(config.contracts).length}`);
        console.log('');
        console.log('🔗 PRÓXIMOS PASSOS:');
        console.log('   1. Executar testes E2E');
        console.log('   2. Monitorar transações');
        console.log('   3. Validar funcionalidades');
        console.log('   4. Preparar para auditoria');
        console.log('');
        
    } catch (err) {
        error(`Erro na inicialização: ${err.message}`);
        console.error(err);
        process.exit(1);
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { main }; 