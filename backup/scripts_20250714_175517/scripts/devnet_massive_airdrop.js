#!/usr/bin/env node

/**
 * GMC Ecosystem - Massive Devnet Airdrop Script
 * Executa por 5 horas coletando 100+ SOL na devnet
 * Usa múltiplas estratégias para contornar rate limits
 */

const { Connection, PublicKey, Keypair, LAMPORTS_PER_SOL } = require('@solana/web3.js');
const fs = require('fs');
const path = require('path');

// Configurações
const DEVNET_RPC = 'https://api.devnet.solana.com';
const TARGET_SOL = 100; // Meta de SOL
const EXECUTION_TIME_HOURS = 5; // Tempo de execução
const EXECUTION_TIME_MS = EXECUTION_TIME_HOURS * 60 * 60 * 1000;
const AIRDROP_AMOUNT = 2; // SOL por airdrop
const BASE_DELAY = 30000; // 30 segundos base
const MAX_DELAY = 300000; // 5 minutos máximo

// Cores para output
const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    reset: '\x1b[0m'
};

class MassiveAirdropManager {
    constructor() {
        this.connection = new Connection(DEVNET_RPC, 'confirmed');
        this.startTime = Date.now();
        this.endTime = this.startTime + EXECUTION_TIME_MS;
        this.totalCollected = 0;
        this.successfulAirdrops = 0;
        this.failedAirdrops = 0;
        this.currentDelay = BASE_DELAY;
        this.wallets = [];
        this.currentWalletIndex = 0;
        
        console.log(`${colors.cyan}🚀 ====================================${colors.reset}`);
        console.log(`${colors.cyan}   GMC MASSIVE DEVNET AIRDROP${colors.reset}`);
        console.log(`${colors.cyan}🚀 ====================================${colors.reset}`);
        console.log(`Meta: ${TARGET_SOL} SOL em ${EXECUTION_TIME_HOURS} horas`);
        console.log(`Início: ${new Date().toLocaleString()}`);
        console.log(`Fim previsto: ${new Date(this.endTime).toLocaleString()}`);
    }

    async loadWallets() {
        console.log(`\n${colors.blue}📁 Carregando carteiras...${colors.reset}`);
        
        // Carregar carteiras principais
        const deployerPath = '.devnet-keys/deployer.json';
        const adminPath = '.devnet-keys/admin.json';
        
        if (fs.existsSync(deployerPath)) {
            const deployerKeypair = Keypair.fromSecretKey(
                new Uint8Array(JSON.parse(fs.readFileSync(deployerPath, 'utf8')))
            );
            this.wallets.push({
                name: 'deployer',
                keypair: deployerKeypair,
                address: deployerKeypair.publicKey.toString()
            });
        }
        
        if (fs.existsSync(adminPath)) {
            const adminKeypair = Keypair.fromSecretKey(
                new Uint8Array(JSON.parse(fs.readFileSync(adminPath, 'utf8')))
            );
            this.wallets.push({
                name: 'admin',
                keypair: adminKeypair,
                address: adminKeypair.publicKey.toString()
            });
        }
        
        // Criar carteiras auxiliares para distribuir rate limits
        const auxWalletsDir = '.devnet-keys/aux';
        if (!fs.existsSync(auxWalletsDir)) {
            fs.mkdirSync(auxWalletsDir, { recursive: true });
        }
        
        // Criar 10 carteiras auxiliares
        for (let i = 0; i < 10; i++) {
            const auxPath = path.join(auxWalletsDir, `aux_${i}.json`);
            let auxKeypair;
            
            if (fs.existsSync(auxPath)) {
                auxKeypair = Keypair.fromSecretKey(
                    new Uint8Array(JSON.parse(fs.readFileSync(auxPath, 'utf8')))
                );
            } else {
                auxKeypair = Keypair.generate();
                fs.writeFileSync(auxPath, JSON.stringify(Array.from(auxKeypair.secretKey)));
            }
            
            this.wallets.push({
                name: `aux_${i}`,
                keypair: auxKeypair,
                address: auxKeypair.publicKey.toString()
            });
        }
        
        console.log(`${colors.green}✅ ${this.wallets.length} carteiras carregadas${colors.reset}`);
        this.wallets.forEach((wallet, index) => {
            console.log(`  ${index + 1}. ${wallet.name}: ${wallet.address}`);
        });
    }

