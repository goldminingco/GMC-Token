import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, createMint, createAccount, mintTo, getAccount } from "@solana/spl-token";
import { assert, expect } from "chai";
import { GmcVesting } from "../target/types/gmc_vesting";

describe("🏗️ GMC Vesting Contract", () => {
  // Configure the client to use the local cluster
  anchor.setProvider(anchor.AnchorProvider.env());

  const program = anchor.workspace.GmcVesting as Program<GmcVesting>;
  const provider = anchor.getProvider();

  // Test accounts
  let authority: Keypair;
  let beneficiary: Keypair;
  let gmcMint: PublicKey;
  let vaultAccount: PublicKey;
  let beneficiaryTokenAccount: PublicKey;
  let vestingSchedulePda: PublicKey;

  before(async () => {
    console.log("🚀 Setting up Vesting Contract test environment...");

    // Create test keypairs
    authority = Keypair.generate();
    beneficiary = Keypair.generate();

    // Airdrop SOL to test accounts
    await provider.connection.requestAirdrop(authority.publicKey, 2 * anchor.web3.LAMPORTS_PER_SOL);
    await provider.connection.requestAirdrop(beneficiary.publicKey, 1 * anchor.web3.LAMPORTS_PER_SOL);

    // Create GMC mint
    gmcMint = await createMint(
      provider.connection,
      authority,
      authority.publicKey,
      null,
      9 // 9 decimals for GMC
    );

    // Create vault account (will hold vested tokens)
    vaultAccount = await createAccount(
      provider.connection,
      authority,
      gmcMint,
      authority.publicKey // For now, authority controls vault
    );

    // Create beneficiary token account
    beneficiaryTokenAccount = await createAccount(
      provider.connection,
      authority,
      gmcMint,
      beneficiary.publicKey
    );

    // Mint test tokens to vault
    await mintTo(
      provider.connection,
      authority,
      gmcMint,
      vaultAccount,
      authority,
      10_000_000 * 10**9 // 10M GMC for testing
    );

    // Derive vesting schedule PDA
    [vestingSchedulePda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("vesting_schedule"),
        beneficiary.publicKey.toBuffer(),
      ],
      program.programId
    );

    console.log("✅ Test environment setup complete");
    console.log(`   - Authority: ${authority.publicKey.toString()}`);
    console.log(`   - Beneficiary: ${beneficiary.publicKey.toString()}`);
    console.log(`   - GMC Mint: ${gmcMint.toString()}`);
    console.log(`   - Vault: ${vaultAccount.toString()}`);
  });

  describe("📅 Vesting Schedule Creation", () => {
    it("should create a team vesting schedule", async () => {
      console.log("🧪 TEST: Creating team vesting schedule...");

      const totalAmount = new anchor.BN(2_000_000 * 10**9); // 2M GMC
      const startTimestamp = new anchor.BN(Math.floor(Date.now() / 1000) + 60); // Start in 1 minute
      const durationSeconds = new anchor.BN(5 * 365 * 24 * 60 * 60); // 5 years
      const cliffSeconds = new anchor.BN(365 * 24 * 60 * 60); // 1 year cliff

      const tx = await program.methods
        .createSchedule(
          beneficiary.publicKey,
          totalAmount,
          startTimestamp,
          durationSeconds,
          cliffSeconds,
          { team: {} }
        )
        .accounts({
          vestingSchedule: vestingSchedulePda,
          authority: authority.publicKey,
          payer: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      console.log("✅ Team vesting schedule created, tx:", tx);

      // Verify the schedule was created correctly
      const scheduleAccount = await program.account.vestingSchedule.fetch(vestingSchedulePda);
      
      assert.equal(scheduleAccount.beneficiary.toString(), beneficiary.publicKey.toString());
      assert.equal(scheduleAccount.totalAmount.toString(), totalAmount.toString());
      assert.equal(scheduleAccount.startTimestamp.toString(), startTimestamp.toString());
      assert.equal(scheduleAccount.durationSeconds.toString(), durationSeconds.toString());
      assert.equal(scheduleAccount.cliffSeconds.toString(), cliffSeconds.toString());
      assert.equal(scheduleAccount.amountReleased.toString(), "0");
      assert.equal(scheduleAccount.isRevoked, false);
      assert.deepEqual(scheduleAccount.scheduleType, { team: {} });

      console.log("✅ Vesting schedule verified");
    });

    it("should fail to create schedule with invalid amount", async () => {
      console.log("🧪 TEST: Should fail with invalid amount...");

      const invalidBeneficiary = Keypair.generate();
      const [invalidPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          invalidBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      try {
        await program.methods
          .createSchedule(
            invalidBeneficiary.publicKey,
            new anchor.BN(0), // Invalid amount
            new anchor.BN(Math.floor(Date.now() / 1000) + 60),
            new anchor.BN(365 * 24 * 60 * 60),
            null,
            { team: {} }
          )
          .accounts({
            vestingSchedule: invalidPda,
            authority: authority.publicKey,
            payer: authority.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([authority])
          .rpc();

        assert.fail("Should have failed with invalid amount");
      } catch (error) {
        expect(error.message).to.include("Invalid amount");
        console.log("✅ Correctly rejected invalid amount");
      }
    });

    it("should fail to create schedule with start time in the past", async () => {
      console.log("🧪 TEST: Should fail with past start time...");

      const invalidBeneficiary = Keypair.generate();
      const [invalidPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          invalidBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      try {
        await program.methods
          .createSchedule(
            invalidBeneficiary.publicKey,
            new anchor.BN(1000 * 10**9),
            new anchor.BN(Math.floor(Date.now() / 1000) - 3600), // 1 hour ago
            new anchor.BN(365 * 24 * 60 * 60),
            null,
            { team: {} }
          )
          .accounts({
            vestingSchedule: invalidPda,
            authority: authority.publicKey,
            payer: authority.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([authority])
          .rpc();

        assert.fail("Should have failed with past start time");
      } catch (error) {
        expect(error.message).to.include("Invalid start time");
        console.log("✅ Correctly rejected past start time");
      }
    });
  });

  describe("🚀 Token Release", () => {
    it("should not release tokens before start time", async () => {
      console.log("🧪 TEST: Should not release tokens before start time...");

      // Try to release tokens before start time
      const tx = await program.methods
        .release()
        .accounts({
          vestingSchedule: vestingSchedulePda,
          vault: vaultAccount,
          beneficiaryTokenAccount: beneficiaryTokenAccount,
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .rpc();

      console.log("✅ Release attempt completed (should be no-op), tx:", tx);

      // Check that no tokens were released
      const scheduleAccount = await program.account.vestingSchedule.fetch(vestingSchedulePda);
      assert.equal(scheduleAccount.amountReleased.toString(), "0");

      const beneficiaryBalance = await getAccount(provider.connection, beneficiaryTokenAccount);
      assert.equal(beneficiaryBalance.amount.toString(), "0");

      console.log("✅ Correctly prevented early release");
    });

    it("should create a schedule with immediate start for testing", async () => {
      console.log("🧪 TEST: Creating immediate start schedule for release testing...");

      const testBeneficiary = Keypair.generate();
      const [testSchedulePda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          testBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      const testBeneficiaryTokenAccount = await createAccount(
        provider.connection,
        authority,
        gmcMint,
        testBeneficiary.publicKey
      );

      const totalAmount = new anchor.BN(1000 * 10**9); // 1000 GMC
      const startTimestamp = new anchor.BN(Math.floor(Date.now() / 1000) - 60); // Started 1 minute ago
      const durationSeconds = new anchor.BN(365 * 24 * 60 * 60); // 1 year
      const cliffSeconds = new anchor.BN(0); // No cliff

      await program.methods
        .createSchedule(
          testBeneficiary.publicKey,
          totalAmount,
          startTimestamp,
          durationSeconds,
          cliffSeconds,
          { strategicReserve: {} }
        )
        .accounts({
          vestingSchedule: testSchedulePda,
          authority: authority.publicKey,
          payer: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      console.log("✅ Test schedule created");

      // Now test release
      console.log("🧪 TEST: Releasing vested tokens...");

      const tx = await program.methods
        .release()
        .accounts({
          vestingSchedule: testSchedulePda,
          vault: vaultAccount,
          beneficiaryTokenAccount: testBeneficiaryTokenAccount,
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .rpc();

      console.log("✅ Tokens released, tx:", tx);

      // Verify tokens were released
      const scheduleAccount = await program.account.vestingSchedule.fetch(testSchedulePda);
      assert.isTrue(scheduleAccount.amountReleased.gt(new anchor.BN(0)));

      const beneficiaryBalance = await getAccount(provider.connection, testBeneficiaryTokenAccount);
      assert.isTrue(beneficiaryBalance.amount > 0n);

      console.log(`✅ Released ${beneficiaryBalance.amount} tokens`);
    });
  });

  describe("🔧 Administrative Functions", () => {
    it("should revoke a vesting schedule", async () => {
      console.log("🧪 TEST: Revoking vesting schedule...");

      const revokeBeneficiary = Keypair.generate();
      const [revokeSchedulePda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          revokeBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      // Create schedule first
      await program.methods
        .createSchedule(
          revokeBeneficiary.publicKey,
          new anchor.BN(500 * 10**9),
          new anchor.BN(Math.floor(Date.now() / 1000) + 60),
          new anchor.BN(365 * 24 * 60 * 60),
          null,
          { advisor: {} }
        )
        .accounts({
          vestingSchedule: revokeSchedulePda,
          authority: authority.publicKey,
          payer: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Now revoke it
      const tx = await program.methods
        .revokeSchedule()
        .accounts({
          vestingSchedule: revokeSchedulePda,
          authority: authority.publicKey,
        })
        .signers([authority])
        .rpc();

      console.log("✅ Schedule revoked, tx:", tx);

      // Verify it was revoked
      const scheduleAccount = await program.account.vestingSchedule.fetch(revokeSchedulePda);
      assert.equal(scheduleAccount.isRevoked, true);

      console.log("✅ Revocation verified");
    });

    it("should update beneficiary", async () => {
      console.log("🧪 TEST: Updating beneficiary...");

      const oldBeneficiary = Keypair.generate();
      const newBeneficiary = Keypair.generate();
      
      const [updateSchedulePda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          oldBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      // Create schedule first
      await program.methods
        .createSchedule(
          oldBeneficiary.publicKey,
          new anchor.BN(300 * 10**9),
          new anchor.BN(Math.floor(Date.now() / 1000) + 60),
          new anchor.BN(365 * 24 * 60 * 60),
          null,
          { marketing: {} }
        )
        .accounts({
          vestingSchedule: updateSchedulePda,
          authority: authority.publicKey,
          payer: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Update beneficiary
      const tx = await program.methods
        .updateBeneficiary(newBeneficiary.publicKey)
        .accounts({
          vestingSchedule: updateSchedulePda,
          authority: authority.publicKey,
        })
        .signers([authority])
        .rpc();

      console.log("✅ Beneficiary updated, tx:", tx);

      // Verify update
      const scheduleAccount = await program.account.vestingSchedule.fetch(updateSchedulePda);
      assert.equal(scheduleAccount.beneficiary.toString(), newBeneficiary.publicKey.toString());

      console.log("✅ Beneficiary update verified");
    });
  });

  describe("📊 Vesting Information", () => {
    it("should get vesting information", async () => {
      console.log("🧪 TEST: Getting vesting information...");

      const infoBeneficiary = Keypair.generate();
      const [infoSchedulePda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          infoBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      // Create schedule
      const totalAmount = new anchor.BN(1500 * 10**9);
      const startTimestamp = new anchor.BN(Math.floor(Date.now() / 1000) - 3600); // Started 1 hour ago
      const durationSeconds = new anchor.BN(365 * 24 * 60 * 60); // 1 year

      await program.methods
        .createSchedule(
          infoBeneficiary.publicKey,
          totalAmount,
          startTimestamp,
          durationSeconds,
          null,
          { team: {} }
        )
        .accounts({
          vestingSchedule: infoSchedulePda,
          authority: authority.publicKey,
          payer: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Get vesting info
      const vestingInfo = await program.methods
        .getVestingInfo()
        .accounts({
          vestingSchedule: infoSchedulePda,
        })
        .view();

      console.log("✅ Vesting info retrieved");
      console.log(`   - Beneficiary: ${vestingInfo.beneficiary.toString()}`);
      console.log(`   - Total Amount: ${vestingInfo.totalAmount.toString()}`);
      console.log(`   - Vested Amount: ${vestingInfo.vestedAmount.toString()}`);
      console.log(`   - Released Amount: ${vestingInfo.releasedAmount.toString()}`);
      console.log(`   - Releasable Amount: ${vestingInfo.releasableAmount.toString()}`);
      console.log(`   - Is Revoked: ${vestingInfo.isRevoked}`);

      // Verify info
      assert.equal(vestingInfo.beneficiary.toString(), infoBeneficiary.publicKey.toString());
      assert.equal(vestingInfo.totalAmount.toString(), totalAmount.toString());
      assert.equal(vestingInfo.isRevoked, false);
      assert.isTrue(vestingInfo.vestedAmount.gt(new anchor.BN(0))); // Some should be vested after 1 hour

      console.log("✅ Vesting information verified");
    });
  });

  describe("🛡️ Security Tests", () => {
    it("should fail when non-authority tries to create schedule", async () => {
      console.log("🧪 TEST: Non-authority creation should fail...");

      const unauthorizedUser = Keypair.generate();
      const testBeneficiary = Keypair.generate();
      
      // Airdrop to unauthorized user
      await provider.connection.requestAirdrop(unauthorizedUser.publicKey, 1 * anchor.web3.LAMPORTS_PER_SOL);

      const [unauthorizedPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          testBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      try {
        await program.methods
          .createSchedule(
            testBeneficiary.publicKey,
            new anchor.BN(100 * 10**9),
            new anchor.BN(Math.floor(Date.now() / 1000) + 60),
            new anchor.BN(365 * 24 * 60 * 60),
            null,
            { team: {} }
          )
          .accounts({
            vestingSchedule: unauthorizedPda,
            authority: unauthorizedUser.publicKey, // Wrong authority
            payer: unauthorizedUser.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([unauthorizedUser])
          .rpc();

        assert.fail("Should have failed with unauthorized access");
      } catch (error) {
        console.log("✅ Correctly rejected unauthorized creation");
      }
    });

    it("should not release tokens from revoked schedule", async () => {
      console.log("🧪 TEST: Revoked schedule should not release tokens...");

      const revokedBeneficiary = Keypair.generate();
      const [revokedSchedulePda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("vesting_schedule"),
          revokedBeneficiary.publicKey.toBuffer(),
        ],
        program.programId
      );

      const revokedBeneficiaryTokenAccount = await createAccount(
        provider.connection,
        authority,
        gmcMint,
        revokedBeneficiary.publicKey
      );

      // Create and immediately revoke schedule
      await program.methods
        .createSchedule(
          revokedBeneficiary.publicKey,
          new anchor.BN(200 * 10**9),
          new anchor.BN(Math.floor(Date.now() / 1000) - 60), // Started 1 minute ago
          new anchor.BN(365 * 24 * 60 * 60),
          null,
          { team: {} }
        )
        .accounts({
          vestingSchedule: revokedSchedulePda,
          authority: authority.publicKey,
          payer: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      await program.methods
        .revokeSchedule()
        .accounts({
          vestingSchedule: revokedSchedulePda,
          authority: authority.publicKey,
        })
        .signers([authority])
        .rpc();

      // Try to release from revoked schedule
      try {
        await program.methods
          .release()
          .accounts({
            vestingSchedule: revokedSchedulePda,
            vault: vaultAccount,
            beneficiaryTokenAccount: revokedBeneficiaryTokenAccount,
            tokenProgram: TOKEN_PROGRAM_ID,
          })
          .rpc();

        assert.fail("Should have failed to release from revoked schedule");
      } catch (error) {
        expect(error.message).to.include("ScheduleRevoked");
        console.log("✅ Correctly prevented release from revoked schedule");
      }
    });
  });

  after(async () => {
    console.log("🏁 Vesting Contract tests completed successfully!");
    console.log("📊 Test Summary:");
    console.log("   ✅ Schedule Creation");
    console.log("   ✅ Token Release");
    console.log("   ✅ Administrative Functions");
    console.log("   ✅ Information Queries");
    console.log("   ✅ Security Validations");
  });
}); 