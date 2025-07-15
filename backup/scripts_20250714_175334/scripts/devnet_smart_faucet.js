#!/usr/bin/env node

const { Connection, Keypair, LAMPORTS_PER_SOL, PublicKey, Transaction, SystemProgram } = require('@solana/web3.js');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Configurações
const TARGET_SOL = 100;
const DEVNET_RPC = 'https://api.devnet.solana.com';
const connection = new Connection(DEVNET_RPC, 'confirmed');

// Faucets alternativos
const FAUCETS = [
    {
        name: 'Solana Official',
        url: 'https://api.devnet.solana.com',
        method: 'requestAirdrop'
    },
    {
        name: 'QuickNode',
        url: 'https://api.devnet.solana.com',
        method: 'requestAirdrop'
    },
    {
        name: 'Alchemy',
        url: 'https://solana-devnet.g.alchemy.com/v2/demo',
        method: 'requestAirdrop'
    }
];

// Carregar wallets
function loadWallet(filename) {
    try {
        const keyPath = path.join(__dirname, '..', '.devnet-keys', filename);
        const secretKey = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
        return Keypair.fromSecretKey(new Uint8Array(secretKey));
    } catch (error) {
        console.log(`⚠️  Erro ao carregar ${filename}:`, error.message);
        return null;
    }
}

