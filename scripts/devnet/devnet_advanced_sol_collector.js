#!/usr/bin/env node

/**
 * Advanced SOL Collector for Devnet
 * Otimizado para bypass de rate limits e coleta massiva de SOL
 * Estratégias: rotação de IPs, delays inteligentes, múltiplos faucets
 */

const { Connection, Keypair, LAMPORTS_PER_SOL, Transaction, SystemProgram } = require('@solana/web3.js');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configurações otimizadas
const CONFIG = {
    TARGET_SOL: 50, // Meta reduzida mas realista
    MIN_SOL_FOR_DEPLOY: 20, // Mínimo para deploy dos 5 contratos
    MAX_ATTEMPTS: 200, // Tentativas máximas
    DELAY_BETWEEN_ATTEMPTS: 3000, // 3s entre tentativas
    DELAY_BETWEEN_WALLETS: 1500, // 1.5s entre wallets
    CONSOLIDATION_INTERVAL: 10, // Consolidar a cada 10 tentativas
    RETRY_DELAY: 5000, // 5s para retry em caso de erro
};

// Múltiplos faucets com diferentes estratégias
const FAUCET_STRATEGIES = [
    {
        name: 'Solana Official',
        url: 'https://faucet.solana.com/api/v1/airdrop',
        amount: 2 * LAMPORTS_PER_SOL,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
    },
    {
        name: 'QuickNode',
        url: 'https://faucet.quicknode.com/solana/devnet',
        amount: 1 * LAMPORTS_PER_SOL,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
    },
    {
        name: 'SolFaucet',
        url: 'https://solfaucet.com/api/v1/airdrop',
        amount: 1 * LAMPORTS_PER_SOL,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
        }
    }
];

// Conexão otimizada com múltiplos endpoints
const RPC_ENDPOINTS = [
    'https://api.devnet.solana.com',
    'https://devnet.helius-rpc.com/?api-key=demo',
    'https://solana-devnet.g.alchemy.com/v2/demo'
];

let currentEndpointIndex = 0;
let connection = new Connection(RPC_ENDPOINTS[0], 'confirmed');

// Rotação de endpoints para evitar rate limits
function rotateEndpoint() {
    currentEndpointIndex = (currentEndpointIndex + 1) % RPC_ENDPOINTS.length;
    connection = new Connection(RPC_ENDPOINTS[currentEndpointIndex], 'confirmed');
    console.log(`🔄 Rotacionando para endpoint: ${RPC_ENDPOINTS[currentEndpointIndex]}`);
}

// Carrega ou cria wallets
function loadWallets() {
    const wallets = {};
    const keysDir = '.devnet-keys';
    
    // Deployer
    const deployerPath = path.join(keysDir, 'deployer.json');
    if (fs.existsSync(deployerPath)) {
        wallets.deployer = Keypair.fromSecretKey(new Uint8Array(JSON.parse(fs.readFileSync(deployerPath))));
    } else {
        console.log('❌ Deployer wallet não encontrada!');
        process.exit(1);
    }
    
    // Wallets auxiliares (criar mais se necessário)
    wallets.aux = [];
    for (let i = 0; i < 20; i++) {
        const auxPath = path.join(keysDir, 'aux', `aux_${i}.json`);
        if (fs.existsSync(auxPath)) {
            wallets.aux.push(Keypair.fromSecretKey(new Uint8Array(JSON.parse(fs.readFileSync(auxPath)))));
        } else {
            // Criar nova wallet auxiliar
            const newWallet = Keypair.generate();
            fs.mkdirSync(path.dirname(auxPath), { recursive: true });
            fs.writeFileSync(auxPath, JSON.stringify(Array.from(newWallet.secretKey)));
            wallets.aux.push(newWallet);
        }
    }
    
    console.log(`📁 Carregadas: 1 deployer + ${wallets.aux.length} auxiliares`);
    return wallets;
}

// Verifica saldo com retry
async function getBalance(publicKey, retries = 3) {
    for (let i = 0; i < retries; i++) {
        try {
            const balance = await connection.getBalance(publicKey);
            return balance / LAMPORTS_PER_SOL;
        } catch (error) {
            if (i === retries - 1) throw error;
            await sleep(1000);
            rotateEndpoint();
        }
    }
}

