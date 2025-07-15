#!/usr/bin/env node

/**
 * GMC Token - Devnet SOL Recovery Tool
 * 
 * Implementa a estratégia de recuperação de SOL através de:
 * - Fechamento de buffer accounts não utilizados
 * - Fechamento de programas antigos
 * - Consolidação de SOL disperso
 * 
 * Esta é uma estratégia sustentável recomendada pela documentação oficial da Solana
 * para reutilizar SOL em devnet sem depender de airdrops.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

class DevnetSolRecovery {
    constructor() {
        this.totalRecovered = 0;
        this.deployerAddress = null;
        this.recoveryLog = [];
    }

    log(message, type = 'info') {
        const timestamp = new Date().toLocaleString('pt-BR');
        const icons = {
            info: 'ℹ️',
            success: '✅',
            warning: '⚠️',
            error: '❌',
            recovery: '♻️',
            money: '💰'
        };
        const logEntry = `[${timestamp}] ${icons[type]} ${message}`;
        console.log(logEntry);
        this.recoveryLog.push(logEntry);
    }

    async setupEnvironment() {
        try {
            this.log('Configurando ambiente para recuperação de SOL...', 'info');
            
            // Configurar para devnet
            execSync('solana config set --url devnet', { stdio: 'pipe' });
            
            // Obter endereço do deployer
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

    async findBufferAccounts() {
        try {
            this.log('Procurando buffer accounts...', 'recovery');
            
            const result = execSync('solana program show --buffers', { 
                encoding: 'utf8',
                timeout: 30000
            });
            
            const lines = result.split('\n').filter(line => line.trim());
            const buffers = [];
            
            for (const line of lines) {
                if (line.includes('Buffer') && line.includes('SOL')) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length >= 3) {
                        const bufferId = parts[0];
                        const solAmount = parseFloat(parts[2]);
                        
                        if (solAmount > 0) {
                            buffers.push({ id: bufferId, amount: solAmount });
                        }
                    }
                }
            }
            
            this.log(`Encontrados ${buffers.length} buffer accounts com SOL`, 'info');
            return buffers;
            
        } catch (error) {
            this.log(`Erro ao buscar buffers: ${error.message}`, 'warning');
            return [];
        }
    }

    async closeBufferAccount(bufferId, expectedAmount) {
        try {
            this.log(`Fechando buffer ${bufferId} (${expectedAmount} SOL)...`, 'recovery');
            
            const result = execSync(`solana program close ${bufferId}`, {
                encoding: 'utf8',
                timeout: 30000
            });
            
            if (result.includes('Signature:') || result.includes('confirmed')) {
                this.totalRecovered += expectedAmount;
                this.log(`Buffer fechado! Recuperados ${expectedAmount} SOL`, 'success');
                return true;
            }
            
            return false;
            
        } catch (error) {
            this.log(`Erro ao fechar buffer ${bufferId}: ${error.message}`, 'warning');
            return false;
        }
    }

    async findDeployedPrograms() {
        try {
            this.log('Procurando programas deployados...', 'recovery');
            
            const result = execSync('solana program show --programs', { 
                encoding: 'utf8',
                timeout: 30000
            });
            
            const lines = result.split('\n').filter(line => line.trim());
            const programs = [];
            
            for (const line of lines) {
                if (line.includes('Program') && line.includes('SOL')) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length >= 3) {
                        const programId = parts[0];
                        const solAmount = parseFloat(parts[2]);
                        
                        // Verificar se não é um programa do sistema
                        if (solAmount > 0 && !this.isSystemProgram(programId)) {
                            programs.push({ id: programId, amount: solAmount });
                        }
                    }
                }
            }
            
            this.log(`Encontrados ${programs.length} programas com SOL recuperável`, 'info');
            return programs;
            
        } catch (error) {
            this.log(`Erro ao buscar programas: ${error.message}`, 'warning');
            return [];
        }
    }

    isSystemProgram(programId) {
        const systemPrograms = [
            '11111111111111111111111111111111', // System Program
            'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA', // Token Program
            'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL', // Associated Token Program
            'SysvarRent111111111111111111111111111111111', // Rent Sysvar
            'SysvarC1ock11111111111111111111111111111111', // Clock Sysvar
        ];
        
        return systemPrograms.includes(programId);
    }

    async closeProgramAccount(programId, expectedAmount) {
        try {
            this.log(`Analisando programa ${programId}...`, 'recovery');
            
            // Verificar se é seguro fechar (não é um programa ativo do GMC)
            const gmcPrograms = ['gmc_token', 'gmc_staking', 'gmc_treasury', 'gmc_ranking', 'gmc_vesting'];
            const isGmcProgram = gmcPrograms.some(name => 
                fs.existsSync(path.join(__dirname, `../target/deploy/${name}.so`))
            );
            
            if (isGmcProgram) {
                this.log(`Programa ${programId} pode ser do GMC - pulando por segurança`, 'warning');
                return false;
            }
            
            this.log(`Fechando programa ${programId} (${expectedAmount} SOL)...`, 'recovery');
            
            const result = execSync(`solana program close ${programId}`, {
                encoding: 'utf8',
                timeout: 30000
            });
            
            if (result.includes('Signature:') || result.includes('confirmed')) {
                this.totalRecovered += expectedAmount;
                this.log(`Programa fechado! Recuperados ${expectedAmount} SOL`, 'success');
                return true;
            }
            
            return false;
            
        } catch (error) {
            this.log(`Erro ao fechar programa ${programId}: ${error.message}`, 'warning');
            return false;
        }
    }

    async checkAuxiliaryWallets() {
        try {
            this.log('Verificando carteiras auxiliares...', 'recovery');
            
            const auxDir = path.join(__dirname, '../.devnet-keys/aux');
            if (!fs.existsSync(auxDir)) {
                this.log('Diretório de carteiras auxiliares não encontrado', 'info');
                return 0;
            }
            
            const auxFiles = fs.readdirSync(auxDir).filter(f => f.endsWith('.json'));
            let totalAuxBalance = 0;
            
            for (const file of auxFiles) {
                try {
                    const auxPath = path.join(auxDir, file);
                    const auxKey = JSON.parse(fs.readFileSync(auxPath, 'utf8'));
                    
                    // Temporariamente usar a chave auxiliar
                    const tempKeyPath = '/tmp/temp_aux_key.json';
                    fs.writeFileSync(tempKeyPath, JSON.stringify(auxKey));
                    
                    const balanceResult = execSync(`solana balance --keypair ${tempKeyPath}`, {
                        encoding: 'utf8',
                        timeout: 10000
                    });
                    
                    const balance = parseFloat(balanceResult.split(' ')[0]);
                    
                    if (balance > 0.001) { // Mínimo para transferência
                        this.log(`Carteira ${file}: ${balance} SOL`, 'info');
                        totalAuxBalance += balance;
                        
                        // Transferir para deployer (deixando um pouco para taxa)
                        const transferAmount = balance - 0.001;
                        if (transferAmount > 0) {
                            const transferResult = execSync(
                                `solana transfer ${this.deployerAddress} ${transferAmount} --keypair ${tempKeyPath}`,
                                { encoding: 'utf8', timeout: 30000 }
                            );
                            
                            if (transferResult.includes('Signature:')) {
                                this.log(`Transferidos ${transferAmount} SOL de ${file}`, 'success');
                                this.totalRecovered += transferAmount;
                            }
                        }
                    }
                    
                    // Limpar arquivo temporário
                    if (fs.existsSync(tempKeyPath)) {
                        fs.unlinkSync(tempKeyPath);
                    }
                    
                } catch (error) {
                    this.log(`Erro ao processar ${file}: ${error.message}`, 'warning');
                }
            }
            
            return totalAuxBalance;
            
        } catch (error) {
            this.log(`Erro ao verificar carteiras auxiliares: ${error.message}`, 'warning');
            return 0;
        }
    }

    async generateRecoveryReport() {
        const reportPath = path.join(__dirname, '../logs/sol_recovery_report.txt');
        
        // Criar diretório de logs se não existir
        const logsDir = path.dirname(reportPath);
        if (!fs.existsSync(logsDir)) {
            fs.mkdirSync(logsDir, { recursive: true });
        }
        
        const report = [
            '='.repeat(60),
            'RELATÓRIO DE RECUPERAÇÃO DE SOL - DEVNET',
            '='.repeat(60),
            `Data: ${new Date().toLocaleString('pt-BR')}`,
            `Deployer: ${this.deployerAddress}`,
            `Total Recuperado: ${this.totalRecovered.toFixed(6)} SOL`,
            '',
            'LOG DETALHADO:',
            ...this.recoveryLog,
            '',
            '='.repeat(60)
        ].join('\n');
        
        fs.writeFileSync(reportPath, report);
        this.log(`Relatório salvo em: ${reportPath}`, 'info');
    }

    async run() {
        this.log('🚀 Iniciando GMC SOL Recovery Tool', 'info');
        
        if (!await this.setupEnvironment()) {
            this.log('Falha na configuração do ambiente', 'error');
            return false;
        }
        
        const initialBalance = await this.getCurrentBalance();
        this.log(`Saldo inicial: ${initialBalance} SOL`, 'money');
        
        // Etapa 1: Fechar buffer accounts
        this.log('\n=== ETAPA 1: BUFFER ACCOUNTS ===', 'recovery');
        const buffers = await this.findBufferAccounts();
        
        for (const buffer of buffers) {
            await this.closeBufferAccount(buffer.id, buffer.amount);
            await new Promise(resolve => setTimeout(resolve, 2000)); // Delay entre operações
        }
        
        // Etapa 2: Verificar carteiras auxiliares
        this.log('\n=== ETAPA 2: CARTEIRAS AUXILIARES ===', 'recovery');
        await this.checkAuxiliaryWallets();
        
        // Etapa 3: Analisar programas (com cuidado)
        this.log('\n=== ETAPA 3: PROGRAMAS DEPLOYADOS ===', 'recovery');
        const programs = await this.findDeployedPrograms();
        
        this.log('ATENÇÃO: Análise de programas requer cuidado manual', 'warning');
        this.log('Programas encontrados:', 'info');
        programs.forEach(prog => {
            this.log(`  • ${prog.id}: ${prog.amount} SOL`, 'info');
        });
        
        if (programs.length > 0) {
            this.log('Para fechar programas manualmente:', 'info');
            this.log('solana program close <PROGRAM_ID>', 'info');
        }
        
        // Resultado final
        const finalBalance = await this.getCurrentBalance();
        const netRecovered = finalBalance - initialBalance;
        
        this.log('\n=== RESULTADO FINAL ===', 'money');
        this.log(`Saldo inicial: ${initialBalance} SOL`, 'info');
        this.log(`Saldo final: ${finalBalance} SOL`, 'info');
        this.log(`SOL recuperado: ${netRecovered.toFixed(6)} SOL`, 'success');
        this.log(`Total processado: ${this.totalRecovered.toFixed(6)} SOL`, 'info');
        
        await this.generateRecoveryReport();
        
        if (netRecovered > 0) {
            this.log('✅ Recuperação concluída com sucesso!', 'success');
            return true;
        } else {
            this.log('ℹ️ Nenhum SOL adicional foi recuperado', 'info');
            return false;
        }
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    const recovery = new DevnetSolRecovery();
    
    recovery.run().then(success => {
        process.exit(success ? 0 : 1);
    }).catch(error => {
        console.error(`Erro fatal: ${error.message}`);
        process.exit(1);
    });
}

module.exports = DevnetSolRecovery;