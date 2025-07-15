#!/usr/bin/env node

/**
 * DEVNET AGGRESSIVE SOL COLLECTOR 2024
 * 
 * Estratégia Ultra-Otimizada para Devnet:
 * - Múltiplas tentativas paralelas com wallets auxiliares
 * - Rotação agressiva de endpoints com delays reduzidos
 * - Recuperação de SOL de buffer accounts e programas antigos
 * - Sistema adaptativo com backoff exponencial otimizado
 * - Monitoramento contínuo e relatórios detalhados
 * 
 * Meta: 25 SOL em 3 horas
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuração otimizada para 2024
const CONFIG = {
    TARGET_SOL: 25,
    MAX_RUNTIME_HOURS: 3,
    PARALLEL_ATTEMPTS: 3,
    MIN_DELAY: 30, // Delay mínimo reduzido
    MAX_DELAY: 120, // Delay máximo reduzido
    BACKOFF_MULTIPLIER: 1.2, // Backoff mais suave
    
    // Endpoints otimizados (removendo os problemáticos)
    RPC_ENDPOINTS: [
        'https://api.devnet.solana.com',
        'https://solana-devnet.g.alchemy.com/v2/demo',
        'https://devnet.solana.dappio.xyz'
    ],
    
    // Wallets auxiliares para tentativas paralelas
    AUX_WALLETS: [
        '.devnet-keys/aux/aux_0.json',
        '.devnet-keys/aux/aux_1.json',
        '.devnet-keys/aux/aux_2.json'
    ]
};

class AggressiveSOLCollector {
    constructor() {
        this.startTime = Date.now();
        this.currentEndpointIndex = 0;
        this.consecutiveFailures = 0;
        this.totalAttempts = 0;
        this.successfulAirdrops = 0;
        this.currentDelay = CONFIG.MIN_DELAY;
        this.cycleCount = 0;
        this.lastBalance = 0;
        
        this.log('🚀 Iniciando Coletor Agressivo de SOL - Devnet 2024');
        this.log(`🎯 Meta: ${CONFIG.TARGET_SOL} SOL em ${CONFIG.MAX_RUNTIME_HOURS} horas`);
    }
    
    log(message) {
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000 / 60);
        const timestamp = new Date().toLocaleString('pt-BR');
        console.log(`[${timestamp}] 📈 [${elapsed}min] ${message}`);
    }
    
    async getCurrentBalance() {
        try {
            const result = execSync('solana balance', { encoding: 'utf8' });
            return parseFloat(result.trim().split(' ')[0]);
        } catch (error) {
            this.log(`❌ Erro ao obter saldo: ${error.message}`);
            return 0;
        }
    }
    
    async tryRecoveryStrategy() {
        this.log('🔧 Executando estratégia de recuperação de SOL...');
        
        try {
            // Tentar recuperar SOL de buffer accounts
            const bufferAccounts = execSync('solana program show --buffers', { encoding: 'utf8' });
            if (bufferAccounts.includes('Buffer')) {
                this.log('📦 Buffer accounts encontrados, tentando recuperar...');
                execSync('solana program close --buffers', { encoding: 'utf8' });
                this.log('✅ Buffer accounts fechados com sucesso');
            }
        } catch (error) {
            this.log(`⚠️ Recuperação de buffers falhou: ${error.message}`);
        }
        
        // Consolidar SOL de wallets auxiliares
        await this.consolidateAuxWallets();
    }
    
    async consolidateAuxWallets() {
        this.log('💰 Consolidando SOL de wallets auxiliares...');
        
        for (const auxWallet of CONFIG.AUX_WALLETS) {
            try {
                const auxPath = path.join(process.cwd(), auxWallet);
                if (fs.existsSync(auxPath)) {
                    const balance = execSync(`solana balance --keypair ${auxPath}`, { encoding: 'utf8' });
                    const auxBalance = parseFloat(balance.trim().split(' ')[0]);
                    
                    if (auxBalance > 0.001) {
                        this.log(`💸 Transferindo ${auxBalance} SOL de ${auxWallet}`);
                        const deployerPubkey = execSync('solana address', { encoding: 'utf8' }).trim();
                        execSync(`solana transfer ${deployerPubkey} ${auxBalance - 0.0001} --keypair ${auxPath} --allow-unfunded-recipient`, { encoding: 'utf8' });
                        this.log(`✅ Transferência concluída de ${auxWallet}`);
                    }
                }
            } catch (error) {
                this.log(`⚠️ Erro ao consolidar ${auxWallet}: ${error.message}`);
            }
        }
    }
    
    async attemptParallelAirdrops() {
        this.log(`🪂 Tentando ${CONFIG.PARALLEL_ATTEMPTS} airdrops paralelos...`);
        
        const promises = [];
        
        for (let i = 0; i < CONFIG.PARALLEL_ATTEMPTS; i++) {
            const endpointIndex = (this.currentEndpointIndex + i) % CONFIG.RPC_ENDPOINTS.length;
            const endpoint = CONFIG.RPC_ENDPOINTS[endpointIndex];
            
            promises.push(this.attemptSingleAirdrop(endpoint, i));
        }
        
        const results = await Promise.allSettled(promises);
        
        let successCount = 0;
        results.forEach((result, index) => {
            if (result.status === 'fulfilled' && result.value) {
                successCount++;
                this.log(`✅ Airdrop paralelo ${index + 1} bem-sucedido`);
            }
        });
        
        return successCount > 0;
    }
    
    async attemptSingleAirdrop(endpoint, attemptIndex) {
        return new Promise((resolve) => {
            try {
                this.log(`🎯 [${attemptIndex + 1}] Tentando via ${endpoint}`);
                
                const result = execSync(`solana airdrop 1 --url ${endpoint}`, {
                    encoding: 'utf8',
                    timeout: 30000
                });
                
                if (result.includes('1 SOL')) {
                    this.successfulAirdrops++;
                    resolve(true);
                } else {
                    resolve(false);
                }
            } catch (error) {
                this.log(`❌ [${attemptIndex + 1}] Falha em ${endpoint}: ${error.message.split('\n')[0]}`);
                resolve(false);
            }
        });
    }
    
    rotateEndpoint() {
        this.currentEndpointIndex = (this.currentEndpointIndex + 1) % CONFIG.RPC_ENDPOINTS.length;
        this.log(`🔄 Rotacionando para: ${CONFIG.RPC_ENDPOINTS[this.currentEndpointIndex]}`);
    }
    
    adjustDelay(success) {
        if (success) {
            this.currentDelay = Math.max(CONFIG.MIN_DELAY, this.currentDelay * 0.8);
            this.consecutiveFailures = 0;
        } else {
            this.consecutiveFailures++;
            if (this.consecutiveFailures >= 2) {
                this.currentDelay = Math.min(CONFIG.MAX_DELAY, this.currentDelay * CONFIG.BACKOFF_MULTIPLIER);
                this.rotateEndpoint();
            }
        }
    }
    
    async checkProgress() {
        const currentBalance = await this.getCurrentBalance();
        const gained = currentBalance - this.lastBalance;
        const remaining = CONFIG.TARGET_SOL - currentBalance;
        const elapsed = (Date.now() - this.startTime) / 1000 / 60;
        
        this.log(`💰 Saldo: ${currentBalance} SOL (+${gained.toFixed(6)}) | Faltam: ${remaining.toFixed(2)} SOL`);
        this.log(`📊 Tentativas: ${this.totalAttempts} | Sucessos: ${this.successfulAirdrops} | Taxa: ${((this.successfulAirdrops/this.totalAttempts)*100).toFixed(1)}%`);
        this.log(`⏱️ Tempo: ${elapsed.toFixed(1)}min | Próximo delay: ${this.currentDelay}s`);
        
        this.lastBalance = currentBalance;
        return currentBalance;
    }
    
    async sleep(seconds) {
        this.log(`⏰ Aguardando ${seconds}s antes do próximo ciclo...`);
        return new Promise(resolve => setTimeout(resolve, seconds * 1000));
    }
    
    async run() {
        this.lastBalance = await this.getCurrentBalance();
        this.log(`🏁 Saldo inicial: ${this.lastBalance} SOL`);
        
        // Executar recuperação inicial
        await this.tryRecoveryStrategy();
        
        const maxRuntime = CONFIG.MAX_RUNTIME_HOURS * 60 * 60 * 1000;
        
        while (Date.now() - this.startTime < maxRuntime) {
            this.cycleCount++;
            this.log(`\n=== CICLO AGRESSIVO ${this.cycleCount} ===`);
            
            // Verificar progresso
            const currentBalance = await this.checkProgress();
            
            if (currentBalance >= CONFIG.TARGET_SOL) {
                this.log(`🎉 META ATINGIDA! ${currentBalance} SOL coletados!`);
                break;
            }
            
            // Tentar airdrops paralelos
            this.totalAttempts += CONFIG.PARALLEL_ATTEMPTS;
            const success = await this.attemptParallelAirdrops();
            
            // Ajustar estratégia
            this.adjustDelay(success);
            
            // A cada 10 ciclos, tentar recuperação novamente
            if (this.cycleCount % 10 === 0) {
                await this.tryRecoveryStrategy();
            }
            
            // Aguardar antes do próximo ciclo
            await this.sleep(this.currentDelay);
        }
        
        const finalBalance = await this.getCurrentBalance();
        const totalGained = finalBalance - this.lastBalance;
        const elapsed = (Date.now() - this.startTime) / 1000 / 60;
        
        this.log(`\n🏁 RELATÓRIO FINAL:`);
        this.log(`💰 SOL coletado: ${totalGained.toFixed(6)} SOL`);
        this.log(`📊 Saldo final: ${finalBalance} SOL`);
        this.log(`⏱️ Tempo total: ${elapsed.toFixed(1)} minutos`);
        this.log(`🎯 Ciclos executados: ${this.cycleCount}`);
        this.log(`📈 Taxa de sucesso: ${((this.successfulAirdrops/this.totalAttempts)*100).toFixed(1)}%`);
    }
}

// Executar o coletor
const collector = new AggressiveSOLCollector();
collector.run().catch(error => {
    console.error('❌ Erro fatal:', error);
    process.exit(1);
});