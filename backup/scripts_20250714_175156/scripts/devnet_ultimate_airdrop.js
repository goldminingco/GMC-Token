#!/usr/bin/env node

/**
 * GMC Ultimate Airdrop Script
 * Estratégia híbrida: CLI + múltiplas wallets + timing otimizado
 * Baseado no script bash que funcionava + melhorias para rate limits atuais
 */

const { execSync } = require('child_process');
const { Connection, Keypair, LAMPORTS_PER_SOL, Transaction, SystemProgram } = require('@solana/web3.js');
const fs = require('fs');
const path = require('path');

// Configurações otimizadas
const CONFIG = {
    TARGET_SOL: 25, // Meta realista
    AIRDROP_AMOUNT: 1, // 1 SOL por tentativa (menor para evitar rate limits)
    DELAY_BETWEEN_ATTEMPTS: 45000, // 45s (um pouco menos que 60s)
    DELAY_BETWEEN_WALLETS: 15000, // 15s entre wallets diferentes
    MAX_EXECUTION_TIME: 3 * 60 * 60 * 1000, // 3 horas
    MAX_ATTEMPTS_PER_AIRDROP: 5, // Menos tentativas por airdrop
    CONSOLIDATION_INTERVAL: 8, // Consolidar a cada 8 tentativas
};

// Múltiplos endpoints RPC
const RPC_ENDPOINTS = [
    'https://api.devnet.solana.com',
    'https://devnet.helius-rpc.com/?api-key=demo',
    'https://solana-devnet.g.alchemy.com/v2/demo'
];

let currentEndpointIndex = 0;
let connection = new Connection(RPC_ENDPOINTS[0], 'confirmed');

// Cores
const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    reset: '\x1b[0m'
};

