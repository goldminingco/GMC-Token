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
  getAccount
} from "@solana/spl-token";

// Helper function to advance blockchain time
async function advanceTime(provider: anchor.AnchorProvider, seconds: number) {
    // There is no direct way to advance time in the main Solana test validator.
    // This is a placeholder for a concept that would be implemented in a custom test environment
    // or by using features of frameworks like anchor-client-gen or a local validator fork.
    // For now, we will manipulate the start_timestamp in the test itself to simulate time passing.
    console.log(`(Simulation) Advancing time by ${seconds} seconds...`);
}

describe("GMC Staking Contract - Withdraw Long-Term Stake", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = (provider.wallet as any).payer as Keypair;
  const staker = Keypair.generate();

  let gmcMint: PublicKey;
  let stakerGmcAta: PublicKey;
  let stakePositionPDA: PublicKey;
  let gmcVaultPDA: PublicKey;
  let globalConfigPDA: PublicKey;
  let userStakeInfoPDA: PublicKey;

  const STAKE_AMOUNT = new anchor.BN(100 * 10**9); // 100 GMC

  before(async () => {
    // Setup environment
    await provider.connection.requestAirdrop(staker.publicKey, 2 * LAMPORTS_PER_SOL);
    const gmcMintKP = Keypair.generate();
    gmcMint = gmcMintKP.publicKey;
    await createMint(provider.connection, authority, gmcMint, null, 9, gmcMintKP, {}, TOKEN_2022_PROGRAM_ID);
    stakerGmcAta = await createAssociatedTokenAccount(provider.connection, staker, gmcMint, staker.publicKey, {}, TOKEN_2022_PROGRAM_ID);
    await mintTo(provider.connection, authority, gmcMint, stakerGmcAta, authority, BigInt(STAKE_AMOUNT.toString()), [], {}, TOKEN_2022_PROGRAM_ID);
    
    // Derive all necessary PDAs
    [userStakeInfoPDA] = PublicKey.findProgramAddressSync([Buffer.from("user_stake_info"), staker.publicKey.toBuffer()], program.programId);
    [gmcVaultPDA] = PublicKey.findProgramAddressSync([Buffer.from("gmc_vault")], program.programId);
    [globalConfigPDA] = PublicKey.findProgramAddressSync([Buffer.from("global_config")], program.programId);
    
    // Initialize user and then perform a long-term stake
    await program.methods.initializeUser().accounts({ userStakeInfo: userStakeInfoPDA, user: staker.publicKey, systemProgram: SystemProgram.programId }).signers([staker]).rpc();
    const userInfo = await program.account.userStakeInfo.fetch(userStakeInfoPDA);
    [stakePositionPDA] = PublicKey.findProgramAddressSync([Buffer.from("stake_position"), staker.publicKey.toBuffer(), userInfo.stakeCount.toBuffer('le', 8)], program.programId);
    
    await program.methods.stakeLongTerm(STAKE_AMOUNT).accounts({
        stakePosition: stakePositionPDA,
        userStakeInfo: userStakeInfoPDA,
        globalConfig: globalConfigPDA,
        staker: staker.publicKey,
        gmcMint: gmcMint,
        stakerGmcAta: stakerGmcAta,
        gmcVault: gmcVaultPDA,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_2022_PROGRAM_ID,
    }).signers([staker]).rpc();
  });

  it("Should allow a user to withdraw their principal after 12 months", async () => {
    // RED: This test will fail as withdraw_principal_long is not implemented

    // Simulate time passing by manually setting the start_timestamp
    const twelveMonthsAndOneDay = (365 * 24 * 60 * 60) + (24 * 60 * 60);
    await program.methods
      .setStakeTimestampTest(new anchor.BN(Math.floor(Date.now() / 1000) - twelveMonthsAndOneDay))
      .accounts({ stakePosition: stakePositionPDA, authority: authority.publicKey })
      .rpc();
      
    const initialStakerBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;

    await program.methods
      .withdrawPrincipalLong()
      .accounts({
        stakePosition: stakePositionPDA,
        globalConfig: globalConfigPDA,
        gmcVault: gmcVaultPDA,
        staker: staker.publicKey,
        stakerGmcAta: stakerGmcAta,
        tokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .signers([staker])
      .rpc();

    const finalStakerBalance = (await getAccount(provider.connection, stakerGmcAta)).amount;
    
    assert.equal(finalStakerBalance.toString(), (initialStakerBalance + BigInt(STAKE_AMOUNT.toString())).toString());
    
    try {
        await program.account.stakePosition.fetch(stakePositionPDA);
        assert.fail("Stake position account should have been closed");
    } catch (e) {
        assert.include(e.message, "Account does not exist");
    }
  });
}); 