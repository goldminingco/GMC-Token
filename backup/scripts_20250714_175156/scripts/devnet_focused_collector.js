#!/usr/bin/env node

/**
 * GMC Token - Focused Devnet SOL Collector
 * 
 * Estratégia focada e otimizada para 2024:
 * - Airdrops CLI com rotação inteligente de endpoints
 * - Sistema de retry adaptativo baseado em rate limits
 * - Delays progressivos e recuperação automática
 * - Monitoramento contínuo de saldo
 * 
 * Meta: 25 SOL em 4 horas usando estratégias comprovadamente eficazes
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

class FocusedDevnetCollector {
    constructor() {
        this.targetAmount = 25.0;
        this.maxDuration = 4 * 60 * 60 * 1000; // 4 horas
        this.startTime = Date.now();
        this.deployerAddress = null;
        this.currentBalance = 0;
        this.totalCollected = 0;
        
        // Endpoints RPC otimizados para 2024
        this.rpcEndpoints = [
            'https://api.devnet.solana.com',
            'https://devnet.helius-rpc.com',
            'https://rpc-devnet.solana.com',
            'https://solana-devnet.g.alchemy.com/v2/demo',
            'https://devnet.solana.dappio.xyz',
            'https://api.devnet.solana.com' // Repetir o primeiro para ciclo
        ];
        
        this.currentRpcIndex = 0;
        this.cycleCount = 0;
        this.successCount = 0;
        this.failureCount = 0;
        this.consecutiveFailures = 0;
        
        // Sistema de delays adaptativos
        this.baseDelay = 60; // 1 minuto base
        this.currentDelay = this.baseDelay;
        this.maxDelay = 300; // 5 minutos máximo
        this.minDelay = 30; // 30 segundos mínimo
        
        // Estatísticas por endpoint
        this.endpointStats = {};
        this.rpcEndpoints.forEach(endpoint => {
            this.endpointStats[endpoint] = {
                attempts: 0,
                successes: 0,
                failures: 0,
                lastSuccess: null,
                avgDelay: this.baseDelay
            };
        });
    }

    log(message, type = 'info') {
        const timestamp = new Date().toLocaleString('pt-BR');
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000 / 60);
        const icons = {
            info: 'ℹ️',
            success: '✅',
            warning: '⚠️',
            error: '❌',
            airdrop: '🪂',
            money: '💰',
            target: '🎯',
            time: '⏰',
            rpc: '🔄',
            stats: '📊'
        };
        
        const progress = this.currentBalance >= this.targetAmount ? '🎉' : 
                        this.currentBalance >= this.targetAmount * 0.8 ? '🔥' :
                        this.currentBalance >= this.targetAmount * 0.5 ? '⚡' : '📈';
        
        console.log(`[${timestamp}] ${icons[type]} [${elapsed}min] ${progress} ${message}`);
    }

    async setupEnvironment() {
        try {
            this.log('🚀 Iniciando Focused SOL Collector para Devnet', 'info');
            
            // Obter endereço do deployer
            const result = execSync('solana address', { encoding: 'utf8' }).trim();
            this.deployerAddress = result;
            
            this.currentBalance = await this.getCurrentBalance();
            const needed = Math.max(0, this.targetAmount - this.currentBalance);
            
            this.log(`Deployer: ${this.deployerAddress}`, 'info');
            this.log(`Saldo atual: ${this.currentBalance} SOL`, 'money');
            this.log(`Meta: ${this.targetAmount} SOL`, 'target');
            this.log(`Necessário: ${needed.toFixed(6)} SOL`, 'target');
            
            return true;
        } catch (error) {
            this.log(`Erro na configuração: ${error.message}`, 'error');
            return false;
        }
    }

    async getCurrentBalance() {
        try {
            const result = execSync('solana balance', { encoding: 'utf8' }).trim();
            return parseFloat(result.split(' ')[0]);
        } catch (error) {
            this.log(`Erro ao obter saldo: ${error.message}`, 'warning');
            return this.currentBalance;
        }
    }

    async updateBalance() {
        const oldBalance = this.currentBalance;
        this.currentBalance = await this.getCurrentBalance();
        const diff = this.currentBalance - oldBalance;
        
        if (diff > 0) {
            this.totalCollected += diff;
            this.log(`Saldo atualizado: ${this.currentBalance} SOL (+${diff.toFixed(6)})`, 'money');
            return diff;
        }
        
        return 0;
    }

    getCurrentEndpoint() {
        return this.rpcEndpoints[this.currentRpcIndex];
    }

    rotateEndpoint() {
        this.currentRpcIndex = (this.currentRpcIndex + 1) % this.rpcEndpoints.length;
        const newEndpoint = this.getCurrentEndpoint();
        this.log(`Rotacionando para endpoint: ${newEndpoint}`, 'rpc');
        return newEndpoint;
    }

    calculateAdaptiveDelay() {
        const endpoint = this.getCurrentEndpoint();
        const stats = this.endpointStats[endpoint];
        
        if (this.consecutiveFailures === 0) {
            // Sucesso recente - diminuir delay gradualmente
            this.currentDelay = Math.max(this.minDelay, this.currentDelay * 0.9);
        } else if (this.consecutiveFailures < 3) {
            // Poucas falhas - aumentar delay moderadamente
            this.currentDelay = Math.min(this.maxDelay, this.currentDelay * 1.2);
        } else if (this.consecutiveFailures < 6) {
            // Muitas falhas - aumentar delay significativamente
            this.currentDelay = Math.min(this.maxDelay, this.currentDelay * 1.5);
        } else {
            // Falhas excessivas - delay máximo e rotação forçada
            this.currentDelay = this.maxDelay;
            this.rotateEndpoint();
        }
        
        // Atualizar estatísticas do endpoint
        stats.avgDelay = this.currentDelay;
        
        return Math.floor(this.currentDelay);
    }

    async executeAirdrop() {
        const endpoint = this.getCurrentEndpoint();
        const stats = this.endpointStats[endpoint];
        
        try {
            this.log(`Tentando airdrop via ${endpoint}...`, 'airdrop');
            stats.attempts++;
            
            // Configurar endpoint temporariamente
            execSync(`solana config set --url ${endpoint}`, { stdio: 'pipe' });
            
            const initialBalance = this.currentBalance;
            
            // Tentar airdrop de 1 SOL (estratégia conservadora para 2024)
            const result = execSync('solana airdrop 1', {
                encoding: 'utf8',
                timeout: 45000 // 45 segundos timeout
            });
            
            // Verificar se o comando foi bem-sucedido
            if (result.includes('Signature:') || result.includes('confirmed') || result.includes('finalized')) {
                // Aguardar confirmação na blockchain
                await new Promise(resolve => setTimeout(resolve, 5000));
                
                const gained = await this.updateBalance();
                
                if (gained > 0) {
                    stats.successes++;
                    stats.lastSuccess = Date.now();
                    this.successCount++;
                    this.consecutiveFailures = 0;
                    
                    this.log(`✅ Airdrop bem-sucedido: +${gained} SOL (Total: ${this.currentBalance} SOL)`, 'success');
                    return true;
                } else {
                    throw new Error('Saldo não aumentou após airdrop');
                }
            } else {
                throw new Error('Comando airdrop não retornou confirmação');
            }
            
        } catch (error) {
            stats.failures++;
            this.failureCount++;
            this.consecutiveFailures++;
            
            const errorMsg = error.message.toLowerCase();
            
            if (errorMsg.includes('rate') || errorMsg.includes('limit') || errorMsg.includes('too many')) {
                this.log(`Rate limit detectado em ${endpoint}`, 'warning');
            } else if (errorMsg.includes('timeout') || errorMsg.includes('network')) {
                this.log(`Problema de rede com ${endpoint}`, 'warning');
            } else {
                this.log(`Erro em ${endpoint}: ${error.message}`, 'warning');
            }
            
            return false;
            
        } finally {
            // Sempre restaurar endpoint padrão
            try {
                execSync('solana config set --url devnet', { stdio: 'pipe' });
            } catch (e) {
                // Ignorar erros de restauração
            }
        }
    }

    generateProgressReport() {
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000 / 60);
        const remaining = Math.max(0, this.targetAmount - this.currentBalance);
        const progress = (this.currentBalance / this.targetAmount * 100).toFixed(1);
        const successRate = this.cycleCount > 0 ? (this.successCount / this.cycleCount * 100).toFixed(1) : '0';
        
        this.log('\n=== RELATÓRIO DE PROGRESSO ===', 'stats');
        this.log(`Tempo: ${elapsed}/${Math.floor(this.maxDuration/1000/60)} min`, 'time');
        this.log(`Progresso: ${progress}% (${this.currentBalance}/${this.targetAmount} SOL)`, 'target');
        this.log(`Restante: ${remaining.toFixed(6)} SOL`, 'target');
        this.log(`Coletado: ${this.totalCollected.toFixed(6)} SOL`, 'money');
        this.log(`Taxa de sucesso: ${successRate}% (${this.successCount}/${this.cycleCount})`, 'stats');
        this.log(`Falhas consecutivas: ${this.consecutiveFailures}`, 'stats');
        this.log(`Delay atual: ${this.currentDelay}s`, 'time');
        
        // Estatísticas por endpoint
        this.log('\nPerformance por endpoint:', 'stats');
        Object.entries(this.endpointStats).forEach(([endpoint, stats]) => {
            if (stats.attempts > 0) {
                const rate = (stats.successes / stats.attempts * 100).toFixed(1);
                const shortEndpoint = endpoint.replace('https://', '').split('/')[0];
                this.log(`  ${shortEndpoint}: ${stats.successes}/${stats.attempts} (${rate}%)`, 'info');
            }
        });
    }

    async executeCycle() {
        this.cycleCount++;
        this.log(`\n=== CICLO ${this.cycleCount} ===`, 'info');
        
        const success = await this.executeAirdrop();
        
        if (success) {
            // Verificar se atingiu a meta
            if (this.currentBalance >= this.targetAmount) {
                this.log('🎉 META ATINGIDA!', 'success');
                return true;
            }
        } else {
            // Em caso de falha, considerar rotação de endpoint
            if (this.consecutiveFailures >= 3) {
                this.rotateEndpoint();
            }
        }
        
        return false;
    }

    async run() {
        if (!await this.setupEnvironment()) {
            this.log('Falha na configuração inicial', 'error');
            return false;
        }
        
        // Verificar se já atingiu a meta
        if (this.currentBalance >= this.targetAmount) {
            this.log('Meta já atingida!', 'success');
            return true;
        }
        
        this.log(`Iniciando coleta com delay base de ${this.baseDelay}s`, 'info');
        
        while (Date.now() - this.startTime < this.maxDuration) {
            try {
                // Executar ciclo de airdrop
                const success = await this.executeCycle();
                
                if (success) {
                    this.log('🎉 Coleta concluída com sucesso!', 'success');
                    break;
                }
                
                // Relatório de progresso a cada 10 ciclos
                if (this.cycleCount % 10 === 0) {
                    this.generateProgressReport();
                }
                
                // Delay adaptativo
                const delay = this.calculateAdaptiveDelay();
                this.log(`Aguardando ${delay}s antes do próximo ciclo...`, 'time');
                await new Promise(resolve => setTimeout(resolve, delay * 1000));
                
            } catch (error) {
                this.log(`Erro no ciclo: ${error.message}`, 'error');
                await new Promise(resolve => setTimeout(resolve, 60000)); // 1 min em caso de erro
            }
        }
        
        // Relatório final
        this.generateProgressReport();
        
        const finalSuccess = this.currentBalance >= this.targetAmount;
        this.log(finalSuccess ? '✅ Missão cumprida!' : '⏰ Tempo esgotado', finalSuccess ? 'success' : 'warning');
        
        // Salvar log final
        await this.saveLogReport();
        
        return finalSuccess;
    }

    async saveLogReport() {
        try {
            const logsDir = path.join(__dirname, '../logs');
            if (!fs.existsSync(logsDir)) {
                fs.mkdirSync(logsDir, { recursive: true });
            }
            
            const reportPath = path.join(logsDir, `focused_collector_${Date.now()}.txt`);
            const elapsed = Math.floor((Date.now() - this.startTime) / 1000 / 60);
            
            const report = [
                '='.repeat(60),
                'RELATÓRIO FINAL - FOCUSED DEVNET SOL COLLECTOR',
                '='.repeat(60),
                `Data: ${new Date().toLocaleString('pt-BR')}`,
                `Duração: ${elapsed} minutos`,
                `Deployer: ${this.deployerAddress}`,
                `Saldo final: ${this.currentBalance} SOL`,
                `Meta: ${this.targetAmount} SOL`,
                `Total coletado: ${this.totalCollected} SOL`,
                `Ciclos executados: ${this.cycleCount}`,
                `Sucessos: ${this.successCount}`,
                `Falhas: ${this.failureCount}`,
                `Taxa de sucesso: ${this.cycleCount > 0 ? (this.successCount / this.cycleCount * 100).toFixed(1) : 0}%`,
                '',
                'ESTATÍSTICAS POR ENDPOINT:',
                ...Object.entries(this.endpointStats).map(([endpoint, stats]) => {
                    if (stats.attempts > 0) {
                        const rate = (stats.successes / stats.attempts * 100).toFixed(1);
                        return `${endpoint}: ${stats.successes}/${stats.attempts} (${rate}%)`;
                    }
                    return null;
                }).filter(Boolean),
                '',
                '='.repeat(60)
            ].join('\n');
            
            fs.writeFileSync(reportPath, report);
            this.log(`Relatório salvo: ${reportPath}`, 'info');
            
        } catch (error) {
            this.log(`Erro ao salvar relatório: ${error.message}`, 'warning');
        }
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    const collector = new FocusedDevnetCollector();
    
    // Capturar sinais para relatório final
    process.on('SIGINT', () => {
        console.log('\n🛑 Interrompido pelo usuário');
        collector.generateProgressReport();
        collector.saveLogReport();
        process.exit(0);
    });
    
    collector.run().then(success => {
        process.exit(success ? 0 : 1);
    }).catch(error => {
        console.error(`Erro fatal: ${error.message}`);
        process.exit(1);
    });
}

module.exports = FocusedDevnetCollector;