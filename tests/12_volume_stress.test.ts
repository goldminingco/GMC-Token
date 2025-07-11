import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import { promises as fs } from 'fs';
import path from 'path';
import { assert } from "chai";
import { getOrCreateAssociatedTokenAccount, TOKEN_2022_PROGRAM_ID } from "@solana/spl-token";

const WALLETS_FILE_PATH = path.join(__dirname, 'volume_test_wallets.json');
const BATCH_SIZE = 10; // Reduzir o lote para transações de staking mais pesadas

type UserWalletData = {
  publicKey: string;
  secretKey: string; // Base64 encoded
};

describe("Stress and Volume Tests for GMC Staking", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const stakingProgram = anchor.workspace.GmcStaking as Program<GmcStaking>;
  
  let userWallets: anchor.Wallet[] = [];
  let gmcMint: anchor.web3.PublicKey; // Precisaremos do mint address do setup

  before(async () => {
    // Carregar as carteiras geradas
    const walletsData: UserWalletData[] = JSON.parse(await fs.readFile(WALLETS_FILE_PATH, 'utf-8'));
    userWallets = walletsData.map(data => {
        const secretKey = Buffer.from(data.secretKey, 'base64');
        const keypair = anchor.web3.Keypair.fromSecretKey(secretKey);
        return new anchor.Wallet(keypair);
    });

    // Precisamos saber o mint do GMC. Como ele é gerado dinamicamente no setup,
    // a forma mais fácil é ler o log do validador ou assumir que o teste
    // é executado logo após o setup. Para este teste, vamos precisar encontrá-lo.
    // **ASSUMINDO** que o mint é o último criado. Uma solução melhor seria salvar o mint no setup.
    // Por enquanto, vamos buscar as contas de token do primeiro usuário.
    const firstUser = userWallets[0];
    const tokenAccounts = await provider.connection.getParsedTokenAccountsByOwner(firstUser.publicKey, { programId: TOKEN_2022_PROGRAM_ID });
    assert.isNotEmpty(tokenAccounts.value, "A carteira do primeiro usuário não possui conta de token");
    gmcMint = new anchor.web3.PublicKey(tokenAccounts.value[0].account.data.parsed.info.mint);
    console.log(`Mint de GMC identificado para o teste: ${gmcMint.toBase58()}`);
  });

  it("Scenario 1: Mass Staking - 100 users stake simultaneously", async () => {
    console.log(`🔥 Iniciando teste de Staking em Massa para ${userWallets.length} usuários...`);
    const stakeAmount = new anchor.BN(100 * 1e9); // Stake de 100 GMC

    let successfulStakes = 0;
    let failedStakes = 0;

    await processInBatches(userWallets, BATCH_SIZE, async (batch, batchIndex) => {
        const stakePromises = batch.map(async (userWallet) => {
            try {
                const userProvider = new anchor.AnchorProvider(provider.connection, userWallet, anchor.AnchorProvider.defaultOptions());

                const userAta = await getOrCreateAssociatedTokenAccount(
                    userProvider.connection,
                    (userProvider.wallet as anchor.Wallet).payer,
                    gmcMint,
                    userWallet.publicKey,
                    false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID
                );
                
                const [stakePositionPda] = anchor.web3.PublicKey.findProgramAddressSync(
                    [Buffer.from("stake"), userWallet.publicKey.toBuffer()],
                    stakingProgram.programId
                );

                const [globalStatePda] = anchor.web3.PublicKey.findProgramAddressSync(
                    [Buffer.from("global_state")],
                    stakingProgram.programId
                );

                const [vaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
                    [Buffer.from("vault")],
                    stakingProgram.programId
                );

                await stakingProgram.methods
                    .stakeFlexible(stakeAmount)
                    .accounts({
                        user: userWallet.publicKey,
                        globalState: globalStatePda,
                        stakePosition: stakePositionPda,
                        userGmcAccount: userAta.address,
                        gmcVault: vaultPda,
                        tokenProgram: TOKEN_2022_PROGRAM_ID,
                        systemProgram: anchor.web3.SystemProgram.programId,
                    })
                    .signers([(userProvider.wallet as anchor.Wallet).payer])
                    .rpc();
                
                successfulStakes++;
            } catch (error) {
                console.error(`Erro ao fazer stake para o usuário ${userWallet.publicKey.toBase58()}:`, error);
                failedStakes++;
            }
        });
        
        await Promise.all(stakePromises);
        console.log(`  -> Lote ${batchIndex + 1}: stakes processados.`);
    });

    console.log("✅ Teste de Staking em Massa Concluído.");
    console.log(`   Resultados: ${successfulStakes} stakes bem-sucedidos, ${failedStakes} falhas.`);
    assert.equal(failedStakes, 0, "Deveriam ocorrer 0 falhas no staking em massa");
  });

  // Cenários futuros (Mass Claim, Mass Unstake) podem ser adicionados aqui
});


async function processInBatches<T>(
    items: T[],
    batchSize: number,
    processFn: (batch: T[], batchIndex: number) => Promise<void>
  ): Promise<void> {
    for (let i = 0; i < items.length; i += batchSize) {
      const batch = items.slice(i, i + batchSize);
      await processFn(batch, i / batchSize);
      await new Promise(resolve => setTimeout(resolve, 1000)); // Delay maior entre lotes
    }
} 