// Sleep otimizado
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Requisição HTTP com retry e rotação de User-Agent
async function makeRequest(url, options, retries = 3) {
    const fetch = (await import('node-fetch')).default;
    
    for (let i = 0; i < retries; i++) {
        try {
            // Rotacionar User-Agent para cada tentativa
            const userAgents = [
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
                'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15'
            ];
            
            options.headers['User-Agent'] = userAgents[i % userAgents.length];
            
            const response = await fetch(url, options);
            return response;
        } catch (error) {
            if (i === retries - 1) throw error;
            await sleep(2000 * (i + 1)); // Backoff exponencial
        }
    }
}

// Tenta airdrop via faucet web
async function tryWebFaucet(faucet, publicKey) {
    try {
        const response = await makeRequest(faucet.url, {
            method: faucet.method,
            headers: faucet.headers,
            body: JSON.stringify({
                pubkey: publicKey.toString(),
                amount: faucet.amount
            })
        });
        
        if (response.ok) {
            const data = await response.json();
            console.log(`✅ ${faucet.name}: Sucesso para ${publicKey.toString().slice(0, 8)}...`);
            return true;
        } else {
            const errorText = await response.text();
            console.log(`❌ ${faucet.name}: ${response.status} - ${errorText.slice(0, 100)}`);
            return false;
        }
    } catch (error) {
        console.log(`❌ ${faucet.name}: Erro - ${error.message}`);
        return false;
    }
}

// Tenta airdrop via RPC
async function tryRPCAirdrop(publicKey, amount = 2 * LAMPORTS_PER_SOL) {
    try {
        const signature = await connection.requestAirdrop(publicKey, amount);
        await connection.confirmTransaction(signature);
        console.log(`✅ RPC Airdrop: Sucesso para ${publicKey.toString().slice(0, 8)}...`);
        return true;
    } catch (error) {
        console.log(`❌ RPC Airdrop: ${error.message}`);
        return false;
    }
}

// Estratégia inteligente de coleta
async function smartCollect(wallet, walletType, attempt) {
    const publicKey = wallet.publicKey;
    let success = false;
    
    console.log(`\n🎯 Tentativa ${attempt} - ${walletType}: ${publicKey.toString().slice(0, 8)}...`);
    
    // Estratégia 1: RPC Airdrop (mais rápido)
    if (!success && attempt % 3 === 0) {
        success = await tryRPCAirdrop(publicKey);
        if (success) await sleep(CONFIG.DELAY_BETWEEN_ATTEMPTS);
    }
    
    // Estratégia 2: Faucets web (rotação)
    if (!success) {
        const faucetIndex = attempt % FAUCET_STRATEGIES.length;
        const faucet = FAUCET_STRATEGIES[faucetIndex];
        success = await tryWebFaucet(faucet, publicKey);
        if (success) await sleep(CONFIG.DELAY_BETWEEN_ATTEMPTS);
    }
    
    // Estratégia 3: Tentar outro faucet se falhou
    if (!success && FAUCET_STRATEGIES.length > 1) {
        const altFaucetIndex = (attempt + 1) % FAUCET_STRATEGIES.length;
        const altFaucet = FAUCET_STRATEGIES[altFaucetIndex];
        success = await tryWebFaucet(altFaucet, publicKey);
    }
    
    return success;
}

// Consolida SOL das wallets auxiliares para o deployer
async function consolidateSOL(wallets) {
    console.log('\n💰 Iniciando consolidação de SOL...');
    
    let totalConsolidated = 0;
    
    for (const auxWallet of wallets.aux) {
        try {
            const balance = await getBalance(auxWallet.publicKey);
            
            if (balance > 0.01) { // Mínimo para cobrir taxa
                const amountToTransfer = Math.floor((balance - 0.005) * LAMPORTS_PER_SOL); // Deixa 0.005 SOL para taxa
                
                if (amountToTransfer > 0) {
                    const transaction = new Transaction().add(
                        SystemProgram.transfer({
                            fromPubkey: auxWallet.publicKey,
                            toPubkey: wallets.deployer.publicKey,
                            lamports: amountToTransfer
                        })
                    );
                    
                    const signature = await connection.sendTransaction(transaction, [auxWallet]);
                    await connection.confirmTransaction(signature);
                    
                    const transferredSOL = amountToTransfer / LAMPORTS_PER_SOL;
                    totalConsolidated += transferredSOL;
                    
                    console.log(`✅ Transferido ${transferredSOL.toFixed(3)} SOL de ${auxWallet.publicKey.toString().slice(0, 8)}...`);
                }
            }
        } catch (error) {
            console.log(`❌ Erro ao consolidar de ${auxWallet.publicKey.toString().slice(0, 8)}...: ${error.message}`);
        }
        
        await sleep(500); // Pequeno delay entre transferências
    }
    
    console.log(`💰 Total consolidado: ${totalConsolidated.toFixed(3)} SOL`);
    return totalConsolidated;
}

