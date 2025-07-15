#!/usr/bin/env node

/**
 * GMC Token - Ultimate Devnet SOL Collector
 * 
 * Implementa TODAS as estratégias conhecidas para coletar SOL em Devnet 2024:
 * 1. Recuperação de SOL (buffer accounts, programas antigos, carteiras auxiliares)
 * 2. Airdrops CLI com múltiplos endpoints RPC
 * 3. Tentativas de web faucets
 * 4. Sistema de retry adaptativo e persistente
 * 5. Rotação inteligente de estratégias
 * 
 * Meta: Coletar 25 SOL em até 6 horas usando todas as estratégias disponíveis
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

class UltimateDevnetSolCollector {
    constructor() {
        this.targetAmount = 25.0;
        this.maxDuration = 6 * 60 * 60 * 1000; // 6 horas
        this.startTime = Date.now();
        this.deployerAddress = null;
        this.currentBalance = 0;
        this.totalCollected = 0;
        this.strategyStats = {
            recovery: { attempts: 0, success: 0, collected: 0 },
            cli_airdrop: { attempts: 0, success: 0, collected: 0 },
            web_faucet: { attempts: 0, success: 0, collected: 0 },
            rpc_rotation: { attempts: 0, success: 0, collected: 0 }
        };
        
        // Endpoints RPC para rotação
        this.rpcEndpoints = [
            'https://api.devnet.solana.com',
            'https://devnet.helius-rpc.com',
            'https://rpc-devnet.solana.com',
            'https://solana-devnet.g.alchemy.com/v2/demo',
            'https://devnet.solana.dappio.xyz'
        ];
        
        this.currentRpcIndex = 0;
        this.cycleCount = 0;
        this.consecutiveFailures = 0;
        this.adaptiveDelay = 60; // Delay inicial em segundos
    }

    log(message, type = 'info') {
        const timestamp = new Date().toLocaleString('pt-BR');
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000 / 60);
        const icons = {
            info: 'ℹ️',
            success: '✅',
            warning: '⚠️',
            error: '❌',
            recovery: '♻️',
            airdrop: '🪂',
            web: '🌐',
            rpc: '🔄',
            money: '💰',
            target: '🎯',
            time: '⏰'
        };
        
        const progress = this.currentBalance >= this.targetAmount ? '🎉' : 
                        this.currentBalance >= this.targetAmount * 0.8 ? '🔥' :
                        this.currentBalance >= this.targetAmount * 0.5 ? '⚡' : '📈';
        
        console.log(`[${timestamp}] ${icons[type]} [${elapsed}min] ${progress} ${message}`);
    }

    async setupEnvironment() {
        try {
            this.log('🚀 Iniciando Ultimate SOL Collector para Devnet', 'info');
            
            // Configurar para devnet
            execSync('solana config set --url devnet', { stdio: 'pipe' });
            
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
        }
        
        return diff;
    }

    // ESTRATÉGIA 1: Recuperação de SOL
    async executeRecoveryStrategy() {
        try {
            this.log('Executando estratégia de recuperação de SOL...', 'recovery');
            this.strategyStats.recovery.attempts++;
            
            const initialBalance = this.currentBalance;
            
            // Executar script de recuperação
            const recoveryScript = path.join(__dirname, 'devnet_sol_recovery.js');
            
            if (fs.existsSync(recoveryScript)) {
                const result = execSync(`node "${recoveryScript}"`, {
                    encoding: 'utf8',
                    timeout: 120000 // 2 minutos
                });
                
                await this.updateBalance();
                const recovered = this.currentBalance - initialBalance;
                
                if (recovered > 0) {
                    this.strategyStats.recovery.success++;
                    this.strategyStats.recovery.collected += recovered;
                    this.log(`Recuperação bem-sucedida: +${recovered.toFixed(6)} SOL`, 'success');
                    return true;
                }
            }
            
            this.log('Nenhum SOL recuperado nesta tentativa', 'info');
            return false;
            
        } catch (error) {
            this.log(`Erro na recuperação: ${error.message}`, 'warning');
            return false;
        }
    }

    // ESTRATÉGIA 2: Airdrop CLI com rotação de RPC
    async executeCliAirdropStrategy() {
        try {
            const endpoint = this.rpcEndpoints[this.currentRpcIndex];
            this.log(`Tentando airdrop CLI via ${endpoint}...`, 'airdrop');
            
            this.strategyStats.cli_airdrop.attempts++;
            
            // Configurar endpoint temporariamente
            execSync(`solana config set --url ${endpoint}`, { stdio: 'pipe' });
            
            const initialBalance = this.currentBalance;
            
            // Tentar airdrop de 1 SOL (mais conservador)
            const result = execSync('solana airdrop 1', {
                encoding: 'utf8',
                timeout: 30000
            });
            
            if (result.includes('Signature:') || result.includes('confirmed')) {
                await this.updateBalance();
                const gained = this.currentBalance - initialBalance;
                
                if (gained > 0) {
                    this.strategyStats.cli_airdrop.success++;
                    this.strategyStats.cli_airdrop.collected += gained;
                    this.log(`Airdrop CLI bem-sucedido: +${gained} SOL`, 'success');
                    this.consecutiveFailures = 0;
                    return true;
                }
            }
            
            throw new Error('Airdrop não confirmado');
            
        } catch (error) {
            this.consecutiveFailures++;
            this.log(`Airdrop CLI falhou: ${error.message}`, 'warning');
            
            // Rotacionar para próximo endpoint
            this.currentRpcIndex = (this.currentRpcIndex + 1) % this.rpcEndpoints.length;
            
            return false;
        } finally {
            // Restaurar endpoint padrão
            try {
                execSync('solana config set --url devnet', { stdio: 'pipe' });
            } catch (e) {}
        }
    }

    // ESTRATÉGIA 3: Web Faucets
    async executeWebFaucetStrategy() {
        try {
            this.log('Tentando web faucets...', 'web');
            this.strategyStats.web_faucet.attempts++;
            
            const faucets = [
                {
                    name: 'SolFaucet',
                    url: `https://solfaucet.com/api/airdrop/${this.deployerAddress}`,
                    method: 'POST'
                },
                {
                    name: 'DevnetFaucet',
                    url: `https://api.devnetfaucet.org/airdrop`,
                    method: 'POST',
                    data: { address: this.deployerAddress }
                }
            ];
            
            for (const faucet of faucets) {
                try {
                    this.log(`Tentando ${faucet.name}...`, 'web');
                    
                    const initialBalance = this.currentBalance;
                    
                    // Simular requisição (implementação básica)
                    await new Promise((resolve, reject) => {
                        const url = new URL(faucet.url);
                        const options = {
                            hostname: url.hostname,
                            port: url.port || (url.protocol === 'https:' ? 443 : 80),
                            path: url.pathname + url.search,
                            method: faucet.method,
                            headers: {
                                'Content-Type': 'application/json',
                                'User-Agent': 'GMC-Token-Collector/1.0'
                            },
                            timeout: 15000
                        };
                        
                        const client = url.protocol === 'https:' ? https : http;
                        const req = client.request(options, (res) => {
                            let data = '';
                            res.on('data', chunk => data += chunk);
                            res.on('end', () => {
                                if (res.statusCode === 200) {
                                    resolve(data);
                                } else {
                                    reject(new Error(`HTTP ${res.statusCode}`));
                                }
                            });
                        });
                        
                        req.on('error', reject);
                        req.on('timeout', () => reject(new Error('Timeout')));
                        
                        if (faucet.data) {
                            req.write(JSON.stringify(faucet.data));
                        }
                        
                        req.end();
                    });
                    
                    // Aguardar um pouco e verificar saldo
                    await new Promise(resolve => setTimeout(resolve, 10000));
                    await this.updateBalance();
                    
                    const gained = this.currentBalance - initialBalance;
                    if (gained > 0) {
                        this.strategyStats.web_faucet.success++;
                        this.strategyStats.web_faucet.collected += gained;
                        this.log(`${faucet.name} bem-sucedido: +${gained} SOL`, 'success');
                        return true;
                    }
                    
                } catch (error) {
                    this.log(`${faucet.name} falhou: ${error.message}`, 'warning');
                }
            }
            
            return false;
            
        } catch (error) {
            this.log(`Erro em web faucets: ${error.message}`, 'warning');
            return false;
        }
    }

    // ESTRATÉGIA 4: Sistema adaptativo
    calculateAdaptiveDelay() {
        // Aumentar delay baseado em falhas consecutivas
        if (this.consecutiveFailures > 10) {
            this.adaptiveDelay = Math.min(300, this.adaptiveDelay * 1.5); // Max 5 min
        } else if (this.consecutiveFailures > 5) {
            this.adaptiveDelay = Math.min(180, this.adaptiveDelay * 1.2); // Max 3 min
        } else if (this.consecutiveFailures === 0) {
            this.adaptiveDelay = Math.max(30, this.adaptiveDelay * 0.9); // Min 30s
        }
        
        return this.adaptiveDelay;
    }

    async executeCycle() {
        this.cycleCount++;
        this.log(`\n=== CICLO ${this.cycleCount} ===`, 'info');
        
        const strategies = [
            { name: 'Recovery', func: () => this.executeRecoveryStrategy(), priority: 1 },
            { name: 'CLI Airdrop', func: () => this.executeCliAirdropStrategy(), priority: 2 },
            { name: 'Web Faucet', func: () => this.executeWebFaucetStrategy(), priority: 3 }
        ];
        
        // Executar estratégias em ordem de prioridade
        for (const strategy of strategies) {
            try {
                this.log(`Executando estratégia: ${strategy.name}`, 'info');
                const success = await strategy.func();
                
                if (success) {
                    this.log(`Estratégia ${strategy.name} bem-sucedida!`, 'success');
                    await this.updateBalance();
                    
                    // Se atingiu a meta, parar
                    if (this.currentBalance >= this.targetAmount) {
                        this.log('🎉 META ATINGIDA!', 'success');
                        return true;
                    }
                }
                
                // Pequeno delay entre estratégias
                await new Promise(resolve => setTimeout(resolve, 5000));
                
            } catch (error) {
                this.log(`Erro na estratégia ${strategy.name}: ${error.message}`, 'error');
            }
        }
        
        return false;
    }

    generateProgressReport() {
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000 / 60);
        const remaining = Math.max(0, this.targetAmount - this.currentBalance);
        const progress = (this.currentBalance / this.targetAmount * 100).toFixed(1);
        
        this.log('\n=== RELATÓRIO DE PROGRESSO ===', 'info');
        this.log(`Tempo decorrido: ${elapsed} minutos`, 'time');
        this.log(`Progresso: ${progress}% (${this.currentBalance}/${this.targetAmount} SOL)`, 'target');
        this.log(`Restante: ${remaining.toFixed(6)} SOL`, 'target');
        this.log(`Total coletado: ${this.totalCollected.toFixed(6)} SOL`, 'money');
        
        this.log('\nEstatísticas por estratégia:', 'info');
        Object.entries(this.strategyStats).forEach(([name, stats]) => {
            const successRate = stats.attempts > 0 ? (stats.success / stats.attempts * 100).toFixed(1) : '0';
            this.log(`  ${name}: ${stats.success}/${stats.attempts} (${successRate}%) - ${stats.collected.toFixed(6)} SOL`, 'info');
        });
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
        
        while (Date.now() - this.startTime < this.maxDuration) {
            try {
                // Executar ciclo de estratégias
                const success = await this.executeCycle();
                
                if (success) {
                    this.log('🎉 Coleta concluída com sucesso!', 'success');
                    break;
                }
                
                // Relatório de progresso a cada 5 ciclos
                if (this.cycleCount % 5 === 0) {
                    this.generateProgressReport();
                }
                
                // Delay adaptativo
                const delay = this.calculateAdaptiveDelay();
                this.log(`Aguardando ${delay}s antes do próximo ciclo...`, 'time');
                await new Promise(resolve => setTimeout(resolve, delay * 1000));
                
            } catch (error) {
                this.log(`Erro no ciclo: ${error.message}`, 'error');
                await new Promise(resolve => setTimeout(resolve, 30000)); // 30s em caso de erro
            }
        }
        
        // Relatório final
        this.generateProgressReport();
        
        const finalSuccess = this.currentBalance >= this.targetAmount;
        this.log(finalSuccess ? '✅ Missão cumprida!' : '⏰ Tempo esgotado', finalSuccess ? 'success' : 'warning');
        
        return finalSuccess;
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    const collector = new UltimateDevnetSolCollector();
    
    // Capturar sinais para relatório final
    process.on('SIGINT', () => {
        console.log('\n🛑 Interrompido pelo usuário');
        collector.generateProgressReport();
        process.exit(0);
    });
    
    collector.run().then(success => {
        process.exit(success ? 0 : 1);
    }).catch(error => {
        console.error(`Erro fatal: ${error.message}`);
        process.exit(1);
    });
}

module.exports = UltimateDevnetSolCollector;