    async checkBalance(address) {
        try {
            const balance = await this.connection.getBalance(new PublicKey(address));
            return balance / LAMPORTS_PER_SOL;
        } catch (error) {
            console.log(`${colors.red}❌ Erro ao verificar balance: ${error.message}${colors.reset}`);
            return 0;
        }
    }

    async requestAirdrop(wallet) {
        try {
            console.log(`\n[${new Date().toLocaleTimeString()}] Solicitando ${AIRDROP_AMOUNT} SOL para ${wallet.name}...`);
            
            const signature = await this.connection.requestAirdrop(
                wallet.keypair.publicKey,
                AIRDROP_AMOUNT * LAMPORTS_PER_SOL
            );
            
            // Aguardar confirmação
            await this.connection.confirmTransaction(signature, 'confirmed');
            
            const newBalance = await this.checkBalance(wallet.address);
            this.totalCollected += AIRDROP_AMOUNT;
            this.successfulAirdrops++;
            
            console.log(`${colors.green}✅ Airdrop bem-sucedido! Balance: ${newBalance.toFixed(2)} SOL${colors.reset}`);
            
            // Reduzir delay em caso de sucesso
            this.currentDelay = Math.max(BASE_DELAY, this.currentDelay * 0.9);
            
            return true;
        } catch (error) {
            this.failedAirdrops++;
            console.log(`${colors.red}❌ Airdrop falhou: ${error.message}${colors.reset}`);
            
            // Aumentar delay em caso de falha
            this.currentDelay = Math.min(MAX_DELAY, this.currentDelay * 1.5);
            
            return false;
        }
    }

    async transferToMainWallet() {
        console.log(`\n${colors.magenta}💸 Consolidando SOL na carteira principal...${colors.reset}`);
        
        const mainWallet = this.wallets[0]; // deployer
        let totalTransferred = 0;
        
        for (let i = 1; i < this.wallets.length; i++) {
            const wallet = this.wallets[i];
            const balance = await this.checkBalance(wallet.address);
            
            if (balance > 0.1) { // Manter 0.1 SOL para taxas
                try {
                    const transferAmount = Math.floor((balance - 0.1) * LAMPORTS_PER_SOL);
                    
                    const transaction = new (require('@solana/web3.js').Transaction)().add(
                        require('@solana/web3.js').SystemProgram.transfer({
                            fromPubkey: wallet.keypair.publicKey,
                            toPubkey: mainWallet.keypair.publicKey,
                            lamports: transferAmount
                        })
                    );
                    
                    const signature = await this.connection.sendTransaction(transaction, [wallet.keypair]);
                    await this.connection.confirmTransaction(signature, 'confirmed');
                    
                    totalTransferred += transferAmount / LAMPORTS_PER_SOL;
                    console.log(`${colors.green}✅ Transferido ${(transferAmount / LAMPORTS_PER_SOL).toFixed(2)} SOL de ${wallet.name}${colors.reset}`);
                } catch (error) {
                    console.log(`${colors.yellow}⚠️  Falha na transferência de ${wallet.name}: ${error.message}${colors.reset}`);
                }
            }
        }
        
        console.log(`${colors.green}✅ Total consolidado: ${totalTransferred.toFixed(2)} SOL${colors.reset}`);
        return totalTransferred;
    }