// Função para fazer airdrop via HTTP direto
async function requestAirdropHTTP(publicKey, amount, faucetUrl) {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({
            jsonrpc: '2.0',
            id: 1,
            method: 'requestAirdrop',
            params: [publicKey.toString(), amount * LAMPORTS_PER_SOL]
        });

        const options = {
            hostname: new URL(faucetUrl).hostname,
            port: new URL(faucetUrl).port || (faucetUrl.startsWith('https') ? 443 : 80),
            path: new URL(faucetUrl).pathname,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': data.length,
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            }
        };

        const protocol = faucetUrl.startsWith('https') ? https : http;
        const req = protocol.request(options, (res) => {
            let responseData = '';
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            res.on('end', () => {
                try {
                    const response = JSON.parse(responseData);
                    if (response.error) {
                        reject(new Error(response.error.message));
                    } else {
                        resolve(response.result);
                    }
                } catch (error) {
                    reject(error);
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        req.write(data);
        req.end();
    });
}

// Função para tentar airdrop com múltiplos faucets
async function tryMultipleFaucets(wallet, amount) {
    for (const faucet of FAUCETS) {
        try {
            console.log(`🔄 Tentando ${faucet.name} para ${wallet.publicKey.toString().slice(0, 8)}...`);
            
            if (faucet.method === 'requestAirdrop') {
                const customConnection = new Connection(faucet.url, 'confirmed');
                const signature = await customConnection.requestAirdrop(wallet.publicKey, amount * LAMPORTS_PER_SOL);
                await customConnection.confirmTransaction(signature);
                console.log(`✅ Sucesso com ${faucet.name}: ${amount} SOL`);
                return true;
            }
        } catch (error) {
            console.log(`❌ ${faucet.name} falhou: ${error.message}`);
            await sleep(2000); // 2s entre tentativas
        }
    }
    return false;
}

// Função para tentar faucets web externos
async function tryWebFaucets(publicKey) {
    const webFaucets = [
        'https://faucet.solana.com',
        'https://solfaucet.com',
        'https://faucet.quicknode.com/solana/devnet'
    ];

    console.log(`🌐 Tentando faucets web para ${publicKey.toString().slice(0, 8)}...`);
    console.log('📋 Visite manualmente se necessário:');
    webFaucets.forEach(url => {
        console.log(`   ${url}`);
    });
    
    return false; // Retorna false pois são manuais
}

// Função para consolidar SOL
async function consolidateSOL(fromWallets, toWallet) {
    console.log('🔄 Consolidando SOL...');
    
    for (const wallet of fromWallets) {
        try {
            const balance = await connection.getBalance(wallet.publicKey);
            if (balance > 0.01 * LAMPORTS_PER_SOL) { // Deixa 0.01 SOL para fees
                const transferAmount = balance - 0.005 * LAMPORTS_PER_SOL; // Taxa de transação
                
                const transaction = new Transaction().add(
                    SystemProgram.transfer({
                        fromPubkey: wallet.publicKey,
                        toPubkey: toWallet.publicKey,
                        lamports: transferAmount
                    })
                );
                
                const signature = await connection.sendTransaction(transaction, [wallet]);
                await connection.confirmTransaction(signature);
                
                console.log(`💰 Consolidado ${(transferAmount / LAMPORTS_PER_SOL).toFixed(3)} SOL de ${wallet.publicKey.toString().slice(0, 8)}`);
            }
        } catch (error) {
            console.log(`⚠️  Erro na consolidação de ${wallet.publicKey.toString().slice(0, 8)}: ${error.message}`);
        }
    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function formatTime() {
    return new Date().toLocaleTimeString('pt-BR');
}

async function main() {
    console.log('🚀 Iniciando coleta inteligente de SOL na Devnet...');
    console.log(`🎯 Meta: ${TARGET_SOL} SOL`);
    console.log('='.repeat(60));

    // Carregar wallets
    const deployer = loadWallet('deployer.json');
    const admin = loadWallet('admin.json');
    const auxWallets = [];
    
    for (let i = 0; i < 10; i++) {
        const aux = loadWallet(`aux/aux_${i}.json`);
        if (aux) auxWallets.push(aux);
    }

    const allWallets = [deployer, admin, ...auxWallets].filter(w => w !== null);
    console.log(`📱 ${allWallets.length} wallets carregadas`);

    let totalCollected = 0;
    let attempts = 0;
    const maxAttempts = 1000;
    
    while (totalCollected < TARGET_SOL && attempts < maxAttempts) {
        attempts++;
        console.log(`\n[${formatTime()}] === Tentativa ${attempts} ===`);
        
        // Verificar saldo atual do deployer
        const deployerBalance = await connection.getBalance(deployer.publicKey);
        const currentSOL = deployerBalance / LAMPORTS_PER_SOL;
        console.log(`💰 Saldo atual do deployer: ${currentSOL.toFixed(3)} SOL`);
        
        if (currentSOL >= TARGET_SOL) {
            console.log(`🎉 Meta atingida! ${currentSOL.toFixed(3)} SOL coletados!`);
            break;
        }
        
        // Tentar airdrop para cada wallet
        let successCount = 0;
        for (let i = 0; i < allWallets.length; i++) {
            const wallet = allWallets[i];
            const walletName = i === 0 ? 'deployer' : i === 1 ? 'admin' : `aux_${i-2}`;
            
            console.log(`\n🔄 [${formatTime()}] Processando ${walletName}...`);
            
            // Tentar múltiplos faucets
            const success = await tryMultipleFaucets(wallet, 2);
            if (success) {
                successCount++;
                totalCollected += 2;
            } else {
                // Se falhar, tentar faucets web (manual)
                await tryWebFaucets(wallet.publicKey);
            }
            
            // Delay entre wallets
            await sleep(5000);
        }
        
        console.log(`\n📊 Tentativa ${attempts}: ${successCount}/${allWallets.length} sucessos`);
        
        // Consolidar SOL a cada 5 tentativas
        if (attempts % 5 === 0) {
            await consolidateSOL(auxWallets, deployer);
        }
        
        // Delay maior entre rodadas
        if (successCount === 0) {
            console.log('⏳ Nenhum sucesso, aguardando 2 minutos...');
            await sleep(120000); // 2 minutos
        } else {
            console.log('⏳ Aguardando 30 segundos...');
            await sleep(30000); // 30 segundos
        }
    }
    
    // Consolidação final
    console.log('\n🔄 Consolidação final...');
    await consolidateSOL(auxWallets, deployer);
    
    // Verificar saldo final
    const finalBalance = await connection.getBalance(deployer.publicKey);
    const finalSOL = finalBalance / LAMPORTS_PER_SOL;
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 RELATÓRIO FINAL');
    console.log('='.repeat(60));
    console.log(`💰 SOL coletado: ${finalSOL.toFixed(3)} SOL`);
    console.log(`🎯 Meta: ${TARGET_SOL} SOL`);
    console.log(`📈 Progresso: ${((finalSOL / TARGET_SOL) * 100).toFixed(1)}%`);
    console.log(`🔄 Tentativas: ${attempts}`);
    
    if (finalSOL >= 15) {
        console.log('\n🚀 SOL suficiente para deployment! Iniciando deploy...');
        // Aqui poderia chamar o script de deploy
    } else {
        console.log('\n⚠️  SOL insuficiente. Considere:');
        console.log('   1. Usar faucets web manuais');
        console.log('   2. Solicitar SOL de outros desenvolvedores');
        console.log('   3. Aguardar reset dos rate limits');
    }
}

// Tratamento de erros
process.on('unhandledRejection', (error) => {
    console.error('❌ Erro não tratado:', error);
});

process.on('SIGINT', () => {
    console.log('\n🛑 Script interrompido pelo usuário');
    process.exit(0);
});

// Executar
main().catch(console.error);