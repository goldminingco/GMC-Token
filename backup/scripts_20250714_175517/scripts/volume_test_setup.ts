import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { promises as fs } from 'fs';
import path from 'path';
import toml from 'toml';
import os from 'os';
import { GmcStaking } from '../target/types/gmc_staking';
import { GmcToken } from '../target/types/gmc_token';
import { TOKEN_2022_PROGRAM_ID, createMint, mintTo, getOrCreateAssociatedTokenAccount } from "@solana/spl-token";

// --- Configuração ---
const NUM_USERS = 100; // Número de usuários a serem simulados
const SOL_TO_AIRDROP = 0.5; // Quantidade de SOL para airdrop para cada usuário
const GMC_TO_MINT = 1000; // Quantidade de GMC para dar a cada usuário

const WALLETS_FILE_PATH = path.join(__dirname, '..', 'tests', 'volume_test_wallets.json');
const BATCH_SIZE = 20; // Tamanho do lote para processamento paralelo para evitar rate limits

type UserWallet = {
  publicKey: string;
  secretKey: string; // Base64 encoded
};

// Função para ler o Anchor.toml e configurar o provider
async function getProvider(): Promise<anchor.AnchorProvider> {
    const anchorTomlPath = path.join(__dirname, '..', 'Anchor.toml');
    const anchorTomlContent = await fs.readFile(anchorTomlPath, 'utf-8');
    const config = toml.parse(anchorTomlContent);
    
    let clusterUrl = config.provider.cluster;
    const clusterAlias = clusterUrl.toLowerCase();

    if (clusterAlias === "localnet") {
        clusterUrl = "http://127.0.0.1:8899";
    } else if (clusterAlias === "devnet") {
        clusterUrl = anchor.web3.clusterApiUrl("devnet");
    }

    const connection = new anchor.web3.Connection(clusterUrl, 'confirmed');
    
    // Carregar a carteira admin a partir do caminho no Anchor.toml
    let walletPath = config.provider.wallet;
    if (walletPath.startsWith('~')) {
        walletPath = path.join(os.homedir(), walletPath.slice(1));
    }
    const adminSecretKey = JSON.parse(await fs.readFile(walletPath, 'utf-8'));
    const adminKeypair = anchor.web3.Keypair.fromSecretKey(Uint8Array.from(adminSecretKey));
    const wallet = new anchor.Wallet(adminKeypair);

    return new anchor.AnchorProvider(connection, wallet, { commitment: 'confirmed' });
}


async function main() {
  console.log("🚀 Iniciando a preparação para o teste de volume...");

  const provider = await getProvider();
  anchor.setProvider(provider);
  
  const admin = (provider.wallet as anchor.Wallet).payer; // admin é um Keypair
  const adminWallet = provider.wallet; // adminWallet é um Wallet

  // Airdrop para a carteira admin não é mais necessário aqui, 
  // pois a carteira já deve ter fundos.


  // 1. Gerar Carteiras
  console.log(`🔑 Gerando ${NUM_USERS} carteiras de teste...`);
  const wallets: UserWallet[] = [];
  const keypairs: anchor.web3.Keypair[] = [];
  for (let i = 0; i < NUM_USERS; i++) {
    const keypair = anchor.web3.Keypair.generate();
    wallets.push({
      publicKey: keypair.publicKey.toBase58(),
      secretKey: Buffer.from(keypair.secretKey).toString('base64'),
    });
    keypairs.push(keypair);
  }

  await fs.writeFile(WALLETS_FILE_PATH, JSON.stringify(wallets, null, 2));
  console.log(`✅ Carteiras salvas em: ${WALLETS_FILE_PATH}`);

  // 2. Airdrop de SOL em lotes
  console.log(`💸 Financiando ${NUM_USERS} carteiras com ${SOL_TO_AIRDROP} SOL cada...`);
  await processInBatches(keypairs, BATCH_SIZE, async (batch, batchIndex) => {
    const airdropPromises = batch.map(kp => 
      provider.connection.requestAirdrop(kp.publicKey, SOL_TO_AIRDROP * anchor.web3.LAMPORTS_PER_SOL)
    );
    const signatures = await Promise.all(airdropPromises);
    await confirmTransactions(provider.connection, signatures);
    console.log(`  -> Lote ${batchIndex + 1}: ${batch.length} carteiras financiadas com SOL.`);
  });
  console.log("✅ Airdrop de SOL concluído.");

  // 3. Criar o Mint do GMC e distribuir tokens
  console.log(`🪙 Criando o mint de GMC e distribuindo ${GMC_TO_MINT} GMC para cada carteira...`);
 
  const adminProvider = new anchor.AnchorProvider(provider.connection, adminWallet, { commitment: 'confirmed' });

  const gmcMint = await createMint(
    adminProvider.connection,
    admin, // payer é um Keypair
    admin.publicKey,
    null, // freeze authority
    9, // 9 decimais
    anchor.web3.Keypair.generate(), // Mint Keypair
    undefined,
    TOKEN_2022_PROGRAM_ID
  );
  console.log(`   -> Mint de GMC criado: ${gmcMint.toBase58()}`);

  await processInBatches(keypairs, BATCH_SIZE, async (batch, batchIndex) => {
    const distributionPromises = batch.map(async (userKp) => {
      const userAta = await getOrCreateAssociatedTokenAccount(
        adminProvider.connection,
        admin,
        gmcMint,
        userKp.publicKey,
        false,
        "confirmed",
        undefined,
        TOKEN_2022_PROGRAM_ID
      );
      
      await mintTo(
        adminProvider.connection,
        admin,
        gmcMint,
        userAta.address,
        admin, // Mint Authority
        BigInt(GMC_TO_MINT * 1e9),
        [],
        undefined,
        TOKEN_2022_PROGRAM_ID
      );
    });
    
    await Promise.all(distributionPromises);
    console.log(`  -> Lote ${batchIndex + 1}: ${batch.length} carteiras receberam GMC tokens.`);
  });
  
  console.log("✅ Distribuição de GMC concluída.");
  console.log("🎉 Preparação para o teste de volume concluída com sucesso!");
}

async function processInBatches<T>(
  items: T[],
  batchSize: number,
  processFn: (batch: T[], batchIndex: number) => Promise<void>
): Promise<void> {
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    await processFn(batch, i / batchSize);
    await new Promise(resolve => setTimeout(resolve, 500));
  }
}

async function confirmTransactions(
  connection: anchor.web3.Connection,
  signatures: string[]
) {
  for (const sig of signatures) {
    const { blockhash, lastValidBlockHeight } = await connection.getLatestBlockhash();
    await connection.confirmTransaction({
      signature: sig,
      blockhash,
      lastValidBlockHeight
    }, 'confirmed');
  }
}


main().catch(err => {
  console.error("Ocorreu um erro durante o setup do teste de volume:");
  console.error(err);
  process.exit(1);
}); 