    async printStatus() {
        const elapsed = Date.now() - this.startTime;
        const remaining = this.endTime - Date.now();
        const progress = (elapsed / EXECUTION_TIME_MS) * 100;
        
        console.log(`\n${colors.cyan}📊 ===== STATUS ATUAL =====${colors.reset}`);
        console.log(`Tempo decorrido: ${Math.floor(elapsed / 60000)} min`);
        console.log(`Tempo restante: ${Math.floor(remaining / 60000)} min`);
        console.log(`Progresso: ${progress.toFixed(1)}%`);
        console.log(`SOL coletado: ${this.totalCollected.toFixed(2)}/${TARGET_SOL}`);
        console.log(`Airdrops: ✅${this.successfulAirdrops} ❌${this.failedAirdrops}`);
        console.log(`Taxa de sucesso: ${((this.successfulAirdrops / (this.successfulAirdrops + this.failedAirdrops)) * 100).toFixed(1)}%`);
        console.log(`Próximo delay: ${Math.floor(this.currentDelay / 1000)}s`);
        
        // Verificar balances atuais
        console.log(`\n💰 Balances atuais:`);
        for (const wallet of this.wallets.slice(0, 3)) { // Mostrar apenas as 3 principais
            const balance = await this.checkBalance(wallet.address);
            console.log(`  ${wallet.name}: ${balance.toFixed(2)} SOL`);
        }
    }

    async run() {
        await this.loadWallets();
        
        console.log(`\n${colors.yellow}🎯 Iniciando coleta massiva de SOL...${colors.reset}`);
        
        while (Date.now() < this.endTime && this.totalCollected < TARGET_SOL) {
            // Rotacionar entre carteiras
            const currentWallet = this.wallets[this.currentWalletIndex];
            this.currentWalletIndex = (this.currentWalletIndex + 1) % this.wallets.length;
            
            await this.requestAirdrop(currentWallet);
            
            // Status a cada 10 tentativas
            if ((this.successfulAirdrops + this.failedAirdrops) % 10 === 0) {
                await this.printStatus();
            }
            
            // Consolidar SOL a cada 50 airdrops bem-sucedidos
            if (this.successfulAirdrops % 50 === 0 && this.successfulAirdrops > 0) {
                await this.transferToMainWallet();
            }
            
            // Aguardar antes da próxima tentativa
            console.log(`${colors.blue}⏳ Aguardando ${Math.floor(this.currentDelay / 1000)}s...${colors.reset}`);
            await new Promise(resolve => setTimeout(resolve, this.currentDelay));
        }
        
        // Consolidação final
        console.log(`\n${colors.magenta}🏁 Finalizando e consolidando...${colors.reset}`);
        await this.transferToMainWallet();
        
        // Status final
        await this.printStatus();
        
        const finalBalance = await this.checkBalance(this.wallets[0].address);
        
        console.log(`\n${colors.green}🎉 ====================================${colors.reset}`);
        console.log(`${colors.green}   COLETA MASSIVA CONCLUÍDA${colors.reset}`);
        console.log(`${colors.green}🎉 ====================================${colors.reset}`);
        console.log(`SOL total coletado: ${this.totalCollected.toFixed(2)}`);
        console.log(`Balance final (deployer): ${finalBalance.toFixed(2)} SOL`);
        console.log(`Meta atingida: ${finalBalance >= TARGET_SOL ? '✅ SIM' : '❌ NÃO'}`);
        console.log(`Airdrops realizados: ${this.successfulAirdrops}`);
        console.log(`Tempo total: ${Math.floor((Date.now() - this.startTime) / 60000)} min`);
        console.log(`====================================${colors.reset}`);
        
        if (finalBalance >= TARGET_SOL) {
            console.log(`\n${colors.green}🚀 Pronto para deploy! Execute:${colors.reset}`);
            console.log(`${colors.cyan}./scripts/devnet_deploy_optimized.sh${colors.reset}`);
        }
    }
}

// Tratamento de sinais para parada graceful
process.on('SIGINT', async () => {
    console.log(`\n${colors.yellow}⚠️  Interrupção detectada. Finalizando...${colors.reset}`);
    process.exit(0);
});

// Executar
if (require.main === module) {
    const manager = new MassiveAirdropManager();
    manager.run().catch(error => {
        console.error(`${colors.red}❌ Erro fatal: ${error.message}${colors.reset}`);
        process.exit(1);
    });
}

module.exports = MassiveAirdropManager;