// Função principal
async function main() {
    console.log('🚀 GMC Advanced SOL Collector - Iniciando...');
    console.log(`🎯 Meta: ${CONFIG.TARGET_SOL} SOL | Mínimo: ${CONFIG.MIN_SOL_FOR_DEPLOY} SOL`);
    
    const wallets = loadWallets();
    let attempt = 0;
    let successCount = 0;
    
    while (attempt < CONFIG.MAX_ATTEMPTS) {
        attempt++;
        
        // Verificar saldo atual do deployer
        const deployerBalance = await getBalance(wallets.deployer.publicKey);
        console.log(`\n📊 Saldo atual do deployer: ${deployerBalance.toFixed(3)} SOL`);
        
        if (deployerBalance >= CONFIG.TARGET_SOL) {
            console.log(`🎉 Meta atingida! ${deployerBalance.toFixed(3)} SOL coletados!`);
            break;
        }
        
        // Estratégia de coleta inteligente
        const walletIndex = attempt % (wallets.aux.length + 1);
        let targetWallet, walletType;
        
        if (walletIndex === 0) {
            targetWallet = wallets.deployer;
            walletType = 'DEPLOYER';
        } else {
            targetWallet = wallets.aux[walletIndex - 1];
            walletType = `AUX_${walletIndex - 1}`;
        }
        
        const success = await smartCollect(targetWallet, walletType, attempt);
        if (success) successCount++;
        
        // Consolidação periódica
        if (attempt % CONFIG.CONSOLIDATION_INTERVAL === 0) {
            await consolidateSOL(wallets);
            
            // Verificar se atingiu o mínimo
            const newBalance = await getBalance(wallets.deployer.publicKey);
            if (newBalance >= CONFIG.MIN_SOL_FOR_DEPLOY) {
                console.log(`\n✅ Mínimo atingido! ${newBalance.toFixed(3)} SOL disponíveis para deploy`);
                
                if (newBalance < CONFIG.TARGET_SOL) {
                    console.log(`🔄 Continuando coleta para atingir meta de ${CONFIG.TARGET_SOL} SOL...`);
                } else {
                    break;
                }
            }
        }
        
        // Delay inteligente baseado na taxa de sucesso
        const successRate = successCount / attempt;
        const dynamicDelay = successRate > 0.3 ? CONFIG.DELAY_BETWEEN_ATTEMPTS : CONFIG.DELAY_BETWEEN_ATTEMPTS * 2;
        
        await sleep(dynamicDelay);
        
        // Rotacionar endpoint a cada 20 tentativas
        if (attempt % 20 === 0) {
            rotateEndpoint();
        }
    }
    
    // Consolidação final
    await consolidateSOL(wallets);
    
    // Relatório final
    const finalBalance = await getBalance(wallets.deployer.publicKey);
    const progress = (finalBalance / CONFIG.TARGET_SOL) * 100;
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 RELATÓRIO FINAL DE COLETA');
    console.log('='.repeat(60));
    console.log(`💰 SOL Coletado: ${finalBalance.toFixed(3)} SOL`);
    console.log(`🎯 Progresso: ${progress.toFixed(1)}% da meta (${CONFIG.TARGET_SOL} SOL)`);
    console.log(`✅ Tentativas bem-sucedidas: ${successCount}/${attempt} (${(successCount/attempt*100).toFixed(1)}%)`);
    console.log(`🚀 Status: ${finalBalance >= CONFIG.MIN_SOL_FOR_DEPLOY ? 'PRONTO PARA DEPLOY' : 'INSUFICIENTE PARA DEPLOY'}`);
    console.log('='.repeat(60));
    
    if (finalBalance >= CONFIG.MIN_SOL_FOR_DEPLOY) {
        console.log('\n🎉 Sucesso! Iniciando deploy dos contratos restantes...');
        return true;
    } else {
        console.log(`\n⚠️  Ainda precisamos de ${(CONFIG.MIN_SOL_FOR_DEPLOY - finalBalance).toFixed(3)} SOL para deploy completo`);
        return false;
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { main, loadWallets, consolidateSOL };