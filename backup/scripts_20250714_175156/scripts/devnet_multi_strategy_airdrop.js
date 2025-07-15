#!/usr/bin/env node

/**
 * GMC Token - Devnet Multi-Strategy SOL Collector
 * 
 * Implementa estratégias diversificadas para contornar os rate limits mais restritivos de 2024:
 * - Múltiplas fontes: CLI, faucets web, RPC providers
 * - Rotação de endpoints RPC
 * - Delays adaptativos baseados em taxa de sucesso
 * - Fallback para faucets alternativos
 * - Sistema de retry persistente com backoff exponencial
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Configurações otimizadas para 2024
const CONFIG = {
    TARGET_SOL: 25,
    SOL_PER_ATTEMPT: 1,
    MAX_RUNTIME_HOURS: 4,
    BASE_DELAY_SECONDS: 120, // Delay base aumentado para 2 minutos
    MAX_DELAY_SECONDS: 600,  // Máximo 10 minutos
    MAX_RETRIES_PER_SOURCE: 5,
    SUCCESS_RATE_THRESHOLD: 0.1, // 10% de sucesso mínimo
    
    // Endpoints RPC alternativos
    RPC_ENDPOINTS: [
        'https://api.devnet.solana.com',
        'https://devnet.helius-rpc.com/?api-key=demo',
        'https://solana-devnet.g.alchemy.com/v2/demo',
        'https://rpc.ankr.com/solana_devnet'
    ],
    
    // Faucets web alternativos
    WEB_FAUCETS: [
        {
            name: 'DevnetFaucet.org',
            url: 'https://devnetfaucet.org',
            note: 'Rate limits separados'
        },
        {
            name: 'QuickNode Faucet',
            url: 'https://faucet.quicknode.com/solana/devnet',
            note: 'Pode ter fila de espera'
        },
        {
            name: 'Solana Foundation',
            url: 'https://faucet.solana.com',
            note: 'Faucet oficial'
        }
    ],
    
    // Discord faucets (apenas informativos)
    DISCORD_FAUCETS: [
        {
            name: 'The 76 Devs',
            command: '!gibsol',
            note: 'Canal BOT commands'
        },
        {
            name: 'LamportDAO',
            command: '/drop <address> <amount>',
            note: 'Canal BOT commands'
        }
    ]
};

class MultiStrategyAirdropCollector {
    constructor() {
        this.startTime = Date.now();
        this.totalCollected = 0;
        this.attempts = 0;
        this.successes = 0;
        this.currentDelay = CONFIG.BASE_DELAY_SECONDS;
        this.currentRpcIndex = 0;
        this.deployerAddress = null;
        this.stats = {
            cli_attempts: 0,
            cli_successes: 0,
            web_faucet_attempts: 0,
            web_faucet_successes: 0,
            total_rate_limits: 0
        };
    }

    log(message, type = 'info') {
        const timestamp = new Date().toLocaleString('pt-BR');
        const icons = {
            info: 'ℹ️',
            success: '✅',
            warning: '⚠️',
            error: '❌',
            strategy: '🎯',
            wait: '⏱️',
            stats: '📊'
        };
        console.log(`[${timestamp}] ${icons[type]} ${message}`);
    }

    async setupEnvironment() {
        try {
            this.log('Configurando ambiente Devnet...', 'info');
            
            // Configurar para devnet
            execSync('solana config set --url devnet', { stdio: 'pipe' });
            
            // Carregar endereço do deployer
            const deployerPath = path.join(__dirname, '../.devnet-keys/deployer.json');
            if (!fs.existsSync(deployerPath)) {
                throw new Error('Arquivo deployer.json não encontrado');
            }
            
            const deployerKey = JSON.parse(fs.readFileSync(deployerPath, 'utf8'));
            const deployerKeypair = deployerKey.slice(0, 32);
            
            // Obter endereço público
            const result = execSync('solana address', { encoding: 'utf8' }).trim();
            this.deployerAddress = result;
            
            this.log(`Deployer: ${this.deployerAddress}`, 'info');
            
            return true;
        } catch (error) {
            this.log(`Erro na configuração: ${error.message}`, 'error');
            return false;
        }
    }

    async getCurrentBalance() {
        try {
            const result = execSync('solana balance', { encoding: 'utf8' }).trim();
            const balance = parseFloat(result.split(' ')[0]);
            return balance;
        } catch (error) {
            this.log(`Erro ao obter saldo: ${error.message}`, 'warning');
            return 0;
        }
    }

    getNextRpcEndpoint() {
        const endpoint = CONFIG.RPC_ENDPOINTS[this.currentRpcIndex];
        this.currentRpcIndex = (this.currentRpcIndex + 1) % CONFIG.RPC_ENDPOINTS.length;
        return endpoint;
    }

    async attemptCliAirdrop() {
        this.stats.cli_attempts++;
        
        try {
            const endpoint = this.getNextRpcEndpoint();
            this.log(`Tentativa CLI com endpoint: ${endpoint}`, 'strategy');
            
            const command = `solana airdrop ${CONFIG.SOL_PER_ATTEMPT} ${this.deployerAddress} --url ${endpoint}`;
            const result = execSync(command, { 
                encoding: 'utf8', 
                timeout: 30000,
                stdio: 'pipe'
            });
            
            if (result.includes('Signature:') || result.includes('confirmed')) {
                this.stats.cli_successes++;
                return { success: true, method: 'CLI', endpoint };
            }
            
            return { success: false, error: 'Resposta inesperada', method: 'CLI' };
            
        } catch (error) {
            const errorMsg = error.message || error.toString();
            
            if (errorMsg.includes('rate limit') || errorMsg.includes('Rate limit')) {
                this.stats.total_rate_limits++;
                return { success: false, error: 'Rate limit', method: 'CLI', rateLimited: true };
            }
            
            return { success: false, error: errorMsg, method: 'CLI' };
        }
    }

    async attemptWebFaucet(faucet) {
        this.stats.web_faucet_attempts++;
        
        // Simulação de tentativa de faucet web (implementação real requereria automação web)
        this.log(`Faucet web disponível: ${faucet.name} - ${faucet.url}`, 'info');
        this.log(`Nota: ${faucet.note}`, 'info');
        
        // Retorna falso para forçar uso de outros métodos
        return { success: false, error: 'Requer interação manual', method: 'Web Faucet' };
    }

    calculateAdaptiveDelay() {
        const successRate = this.attempts > 0 ? this.successes / this.attempts : 0;
        
        if (successRate < CONFIG.SUCCESS_RATE_THRESHOLD) {
            // Taxa de sucesso baixa - aumentar delay
            this.currentDelay = Math.min(
                this.currentDelay * 1.5,
                CONFIG.MAX_DELAY_SECONDS
            );
        } else if (successRate > 0.3) {
            // Taxa de sucesso boa - diminuir delay gradualmente
            this.currentDelay = Math.max(
                this.currentDelay * 0.9,
                CONFIG.BASE_DELAY_SECONDS
            );
        }
        
        return Math.floor(this.currentDelay);
    }

    async performAirdropCycle() {
        this.attempts++;
        
        this.log(`Ciclo ${this.attempts}: Tentando coletar ${CONFIG.SOL_PER_ATTEMPT} SOL`, 'strategy');
        
        // Estratégia 1: CLI com rotação de endpoints
        let result = await this.attemptCliAirdrop();
        
        if (result.success) {
            this.successes++;
            this.totalCollected += CONFIG.SOL_PER_ATTEMPT;
            this.log(`Sucesso via ${result.method}! Total coletado: ${this.totalCollected} SOL`, 'success');
            return true;
        }
        
        this.log(`Falha via ${result.method}: ${result.error}`, 'warning');
        
        // Estratégia 2: Informar sobre faucets web alternativos
        if (this.attempts % 5 === 0) {
            this.log('Considere usar faucets web alternativos:', 'info');
            CONFIG.WEB_FAUCETS.forEach(faucet => {
                this.log(`  • ${faucet.name}: ${faucet.url}`, 'info');
            });
        }
        
        // Estratégia 3: Informar sobre Discord faucets
        if (this.attempts % 10 === 0) {
            this.log('Faucets Discord disponíveis:', 'info');
            CONFIG.DISCORD_FAUCETS.forEach(faucet => {
                this.log(`  • ${faucet.name}: ${faucet.command}`, 'info');
            });
        }
        
        return false;
    }

    async waitWithProgress(seconds) {
        this.log(`Aguardando ${seconds}s antes da próxima tentativa...`, 'wait');
        
        for (let i = seconds; i > 0; i--) {
            if (i % 30 === 0 || i <= 10) {
                process.stdout.write(`\r⏱️  ${i}s restantes...`);
            }
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
        
        process.stdout.write('\r');
    }

    printStats() {
        const runtime = (Date.now() - this.startTime) / 1000 / 60; // minutos
        const successRate = this.attempts > 0 ? (this.successes / this.attempts * 100).toFixed(1) : '0.0';
        
        this.log('='.repeat(60), 'stats');
        this.log('ESTATÍSTICAS DETALHADAS', 'stats');
        this.log('='.repeat(60), 'stats');
        this.log(`Tempo de execução: ${runtime.toFixed(1)} minutos`, 'stats');
        this.log(`SOL coletado: ${this.totalCollected}/${CONFIG.TARGET_SOL}`, 'stats');
        this.log(`Tentativas totais: ${this.attempts}`, 'stats');
        this.log(`Sucessos: ${this.successes}`, 'stats');
        this.log(`Taxa de sucesso: ${successRate}%`, 'stats');
        this.log(`Rate limits encontrados: ${this.stats.total_rate_limits}`, 'stats');
        this.log(`Delay atual: ${this.currentDelay}s`, 'stats');
        this.log('', 'stats');
        this.log('POR MÉTODO:', 'stats');
        this.log(`CLI: ${this.stats.cli_successes}/${this.stats.cli_attempts}`, 'stats');
        this.log(`Web Faucets: ${this.stats.web_faucet_successes}/${this.stats.web_faucet_attempts}`, 'stats');
        this.log('='.repeat(60), 'stats');
    }

    async run() {
        this.log('🚀 Iniciando GMC Multi-Strategy SOL Collector', 'info');
        this.log(`Meta: ${CONFIG.TARGET_SOL} SOL em ${CONFIG.MAX_RUNTIME_HOURS}h`, 'info');
        
        if (!await this.setupEnvironment()) {
            this.log('Falha na configuração do ambiente', 'error');
            return false;
        }
        
        const initialBalance = await this.getCurrentBalance();
        this.log(`Saldo inicial: ${initialBalance} SOL`, 'info');
        
        const needed = CONFIG.TARGET_SOL - initialBalance;
        if (needed <= 0) {
            this.log('Meta já atingida!', 'success');
            return true;
        }
        
        this.log(`Necessário: ${needed.toFixed(6)} SOL`, 'info');
        this.log('', 'info');
        
        const maxRuntime = CONFIG.MAX_RUNTIME_HOURS * 60 * 60 * 1000;
        
        while (Date.now() - this.startTime < maxRuntime) {
            const currentBalance = await this.getCurrentBalance();
            
            if (currentBalance >= CONFIG.TARGET_SOL) {
                this.log('🎉 Meta atingida!', 'success');
                break;
            }
            
            const success = await this.performAirdropCycle();
            
            // Imprimir estatísticas a cada 10 tentativas
            if (this.attempts % 10 === 0) {
                this.printStats();
            }
            
            if (!success) {
                const delay = this.calculateAdaptiveDelay();
                await this.waitWithProgress(delay);
            } else {
                // Delay menor após sucesso
                await this.waitWithProgress(30);
            }
        }
        
        this.printStats();
        
        const finalBalance = await this.getCurrentBalance();
        this.log(`Saldo final: ${finalBalance} SOL`, 'info');
        
        if (finalBalance >= CONFIG.TARGET_SOL) {
            this.log('✅ Coleta concluída com sucesso!', 'success');
            return true;
        } else {
            this.log('⚠️ Meta não atingida no tempo limite', 'warning');
            this.log('Recomendações:', 'info');
            this.log('1. Use faucets web manuais listados acima', 'info');
            this.log('2. Tente faucets Discord da comunidade', 'info');
            this.log('3. Execute novamente após algumas horas', 'info');
            return false;
        }
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    const collector = new MultiStrategyAirdropCollector();
    
    // Handlers para interrupção
    process.on('SIGINT', () => {
        console.log('\n');
        collector.log('Interrompido pelo usuário', 'warning');
        collector.printStats();
        process.exit(0);
    });
    
    collector.run().then(success => {
        process.exit(success ? 0 : 1);
    }).catch(error => {
        collector.log(`Erro fatal: ${error.message}`, 'error');
        process.exit(1);
    });
}

module.exports = MultiStrategyAirdropCollector;