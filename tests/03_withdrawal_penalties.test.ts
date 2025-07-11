import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import {
  Keypair,
  SystemProgram,
  PublicKey,
} from "@solana/web3.js";
import {
  getOrCreateAssociatedTokenAccount,
  mintTo,
  createMint,
  TOKEN_PROGRAM_ID,
  getAccount,
} from "@solana/spl-token";
import { assert } from "chai";

describe("GMC Staking - Withdrawal Penalties", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = provider.wallet as anchor.Wallet;

  let gmcMint: PublicKey;
  let usdtMint: PublicKey;
  let globalConfig: PublicKey;
  
  let staker: Keypair;
  let stakerGmcAta: PublicKey;
  let stakerUsdtAta: PublicKey;
  let userStakeInfo: PublicKey;

  before(async () => {
    // Mints
    gmcMint = await createMint(provider.connection, authority.payer, authority.publicKey, null, 9);
    usdtMint = await createMint(provider.connection, authority.payer, authority.publicKey, null, 6);

    // Staker setup
    staker = Keypair.generate();
    await provider.connection.requestAirdrop(staker.publicKey, 5 * anchor.web3.LAMPORTS_PER_SOL);
    stakerGmcAta = (await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, staker.publicKey)).address;
    stakerUsdtAta = (await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, usdtMint, staker.publicKey)).address;
    
    // Mint initial tokens to staker for test
    await mintTo(provider.connection, authority.payer, gmcMint, stakerGmcAta, authority.payer, 1_000_000 * (10 ** 9)); // 1M GMC
    await mintTo(provider.connection, authority.payer, usdtMint, stakerUsdtAta, authority.payer, 100 * (10 ** 6)); // 100 USDT
    
    // PDAs
    [globalConfig] = PublicKey.findProgramAddressSync([Buffer.from("global_config")], program.programId);
    [userStakeInfo] = PublicKey.findProgramAddressSync([Buffer.from("user_stake_info"), staker.publicKey.toBuffer()], program.programId);
    
    // Initialize program
    await program.methods.initialize(authority.publicKey, authority.publicKey, authority.publicKey, authority.publicKey)
        .accounts({ globalConfig, gmcMint, usdtMint, authority: authority.publicKey, systemProgram: SystemProgram.programId }).rpc();
    await program.methods.initializeUser().accounts({ userStakeInfo, user: staker.publicKey, systemProgram: SystemProgram.programId }).signers([staker]).rpc();
  });

  it("RED: Should apply penalty on principal AND accrued interest", async () => {
    // 1. Create a long-term stake
    const stakeAmount = new anchor.BN(1000 * (10 ** 9));
    const [stakePosition] = PublicKey.findProgramAddressSync(
        [Buffer.from("stake_position"), staker.publicKey.toBuffer(), new anchor.BN(0).toBuffer('le', 8)],
        program.programId
    );
    const [gmcVault] = PublicKey.findProgramAddressSync([Buffer.from("gmc_vault")], program.programId);

    await program.methods.stakeLongTerm(stakeAmount).accounts({
        stakePosition,
        userStakeInfo,
        gmcVault,
        stakerGmcAta,
        staker: staker.publicKey,
        gmcMint,
        globalConfig,
        tokenProgram: TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId,
    }).signers([staker]).rpc();

    // 2. Simulate time passing by fetching the schedule and calculating interest off-chain
    const schedule = await program.account.stakePosition.fetch(stakePosition);
    // Let's assume 180 days have passed for interest calculation
    const timeElapsed = 180 * 24 * 60 * 60; 
    
    // Helper to calculate expected interest (simplified from contract logic for test validation)
    const calculateExpectedInterest = (principal, days) => {
        const baseApy = 10; // 10%
        const dailyRate = baseApy / 365 / 100;
        return BigInt(Math.floor(Number(principal) * dailyRate * days));
    };

    const accruedInterest = calculateExpectedInterest(stakeAmount, 180);
    const interestPenalty = BigInt(Math.floor(Number(accruedInterest) * 0.8)); // 80% penalty
    const capitalPenalty = stakeAmount.divn(2).toNumber(); // 50% penalty
    const totalPenalty = BigInt(capitalPenalty) + interestPenalty;

    // 3. Call emergency unstake
    const burnWalletKeypair = Keypair.generate();
    const burnWallet = await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, burnWalletKeypair.publicKey);
    const rankingFundKeypair = Keypair.generate();
    const rankingFundWallet = await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, rankingFundKeypair.publicKey);
    const penaltyWalletKeypair = Keypair.generate();
    const penaltyWallet = await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, usdtMint, penaltyWalletKeypair.publicKey);

    const initialStakerBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;

    await program.methods.emergencyUnstakeLong()
        .accounts({
            stakePosition,
            staker: staker.publicKey,
            gmcVault,
            stakerGmcAta,
            stakerUsdtAta,
            penaltyWallet: penaltyWallet.address,
            burnWallet: burnWallet.address,
            rankingFundWallet: rankingFundWallet.address,
            globalConfig,
            tokenProgram: TOKEN_PROGRAM_ID,
            gmcTokenProgram: TOKEN_PROGRAM_ID,
        })
        .signers([staker])
        .rpc();

    // 4. Assert balances
    const expectedReturnAmount = stakeAmount.sub(new anchor.BN(capitalPenalty));
    const finalStakerBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;
    assert.equal(finalStakerBalance.toString(), (initialStakerBalance + BigInt(expectedReturnAmount.toString())).toString(), "Staker did not receive the correct amount back");

    const burnBalance = (await getAccount(provider.connection, burnWallet.address)).amount;
    const rankingBalance = (await getAccount(provider.connection, rankingFundWallet.address)).amount;
    const expectedBurnShare = totalPenalty * BigInt(30) / BigInt(100);
    const expectedRankingShare = totalPenalty * BigInt(20) / BigInt(100);

    assert.equal(burnBalance.toString(), expectedBurnShare.toString(), "Burn wallet did not receive the correct penalty share");
    assert.equal(rankingBalance.toString(), expectedRankingShare.toString(), "Ranking wallet did not receive the correct penalty share");
  });
}); 