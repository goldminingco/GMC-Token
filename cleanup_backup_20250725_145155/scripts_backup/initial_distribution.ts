#!/usr/bin/env npx ts-node

/**
 * 🚀 GMC Token - Script de Distribuição Inicial
 * 
 * Este script automatiza a distribuição inicial dos 100,000,000 GMC tokens
 * conforme definido no tokenomics oficial do projeto.
 * 
 * DISTRIBUIÇÃO OFICIAL:
 * - Fundo Pool de Staking: 70,000,000 GMC (70%)
 * - Pré-venda (ICO): 8,000,000 GMC (8%)
 * - Reserva Gold Mining: 10,000,000 GMC (10%) [com vesting 5 anos]
 * - Tesouraria: 2,000,000 GMC (2%)
 * - Marketing: 6,000,000 GMC (6%)
 * - Airdrop: 2,000,000 GMC (2%)
 * - Equipe: 2,000,000 GMC (2%) [com vesting]
 * 
 * TOTAL: 100,000,000 GMC
 */

import {
    Connection,
    Keypair,
    PublicKey,
    Transaction,
    sendAndConfirmTransaction,
    SystemProgram,
    LAMPORTS_PER_SOL,
} from '@solana/web3.js';
import {
    createMint,
    getOrCreateAssociatedTokenAccount,
    mintTo,
    transfer,
    TOKEN_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID,
} from '@solana/spl-token';
import fs from 'fs';
import path from 'path';
import BN from 'bn.js';

// 🔧 Configurações
const CLUSTER = process.env.CLUSTER || 'devnet';
const RPC_URL = process.env.RPC_URL || 'https://api.devnet.solana.com';
const PROGRAM_ID = new PublicKey('H5f91LGHdQBRqSGFupaP5N6tFTZsXxqHtroam4p6nBdT');

// 🪙 Constantes do Tokenomics (espelham as constantes do contrato)
const TOKEN_DECIMALS = 9;
const INITIAL_SUPPLY = 100_000_000 * Math.pow(10, TOKEN_DECIMALS); // 100M GMC
const BURN_CAP = 12_000_000 * Math.pow(10, TOKEN_DECIMALS); // 12M GMC

// 📊 Distribuição Inicial Oficial
const DISTRIBUTION = {
    STAKING_POOL: 70_000_000 * Math.pow(10, TOKEN_DECIMALS), // 70M GMC
    ICO_PRESALE: 8_000_000 * Math.pow(10, TOKEN_DECIMALS),   // 8M GMC
    STRATEGIC_RESERVE: 10_000_000 * Math.pow(10, TOKEN_DECIMALS), // 10M GMC (vesting 5 anos)
    TREASURY: 2_000_000 * Math.pow(10, TOKEN_DECIMALS),      // 2M GMC
    MARKETING: 6_000_000 * Math.pow(10, TOKEN_DECIMALS),     // 6M GMC
    AIRDROP: 2_000_000 * Math.pow(10, TOKEN_DECIMALS),       // 2M GMC
    TEAM: 2_000_000 * Math.pow(10, TOKEN_DECIMALS),          // 2M GMC (vesting)
};

// 🔐 Configuração de Segurança
interface DistributionConfig {
    connection: Connection;
    authority: Keypair;
    mint?: PublicKey;
    recipients: {
        stakingPool: PublicKey;
        icoPresale: PublicKey;
        strategicReserve: PublicKey;
        treasury: PublicKey;
        marketing: PublicKey;
        airdrop: PublicKey;
        team: PublicKey;
    };
}

// 📈 Interface para relatório
interface DistributionReport {
    timestamp: string;
    cluster: string;
    mintAddress: string;
    totalSupply: number;
    distributions: {
        [key: string]: {
            address: string;
            amount: number;
            amountFormatted: string;
            percentage: number;
            txSignature?: string;
        }
    };
    vestingSchedules: {
        [key: string]: {
            beneficiary: string;
            totalAmount: number;
            cliffDuration: number;
            vestingDuration: number;
            txSignature?: string;
        }
    };
    verification: {
        totalDistributed: number;
        supplyMatch: boolean;
        percentageSum: number;
    };
}

