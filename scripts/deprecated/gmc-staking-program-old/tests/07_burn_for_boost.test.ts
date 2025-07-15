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
} from "@solana/spl-token";

describe("GMC Staking Contract - Burn for Boost", () => {
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
  let feeWallet: PublicKey; // Mock wallet for fees
  const burnAddress = Keypair.generate().publicKey; // A random address for burning

  const STAKE_AMOUNT = new anchor.BN(1000 * 10**9); // 1000 GMC
  const BURN_AMOUNT = new anchor.BN(300 * 10**9); // 300 GMC
  const USDT_FEE = new anchor.BN(800_000); // 0.8 USDT

  before(async () => {
    // Setup: Create mints, ATAs, perform a stake
    await provider.connection.requestAirdrop(staker.publicKey, 2 * LAMPORTS_PER_SOL);
    const gmcMintKP = Keypair.generate();
    gmcMint = gmcMintKP.publicKey;
    const usdtMintKP = Keypair.generate();
    usdtMint = usdtMintKP.publicKey;
    
    await createMint(provider.connection, authority, gmcMint, null, 9, gmcMintKP, {}, TOKEN_2022_PROGRAM_ID);
    await createMint(provider.connection, authority, usdtMint, null, 6, usdtMintKP);
    
    stakerGmcAta = await createAssociatedTokenAccount(provider.connection, staker, gmcMint, staker.publicKey, {}, TOKEN_2022_PROGRAM_ID);
    stakerUsdtAta = await createAssociatedTokenAccount(provider.connection, staker, usdtMint, staker.publicKey);
    feeWallet = await createAssociatedTokenAccount(provider.connection, authority, usdtMint, authority.publicKey);

    // Mint enough GMC for staking and burning, and USDT for the fee
    await mintTo(provider.connection, authority, gmcMint, stakerGmcAta, authority, BigInt(STAKE_AMOUNT.add(BURN_AMOUNT.muln(2)).toString()), [], {}, TOKEN_2022_PROGRAM_ID);
    await mintTo(provider.connection, authority, usdtMint, stakerUsdtAta, authority, BigInt(USDT_FEE.toString()));
    
    // This setup assumes initialize and initializeUser have been run.
  });

  it("Should allow a user to burn GMC to boost their staking power", async () => {
    // RED: This will fail as burn_for_boost is not implemented

    // First, perform a stake
    // ... (staking logic from previous tests would be here) ...
    
    const gmcFeeForBurning = BURN_AMOUNT.divn(10); // 10% fee on burn amount
    const totalGmcToDebit = BURN_AMOUNT.add(gmcFeeForBurning);

    await program.methods
      .burnForBoost(BURN_AMOUNT)
      .accounts({
        stakePosition: stakePositionPDA,
        staker: staker.publicKey,
        stakerGmcAta: stakerGmcAta,
        stakerUsdtAta: stakerUsdtAta,
        usdtFeeWallet: feeWallet,
        gmcBurnWallet: burnAddress,
        tokenProgram: TOKEN_PROGRAM_ID,
        gmcTokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .signers([staker])
      .rpc();

    // Assertions
    const positionAccount = await program.account.stakePosition.fetch(stakePositionPDA);
    // Formula: Staking Power = MIN(100, (total burned / principal) * 100)
    // Here: (300 / 1000) * 100 = 30
    assert.equal(positionAccount.stakingPowerFromBurn, 30, "Staking power should be 30");
    assert.equal(positionAccount.totalGmcBurned.toString(), BURN_AMOUNT.toString(), "Total burned amount incorrect");
  });
}); 