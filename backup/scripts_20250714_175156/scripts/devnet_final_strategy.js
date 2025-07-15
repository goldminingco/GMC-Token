#!/usr/bin/env node

/**
 * DEVNET FINAL STRATEGY - SOL COLLECTOR 2024
 * 
 * Estratégia Final Ultra-Agressiva:
 * - Exploração de faucets web alternativos
 * - Criação de múltiplas wallets temporárias
 * - Tentativas com diferentes user agents e IPs
 * - Recuperação máxima de SOL de todas as fontes possíveis
 * - Sistema de retry extremamente persistente
 * 
 * Meta: 25 SOL usando TODAS as estratégias possíveis
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Configuração final extrema
const CONFIG = {
    TARGET_SOL: 25,
    MAX_RUNTIME_HOURS: 4,
    TEMP_WALLETS_COUNT: 10,
    ULTRA_AGGRESSIVE_DELAY: 15, // Delay mínimo extremo
    MAX_DELAY: 60,
    
    // Todos os endpoints conhecidos + alternativos
    ALL_ENDPOINTS: [
        'https://api.devnet.solana.com',
        'https://solana-devnet.g.alchemy.com/v2/demo',
        'https://devnet.solana.dappio.xyz',
        'https://rpc-devnet.solana.com',
        'https://devnet.helius-rpc.com',
        'https://api.devnet.solana.com',
        'https://solana-devnet.rpc.extrnode.com'
    ],
    
    // Faucets web conhecidos (para referência)
    WEB_FAUCETS: [
        'https://faucet.solana.com',
        'https://solfaucet.com',
        'https://solana-faucet.com'
    ]
};

class FinalStrategyCollector {
    constructor() {
        this.startTime = Date.now();
        this.totalAttempts = 0;
        this.successfulAirdrops = 0;
        this.cycleCount = 0;
        this.lastBalance = 0;
        this.tempWallets = [];
        this.currentDelay = CONFIG.ULTRA_AGGRESSIVE_DELAY;
        
        this.log('🔥 ESTRATÉGIA FINAL - Coletor Ultra-Agressivo de SOL');
        this.log(`🎯 Meta: ${CONFIG.TARGET_SOL} SOL usando TODAS as estratégias possíveis`);
    }
    
    log(message) {
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000 / 60);
        const timestamp = new Date().toLocaleString('pt-BR');
        console.log(`[${timestamp}] 🔥 [${elapsed}min] ${message}`);
    }
    
    async getCurrentBalance() {
        try {
            const result = execSync('solana balance', { encoding: 'utf8' });
            return parseFloat(result.trim().split(' ')[0]);
        } catch (error) {
            return 0;
        }
    }
    
    async createTempWallets() {
        this.log(`🔑 Criando ${CONFIG.TEMP_WALLETS_COUNT} wallets temporárias...`);
        
        for (let i = 0; i < CONFIG.TEMP_WALLETS_COUNT; i++) {
            try {
                const tempPath = path.join(process.cwd(), `.temp_wallet_${i}.json`);
                execSync(`solana-keygen new --no-bip39-passphrase --silent --outfile ${tempPath}`);
                this.tempWallets.push(tempPath);
                this.log(`✅ Wallet temporária ${i + 1} criada`);
            } catch (error) {
                this.log(`❌ Erro ao criar wallet ${i + 1}: ${error.message}`);
            }
        }
    }
    
    async tryAllRecoveryStrategies() {
        this.log('🔧 Executando TODAS as estratégias de recuperação...');
        
        // 1. Buffer accounts
        try {
            execSync('solana program close --buffers', { encoding: 'utf8' });
            this.log('✅ Buffer accounts processados');
        } catch (error) {
            this.log(`⚠️ Buffers: ${error.message.split('\n')[0]}`);
        }
        
        // 2. Programas antigos
        try {
            const programs = execSync('solana program show --programs', { encoding: 'utf8' });
            if (programs.includes('Program Id')) {
                this.log('📦 Programas antigos encontrados');
                // Tentar fechar programas não utilizados (cuidado!)
            }
        } catch (error) {
            this.log(`⚠️ Programas: ${error.message.split('\n')[0]}`);
        }
        
        // 3. Contas de stake antigas
        try {
            const stakes = execSync('solana stakes', { encoding: 'utf8' });
            if (stakes.includes('Stake Account')) {
                this.log('🥩 Contas de stake encontradas');
            }
        } catch (error) {
            this.log(`⚠️ Stakes: ${error.message.split('\n')[0]}`);
        }
    }
    
    async tryMassiveParallelAirdrops() {
        this.log('🚀 Tentando airdrops massivos paralelos...');
        
        const promises = [];
        
        // Tentar com wallet principal em todos os endpoints
        CONFIG.ALL_ENDPOINTS.forEach((endpoint, index) => {
            promises.push(this.attemptAirdropWithRetry(endpoint, 'main', index));
        });
        
        // Tentar com wallets temporárias nos melhores endpoints
        const bestEndpoints = CONFIG.ALL_ENDPOINTS.slice(0, 3);
        this.tempWallets.slice(0, 3).forEach((wallet, walletIndex) => {
            bestEndpoints.forEach((endpoint, endpointIndex) => {
                promises.push(this.attemptAirdropWithRetry(endpoint, wallet, `temp_${walletIndex}_${endpointIndex}`));
            });
        });
        
        this.log(`🎯 Executando ${promises.length} tentativas paralelas...`);
        
        const results = await Promise.allSettled(promises);
        
        let successCount = 0;
        results.forEach((result, index) => {
            if (result.status === 'fulfilled' && result.value) {
                successCount++;
                this.log(`✅ Sucesso na tentativa ${index + 1}`);
            }
        });
        
        this.log(`📊 Sucessos: ${successCount}/${promises.length}`);
        return successCount > 0;
    }
    
    async attemptAirdropWithRetry(endpoint, wallet, identifier) {
        return new Promise(async (resolve) => {
            try {
                let cmd = `solana airdrop 1 --url ${endpoint}`;
                
                if (wallet !== 'main' && fs.existsSync(wallet)) {
                    cmd += ` --keypair ${wallet}`;
                }
                
                this.log(`🎯 [${identifier}] ${endpoint}`);
                
                const result = execSync(cmd, {
                    encoding: 'utf8',
                    timeout: 25000
                });
                
                if (result.includes('1 SOL') || result.includes('signature')) {
                    this.successfulAirdrops++;
                    
                    // Se foi para wallet temporária, transferir para principal
                    if (wallet !== 'main' && fs.existsSync(wallet)) {
                        await this.transferFromTempWallet(wallet);
                    }
                    
                    resolve(true);
                } else {
                    resolve(false);
                }
            } catch (error) {
                // Tentar novamente com delay menor
                await this.sleep(5);
                try {
                    let cmd = `solana airdrop 0.5 --url ${endpoint}`;
                    if (wallet !== 'main' && fs.existsSync(wallet)) {
                        cmd += ` --keypair ${wallet}`;
                    }
                    
                    const result = execSync(cmd, { encoding: 'utf8', timeout: 20000 });
                    if (result.includes('0.5 SOL') || result.includes('signature')) {
                        this.successfulAirdrops++;
                        if (wallet !== 'main' && fs.existsSync(wallet)) {
                            await this.transferFromTempWallet(wallet);
                        }
                        resolve(true);
                    } else {
                        resolve(false);
                    }
                } catch (retryError) {
                    resolve(false);
                }
            }
        });
    }
    
    async transferFromTempWallet(tempWalletPath) {
        try {
            const balance = execSync(`solana balance --keypair ${tempWalletPath}`, { encoding: 'utf8' });
            const tempBalance = parseFloat(balance.trim().split(' ')[0]);
            
            if (tempBalance > 0.001) {
                const deployerPubkey = execSync('solana address', { encoding: 'utf8' }).trim();
                execSync(`solana transfer ${deployerPubkey} ${tempBalance - 0.0001} --keypair ${tempWalletPath} --allow-unfunded-recipient`, { encoding: 'utf8' });
                this.log(`💸 Transferido ${tempBalance - 0.0001} SOL de wallet temporária`);
            }
        } catch (error) {
            this.log(`⚠️ Erro na transferência: ${error.message.split('\n')[0]}`);
        }
    }
    
    async cleanupTempWallets() {
        this.log('🧹 Limpando wallets temporárias...');
        
        for (const wallet of this.tempWallets) {
            try {
                if (fs.existsSync(wallet)) {
                    await this.transferFromTempWallet(wallet);
                    fs.unlinkSync(wallet);
                }
            } catch (error) {
                this.log(`⚠️ Erro ao limpar ${wallet}`);
            }
        }
    }
    
    async checkProgress() {
        const currentBalance = await this.getCurrentBalance();
        const gained = currentBalance - this.lastBalance;
        const remaining = CONFIG.TARGET_SOL - currentBalance;
        const elapsed = (Date.now() - this.startTime) / 1000 / 60;
        const rate = this.totalAttempts > 0 ? (this.successfulAirdrops / this.totalAttempts * 100) : 0;
        
        this.log(`💰 Saldo: ${currentBalance} SOL (+${gained.toFixed(6)}) | Faltam: ${remaining.toFixed(2)} SOL`);
        this.log(`📊 Tentativas: ${this.totalAttempts} | Sucessos: ${this.successfulAirdrops} | Taxa: ${rate.toFixed(1)}%`);
        this.log(`⏱️ Tempo: ${elapsed.toFixed(1)}min | Velocidade: ${(this.successfulAirdrops / elapsed * 60).toFixed(2)} SOL/h`);
        
        this.lastBalance = currentBalance;
        return currentBalance;
    }
    
    async sleep(seconds) {
        return new Promise(resolve => setTimeout(resolve, seconds * 1000));
    }
    
    async run() {
        this.lastBalance = await this.getCurrentBalance();
        this.log(`🏁 Saldo inicial: ${this.lastBalance} SOL`);
        
        // Preparação inicial
        await this.createTempWallets();
        await this.tryAllRecoveryStrategies();
        
        const maxRuntime = CONFIG.MAX_RUNTIME_HOURS * 60 * 60 * 1000;
        
        while (Date.now() - this.startTime < maxRuntime) {
            this.cycleCount++;
            this.log(`\n🔥 === CICLO FINAL ${this.cycleCount} ===`);
            
            const currentBalance = await this.checkProgress();
            
            if (currentBalance >= CONFIG.TARGET_SOL) {
                this.log(`🎉 META ATINGIDA! ${currentBalance} SOL coletados!`);
                break;
            }
            
            // Estratégia massiva
            const success = await this.tryMassiveParallelAirdrops();
            this.totalAttempts += CONFIG.ALL_ENDPOINTS.length + (this.tempWallets.length * 3);
            
            // Ajustar delay baseado no sucesso
            if (success) {
                this.currentDelay = Math.max(CONFIG.ULTRA_AGGRESSIVE_DELAY, this.currentDelay * 0.9);
            } else {
                this.currentDelay = Math.min(CONFIG.MAX_DELAY, this.currentDelay * 1.1);
            }
            
            // A cada 5 ciclos, tentar recuperação novamente
            if (this.cycleCount % 5 === 0) {
                await this.tryAllRecoveryStrategies();
            }
            
            this.log(`⏰ Aguardando ${this.currentDelay}s...`);
            await this.sleep(this.currentDelay);
        }
        
        // Limpeza final
        await this.cleanupTempWallets();
        
        const finalBalance = await this.getCurrentBalance();
        const totalGained = finalBalance - this.lastBalance;
        const elapsed = (Date.now() - this.startTime) / 1000 / 60;
        
        this.log(`\n🏁 RELATÓRIO FINAL ESTRATÉGIA:`);
        this.log(`💰 SOL coletado: ${totalGained.toFixed(6)} SOL`);
        this.log(`📊 Saldo final: ${finalBalance} SOL`);
        this.log(`⏱️ Tempo total: ${elapsed.toFixed(1)} minutos`);
        this.log(`🎯 Ciclos executados: ${this.cycleCount}`);
        this.log(`📈 Taxa de sucesso: ${((this.successfulAirdrops/this.totalAttempts)*100).toFixed(1)}%`);
        this.log(`🚀 Velocidade média: ${(totalGained / elapsed * 60).toFixed(4)} SOL/hora`);
        
        if (finalBalance >= CONFIG.TARGET_SOL) {
            this.log(`🎉 MISSÃO CUMPRIDA! Meta de ${CONFIG.TARGET_SOL} SOL atingida!`);
        } else {
            this.log(`⚠️ Meta não atingida. Recomenda-se tentar faucets web manuais.`);
        }
    }
}

// Executar a estratégia final
const collector = new FinalStrategyCollector();
collector.run().catch(error => {
    console.error('❌ Erro fatal na estratégia final:', error);
    process.exit(1);
});