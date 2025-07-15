import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import {
  Keypair,
  SystemProgram,
  PublicKey,
} from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  createMint,
  createAssociatedTokenAccount,
  mintTo,
  getAccount,
} from "@solana/spl-token";
import { assert } from "chai";
import { GmcVesting } from "../target/types/gmc_vesting";

describe("GMC Vesting Contract", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcVesting as Program<GmcVesting>;
  
  let authority: Keypair;
  let beneficiary: Keypair;
  let gmcMint: PublicKey;
  let vaultTokenAccount: PublicKey;
  let beneficiaryTokenAccount: PublicKey;
  let vestingSchedulePda: PublicKey;
  let vestingScheduleBump: number;

  // Constants
  const DECIMALS = 9;
  const ONE_YEAR_IN_SECONDS = 365 * 24 * 60 * 60;

  before(async () => {
    authority = (provider.wallet as any).payer;
    beneficiary = Keypair.generate();

    // Create GMC Mint
    gmcMint = await createMint(
      provider.connection,
      authority,
      authority.publicKey,
      null,
      DECIMALS,
      undefined,
      {},
      TOKEN_2022_PROGRAM_ID
    );

    // Create Vault and Beneficiary Token Accounts
    vaultTokenAccount = await createAssociatedTokenAccount(
      provider.connection,
      authority,
      gmcMint,
      authority.publicKey, // The authority will hold the tokens initially
      {},
      TOKEN_2022_PROGRAM_ID
    );

    beneficiaryTokenAccount = await createAssociatedTokenAccount(
      provider.connection,
      authority,
      gmcMint,
      beneficiary.publicKey,
      {},
      TOKEN_2022_PROGRAM_ID
    );
    
    // Find the PDA for the vesting schedule
    [vestingSchedulePda, vestingScheduleBump] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_schedule"), beneficiary.publicKey.toBuffer()],
      program.programId
    );
  });

  it("Should create a new vesting schedule", async () => {
    const totalAmount = new anchor.BN(1_000_000 * 10 ** DECIMALS); // 1,000,000 GMC
    const clock = await provider.connection.getBlockTime(await provider.connection.getSlot());
    const startTimestamp = new anchor.BN(clock + 10); // Start in 10 seconds
    const durationSeconds = new anchor.BN(ONE_YEAR_IN_SECONDS);
    const cliffSeconds = new anchor.BN(ONE_YEAR_IN_SECONDS / 2); // 6 months cliff

    await program.methods
      .createSchedule(
        beneficiary.publicKey,
        totalAmount,
        startTimestamp,
        durationSeconds,
        cliffSeconds,
        { team: {} } // VestingType::Team
      )
      .accounts({
        vestingSchedule: vestingSchedulePda,
        authority: authority.publicKey,
        payer: authority.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    const schedule = await program.account.vestingSchedule.fetch(vestingSchedulePda);

    assert.ok(schedule.beneficiary.equals(beneficiary.publicKey));
    assert.equal(schedule.totalAmount.toString(), totalAmount.toString());
    assert.equal(schedule.startTimestamp.toString(), startTimestamp.toString());
    assert.equal(schedule.durationSeconds.toString(), durationSeconds.toString());
    assert.equal(schedule.cliffSeconds.toString(), cliffSeconds.toString());
    assert.equal(schedule.amountReleased.toString(), "0");
    assert.isFalse(schedule.isRevoked);
    assert.deepEqual(schedule.scheduleType, { team: {} });
    console.log("✅ Vesting schedule created successfully.");
  });

  it("Should fail to release tokens before the cliff period", async () => {
    // Mint tokens to vault to be used for vesting
    await mintTo(
        provider.connection,
        authority,
        gmcMint,
        vaultTokenAccount,
        authority,
        BigInt(1_000_000 * 10 ** DECIMALS),
        [],
        {},
        TOKEN_2022_PROGRAM_ID
    );

    try {
      await program.methods
        .release()
        .accounts({
          vestingSchedule: vestingSchedulePda,
          vault: vaultTokenAccount,
          beneficiaryTokenAccount: beneficiaryTokenAccount,
          tokenProgram: TOKEN_2022_PROGRAM_ID,
        })
        .rpc();
      assert.fail("Should have failed to release before cliff");
    } catch (error) {
      assert.include(error.message, "No tokens available for release at this time");
      console.log("✅ Correctly failed to release tokens before cliff period.");
    }
  });
  
  it("Should release a partial amount of tokens after the cliff", async () => {
    // To simulate time passing, we can't actually fast-forward the Solana clock in a live test.
    // Instead, we'll re-create a schedule with a past start time to simulate that time has passed.
    
    const beneficiary2 = Keypair.generate();
    const [schedulePda2] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), beneficiary2.publicKey.toBuffer()],
        program.programId
    );
     const beneficiaryTokenAccount2 = await createAssociatedTokenAccount(
      provider.connection,
      authority,
      gmcMint,
      beneficiary2.publicKey,
      {},
      TOKEN_2022_PROGRAM_ID
    );

    const totalAmount = new anchor.BN(1_000_000 * 10 ** DECIMALS);
    const currentTime = Math.floor(Date.now() / 1000);
    // Schedule started 9 months ago, cliff was 6 months ago, duration is 12 months
    const startTimestamp = new anchor.BN(currentTime - (ONE_YEAR_IN_SECONDS * 3 / 4));
    const durationSeconds = new anchor.BN(ONE_YEAR_IN_SECONDS);
    const cliffSeconds = new anchor.BN(ONE_YEAR_IN_SECONDS / 2);

    await program.methods
      .createSchedule(
        beneficiary2.publicKey,
        totalAmount,
        startTimestamp,
        durationSeconds,
        cliffSeconds,
        { strategicReserve: {} }
      )
      .accounts({
        vestingSchedule: schedulePda2,
        authority: authority.publicKey,
        payer: authority.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    await program.methods
      .release()
      .accounts({
        vestingSchedule: schedulePda2,
        vault: vaultTokenAccount,
        beneficiaryTokenAccount: beneficiaryTokenAccount2,
        tokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .rpc();

    const beneficiaryAccountAfter = await getAccount(provider.connection, beneficiaryTokenAccount2, 'confirmed', TOKEN_2022_PROGRAM_ID);
    const scheduleAfter = await program.account.vestingSchedule.fetch(schedulePda2);

    // Expected vested amount is 75% of total
    const expectedAmount = totalAmount.mul(new anchor.BN(3)).div(new anchor.BN(4));
    
    assert.equal(beneficiaryAccountAfter.amount.toString(), expectedAmount.toString(), "Beneficiary should have ~75% of tokens");
    assert.equal(scheduleAfter.amountReleased.toString(), expectedAmount.toString(), "Schedule should track the released amount");
    console.log("✅ Partial release successful after cliff.");
  });
  
  it("Should release all remaining tokens after the duration ends", async () => {
    // Using the same schedule from the previous test
    const beneficiary2 = Keypair.generate();
     const [schedulePda2] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), beneficiary2.publicKey.toBuffer()],
        program.programId
    );
     const beneficiaryTokenAccount2 = await createAssociatedTokenAccount(
      provider.connection,
      authority,
      gmcMint,
      beneficiary2.publicKey,
      {},
      TOKEN_2022_PROGRAM_ID
    );

    const totalAmount = new anchor.BN(1_000_000 * 10 ** DECIMALS);
    const currentTime = Math.floor(Date.now() / 1000);
    // Schedule started 13 months ago
    const startTimestamp = new anchor.BN(currentTime - (ONE_YEAR_IN_SECONDS + 30*24*60*60));
    const durationSeconds = new anchor.BN(ONE_YEAR_IN_SECONDS);
    const cliffSeconds = new anchor.BN(0); // No cliff for simplicity

     await program.methods
      .createSchedule(
        beneficiary2.publicKey,
        totalAmount,
        startTimestamp,
        durationSeconds,
        cliffSeconds,
        { marketing: {} }
      )
      .accounts({
        vestingSchedule: schedulePda2,
        authority: authority.publicKey,
        payer: authority.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();
      
    await program.methods
      .release()
      .accounts({
        vestingSchedule: schedulePda2,
        vault: vaultTokenAccount,
        beneficiaryTokenAccount: beneficiaryTokenAccount2,
        tokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .rpc();

    const beneficiaryAccountAfter = await getAccount(provider.connection, beneficiaryTokenAccount2, 'confirmed', TOKEN_2022_PROGRAM_ID);
    assert.equal(beneficiaryAccountAfter.amount.toString(), totalAmount.toString(), "Beneficiary should have all tokens");
    console.log("✅ Full release successful after duration ends.");
  });

  it("Should allow the admin to revoke a schedule", async () => {
    const schedule = await program.account.vestingSchedule.fetch(vestingSchedulePda);

    await program.methods
      .revokeSchedule()
      .accounts({
        vestingSchedule: vestingSchedulePda,
        authority: authority.publicKey,
      })
      .rpc();
      
    const scheduleAfter = await program.account.vestingSchedule.fetch(vestingSchedulePda);
    assert.isTrue(scheduleAfter.isRevoked, "Schedule should be revoked");
    console.log("✅ Schedule revoked successfully.");
  });

  it("Should fail to release tokens from a revoked schedule", async () => {
    try {
      await program.methods
        .release()
        .accounts({
          vestingSchedule: vestingSchedulePda,
          vault: vaultTokenAccount,
          beneficiaryTokenAccount: beneficiaryTokenAccount,
          tokenProgram: TOKEN_2022_PROGRAM_ID,
        })
        .rpc();
      assert.fail("Should have failed to release from a revoked schedule");
    } catch (error) {
      assert.include(error.message, "Vesting schedule has been revoked");
      console.log("✅ Correctly failed to release tokens from revoked schedule.");
    }
  });

});
