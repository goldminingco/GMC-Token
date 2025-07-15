#!/usr/bin/env node

/**
 * GMC Simple Airdrop Script
 * Baseado EXATAMENTE no script bash que funcionava
 * Estratégia: CLI simples + timing original (2 SOL a cada 60s)
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configurações EXATAS do script bash original
const CONFIG = {
    TARGET_SOL: 15, // Meta original do bash
    AIRDROP_AMOUNT: 2, // 2 SOL como no original
    DELAY_SUCCESS: 60000, // 60s como no original
    INITIAL_RETRY_DELAY: 30000, // 30s inicial
    RETRY_INCREMENT: 10000, // +10s por retry
    MAX_RETRIES: 10, // 10 tentativas como no original
    MAX_EXECUTION_TIME: 2 * 60 * 60 * 1000, // 2 horas como no original
};

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

// Executa comando exatamente como no bash
function execCommand(command) {
    try {
        return execSync(command, { 
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe']
        }).trim();
    } catch (error) {
        throw new Error(error.message);
    }
}

// Verifica saldo exatamente como no bash
function checkBalance(address) {
    try {
        const result = execCommand(`solana balance ${address}`);
        const match = result.match(/([0-9.]+)\s*SOL/);
        return match ? parseFloat(match[1]) : 0;
    } catch (error) {
        log(`Erro ao verificar saldo: ${error.message}`, 'red');
        return 0;
    }
}

// Airdrop com retry exatamente como no bash
async function airdropWithRetry(address, amount) {
    let attempt = 0;
    
    while (attempt < CONFIG.MAX_RETRIES) {
        attempt++;
        
        try {
            log(`🎯 Tentativa ${attempt}: Solicitando ${amount} SOL...`, 'blue');
            
            const result = execCommand(`solana airdrop ${amount} ${address}`);
            
            // Verifica se foi bem-sucedido (mesma lógica do bash)
            if (result.includes('Requesting airdrop') || 
                result.includes('SOL') || 
                result.includes('Signature')) {
                
                log(`✅ Airdrop bem-sucedido: ${amount} SOL`, 'green');
                return true;
            } else {
                log(`⚠️ Resposta inesperada: ${result}`, 'yellow');
            }
            
        } catch (error) {
            const errorMsg = error.message.toLowerCase();
            
            if (errorMsg.includes('rate limit')) {
                log(`⚠️ Rate limit detectado na tentativa ${attempt}`, 'yellow');
            } else {
                log(`❌ Erro na tentativa ${attempt}: ${error.message}`, 'red');
            }
        }
        
        // Se não foi a última tentativa, aguarda antes de tentar novamente
        if (attempt < CONFIG.MAX_RETRIES) {
            const waitTime = CONFIG.INITIAL_RETRY_DELAY + (attempt - 1) * CONFIG.RETRY_INCREMENT;
            log(`⏱️ Aguardando ${waitTime/1000}s antes da próxima tentativa...`, 'yellow');
            await sleep(waitTime);
        }
    }
    
    log(`❌ Falha após ${CONFIG.MAX_RETRIES} tentativas`, 'red');
    return false;
}

// Configura devnet exatamente como no bash
function configureDevnet() {
    try {
        log('🔧 Configurando Devnet...', 'blue');
        execCommand('solana config set --url https://api.devnet.solana.com');
        execCommand('solana config set --keypair .devnet-keys/deployer.json');
        log('✅ Configurado para Devnet', 'green');
        return true;
    } catch (error) {
        log(`❌ Erro ao configurar devnet: ${error.message}`, 'red');
        return false;
    }
}

// Carrega endereço do deployer
function loadDeployerAddress() {
    try {
        const deployerPath = '.devnet-keys/deployer.json';
        if (!fs.existsSync(deployerPath)) {
            log('❌ Arquivo deployer.json não encontrado!', 'red');
            return null;
        }
        
        const keyData = JSON.parse(fs.readFileSync(deployerPath));
        const { Keypair } = require('@solana/web3.js');
        const keypair = Keypair.fromSecretKey(new Uint8Array(keyData));
        const address = keypair.publicKey.toString();
        
        log(`📁 Deployer carregado: ${address.slice(0, 8)}...${address.slice(-8)}`, 'blue');
        return address;
        
    } catch (error) {
        log(`❌ Erro ao carregar deployer: ${error.message}`, 'red');
        return null;
    }
}

// Função principal - EXATAMENTE como o bash original
async function main() {
    console.log('🚀 ====================================');
    console.log('   GMC SIMPLE AIRDROP SCRIPT');
    console.log('   (Baseado no Script Bash Original)');
    console.log('🚀 ====================================');
    
    log(`🎯 Meta: ${CONFIG.TARGET_SOL} SOL`, 'blue');
    log(`💰 Airdrop: ${CONFIG.AIRDROP_AMOUNT} SOL a cada ${CONFIG.DELAY_SUCCESS/1000}s`, 'blue');
    log(`⏱️ Tempo máximo: ${CONFIG.MAX_EXECUTION_TIME/(60*60*1000)} horas`, 'blue');
    
    // Configurar devnet
    if (!configureDevnet()) {
        process.exit(1);
    }
    
    // Carregar deployer
    const deployerAddress = loadDeployerAddress();
    if (!deployerAddress) {
        process.exit(1);
    }
    
    // Verificar saldo inicial
    const initialBalance = checkBalance(deployerAddress);
    log(`💰 Balance inicial: ${initialBalance} SOL`, 'blue');
    
    if (initialBalance >= CONFIG.TARGET_SOL) {
        log('✅ Meta já atingida!', 'green');
        return true;
    }
    
    const needAmount = CONFIG.TARGET_SOL - initialBalance;
    log(`📊 Necessário: ${needAmount.toFixed(3)} SOL`, 'yellow');
    
    // Iniciar coleta
    const startTime = Date.now();
    const endTime = startTime + CONFIG.MAX_EXECUTION_TIME;
    let totalAttempts = 0;
    let successfulAirdrops = 0;
    
    log('🚀 Iniciando coleta simples...', 'green');
    
    while (Date.now() < endTime) {
        totalAttempts++;
        
        const currentBalance = checkBalance(deployerAddress);
        const progress = ((currentBalance / CONFIG.TARGET_SOL) * 100).toFixed(1);
        
        log(`\n📊 === CICLO ${totalAttempts} ===`, 'cyan');
        log(`💰 Balance atual: ${currentBalance} SOL (${progress}% da meta)`, 'blue');
        
        if (currentBalance >= CONFIG.TARGET_SOL) {
            log('🎉 Meta atingida!', 'green');
            break;
        }
        
        // Tentar airdrop com retry (exatamente como no bash)
        const success = await airdropWithRetry(deployerAddress, CONFIG.AIRDROP_AMOUNT);
        
        if (success) {
            successfulAirdrops++;
            
            // Verificar saldo após airdrop
            await sleep(3000); // Aguarda confirmação
            const newBalance = checkBalance(deployerAddress);
            const gained = newBalance - currentBalance;
            
            log(`💰 Novo balance: ${newBalance} SOL (+${gained.toFixed(3)})`, 'green');
            
            if (newBalance >= CONFIG.TARGET_SOL) {
                log('🎉 Meta atingida após airdrop!', 'green');
                break;
            }
            
            // Delay de sucesso (60s como no original)
            const remainingTime = Math.floor((endTime - Date.now()) / 1000);
            log(`⏱️ Aguardando ${CONFIG.DELAY_SUCCESS/1000}s... (Restam: ${Math.floor(remainingTime/60)}min)`, 'yellow');
            await sleep(CONFIG.DELAY_SUCCESS);
            
        } else {
            log('❌ Airdrop falhou após todas as tentativas', 'red');
            
            // Aguarda um pouco antes de tentar novamente
            log('⏱️ Aguardando 120s antes do próximo ciclo...', 'yellow');
            await sleep(120000);
        }
    }
    
    // Relatório final
    const finalBalance = checkBalance(deployerAddress);
    const totalTime = (Date.now() - startTime) / 1000;
    const successRate = totalAttempts > 0 ? (successfulAirdrops / totalAttempts * 100).toFixed(1) : 0;
    
    console.log('\n' + '='.repeat(60));
    log('📊 RELATÓRIO FINAL', 'blue');
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
            log('⚠️ Coleta parcial. Pode tentar novamente.', 'yellow');
            process.exit(1);
        }
    }).catch(error => {
        log(`❌ Erro fatal: ${error.message}`, 'red');
        process.exit(1);
    });
}

module.exports = { main };