function log(message, color = 'reset') {
    const timestamp = new Date().toLocaleString('pt-BR');
    console.log(`${colors[color]}[${timestamp}] ${message}${colors.reset}`);
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Rotaciona endpoint RPC
function rotateEndpoint() {
    currentEndpointIndex = (currentEndpointIndex + 1) % RPC_ENDPOINTS.length;
    connection = new Connection(RPC_ENDPOINTS[currentEndpointIndex], 'confirmed');
    log(`🔄 Rotacionando para endpoint: ${RPC_ENDPOINTS[currentEndpointIndex]}`, 'cyan');
}

// Executa comando com timeout
function execWithTimeout(command, timeout = 25000) {
    try {
        return execSync(command, { 
            timeout, 
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe']
        }).trim();
    } catch (error) {
        throw new Error(`${error.message}`);
    }
}

// Verifica saldo via CLI
function checkBalance(address) {
    try {
        const result = execWithTimeout(`solana balance ${address}`);
        const match = result.match(/([0-9.]+)\s*SOL/);
        return match ? parseFloat(match[1]) : 0;
    } catch (error) {
        log(`Erro ao verificar saldo: ${error.message}`, 'red');
        return 0;
    }
}

// Verifica saldo via RPC (alternativo)
async function checkBalanceRPC(publicKey) {
    try {
        const balance = await connection.getBalance(publicKey);
        return balance / LAMPORTS_PER_SOL;
    } catch (error) {
        log(`Erro RPC saldo: ${error.message}`, 'yellow');
        return 0;
    }
}

// Airdrop via CLI (método original que funcionava)
async function airdropCLI(address, amount) {
    try {
        const result = execWithTimeout(`solana airdrop ${amount} ${address}`);
        
        if (result.includes('Requesting airdrop') || result.includes('SOL') || result.includes('Signature')) {
            log(`✅ CLI Airdrop: ${amount} SOL para ${address.slice(0, 8)}...`, 'green');
            return true;
        } else {
            log(`❌ CLI falhou: ${result}`, 'yellow');
            return false;
        }
    } catch (error) {
        if (error.message.includes('rate limit')) {
            log(`⚠️ Rate limit CLI: ${error.message}`, 'yellow');
        } else {
            log(`❌ Erro CLI: ${error.message}`, 'red');
        }
        return false;
    }
}

// Airdrop via RPC (alternativo)
async function airdropRPC(publicKey, amount = LAMPORTS_PER_SOL) {
    try {
        const signature = await connection.requestAirdrop(publicKey, amount);
        await connection.confirmTransaction(signature);
        log(`✅ RPC Airdrop: ${amount/LAMPORTS_PER_SOL} SOL para ${publicKey.toString().slice(0, 8)}...`, 'green');
        return true;
    } catch (error) {
        log(`❌ RPC falhou: ${error.message}`, 'yellow');
        return false;
    }
}

// Estratégia híbrida de airdrop
async function hybridAirdrop(address, publicKey, amount) {
    let success = false;
    
    // Estratégia 1: CLI (método original)
    if (!success) {
        success = await airdropCLI(address, amount);
        if (success) await sleep(3000);
    }
    
    // Estratégia 2: RPC se CLI falhar
    if (!success) {
        rotateEndpoint();
        success = await airdropRPC(publicKey, amount * LAMPORTS_PER_SOL);
        if (success) await sleep(3000);
    }
    
    return success;
}

// Carrega wallets
function loadWallets() {
    const wallets = {};
    const keysDir = '.devnet-keys';
    
    // Deployer
    const deployerPath = path.join(keysDir, 'deployer.json');
    if (fs.existsSync(deployerPath)) {
        const keyData = JSON.parse(fs.readFileSync(deployerPath));
        wallets.deployer = {
            keypair: Keypair.fromSecretKey(new Uint8Array(keyData)),
            address: null
        };
        wallets.deployer.address = wallets.deployer.keypair.publicKey.toString();
    } else {
        log('❌ Deployer wallet não encontrada!', 'red');
        process.exit(1);
    }
    
    // Admin
    const adminPath = path.join(keysDir, 'admin.json');
    if (fs.existsSync(adminPath)) {
        const keyData = JSON.parse(fs.readFileSync(adminPath));
        wallets.admin = {
            keypair: Keypair.fromSecretKey(new Uint8Array(keyData)),
            address: null
        };
        wallets.admin.address = wallets.admin.keypair.publicKey.toString();
    }
    
    // Auxiliares
    wallets.aux = [];
    for (let i = 0; i < 10; i++) {
        const auxPath = path.join(keysDir, 'aux', `aux_${i}.json`);
        if (fs.existsSync(auxPath)) {
            const keyData = JSON.parse(fs.readFileSync(auxPath));
            const keypair = Keypair.fromSecretKey(new Uint8Array(keyData));
            wallets.aux.push({
                keypair,
                address: keypair.publicKey.toString(),
                name: `aux_${i}`
            });
        }
    }
    
    log(`📁 Wallets carregadas: deployer + ${wallets.admin ? 'admin + ' : ''}${wallets.aux.length} auxiliares`, 'blue');
    return wallets;
}

// Transfere SOL entre wallets
async function transferSOL(fromWallet, toAddress, amount) {
    try {
        const transaction = new Transaction().add(
            SystemProgram.transfer({
                fromPubkey: fromWallet.keypair.publicKey,
                toPubkey: new (require('@solana/web3.js').PublicKey)(toAddress),
                lamports: Math.floor(amount * LAMPORTS_PER_SOL)
            })
        );
        
        const signature = await connection.sendTransaction(transaction, [fromWallet.keypair]);
        await connection.confirmTransaction(signature);
        
        log(`✅ Transferido ${amount} SOL de ${fromWallet.name || 'wallet'} para deployer`, 'green');
        return true;
    } catch (error) {
        log(`❌ Erro na transferência: ${error.message}`, 'red');
        return false;
    }
}

// Consolida SOL das auxiliares
async function consolidateSOL(wallets) {
    log('💰 Iniciando consolidação...', 'cyan');
    
    let totalConsolidated = 0;
    
    // Consolidar admin se existir
    if (wallets.admin) {
        const adminBalance = await checkBalanceRPC(wallets.admin.keypair.publicKey);
        if (adminBalance > 0.01) {
            const amountToTransfer = adminBalance - 0.005;
            const success = await transferSOL(wallets.admin, wallets.deployer.address, amountToTransfer);
            if (success) totalConsolidated += amountToTransfer;
        }
    }
    
    // Consolidar auxiliares
    for (const auxWallet of wallets.aux) {
        const balance = await checkBalanceRPC(auxWallet.keypair.publicKey);
        if (balance > 0.01) {
            const amountToTransfer = balance - 0.005;
            const success = await transferSOL(auxWallet, wallets.deployer.address, amountToTransfer);
            if (success) totalConsolidated += amountToTransfer;
        }
        await sleep(1000);
    }
    
    log(`💰 Total consolidado: ${totalConsolidated.toFixed(3)} SOL`, 'green');
    return totalConsolidated;
}

// Configura devnet
function configureDevnet() {
    try {
        log('Configurando Devnet...', 'blue');
        execWithTimeout('solana config set --url https://api.devnet.solana.com');
        execWithTimeout('solana config set --keypair .devnet-keys/deployer.json');
        log('✅ Configurado para Devnet', 'green');
        return true;
    } catch (error) {
        log(`Erro ao configurar devnet: ${error.message}`, 'red');
        return false;
    }
}

// Função principal
async function main() {
    console.log('🚀 ====================================');
    console.log('   GMC ULTIMATE AIRDROP SCRIPT');
    console.log('   (Estratégia Híbrida Otimizada)');
    console.log('🚀 ====================================');
    
    log(`🎯 Meta: ${CONFIG.TARGET_SOL} SOL`);
    log(`💰 Airdrop: ${CONFIG.AIRDROP_AMOUNT} SOL a cada ${CONFIG.DELAY_BETWEEN_ATTEMPTS/1000}s`);
    log(`⏱️ Tempo máximo: ${CONFIG.MAX_EXECUTION_TIME/(60*60*1000)} horas`);
    
    // Configurar devnet
    if (!configureDevnet()) {
        log('❌ Falha na configuração', 'red');
        process.exit(1);
    }
    
    // Carregar wallets
    const wallets = loadWallets();
    
    // Verificar saldo inicial
    const initialBalance = checkBalance(wallets.deployer.address);
    log(`Balance inicial: ${initialBalance} SOL`, 'blue');
    
    if (initialBalance >= CONFIG.TARGET_SOL) {
        log('✅ Meta já atingida!', 'green');
        return true;
    }
    
    // Iniciar coleta
    const startTime = Date.now();
    const endTime = startTime + CONFIG.MAX_EXECUTION_TIME;
    let totalAttempts = 0;
    let successfulAirdrops = 0;
    
    log('🚀 Iniciando coleta híbrida...', 'green');
    
    while (Date.now() < endTime) {
        totalAttempts++;
        
        const currentBalance = checkBalance(wallets.deployer.address);
        const progress = ((currentBalance / CONFIG.TARGET_SOL) * 100).toFixed(1);
        
        log(`📊 Tentativa ${totalAttempts} - Balance: ${currentBalance} SOL (${progress}%)`, 'blue');
        
        if (currentBalance >= CONFIG.TARGET_SOL) {
            log('🎉 Meta atingida!', 'green');
            break;
        }
        
        // Estratégia de rotação de wallets
        let targetWallet;
        let walletName;
        
        if (totalAttempts % 4 === 1) {
            targetWallet = wallets.deployer;
            walletName = 'DEPLOYER';
        } else if (totalAttempts % 4 === 2 && wallets.admin) {
            targetWallet = wallets.admin;
            walletName = 'ADMIN';
        } else {
            const auxIndex = (totalAttempts - 1) % wallets.aux.length;
            targetWallet = wallets.aux[auxIndex];
            walletName = targetWallet.name.toUpperCase();
        }
        
        log(`🎯 ${walletName}: ${targetWallet.address.slice(0, 8)}...`, 'cyan');
        
        // Tentar airdrop híbrido
        const success = await hybridAirdrop(
            targetWallet.address, 
            targetWallet.keypair.publicKey, 
            CONFIG.AIRDROP_AMOUNT
        );
        
        if (success) {
            successfulAirdrops++;
        }
        
        // Consolidação periódica
        if (totalAttempts % CONFIG.CONSOLIDATION_INTERVAL === 0) {
            await consolidateSOL(wallets);
            
            const newBalance = checkBalance(wallets.deployer.address);
            log(`💰 Balance pós-consolidação: ${newBalance} SOL`, 'green');
            
            if (newBalance >= CONFIG.TARGET_SOL) {
                log('🎉 Meta atingida após consolidação!', 'green');
                break;
            }
        }
        
        // Delay inteligente
        const successRate = successfulAirdrops / totalAttempts;
        const delay = successRate > 0.3 ? CONFIG.DELAY_BETWEEN_ATTEMPTS : CONFIG.DELAY_BETWEEN_ATTEMPTS * 1.2;
        
        const remainingTime = Math.floor((endTime - Date.now()) / 1000);
        log(`⏱️ Aguardando ${delay/1000}s... (Sucesso: ${(successRate*100).toFixed(1)}% | Restam: ${Math.floor(remainingTime/60)}min)`, 'yellow');
        
        await sleep(delay);
    }
    
    // Consolidação final
    await consolidateSOL(wallets);
    
    // Relatório final
    const finalBalance = checkBalance(wallets.deployer.address);
    const totalTime = (Date.now() - startTime) / 1000;
    const successRate = totalAttempts > 0 ? (successfulAirdrops / totalAttempts * 100).toFixed(1) : 0;
    
    console.log('\n' + '='.repeat(60));
    log('📊 RELATÓRIO FINAL HÍBRIDO', 'blue');
    console.log('='.repeat(60));
    log(`💰 SOL Final: ${finalBalance} SOL`, 'green');
    log(`📈 Coletado: ${(finalBalance - initialBalance).toFixed(3)} SOL`, 'green');
    log(`🎯 Progresso: ${((finalBalance / CONFIG.TARGET_SOL) * 100).toFixed(1)}% da meta`, 'blue');
    log(`✅ Sucessos: ${successfulAirdrops}/${totalAttempts} (${successRate}%)`, 'green');
    log(`⏱️ Tempo: ${Math.floor(totalTime/60)}min ${Math.floor(totalTime%60)}s`, 'blue');
    log(`🚀 Status: ${finalBalance >= CONFIG.TARGET_SOL ? 'META ATINGIDA!' : 'COLETA PARCIAL'}`, 
        finalBalance >= CONFIG.TARGET_SOL ? 'green' : 'yellow');
    console.log('='.repeat(60));
    
    return finalBalance >= CONFIG.TARGET_SOL;
}

// Executar
if (require.main === module) {
    main().then(success => {
        if (success) {
            log('🎉 Sucesso! Pronto para deploy!', 'green');
            process.exit(0);
        } else {
            log('⚠️ Coleta parcial. Continuando...', 'yellow');
            process.exit(1);
        }
    }).catch(error => {
        log(`❌ Erro fatal: ${error.message}`, 'red');
        process.exit(1);
    });
}

module.exports = { main };