#!/usr/bin/env node

/**
 * 🏷️ Script Final para Adicionar Metadados ao GMC Token
 * Abordagem simples e robusta usando Metaplex SDK
 */

const { Connection, PublicKey, Keypair } = require('@solana/web3.js');
const { createUmi } = require('@metaplex-foundation/umi-bundle-defaults');
const { mplTokenMetadata, createV1, TokenStandard } = require('@metaplex-foundation/mpl-token-metadata');
const { createSignerFromKeypair, signerIdentity, publicKey } = require('@metaplex-foundation/umi');
const fs = require('fs');

// 🎯 Configurações
const CONFIG = {
    TOKEN_MINT: '48h1Nsg5vrpjtfWg5jHk3YwaVgvUSR7P9Ry2GEoBU8dv',
    CLUSTER_URL: 'https://api.devnet.solana.com',
    KEYPAIR_PATH: '.testnet-keys/funded_deployer.json',
    METADATA_URI: 'https://raw.githubusercontent.com/goldminingco/GMC-Token/main/assets/gmc-metadata.json'
};

/**
 * 🔑 Carregar keypair
 */
function loadKeypair(umi) {
    try {
        const keypairData = JSON.parse(fs.readFileSync(CONFIG.KEYPAIR_PATH, 'utf8'));
        const keypair = umi.eddsa.createKeypairFromSecretKey(new Uint8Array(keypairData));
        return createSignerFromKeypair(umi, keypair);
    } catch (error) {
        throw new Error(`❌ Erro ao carregar keypair: ${error.message}`);
    }
}

/**
 * 🏷️ Adicionar metadados ao token
 */
async function addMetadata() {
    console.log('============================================================================');
    console.log('🏷️ ADICIONANDO METADADOS AO GMC TOKEN - VERSÃO FINAL');
    console.log('============================================================================');
    console.log(`📍 Token Mint: ${CONFIG.TOKEN_MINT}`);
    console.log(`🌐 Cluster: ${CONFIG.CLUSTER_URL}`);
    console.log(`📄 Metadata URI: ${CONFIG.METADATA_URI}`);
    console.log('============================================================================');

    try {
        // 🔧 Inicializar Umi
        console.log('🔄 Inicializando Umi framework...');
        const umi = createUmi(CONFIG.CLUSTER_URL).use(mplTokenMetadata());

        // 🔑 Carregar signer
        console.log('🔑 Carregando keypair...');
        const signer = loadKeypair(umi);
        umi.use(signerIdentity(signer));
        console.log(`👤 Wallet: ${signer.publicKey}`);

        // 💰 Verificar saldo usando conexão direta
        const connection = new Connection(CONFIG.CLUSTER_URL, 'confirmed');
        const balance = await connection.getBalance(new PublicKey(signer.publicKey));
        console.log(`💰 Saldo: ${balance / 1e9} SOL`);

        if (balance < 0.01 * 1e9) {
            throw new Error('❌ Saldo insuficiente. Mínimo: 0.01 SOL');
        }

        // 🏷️ Tentar criar metadados
        console.log('🔄 Criando metadados...');
        
        const mintPublicKey = publicKey(CONFIG.TOKEN_MINT);
        
        const result = await createV1(umi, {
            mint: mintPublicKey,
            authority: signer,
            name: 'GMC Gold Mining',
            symbol: 'GMC',
            uri: CONFIG.METADATA_URI,
            sellerFeeBasisPoints: { basisPoints: 0n, identifier: '%', decimals: 2 },
            tokenStandard: TokenStandard.Fungible,
        }).sendAndConfirm(umi);

        console.log('✅ Metadados criados com sucesso!');
        console.log(`📝 Transação: ${result.signature}`);
        
        console.log('');
        console.log('🎉 RESULTADO:');
        console.log('   • Nome: GMC Gold Mining');
        console.log('   • Símbolo: GMC');
        console.log('   • URI: https://raw.githubusercontent.com/goldminingco/GMC-Token/main/assets/gmc-metadata.json');
        console.log('   • Imagem: https://raw.githubusercontent.com/goldminingco/GMC-Token/main/assets/gmc-logo.png');
        
        console.log('');
        console.log('🔗 Verifique no Explorer:');
        console.log(`   https://explorer.solana.com/address/${CONFIG.TOKEN_MINT}?cluster=devnet`);
        
        console.log('');
        console.log('⏰ Aguarde alguns minutos para os metadados aparecerem no Explorer.');

    } catch (error) {
        console.error('❌ Erro:', error.message);
        
        if (error.message.includes('already exists') || error.message.includes('0x0')) {
            console.log('');
            console.log('ℹ️ Os metadados podem já existir para este token.');
            console.log('🔗 Verifique no Explorer:');
            console.log(`   https://explorer.solana.com/address/${CONFIG.TOKEN_MINT}?cluster=devnet`);
            console.log('');
            console.log('💡 Se o token ainda aparece como "Unknown Token", aguarde alguns minutos');
            console.log('   ou verifique se a URL do JSON está acessível.');
        } else {
            console.log('');
            console.log('💡 Possíveis soluções:');
            console.log('   1. Aguarde alguns minutos e tente novamente');
            console.log('   2. Verifique se você é o authority do token');
            console.log('   3. Confirme se a URL do JSON está acessível');
        }
    }

    console.log('============================================================================');
    console.log('🎯 PROCESSO DE METADADOS GMC TOKEN CONCLUÍDO!');
    console.log('============================================================================');
}

// 🚀 Executar
if (require.main === module) {
    addMetadata().catch(console.error);
}

module.exports = { addMetadata };
