#!/usr/bin/env node

const { Connection, Keypair, LAMPORTS_PER_SOL } = require('@solana/web3.js');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configurações
const DEVNET_RPC = 'https://api.devnet.solana.com';
const connection = new Connection(DEVNET_RPC, 'confirmed');

// Função para carregar wallet
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

// Função para gerar keypair otimizada (menor custo)
function generateOptimizedKeypair() {
    let bestKeypair = null;
    let bestScore = Infinity;
    
    // Gerar múltiplas tentativas para encontrar a mais eficiente
    for (let i = 0; i < 100; i++) {
        const keypair = Keypair.generate();
        const pubkeyStr = keypair.publicKey.toString();
        
        // Calcular "score" baseado em zeros iniciais (menor custo de armazenamento)
        let score = 0;
        for (let j = 0; j < pubkeyStr.length; j++) {
            if (pubkeyStr[j] === '1' || pubkeyStr[j] === '0') {
                score -= 1; // Preferir 1s e 0s
            } else {
                score += 1;
            }
        }
        
        if (score < bestScore) {
            bestScore = score;
            bestKeypair = keypair;
        }
    }
    
    return bestKeypair;
}

// Função para verificar saldo
async function checkBalance(wallet, name) {
    const balance = await connection.getBalance(wallet.publicKey);
    const solBalance = balance / LAMPORTS_PER_SOL;
    console.log(`💰 ${name}: ${solBalance.toFixed(3)} SOL`);
    return solBalance;
}

// Função para deploy individual com otimização
async function deployProgram(programName, maxRetries = 3) {
    console.log(`\n🚀 Deployando ${programName}...`);
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            console.log(`   Tentativa ${attempt}/${maxRetries}`);
            
            // Gerar keypair otimizada para o programa
            const programKeypair = generateOptimizedKeypair();
            const keypairPath = `.devnet-keys/${programName}_keypair.json`;
            const fullKeypairPath = path.join(process.cwd(), '.devnet-keys', `${programName}_keypair.json`);
            
            // Salvar keypair
            fs.writeFileSync(fullKeypairPath, JSON.stringify(Array.from(programKeypair.secretKey)));
            console.log(`   📝 Keypair gerada: ${programKeypair.publicKey.toString().slice(0, 8)}...`);
            
            // Deploy com configurações otimizadas
            const deployCmd = `anchor deploy --program-name ${programName} --program-keypair ${keypairPath} --provider.cluster devnet`;
            
            console.log(`   🔄 Executando deploy...`);
            const output = execSync(deployCmd, { 
                cwd: process.cwd(),
                encoding: 'utf8',
                timeout: 120000 // 2 minutos timeout
            });
            
            console.log(`   ✅ ${programName} deployado com sucesso!`);
            console.log(`   📍 Program ID: ${programKeypair.publicKey.toString()}`);
            
            // Atualizar Anchor.toml
            updateAnchorToml(programName, programKeypair.publicKey.toString());
            
            // Atualizar .env.devnet
            updateEnvFile(programName, programKeypair.publicKey.toString());
            
            return {
                success: true,
                programId: programKeypair.publicKey.toString(),
                cost: 'Estimado: ~2 SOL'
            };
            
        } catch (error) {
            console.log(`   ❌ Tentativa ${attempt} falhou: ${error.message}`);
            
            if (attempt === maxRetries) {
                return {
                    success: false,
                    error: error.message
                };
            }
            
            // Aguardar antes da próxima tentativa
            console.log(`   ⏳ Aguardando 10s antes da próxima tentativa...`);
            await new Promise(resolve => setTimeout(resolve, 10000));
        }
    }
}

// Função para atualizar Anchor.toml
function updateAnchorToml(programName, programId) {
    try {
        const anchorTomlPath = path.join(process.cwd(), 'Anchor.toml');
        let content = fs.readFileSync(anchorTomlPath, 'utf8');
        
        // Atualizar ou adicionar program ID
        const programKey = `${programName} = "`;
        const newLine = `${programName} = "${programId}"`;
        
        if (content.includes(programKey)) {
            // Substituir linha existente
            const lines = content.split('\n');
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].includes(programKey)) {
                    lines[i] = newLine;
                    break;
                }
            }
            content = lines.join('\n');
        } else {
            // Adicionar nova linha na seção [programs.devnet]
            if (content.includes('[programs.devnet]')) {
                content = content.replace('[programs.devnet]', `[programs.devnet]\n${newLine}`);
            } else {
                content += `\n\n[programs.devnet]\n${newLine}`;
            }
        }
        
        fs.writeFileSync(anchorTomlPath, content);
        console.log(`   📝 Anchor.toml atualizado`);
    } catch (error) {
        console.log(`   ⚠️  Erro ao atualizar Anchor.toml: ${error.message}`);
    }
}