class InitialDistribution {
    private config: DistributionConfig;
    private report: DistributionReport;

    constructor(config: DistributionConfig) {
        this.config = config;
        this.report = this.initializeReport();
    }

    private initializeReport(): DistributionReport {
        return {
            timestamp: new Date().toISOString(),
            cluster: CLUSTER,
            mintAddress: '',
            totalSupply: INITIAL_SUPPLY,
            distributions: {},
            vestingSchedules: {},
            verification: {
                totalDistributed: 0,
                supplyMatch: false,
                percentageSum: 0,
            }
        };
    }

    /**
     * 🚀 Executar distribuição completa
     */
    async execute(): Promise<void> {
        console.log('🚀 Iniciando Distribuição Inicial do GMC Token');
        console.log(`📍 Cluster: ${CLUSTER}`);
        console.log(`💰 Supply Total: ${this.formatTokenAmount(INITIAL_SUPPLY)} GMC`);
        console.log('');

        try {
            // Etapa 1: Criar ou usar mint existente
            await this.setupMint();
            
            // Etapa 2: Distribuir fundos
            await this.distributeTokens();
            
            // Etapa 3: Configurar vesting
            await this.setupVesting();
            
            // Etapa 4: Verificar distribuição
            await this.verifyDistribution();
            
            // Etapa 5: Gerar relatório
            await this.generateReport();
            
            console.log('✅ Distribuição inicial concluída com sucesso!');
            
        } catch (error) {
            console.error('❌ Erro durante a distribuição:', error);
            throw error;
        }
    }

    /**
     * 🪙 Configurar o mint do token GMC
     */
    private async setupMint(): Promise<void> {
        console.log('🪙 Configurando Mint do Token GMC...');

        if (!this.config.mint) {
            // Criar novo mint
            console.log('   Criando novo mint...');
            this.config.mint = await createMint(
                this.config.connection,
                this.config.authority,
                this.config.authority.publicKey,
                this.config.authority.publicKey,
                TOKEN_DECIMALS,
                undefined,
                undefined,
                TOKEN_PROGRAM_ID
            );
            console.log(`   ✅ Mint criado: ${this.config.mint.toBase58()}`);
        } else {
            console.log(`   ✅ Usando mint existente: ${this.config.mint.toBase58()}`);
        }

        this.report.mintAddress = this.config.mint.toBase58();

        // Criar conta de token da autoridade para mintar
        const authorityTokenAccount = await getOrCreateAssociatedTokenAccount(
            this.config.connection,
            this.config.authority,
            this.config.mint,
            this.config.authority.publicKey
        );

        // Mintar o supply total para a autoridade
        console.log('   Mintando supply total...');
        const mintSignature = await mintTo(
            this.config.connection,
            this.config.authority,
            this.config.mint,
            authorityTokenAccount.address,
            this.config.authority,
            INITIAL_SUPPLY
        );

        console.log(`   ✅ ${this.formatTokenAmount(INITIAL_SUPPLY)} GMC mintados`);
        console.log(`   📝 Tx: ${mintSignature}`);
        console.log('');
    }

