import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import { assert } from "chai";
import { Keypair, LAMPORTS_PER_SOL, SystemProgram, PublicKey } from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  createMint,
  createAssociatedTokenAccount,
  mintTo,
  getAccount,
} from "@solana/spl-token";

describe("GMC Staking Contract - Claim Rewards", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = (provider.wallet as any).payer as Keypair;
  const staker = Keypair.generate();

  let gmcMint: PublicKey;
  let stakerGmcAta: PublicKey;
  let stakePositionPDA: PublicKey;
  let gmcVaultPDA: PublicKey;
  let burnWallet: PublicKey;
  let rankingFundWallet: PublicKey;

  const STAKE_AMOUNT = new anchor.BN(1000 * 10**9); // 1000 GMC

  before(async () => {
    // Basic setup from previous tests
    await provider.connection.requestAirdrop(staker.publicKey, 2 * LAMPORTS_PER_SOL);
    const gmcMintKP = Keypair.generate();
    gmcMint = gmcMintKP.publicKey;
    await createMint(provider.connection, authority, gmcMint, null, 9, gmcMintKP, {}, TOKEN_2022_PROGRAM_ID);
    stakerGmcAta = await createAssociatedTokenAccount(provider.connection, staker, gmcMint, staker.publicKey, {}, TOKEN_2022_PROGRAM_ID);
    await mintTo(provider.connection, authority, gmcMint, stakerGmcAta, authority, BigInt(STAKE_AMOUNT.muln(2).toString()), [], {}, TOKEN_2022_PROGRAM_ID);
    
    // Assumes global_config and user_stake_info are initialized, and a stake is made.
    burnWallet = await createAssociatedTokenAccount(provider.connection, authority, gmcMint, new PublicKey("11111111111111111111111111111111"), true, TOKEN_2022_PROGRAM_ID);
    rankingFundWallet = await createAssociatedTokenAccount(provider.connection, authority, gmcMint, authority.publicKey, {}, TOKEN_2022_PROGRAM_ID);
  });

  it("Should allow a user to claim rewards and correctly distribute fees", async () => {
    // RED: This test will fail as claim_rewards is not implemented
    
    // 1. Stake
    // ... (staking logic would be here)

    // 2. Simulate 30 days passing
    const thirtyDays = 30 * 24 * 60 * 60;
    await program.methods
        .setStakeTimestampTest(new anchor.BN(Math.floor(Date.now() / 1000) - thirtyDays))
        .accounts({ stakePosition: stakePositionPDA, staker: staker.publicKey })
        .signers([staker])
        .rpc();

    const initialStakerBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;
    const stakePositionBefore = await program.account.stakePosition.fetch(stakePositionPDA);

    // 3. Claim Rewards
    await program.methods
      .claimRewards()
      .accounts({
        stakePosition: stakePositionPDA,
        staker: staker.publicKey,
        stakerGmcAta: stakerGmcAta,
        gmcVault: gmcVaultPDA,
        burnWallet: burnWallet,
        rankingFundWallet: rankingFundWallet,
        tokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .signers([staker])
      .rpc();

    // 4. Assertions
    const stakePositionAfter = await program.account.stakePosition.fetch(stakePositionPDA);
    const finalStakerBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;

    // Expected rewards for 30 days at 10% APY (base)
    // Rewards = Principal * APY * Time / (SecondsInYear * BasisPoints)
    // Rewards = 1000 * 1000 * (30*24*60*60) / (365*24*60*60 * 10000) = ~8.219 GMC
    const expectedRewards = new anchor.BN("8219178082"); // ~8.219 GMC
    const fee = expectedRewards.divn(100); // 1% fee
    const expectedPayout = expectedRewards.sub(fee);
    
    assert.equal(finalStakerBalance.toString(), (initialStakerBalance + BigInt(expectedPayout.toString())).toString(), "Incorrect payout amount");
    assert.ok(stakePositionAfter.lastRewardClaimTimestamp > stakePositionBefore.lastRewardClaimTimestamp, "lastRewardClaimTimestamp should be updated");

    // New Assertions for fee distribution
    const burnAmount = fee.muln(40).divn(100); // 40%
    const rankingAmount = fee.muln(10).divn(100); // 10%
    // 50% remains in the vault

    const burnWalletAccount = await getAccount(provider.connection, burnWallet);
    const rankingFundWalletAccount = await getAccount(provider.connection, rankingFundWallet);

    assert.equal(burnWalletAccount.amount.toString(), burnAmount.toString(), "40% of the fee should go to the burn wallet");
    assert.equal(rankingFundWalletAccount.amount.toString(), rankingAmount.toString(), "10% of the fee should go to the ranking fund");
  });
}); 