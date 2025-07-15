#!/usr/bin/env node

/**
 * GMC Classic Airdrop Script
 * Baseado no script bash que funcionava perfeitamente
 * Faz airdrop de 2 SOL a cada 60 segundos por 2 horas
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configurações baseadas no script que funcionava
const CONFIG = {
    TARGET_SOL: 30, // Meta realista
    AIRDROP_AMOUNT: 2, // 2 SOL por tentativa (como no script original)
    DELAY_BETWEEN_ATTEMPTS: 60000, // 60 segundos (como no script original)
    MAX_EXECUTION_TIME: 2 * 60 * 60 * 1000, // 2 horas
    MAX_ATTEMPTS_PER_AIRDROP: 10, // Tentativas por airdrop
    INITIAL_WAIT_TIME: 30000, // 30s inicial
};

// Cores para output
const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    reset: '\x1b[0m'
};

function log(message, color = 'reset') {
    const timestamp = new Date().toLocaleString('pt-BR');
    console.log(`${colors[color]}[${timestamp}] ${message}${colors.reset}`);
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Executa comando com timeout e retry
function execWithRetry(command, timeout = 30000, retries = 3) {
    for (let i = 0; i < retries; i++) {
        try {
            return execSync(command, { 
                timeout, 
                encoding: 'utf8',
                stdio: ['pipe', 'pipe', 'pipe']
            }).trim();
        } catch (error) {
            if (i === retries - 1) throw error;
            log(`Tentativa ${i + 1} falhou, tentando novamente...`, 'yellow');
        }
    }
}

// Verifica saldo usando CLI (método que funcionava)
function checkBalance(address) {
    try {
        const result = execWithRetry(`solana balance ${address}`);
        const match = result.match(/([0-9.]+)\s*SOL/);
        return match ? parseFloat(match[1]) : 0;
    } catch (error) {
        log(`Erro ao verificar saldo: ${error.message}`, 'red');
        return 0;
    }
}

// Função de airdrop com retry (baseada no script bash original)
async function airdropWithRetry(address, amount) {
    let attempt = 1;
    let waitTime = CONFIG.INITIAL_WAIT_TIME;
    
    log(`Tentando airdrop de ${amount} SOL para ${address.slice(0, 8)}...`, 'blue');
    
    while (attempt <= CONFIG.MAX_ATTEMPTS_PER_AIRDROP) {
        log(`Tentativa ${attempt}/${CONFIG.MAX_ATTEMPTS_PER_AIRDROP}...`);
        
        try {
            const result = execWithRetry(`solana airdrop ${amount} ${address}`, 20000);
            
            if (result.includes('Requesting airdrop') || result.includes('SOL') || result.includes('Signature')) {
                log(`✅ Airdrop de ${amount} SOL bem-sucedido!`, 'green');
                return true;
            } else {
                log(`❌ Resultado inesperado: ${result}`, 'yellow');
            }
        } catch (error) {
            log(`⚠️ Tentativa ${attempt} falhou: ${error.message}`, 'yellow');
        }
        
        if (attempt < CONFIG.MAX_ATTEMPTS_PER_AIRDROP) {
            log(`Aguardando ${waitTime/1000}s antes da próxima tentativa...`, 'yellow');
            await sleep(waitTime);
            attempt++;
            waitTime += 10000; // Aumenta o tempo de espera
        } else {
            break;
        }
    }
    
    log(`❌ Falha ao obter airdrop após ${CONFIG.MAX_ATTEMPTS_PER_AIRDROP} tentativas`, 'red');
    return false;
}

// Carrega endereço do deployer
function loadDeployerAddress() {
    try {
        const deployerPubkeyPath = '.devnet-keys/deployer.pubkey';
        
        if (fs.existsSync(deployerPubkeyPath)) {
            return fs.readFileSync(deployerPubkeyPath, 'utf8').trim();
        } else {
            // Gerar pubkey se não existir
            const result = execWithRetry('solana-keygen pubkey .devnet-keys/deployer.json');
            fs.writeFileSync(deployerPubkeyPath, result);
            return result.trim();
        }
    } catch (error) {
        log(`Erro ao carregar deployer: ${error.message}`, 'red');
        process.exit(1);
    }
}

// Configura ambiente devnet
function configureDevnet() {
    try {
        log('Configurando Devnet...', 'blue');
        execWithRetry('solana config set --url https://api.devnet.solana.com');
        execWithRetry('solana config set --keypair .devnet-keys/deployer.json');
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
    console.log('   GMC CLASSIC AIRDROP SCRIPT');
    console.log('   (Baseado no script que funcionava)');
    console.log('🚀 ====================================');
    
    log(`🎯 Meta: ${CONFIG.TARGET_SOL} SOL`);
    log(`⏱️ Tempo máximo: ${CONFIG.MAX_EXECUTION_TIME / (60 * 60 * 1000)} horas`);
    log(`💰 Airdrop: ${CONFIG.AIRDROP_AMOUNT} SOL a cada ${CONFIG.DELAY_BETWEEN_ATTEMPTS / 1000}s`);
    
    // Configurar devnet
    if (!configureDevnet()) {
        log('❌ Falha na configuração do devnet', 'red');
        process.exit(1);
    }
    
    // Carregar endereço do deployer
    const deployerAddress = loadDeployerAddress();
    log(`Deployer: ${deployerAddress}`, 'blue');
    
    // Verificar saldo inicial
    const initialBalance = checkBalance(deployerAddress);
    log(`Balance inicial: ${initialBalance} SOL`, 'blue');
    
    // Calcular SOL necessário
    const neededSOL = Math.max(0, CONFIG.TARGET_SOL - initialBalance);
    log(`SOL necessário: ${neededSOL} SOL`, 'yellow');
    
    if (neededSOL <= 0) {
        log('✅ Já temos SOL suficiente!', 'green');
        return true;
    }
    
    // Iniciar coleta
    const startTime = Date.now();
    const endTime = startTime + CONFIG.MAX_EXECUTION_TIME;
    let totalCollected = 0;
    let successfulAirdrops = 0;
    let totalAttempts = 0;
    
    log('🚀 Iniciando coleta de SOL...', 'green');
    
    while (Date.now() < endTime && totalCollected < neededSOL) {
        totalAttempts++;
        
        const currentBalance = checkBalance(deployerAddress);
        const progress = ((currentBalance / CONFIG.TARGET_SOL) * 100).toFixed(1);
        
        log(`📊 Tentativa ${totalAttempts} - Balance: ${currentBalance} SOL (${progress}%)`, 'blue');
        
        if (currentBalance >= CONFIG.TARGET_SOL) {
            log('🎉 Meta atingida!', 'green');
            break;
        }
        
        // Tentar airdrop
        const success = await airdropWithRetry(deployerAddress, CONFIG.AIRDROP_AMOUNT);
        
        if (success) {
            successfulAirdrops++;
            totalCollected += CONFIG.AIRDROP_AMOUNT;
            
            // Verificar saldo após airdrop
            await sleep(3000); // Aguardar confirmação
            const newBalance = checkBalance(deployerAddress);
            log(`💰 Novo balance: ${newBalance} SOL (+${(newBalance - currentBalance).toFixed(3)})`, 'green');
        }
        
        // Aguardar antes da próxima tentativa (como no script original)
        if (Date.now() < endTime && totalCollected < neededSOL) {
            const remainingTime = Math.floor((endTime - Date.now()) / 1000);
            log(`⏱️ Aguardando 60s... (Tempo restante: ${Math.floor(remainingTime/60)}min)`, 'yellow');
            await sleep(CONFIG.DELAY_BETWEEN_ATTEMPTS);
        }
    }
    
    // Relatório final
    const finalBalance = checkBalance(deployerAddress);
    const totalTime = (Date.now() - startTime) / 1000;
    const successRate = totalAttempts > 0 ? (successfulAirdrops / totalAttempts * 100).toFixed(1) : 0;
    
    console.log('\n' + '='.repeat(50));
    log('📊 RELATÓRIO FINAL', 'blue');
    console.log('='.repeat(50));
    log(`💰 SOL Final: ${finalBalance} SOL`, 'green');
    log(`📈 Coletado: ${(finalBalance - initialBalance).toFixed(3)} SOL`, 'green');
    log(`🎯 Progresso: ${((finalBalance / CONFIG.TARGET_SOL) * 100).toFixed(1)}% da meta`, 'blue');
    log(`✅ Sucessos: ${successfulAirdrops}/${totalAttempts} (${successRate}%)`, 'green');
    log(`⏱️ Tempo total: ${Math.floor(totalTime/60)}min ${Math.floor(totalTime%60)}s`, 'blue');
    log(`🚀 Status: ${finalBalance >= CONFIG.TARGET_SOL ? 'META ATINGIDA!' : 'COLETA PARCIAL'}`, 
        finalBalance >= CONFIG.TARGET_SOL ? 'green' : 'yellow');
    console.log('='.repeat(50));
    
    return finalBalance >= CONFIG.TARGET_SOL;
}

// Executar se chamado diretamente
if (require.main === module) {
    main().then(success => {
        if (success) {
            log('🎉 Sucesso! SOL suficiente coletado!', 'green');
            process.exit(0);
        } else {
            log('⚠️ Coleta parcial. Pode ser necessário mais tempo.', 'yellow');
            process.exit(1);
        }
    }).catch(error => {
        log(`❌ Erro fatal: ${error.message}`, 'red');
        process.exit(1);
    });
}

module.exports = { main };