// Função para atualizar .env.devnet
function updateEnvFile(programName, programId) {
    try {
        const envPath = path.join(process.cwd(), '.env.devnet');
        let content = fs.readFileSync(envPath, 'utf8');
        
        const envKey = `${programName.toUpperCase()}_PROGRAM_ID=`;
        const newLine = `${programName.toUpperCase()}_PROGRAM_ID=${programId}`;
        
        if (content.includes(envKey)) {
            // Substituir linha existente
            const lines = content.split('\n');
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].includes(envKey)) {
                    lines[i] = newLine;
                    break;
                }
            }
            content = lines.join('\n');
        } else {
            // Adicionar nova linha
            content += `\n${newLine}`;
        }
        
        fs.writeFileSync(envPath, content);
        console.log(`   📝 .env.devnet atualizado`);
    } catch (error) {
        console.log(`   ⚠️  Erro ao atualizar .env.devnet: ${error.message}`);
    }
}

// Função principal
async function main() {
    console.log('🚀 Deploy Mínimo e Otimizado para Devnet');
    console.log('=' .repeat(50));
    
    // Configurar Solana CLI
    try {
        execSync('solana config set --url devnet', { encoding: 'utf8' });
        execSync('solana config set --keypair .devnet-keys/deployer.json', { encoding: 'utf8' });
        console.log('✅ Solana CLI configurado para Devnet');
    } catch (error) {
        console.log('⚠️  Erro na configuração do Solana CLI:', error.message);
    }
    
    // Carregar deployer
    const deployer = loadWallet('deployer.json');
    if (!deployer) {
        console.log('❌ Não foi possível carregar o deployer');
        return;
    }
    
    // Verificar saldo
    const deployerBalance = await checkBalance(deployer, 'Deployer');
    
    if (deployerBalance < 2) {
        console.log('❌ Saldo insuficiente para deployment (mínimo 2 SOL)');
        return;
    }
    
    console.log(`\n💡 Estratégia: Deploy sequencial com ${deployerBalance.toFixed(1)} SOL disponível`);
    
    // Lista de programas em ordem de prioridade (menor para maior)
    const programs = [
        'gmc_token',      // Mais importante
        'gmc_staking',    // Segundo mais importante
        'gmc_treasury',   // Terceiro
        'gmc_vesting',    // Quarto
        'gmc_ranking'     // Último
    ];
    
    const results = [];
    let totalCost = 0;
    
    for (const program of programs) {
        // Verificar saldo antes de cada deploy
        const currentBalance = await checkBalance(deployer, 'Deployer');
        
        if (currentBalance < 1.5) {
            console.log(`\n⚠️  Saldo insuficiente para ${program} (${currentBalance.toFixed(3)} SOL)`);
            console.log('🛑 Parando deployments para preservar SOL');
            break;
        }
        
        const result = await deployProgram(program);
        results.push({ program, ...result });
        
        if (result.success) {
            totalCost += 2; // Estimativa
            console.log(`✅ ${program} deployado com sucesso`);
        } else {
            console.log(`❌ Falha no deploy de ${program}: ${result.error}`);
            // Continuar com próximo programa
        }
        
        // Pequeno delay entre deploys
        await new Promise(resolve => setTimeout(resolve, 5000));
    }
    
    // Relatório final
    console.log('\n' + '='.repeat(50));
    console.log('📊 RELATÓRIO DE DEPLOYMENT');
    console.log('='.repeat(50));
    
    const successful = results.filter(r => r.success);
    const failed = results.filter(r => !r.success);
    
    console.log(`✅ Sucessos: ${successful.length}/${results.length}`);
    console.log(`❌ Falhas: ${failed.length}/${results.length}`);
    console.log(`💰 Custo estimado: ~${totalCost} SOL`);
    
    if (successful.length > 0) {
        console.log('\n🎉 Programas deployados:');
        successful.forEach(r => {
            console.log(`   ${r.program}: ${r.programId}`);
        });
    }
    
    if (failed.length > 0) {
        console.log('\n⚠️  Programas que falharam:');
        failed.forEach(r => {
            console.log(`   ${r.program}: ${r.error}`);
        });
    }
    
    // Verificar se pode executar inicialização
    if (successful.length >= 2) {
        console.log('\n🚀 Programas suficientes deployados. Tentando inicialização...');
        try {
            execSync('node scripts/initialize_devnet.js', { 
                encoding: 'utf8',
                stdio: 'inherit'
            });
        } catch (error) {
            console.log('⚠️  Erro na inicialização:', error.message);
        }
    } else {
        console.log('\n⚠️  Programas insuficientes para inicialização completa');
    }
    
    const finalBalance = await checkBalance(deployer, 'Deployer Final');
    console.log(`\n💰 SOL restante: ${finalBalance.toFixed(3)} SOL`);
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