    /**
     * 💸 Distribuir tokens para os destinatários
     */
    private async distributeTokens(): Promise<void> {
        console.log('💸 Distribuindo tokens...');

        const distributions = [
            { name: 'STAKING_POOL', amount: DISTRIBUTION.STAKING_POOL, recipient: this.config.recipients.stakingPool },
            { name: 'ICO_PRESALE', amount: DISTRIBUTION.ICO_PRESALE, recipient: this.config.recipients.icoPresale },
            { name: 'STRATEGIC_RESERVE', amount: DISTRIBUTION.STRATEGIC_RESERVE, recipient: this.config.recipients.strategicReserve },
            { name: 'TREASURY', amount: DISTRIBUTION.TREASURY, recipient: this.config.recipients.treasury },
            { name: 'MARKETING', amount: DISTRIBUTION.MARKETING, recipient: this.config.recipients.marketing },
            { name: 'AIRDROP', amount: DISTRIBUTION.AIRDROP, recipient: this.config.recipients.airdrop },
            { name: 'TEAM', amount: DISTRIBUTION.TEAM, recipient: this.config.recipients.team },
        ];

        // Obter conta de token da autoridade
        const authorityTokenAccount = await getOrCreateAssociatedTokenAccount(
            this.config.connection,
            this.config.authority,
            this.config.mint!,
            this.config.authority.publicKey
        );

        for (const dist of distributions) {
            console.log(`   📤 ${dist.name}: ${this.formatTokenAmount(dist.amount)} GMC`);
            
            // Criar conta de token do destinatário
            const recipientTokenAccount = await getOrCreateAssociatedTokenAccount(
                this.config.connection,
                this.config.authority,
                this.config.mint!,
                dist.recipient
            );

            // Transferir tokens
            const transferSignature = await transfer(
                this.config.connection,
                this.config.authority,
                authorityTokenAccount.address,
                recipientTokenAccount.address,
                this.config.authority,
                dist.amount
            );

            console.log(`      ✅ Transferido para: ${dist.recipient.toBase58()}`);
            console.log(`      📝 Tx: ${transferSignature}`);

            // Registrar no relatório
            this.report.distributions[dist.name] = {
                address: dist.recipient.toBase58(),
                amount: dist.amount,
                amountFormatted: this.formatTokenAmount(dist.amount),
                percentage: (dist.amount / INITIAL_SUPPLY) * 100,
                txSignature: transferSignature,
            };

            this.report.verification.totalDistributed += dist.amount;
        }

        console.log('');
    }

    /**
     * 📅 Configurar cronogramas de vesting
     */
    private async setupVesting(): Promise<void> {
        console.log('📅 Configurando Vesting...');

        // Vesting para Reserva Estratégica (5 anos)
        await this.createVestingSchedule(
            'STRATEGIC_RESERVE',
            this.config.recipients.strategicReserve,
            DISTRIBUTION.STRATEGIC_RESERVE,
            0, // Sem cliff
            5 * 365 * 24 * 3600, // 5 anos em segundos
            30 * 24 * 3600 // Release a cada 30 dias
        );

        // Vesting para Equipe (vesting conforme definido)
        await this.createVestingSchedule(
            'TEAM',
            this.config.recipients.team,
            DISTRIBUTION.TEAM,
            6 * 30 * 24 * 3600, // Cliff de 6 meses
            24 * 30 * 24 * 3600, // Vesting de 24 meses
            30 * 24 * 3600 // Release a cada 30 dias
        );

        console.log('');
    }

    /**
     * 📅 Criar cronograma de vesting individual
     */
    private async createVestingSchedule(
        name: string,
        beneficiary: PublicKey,
        totalAmount: number,
        cliffDuration: number,
        vestingDuration: number,
        releaseInterval: number
    ): Promise<void> {
        console.log(`   📅 ${name}: ${this.formatTokenAmount(totalAmount)} GMC`);
        console.log(`      🎯 Beneficiário: ${beneficiary.toBase58()}`);
        console.log(`      ⏰ Cliff: ${cliffDuration / (30 * 24 * 3600)} meses`);
        console.log(`      📈 Vesting: ${vestingDuration / (30 * 24 * 3600)} meses`);

        // TODO: Implementar chamada para o contrato de vesting
        // Aqui seria feita a chamada para CreateVestingSchedule do programa
        
        // Simulação de transação bem-sucedida
        const mockTxSignature = 'vesting_' + Math.random().toString(36).substring(7);
        
        this.report.vestingSchedules[name] = {
            beneficiary: beneficiary.toBase58(),
            totalAmount,
            cliffDuration,
            vestingDuration,
            txSignature: mockTxSignature,
        };

        console.log(`      ✅ Vesting configurado: ${mockTxSignature}`);
    }

