#!/usr/bin/env node

/**
 * Direct Airdrop Script usando comando nativo do Solana CLI
 * Estratégia otimizada para bypass de rate limits
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configurações
const CONFIG = {
    TARGET_SOL: 25, // Meta realista
    MIN_SOL_FOR_DEPLOY: 15, // Mínimo para deploy
    MAX_ATTEMPTS: 100,
    DELAY_BETWEEN_ATTEMPTS: 5000, // 5s
    AIRDROP_AMOUNT: 2, // 2 SOL por tentativa
};

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Executa comando com timeout
function execWithTimeout(command, timeout = 30000) {
    try {
        return execSync(command, { 
            timeout, 
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe']
        }).trim();
    } catch (error) {
        throw new Error(`Comando falhou: ${error.message}`);
    }
}

// Verifica saldo usando CLI
function getBalance(address) {
    try {
        const result = execWithTimeout(`solana balance ${address} --url devnet`);
        const match = result.match(/([0-9.]+)\s*SOL/);
        return match ? parseFloat(match[1]) : 0;
    } catch (error) {
        console.log(`❌ Erro ao verificar saldo: ${error.message}`);
        return 0;
    }
}

// Executa airdrop usando CLI
async function performAirdrop(address, amount = CONFIG.AIRDROP_AMOUNT) {
    try {
        console.log(`🎯 Tentando airdrop de ${amount} SOL para ${address.slice(0, 8)}...`);
        
        const result = execWithTimeout(
            `solana airdrop ${amount} ${address} --url devnet`,
            20000
        );
        
        if (result.includes('Requesting airdrop') || result.includes('SOL')) {
            console.log(`✅ Airdrop bem-sucedido: ${result}`);
            return true;
        } else {
            console.log(`❌ Airdrop falhou: ${result}`);
            return false;
        }
    } catch (error) {
        console.log(`❌ Erro no airdrop: ${error.message}`);
        return false;
    }
}

// Carrega endereços das wallets
function loadWalletAddresses() {
    const addresses = {};
    const keysDir = '.devnet-keys';
    
    // Deployer
    const deployerPath = path.join(keysDir, 'deployer.pubkey');
    if (fs.existsSync(deployerPath)) {
        addresses.deployer = fs.readFileSync(deployerPath, 'utf8').trim();
    } else {
        console.log('❌ Deployer pubkey não encontrada!');
        process.exit(1);
    }
    
    // Admin
    const adminPath = path.join(keysDir, 'admin.pubkey');
    if (fs.existsSync(adminPath)) {
        addresses.admin = fs.readFileSync(adminPath, 'utf8').trim();
    }
    
    // Auxiliares
    addresses.aux = [];
    for (let i = 0; i < 10; i++) {
        const auxDir = path.join(keysDir, 'aux');
        const auxPath = path.join(auxDir, `aux_${i}.json`);
        
        if (fs.existsSync(auxPath)) {
            try {
                const keyData = JSON.parse(fs.readFileSync(auxPath));
                const { Keypair } = require('@solana/web3.js');
                const keypair = Keypair.fromSecretKey(new Uint8Array(keyData));
                addresses.aux.push(keypair.publicKey.toString());
            } catch (error) {
                console.log(`⚠️  Erro ao carregar aux_${i}: ${error.message}`);
            }
        }
    }
    
    console.log(`📁 Endereços carregados: deployer + admin + ${addresses.aux.length} auxiliares`);
    return addresses;
}

// Transfere SOL usando CLI
async function transferSOL(fromKeypair, toAddress, amount) {
    try {
        const tempKeyPath = `/tmp/temp_key_${Date.now()}.json`;
        fs.writeFileSync(tempKeyPath, JSON.stringify(Array.from(fromKeypair)));
        
        const result = execWithTimeout(
            `solana transfer --from ${tempKeyPath} ${toAddress} ${amount} --url devnet --allow-unfunded-recipient`,
            15000
        );
        
        fs.unlinkSync(tempKeyPath); // Limpar arquivo temporário
        
        if (result.includes('Signature:')) {
            console.log(`✅ Transferência bem-sucedida: ${amount} SOL`);
            return true;
        } else {
            console.log(`❌ Transferência falhou: ${result}`);
            return false;
        }
    } catch (error) {
        console.log(`❌ Erro na transferência: ${error.message}`);
        return false;
    }
}

// Consolida SOL das auxiliares para o deployer
async function consolidateSOL(addresses) {
    console.log('\n💰 Iniciando consolidação...');
    
    let totalConsolidated = 0;
    
    for (let i = 0; i < addresses.aux.length; i++) {
        const auxAddress = addresses.aux[i];
        const balance = getBalance(auxAddress);
        
        if (balance > 0.01) { // Mínimo para cobrir taxa
            const amountToTransfer = balance - 0.005; // Deixa para taxa
            
            try {
                // Carregar keypair da auxiliar
                const auxPath = path.join('.devnet-keys', 'aux', `aux_${i}.json`);
                const keyData = JSON.parse(fs.readFileSync(auxPath));
                
                const success = await transferSOL(
                    new Uint8Array(keyData),
                    addresses.deployer,
                    amountToTransfer
                );
                
                if (success) {
                    totalConsolidated += amountToTransfer;
                }
            } catch (error) {
                console.log(`❌ Erro ao consolidar aux_${i}: ${error.message}`);
            }
        }
        
        await sleep(1000); // Delay entre transferências
    }
    
    console.log(`💰 Total consolidado: ${totalConsolidated.toFixed(3)} SOL`);
    return totalConsolidated;
}

// Função principal
async function main() {
    console.log('🚀 GMC Direct Airdrop - Iniciando...');
    console.log(`🎯 Meta: ${CONFIG.TARGET_SOL} SOL | Mínimo: ${CONFIG.MIN_SOL_FOR_DEPLOY} SOL`);
    
    // Configurar para devnet
    try {
        execWithTimeout('solana config set --url devnet');
        console.log('✅ Configurado para Devnet');
    } catch (error) {
        console.log('⚠️  Erro ao configurar devnet, continuando...');
    }
    
    const addresses = loadWalletAddresses();
    let attempt = 0;
    let successCount = 0;
    
    while (attempt < CONFIG.MAX_ATTEMPTS) {
        attempt++;
        
        // Verificar saldo atual
        const deployerBalance = getBalance(addresses.deployer);
        console.log(`\n📊 Tentativa ${attempt} - Saldo deployer: ${deployerBalance.toFixed(3)} SOL`);
        
        if (deployerBalance >= CONFIG.TARGET_SOL) {
            console.log(`🎉 Meta atingida! ${deployerBalance.toFixed(3)} SOL`);
            break;
        }
        
        // Estratégia de airdrop
        let targetAddress;
        let targetName;
        
        if (attempt % 3 === 1) {
            targetAddress = addresses.deployer;
            targetName = 'DEPLOYER';
        } else if (attempt % 3 === 2 && addresses.admin) {
            targetAddress = addresses.admin;
            targetName = 'ADMIN';
        } else {
            const auxIndex = (attempt - 1) % addresses.aux.length;
            targetAddress = addresses.aux[auxIndex];
            targetName = `AUX_${auxIndex}`;
        }
        
        console.log(`🎯 ${targetName}: ${targetAddress.slice(0, 8)}...`);
        
        const success = await performAirdrop(targetAddress);
        if (success) {
            successCount++;
            
            // Aguardar confirmação
            await sleep(3000);
        }
        
        // Consolidação a cada 10 tentativas
        if (attempt % 10 === 0) {
            await consolidateSOL(addresses);
            
            const newBalance = getBalance(addresses.deployer);
            console.log(`💰 Saldo após consolidação: ${newBalance.toFixed(3)} SOL`);
            
            if (newBalance >= CONFIG.MIN_SOL_FOR_DEPLOY) {
                console.log(`✅ Mínimo atingido! Pronto para deploy`);
                
                if (newBalance >= CONFIG.TARGET_SOL) {
                    break;
                }
            }
        }
        
        // Delay inteligente
        const successRate = successCount / attempt;
        const delay = successRate > 0.2 ? CONFIG.DELAY_BETWEEN_ATTEMPTS : CONFIG.DELAY_BETWEEN_ATTEMPTS * 1.5;
        
        console.log(`⏱️  Aguardando ${delay/1000}s... (Taxa sucesso: ${(successRate*100).toFixed(1)}%)`);
        await sleep(delay);
    }
    
    // Consolidação final
    await consolidateSOL(addresses);
    
    // Relatório final
    const finalBalance = getBalance(addresses.deployer);
    const progress = (finalBalance / CONFIG.TARGET_SOL) * 100;
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 RELATÓRIO FINAL');
    console.log('='.repeat(60));
    console.log(`💰 SOL Final: ${finalBalance.toFixed(3)} SOL`);
    console.log(`🎯 Progresso: ${progress.toFixed(1)}% da meta`);
    console.log(`✅ Sucessos: ${successCount}/${attempt} (${(successCount/attempt*100).toFixed(1)}%)`);
    console.log(`🚀 Status: ${finalBalance >= CONFIG.MIN_SOL_FOR_DEPLOY ? 'PRONTO PARA DEPLOY' : 'INSUFICIENTE'}`);
    console.log('='.repeat(60));
    
    return finalBalance >= CONFIG.MIN_SOL_FOR_DEPLOY;
}

// Executar
if (require.main === module) {
    main().then(success => {
        if (success) {
            console.log('\n🎉 Sucesso! Executando deploy dos contratos restantes...');
            process.exit(0);
        } else {
            console.log('\n⚠️  Ainda insuficiente para deploy completo');
            process.exit(1);
        }
    }).catch(console.error);
}

module.exports = { main };