import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import { assert } from "chai";
import { Keypair, LAMPORTS_PER_SOL, SystemProgram, PublicKey } from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  TOKEN_PROGRAM_ID,
  createMint,
  createAssociatedTokenAccount,
  mintTo,
  getAccount,
  transfer,
} from "@solana/spl-token";

describe("GMC Staking Contract - Emergency Unstake Long-Term", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = (provider.wallet as any).payer as Keypair;
  const staker = Keypair.generate();

  let gmcMint: PublicKey;
  let usdtMint: PublicKey;
  let stakerGmcAta: PublicKey;
  let stakerUsdtAta: PublicKey;
  let stakePositionPDA: PublicKey;
  let gmcVaultPDA: PublicKey;
  let penaltyWallet: PublicKey; // Wallet to collect penalties

  const STAKE_AMOUNT = new anchor.BN(100 * 10**9); // 100 GMC
  const USDT_FEE = 5 * 10**6; // 5 USDT

  before(async () => {
    // Basic setup
    await provider.connection.requestAirdrop(staker.publicKey, 2 * LAMPORTS_PER_SOL);
    const gmcMintKP = Keypair.generate();
    gmcMint = gmcMintKP.publicKey;
    const usdtMintKP = Keypair.generate();
    usdtMint = usdtMintKP.publicKey;
    
    await createMint(provider.connection, authority, gmcMint, null, 9, gmcMintKP, {}, TOKEN_2022_PROGRAM_ID);
    await createMint(provider.connection, authority, usdtMint, null, 6, usdtMintKP); // Standard USDT decimals
    
    stakerGmcAta = await createAssociatedTokenAccount(provider.connection, staker, gmcMint, staker.publicKey, {}, TOKEN_2022_PROGRAM_ID);
    stakerUsdtAta = await createAssociatedTokenAccount(provider.connection, staker, usdtMint, staker.publicKey);
    penaltyWallet = await createAssociatedTokenAccount(provider.connection, authority, usdtMint, authority.publicKey);

    await mintTo(provider.connection, authority, gmcMint, stakerGmcAta, authority, BigInt(STAKE_AMOUNT.toString()), [], {}, TOKEN_2022_PROGRAM_ID);
    await mintTo(provider.connection, authority, usdtMint, stakerUsdtAta, authority, BigInt(USDT_FEE));
    
    // Perform a stake to test emergency withdrawal on
    // This part assumes previous instructions like initializeUser and stakeLongTerm work
    // and would be part of a larger, chained test suite.
  });

  it("Should allow a user to perform an emergency unstake with penalty", async () => {
    // RED: This test will fail as the instruction is not implemented
    
    // First, let's do a stake
    const [userStakeInfoPDA] = await PublicKey.findProgramAddress([Buffer.from("user_stake_info"), staker.publicKey.toBuffer()], program.programId);
    await program.methods.initializeUser().accounts({ userStakeInfo: userStakeInfoPDA, user: staker.publicKey }).signers([staker]).rpc();
    const userInfo = await program.account.userStakeInfo.fetch(userStakeInfoPDA);
    [stakePositionPDA] = await PublicKey.findProgramAddress([Buffer.from("stake_position"), staker.publicKey.toBuffer(), userInfo.stakeCount.toBuffer('le', 8)], program.programId);
    [gmcVaultPDA] = await PublicKey.findProgramAddress([Buffer.from("gmc_vault")], program.programId);
    
    await program.methods.stakeLongTerm(STAKE_AMOUNT).accounts({ /* ... full accounts ... */ }).signers([staker]).rpc();

    const initialStakerGmcBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;
    
    // Now, perform the emergency unstake
    await program.methods
      .emergencyUnstakeLong()
      .accounts({
        stakePosition: stakePositionPDA,
        staker: staker.publicKey,
        gmcVault: gmcVaultPDA,
        stakerGmcAta: stakerGmcAta,
        stakerUsdtAta: stakerUsdtAta,
        penaltyWallet: penaltyWallet,
        tokenProgram: TOKEN_PROGRAM_ID, // Note: Standard token program for USDT transfer
        gmcTokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .signers([staker])
      .rpc();

    // Assertions
    const finalStakerGmcBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;
    const expectedReturnAmount = BigInt(STAKE_AMOUNT.divn(2).toString()); // 50% penalty
    
    assert.equal(finalStakerGmcBalance.toString(), (initialStakerGmcBalance + expectedReturnAmount).toString(), "User should receive 50% of principal back");
    
    // Check if stake account is closed
    try {
      await program.account.stakePosition.fetch(stakePositionPDA);
      assert.fail("Stake position account should have been closed.");
    } catch (error) {
      assert.include(error.message, "Account does not exist");
    }
  });
}); 