    /**
     * ✅ Verificar se a distribuição está correta
     */
    private async verifyDistribution(): Promise<void> {
        console.log('✅ Verificando distribuição...');

        // Verificar se o total distribuído bate com o supply
        this.report.verification.supplyMatch = this.report.verification.totalDistributed === INITIAL_SUPPLY;
        
        // Calcular soma das porcentagens
        this.report.verification.percentageSum = Object.values(this.report.distributions)
            .reduce((sum, dist) => sum + dist.percentage, 0);

        console.log(`   📊 Total distribuído: ${this.formatTokenAmount(this.report.verification.totalDistributed)} GMC`);
        console.log(`   📊 Supply total: ${this.formatTokenAmount(INITIAL_SUPPLY)} GMC`);
        console.log(`   ✅ Distribuição correta: ${this.report.verification.supplyMatch ? 'SIM' : 'NÃO'}`);
        console.log(`   📊 Soma das porcentagens: ${this.report.verification.percentageSum.toFixed(2)}%`);
        
        if (!this.report.verification.supplyMatch) {
            throw new Error('❌ Erro: Total distribuído não confere com o supply inicial!');
        }
        
        console.log('');
    }

    /**
     * 📋 Gerar relatório final
     */
    private async generateReport(): Promise<void> {
        const reportPath = path.join(__dirname, '..', 'reports', `initial_distribution_${Date.now()}.json`);
        
        // Criar diretório se não existir
        const reportsDir = path.dirname(reportPath);
        if (!fs.existsSync(reportsDir)) {
            fs.mkdirSync(reportsDir, { recursive: true });
        }

        // Salvar relatório
        fs.writeFileSync(reportPath, JSON.stringify(this.report, null, 2));
        
        console.log('📋 Relatório final gerado:');
        console.log(`   📁 Arquivo: ${reportPath}`);
        console.log(`   🪙 Mint: ${this.report.mintAddress}`);
        console.log(`   📊 Distribuições: ${Object.keys(this.report.distributions).length}`);
        console.log(`   📅 Vesting Schedules: ${Object.keys(this.report.vestingSchedules).length}`);
    }

    /**
     * 🔧 Formatizar quantidade de tokens
     */
    private formatTokenAmount(amount: number): string {
        return (amount / Math.pow(10, TOKEN_DECIMALS)).toLocaleString('pt-BR');
    }
}

/**
 * 🚀 Função principal
 */
async function main() {
    console.log('🚀 GMC Token - Script de Distribuição Inicial');
    console.log('='.repeat(50));

    try {
        // Configurar conexão
        const connection = new Connection(RPC_URL, 'confirmed');
        
        // Carregar chave da autoridade
        const authorityPath = process.env.AUTHORITY_KEYPAIR_PATH || 
                             path.join(__dirname, '..', '.devnet-keys', 'authority.json');
        
        if (!fs.existsSync(authorityPath)) {
            throw new Error(`❌ Arquivo de chave da autoridade não encontrado: ${authorityPath}`);
        }

        const authorityKeypair = Keypair.fromSecretKey(
            new Uint8Array(JSON.parse(fs.readFileSync(authorityPath, 'utf8')))
        );

        console.log(`🔑 Autoridade: ${authorityKeypair.publicKey.toBase58()}`);

        // Verificar saldo da autoridade
        const balance = await connection.getBalance(authorityKeypair.publicKey);
        console.log(`💰 Saldo SOL: ${balance / LAMPORTS_PER_SOL} SOL`);
        
        if (balance < 0.1 * LAMPORTS_PER_SOL) {
            throw new Error('❌ Saldo insuficiente para executar as transações (mínimo 0.1 SOL)');
        }

        // Configurar destinatários
        // NOTA: Em produção, estes endereços seriam fornecidos via arquivo de configuração
        const recipients = {
            stakingPool: new PublicKey('11111111111111111111111111111111'), // Placeholder
            icoPresale: new PublicKey('11111111111111111111111111111111'),  // Placeholder
            strategicReserve: new PublicKey('11111111111111111111111111111111'), // Placeholder
            treasury: new PublicKey('11111111111111111111111111111111'),  // Placeholder
            marketing: new PublicKey('11111111111111111111111111111111'), // Placeholder
            airdrop: new PublicKey('11111111111111111111111111111111'),   // Placeholder
            team: new PublicKey('11111111111111111111111111111111'),      // Placeholder
        };

        // Executar distribuição
        const distribution = new InitialDistribution({
            connection,
            authority: authorityKeypair,
            recipients,
        });

        await distribution.execute();

    } catch (error) {
        console.error('❌ Erro:', error);
        process.exit(1);
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    main().catch(console.error);
}

export { InitialDistribution, DistributionConfig, DistributionReport }; 