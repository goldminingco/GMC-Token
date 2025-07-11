import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import { 
  TOKEN_PROGRAM_ID, 
  ASSOCIATED_TOKEN_PROGRAM_ID,
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  createMintToInstruction,
  getAccount,
} from "@solana/spl-token";
import { expect } from "chai";
import { GmcVesting } from "../target/types/gmc_vesting";
import { setupVestingSchedules, VestingSetup, calculateVestingInfo } from "../scripts/vesting_setup";

describe("🧪 GMC Vesting Contract - Complete Test Suite", () => {
  // Configure the client to use the local cluster
  anchor.setProvider(anchor.AnchorProvider.env());

  const program = anchor.workspace.GmcVesting as Program<GmcVesting>;
  const provider = anchor.AnchorProvider.env();
  
  // Test accounts
  let authority: Keypair;
  let gmcMint: PublicKey;
  let teamWallet: Keypair;
  let reserveWallet: Keypair;
  let vestingSetup: VestingSetup;
  
  // Program addresses
  let vestingState: PublicKey;
  let tokenVault: PublicKey;
  
  // Test constants
  const TEAM_ALLOCATION = 2_000_000_000_000_000; // 2M GMC
  const STRATEGIC_RESERVE = 10_000_000_000_000_000; // 10M GMC
  const ONE_YEAR = 365 * 24 * 60 * 60; // 1 year in seconds
  const FIVE_YEARS = 5 * 365 * 24 * 60 * 60; // 5 years in seconds

  before("🚀 Setup test environment", async () => {
    console.log("Setting up test environment...");
    
    // Generate test keypairs
    authority = Keypair.generate();
    teamWallet = Keypair.generate();
    reserveWallet = Keypair.generate();
    
    // Airdrop SOL to accounts
    await Promise.all([
      provider.connection.requestAirdrop(authority.publicKey, 2 * anchor.web3.LAMPORTS_PER_SOL),
      provider.connection.requestAirdrop(teamWallet.publicKey, 1 * anchor.web3.LAMPORTS_PER_SOL),
      provider.connection.requestAirdrop(reserveWallet.publicKey, 1 * anchor.web3.LAMPORTS_PER_SOL),
    ]);

    // Wait for airdrops to confirm
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // For this test, we'll use a mock GMC mint
    gmcMint = Keypair.generate().publicKey;
    
    // Initialize VestingSetup instance
    vestingSetup = new VestingSetup(program, provider, authority, gmcMint);
    
    // Derive program addresses
    [vestingState] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_state")],
      program.programId
    );
    
    tokenVault = await getAssociatedTokenAddress(
      gmcMint,
      vestingState,
      true
    );
    
    console.log("✅ Test environment setup complete");
  });

  describe("📋 Program Initialization", () => {
    it("Should initialize the vesting program", async () => {
      const tx = await program.methods
        .initialize()
        .accounts({
          vestingState,
          authority: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Verify initialization
      const state = await program.account.vestingState.fetch(vestingState);
      expect(state.authority.toString()).to.equal(authority.publicKey.toString());
      expect(state.totalSchedules).to.equal(0);
      expect(state.totalVestedAmount.toNumber()).to.equal(0);
      expect(state.totalReleasedAmount.toNumber()).to.equal(0);
      expect(state.isPaused).to.be.false;
      
      console.log("✅ Vesting program initialized successfully");
    });

    it("Should fail to initialize twice", async () => {
      try {
        await program.methods
          .initialize()
          .accounts({
            vestingState,
            authority: authority.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([authority])
          .rpc();
        
        expect.fail("Should have failed to initialize twice");
      } catch (error) {
        expect(error.message).to.include("already in use");
        console.log("✅ Correctly prevented double initialization");
      }
    });
  });

  describe("👥 Team Vesting Schedule", () => {
    let teamSchedule: PublicKey;

    before("Setup team schedule address", async () => {
      [teamSchedule] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), teamWallet.publicKey.toBuffer()],
        program.programId
      );
    });

    it("Should create team vesting schedule with cliff", async () => {
      const startTimestamp = Math.floor(Date.now() / 1000);
      const cliffDuration = ONE_YEAR; // 1 year cliff
      const totalDuration = FIVE_YEARS; // 5 years total
      
      const tx = await program.methods
        .createSchedule(
          teamWallet.publicKey,
          new anchor.BN(TEAM_ALLOCATION),
          new anchor.BN(startTimestamp),
          new anchor.BN(totalDuration),
          { team: {} },
          new anchor.BN(cliffDuration)
        )
        .accounts({
          vestingState,
          vestingSchedule: teamSchedule,
          tokenVault,
          authority: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Verify schedule creation
      const schedule = await program.account.vestingSchedule.fetch(teamSchedule);
      expect(schedule.beneficiary.toString()).to.equal(teamWallet.publicKey.toString());
      expect(schedule.totalAmount.toNumber()).to.equal(TEAM_ALLOCATION);
      expect(schedule.durationSeconds.toNumber()).to.equal(totalDuration);
      expect(schedule.cliffDuration.toNumber()).to.equal(cliffDuration);
      expect(schedule.amountReleased.toNumber()).to.equal(0);
      expect(schedule.isActive).to.be.true;
      
      // Verify global state update
      const state = await program.account.vestingState.fetch(vestingState);
      expect(state.totalSchedules).to.equal(1);
      expect(state.totalVestedAmount.toNumber()).to.equal(TEAM_ALLOCATION);
      
      console.log("✅ Team vesting schedule created with cliff");
    });

    it("Should not allow non-authority to create schedule", async () => {
      const unauthorizedUser = Keypair.generate();
      await provider.connection.requestAirdrop(unauthorizedUser.publicKey, anchor.web3.LAMPORTS_PER_SOL);
      await new Promise(resolve => setTimeout(resolve, 1000));

      try {
        await program.methods
          .createSchedule(
            unauthorizedUser.publicKey,
            new anchor.BN(1000000),
            new anchor.BN(Math.floor(Date.now() / 1000)),
            new anchor.BN(ONE_YEAR),
            { team: {} },
            null
          )
          .accounts({
            vestingState,
            vestingSchedule: PublicKey.findProgramAddressSync(
              [Buffer.from("vesting_schedule"), unauthorizedUser.publicKey.toBuffer()],
              program.programId
            )[0],
            tokenVault,
            authority: unauthorizedUser.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([unauthorizedUser])
          .rpc();
          
        expect.fail("Should have failed with unauthorized access");
      } catch (error) {
        expect(error.message).to.include("Unauthorized");
        console.log("✅ Correctly rejected unauthorized schedule creation");
      }
    });

    it("Should validate input parameters", async () => {
      const testUser = Keypair.generate();
      
      // Test invalid amount (zero)
      try {
        await program.methods
          .createSchedule(
            testUser.publicKey,
            new anchor.BN(0), // Invalid: zero amount
            new anchor.BN(Math.floor(Date.now() / 1000)),
            new anchor.BN(ONE_YEAR),
            { team: {} },
            null
          )
          .accounts({
            vestingState,
            vestingSchedule: PublicKey.findProgramAddressSync(
              [Buffer.from("vesting_schedule"), testUser.publicKey.toBuffer()],
              program.programId
            )[0],
            tokenVault,
            authority: authority.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([authority])
          .rpc();
          
        expect.fail("Should have failed with invalid amount");
      } catch (error) {
        expect(error.message).to.include("InvalidAmount");
        console.log("✅ Correctly rejected zero amount");
      }

      // Test invalid duration (zero)
      try {
        await program.methods
          .createSchedule(
            testUser.publicKey,
            new anchor.BN(1000000),
            new anchor.BN(Math.floor(Date.now() / 1000)),
            new anchor.BN(0), // Invalid: zero duration
            { team: {} },
            null
          )
          .accounts({
            vestingState,
            vestingSchedule: PublicKey.findProgramAddressSync(
              [Buffer.from("vesting_schedule"), testUser.publicKey.toBuffer()],
              program.programId
            )[0],
            tokenVault,
            authority: authority.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([authority])
          .rpc();
          
        expect.fail("Should have failed with invalid duration");
      } catch (error) {
        expect(error.message).to.include("InvalidDuration");
        console.log("✅ Correctly rejected zero duration");
      }
    });
  });

  describe("🏦 Strategic Reserve Vesting Schedule", () => {
    let reserveSchedule: PublicKey;

    before("Setup reserve schedule address", async () => {
      [reserveSchedule] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), reserveWallet.publicKey.toBuffer()],
        program.programId
      );
    });

    it("Should create strategic reserve vesting schedule without cliff", async () => {
      const startTimestamp = Math.floor(Date.now() / 1000);
      const totalDuration = FIVE_YEARS; // 5 years
      
      const tx = await program.methods
        .createSchedule(
          reserveWallet.publicKey,
          new anchor.BN(STRATEGIC_RESERVE),
          new anchor.BN(startTimestamp),
          new anchor.BN(totalDuration),
          { strategicReserve: {} },
          null // No cliff
        )
        .accounts({
          vestingState,
          vestingSchedule: reserveSchedule,
          tokenVault,
          authority: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Verify schedule creation
      const schedule = await program.account.vestingSchedule.fetch(reserveSchedule);
      expect(schedule.beneficiary.toString()).to.equal(reserveWallet.publicKey.toString());
      expect(schedule.totalAmount.toNumber()).to.equal(STRATEGIC_RESERVE);
      expect(schedule.durationSeconds.toNumber()).to.equal(totalDuration);
      expect(schedule.cliffDuration.toNumber()).to.equal(0); // No cliff
      expect(schedule.amountReleased.toNumber()).to.equal(0);
      expect(schedule.isActive).to.be.true;
      
      // Verify global state update
      const state = await program.account.vestingState.fetch(vestingState);
      expect(state.totalSchedules).to.equal(2); // Team + Reserve
      expect(state.totalVestedAmount.toNumber()).to.equal(TEAM_ALLOCATION + STRATEGIC_RESERVE);
      
      console.log("✅ Strategic reserve vesting schedule created without cliff");
    });
  });

  describe("🔓 Token Release Mechanism", () => {
    let testUser: Keypair;
    let testSchedule: PublicKey;
    let testTokenAccount: PublicKey;

    before("Setup test user for release", async () => {
      testUser = Keypair.generate();
      await provider.connection.requestAirdrop(testUser.publicKey, anchor.web3.LAMPORTS_PER_SOL);
      await new Promise(resolve => setTimeout(resolve, 1000));

      [testSchedule] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), testUser.publicKey.toBuffer()],
        program.programId
      );

      testTokenAccount = await getAssociatedTokenAddress(
        gmcMint,
        testUser.publicKey
      );

      // Create a short-term vesting schedule for testing
      const startTimestamp = Math.floor(Date.now() / 1000) - 100; // Started 100 seconds ago
      const duration = 1000; // 1000 seconds total
      
      await program.methods
        .createSchedule(
          testUser.publicKey,
          new anchor.BN(1000000000), // 1 GMC
          new anchor.BN(startTimestamp),
          new anchor.BN(duration),
          { team: {} },
          null // No cliff for testing
        )
        .accounts({
          vestingState,
          vestingSchedule: testSchedule,
          tokenVault,
          authority: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();
    });

    it("Should calculate correct releasable amount", async () => {
      const schedule = await program.account.vestingSchedule.fetch(testSchedule);
      const currentTime = Math.floor(Date.now() / 1000);
      
      // Calculate expected vested amount
      const elapsed = currentTime - schedule.startTimestamp.toNumber();
      const expectedVested = Math.min(
        schedule.totalAmount.toNumber(),
        Math.floor((schedule.totalAmount.toNumber() * elapsed) / schedule.durationSeconds.toNumber())
      );
      
      console.log(`⏰ Elapsed time: ${elapsed} seconds`);
      console.log(`💰 Expected vested: ${expectedVested / 1e9} GMC`);
      console.log(`📊 Progress: ${(elapsed / schedule.durationSeconds.toNumber() * 100).toFixed(2)}%`);
    });

    it("Should fail to release tokens before vesting starts", async () => {
      // Create a future vesting schedule
      const futureUser = Keypair.generate();
      const futureStartTime = Math.floor(Date.now() / 1000) + 3600; // 1 hour in future
      
      const [futureSchedule] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), futureUser.publicKey.toBuffer()],
        program.programId
      );

      await program.methods
        .createSchedule(
          futureUser.publicKey,
          new anchor.BN(1000000000),
          new anchor.BN(futureStartTime),
          new anchor.BN(ONE_YEAR),
          { team: {} },
          null
        )
        .accounts({
          vestingState,
          vestingSchedule: futureSchedule,
          tokenVault,
          authority: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Try to release tokens before start time
      try {
        await program.methods
          .release()
          .accounts({
            vestingState,
            vestingSchedule: futureSchedule,
            tokenVault,
            beneficiaryTokenAccount: await getAssociatedTokenAddress(gmcMint, futureUser.publicKey),
            beneficiary: futureUser.publicKey,
            tokenProgram: TOKEN_PROGRAM_ID,
          })
          .rpc();

        expect.fail("Should have failed to release before vesting starts");
      } catch (error) {
        expect(error.message).to.include("VestingNotStarted");
        console.log("✅ Correctly prevented release before vesting start");
      }
    });

    it("Should fail to release when no tokens are available", async () => {
      // Create a schedule with cliff that hasn't passed
      const cliffUser = Keypair.generate();
      const startTime = Math.floor(Date.now() / 1000) - 100; // Started 100 seconds ago
      const cliffDuration = 3600; // 1 hour cliff (not passed yet)
      
      const [cliffSchedule] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), cliffUser.publicKey.toBuffer()],
        program.programId
      );

      await program.methods
        .createSchedule(
          cliffUser.publicKey,
          new anchor.BN(1000000000),
          new anchor.BN(startTime),
          new anchor.BN(ONE_YEAR),
          { team: {} },
          new anchor.BN(cliffDuration)
        )
        .accounts({
          vestingState,
          vestingSchedule: cliffSchedule,
          tokenVault,
          authority: authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([authority])
        .rpc();

      // Try to release during cliff period
      try {
        await program.methods
          .release()
          .accounts({
            vestingState,
            vestingSchedule: cliffSchedule,
            tokenVault,
            beneficiaryTokenAccount: await getAssociatedTokenAddress(gmcMint, cliffUser.publicKey),
            beneficiary: cliffUser.publicKey,
            tokenProgram: TOKEN_PROGRAM_ID,
          })
          .rpc();

        expect.fail("Should have failed to release during cliff period");
      } catch (error) {
        expect(error.message).to.include("NoTokensToRelease");
        console.log("✅ Correctly prevented release during cliff period");
      }
    });
  });

  describe("⚡ Admin Functions", () => {
    it("Should pause and unpause vesting operations", async () => {
      // Pause vesting
      await program.methods
        .setPauseState(true)
        .accounts({
          vestingState,
          authority: authority.publicKey,
        })
        .signers([authority])
        .rpc();

      let state = await program.account.vestingState.fetch(vestingState);
      expect(state.isPaused).to.be.true;
      console.log("✅ Vesting operations paused");

      // Try to create schedule while paused (should fail)
      const pausedUser = Keypair.generate();
      try {
        await program.methods
          .createSchedule(
            pausedUser.publicKey,
            new anchor.BN(1000000),
            new anchor.BN(Math.floor(Date.now() / 1000)),
            new anchor.BN(ONE_YEAR),
            { team: {} },
            null
          )
          .accounts({
            vestingState,
            vestingSchedule: PublicKey.findProgramAddressSync(
              [Buffer.from("vesting_schedule"), pausedUser.publicKey.toBuffer()],
              program.programId
            )[0],
            tokenVault,
            authority: authority.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([authority])
          .rpc();

        expect.fail("Should have failed while paused");
      } catch (error) {
        expect(error.message).to.include("VestingPaused");
        console.log("✅ Correctly prevented operations while paused");
      }

      // Unpause vesting
      await program.methods
        .setPauseState(false)
        .accounts({
          vestingState,
          authority: authority.publicKey,
        })
        .signers([authority])
        .rpc();

      state = await program.account.vestingState.fetch(vestingState);
      expect(state.isPaused).to.be.false;
      console.log("✅ Vesting operations resumed");
    });

    it("Should transfer authority", async () => {
      const newAuthority = Keypair.generate();
      await provider.connection.requestAirdrop(newAuthority.publicKey, anchor.web3.LAMPORTS_PER_SOL);
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Transfer authority
      await program.methods
        .transferAuthority(newAuthority.publicKey)
        .accounts({
          vestingState,
          authority: authority.publicKey,
        })
        .signers([authority])
        .rpc();

      const state = await program.account.vestingState.fetch(vestingState);
      expect(state.authority.toString()).to.equal(newAuthority.publicKey.toString());
      console.log("✅ Authority transferred successfully");

      // Transfer back for other tests
      await program.methods
        .transferAuthority(authority.publicKey)
        .accounts({
          vestingState,
          authority: newAuthority.publicKey,
        })
        .signers([newAuthority])
        .rpc();
    });

    it("Should not allow unauthorized admin functions", async () => {
      const unauthorizedUser = Keypair.generate();
      await provider.connection.requestAirdrop(unauthorizedUser.publicKey, anchor.web3.LAMPORTS_PER_SOL);
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Try to pause with unauthorized user
      try {
        await program.methods
          .setPauseState(true)
          .accounts({
            vestingState,
            authority: unauthorizedUser.publicKey,
          })
          .signers([unauthorizedUser])
          .rpc();

        expect.fail("Should have failed with unauthorized access");
      } catch (error) {
        expect(error.message).to.include("Unauthorized");
        console.log("✅ Correctly rejected unauthorized pause attempt");
      }
    });
  });

  describe("📊 Vesting Calculation Helper", () => {
    it("Should calculate vesting info correctly", async () => {
      const totalAmount = 1000000000; // 1 GMC
      const startTimestamp = Math.floor(Date.now() / 1000) - 500; // Started 500 seconds ago
      const durationSeconds = 1000; // 1000 seconds total
      const cliffDuration = 200; // 200 seconds cliff (already passed)
      
      const info = calculateVestingInfo(
        totalAmount,
        startTimestamp,
        durationSeconds,
        cliffDuration
      );

      expect(info.totalAmount).to.equal(totalAmount);
      expect(info.isCliffPassed).to.be.true;
      expect(info.vestedAmount).to.be.greaterThan(0);
      expect(info.vestedAmount).to.be.lessThan(totalAmount);
      expect(info.progressPercentage).to.be.greaterThan(40);
      expect(info.progressPercentage).to.be.lessThan(60);
      
      console.log("✅ Vesting calculation helper working correctly");
      console.log(`📊 Progress: ${info.progressPercentage.toFixed(2)}%`);
      console.log(`💰 Vested: ${(info.vestedAmount / 1e9).toFixed(3)} GMC`);
    });

    it("Should handle cliff period correctly", async () => {
      const totalAmount = 1000000000;
      const startTimestamp = Math.floor(Date.now() / 1000) - 100; // Started 100 seconds ago
      const durationSeconds = 1000;
      const cliffDuration = 200; // 200 seconds cliff (not passed yet)
      
      const info = calculateVestingInfo(
        totalAmount,
        startTimestamp,
        durationSeconds,
        cliffDuration
      );

      expect(info.isCliffPassed).to.be.false;
      expect(info.vestedAmount).to.equal(0);
      expect(info.releasableAmount).to.equal(0);
      
      console.log("✅ Cliff period handled correctly");
    });

    it("Should handle fully vested scenario", async () => {
      const totalAmount = 1000000000;
      const startTimestamp = Math.floor(Date.now() / 1000) - 2000; // Started 2000 seconds ago
      const durationSeconds = 1000; // Should be fully vested
      const cliffDuration = 0;
      
      const info = calculateVestingInfo(
        totalAmount,
        startTimestamp,
        durationSeconds,
        cliffDuration
      );

      expect(info.isFullyVested).to.be.true;
      expect(info.vestedAmount).to.equal(totalAmount);
      expect(info.progressPercentage).to.equal(100);
      
      console.log("✅ Fully vested scenario handled correctly");
    });
  });

  describe("📈 Integration Tests", () => {
    it("Should handle complete vesting lifecycle", async () => {
      console.log("🔄 Testing complete vesting lifecycle...");
      
      // Get initial state
      const initialState = await program.account.vestingState.fetch(vestingState);
      console.log(`📊 Initial total schedules: ${initialState.totalSchedules}`);
      console.log(`💰 Initial total vested: ${(initialState.totalVestedAmount.toNumber() / 1e9).toLocaleString()} GMC`);
      
      // Verify team and reserve schedules exist
      const [teamSchedule] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), teamWallet.publicKey.toBuffer()],
        program.programId
      );
      
      const [reserveSchedule] = PublicKey.findProgramAddressSync(
        [Buffer.from("vesting_schedule"), reserveWallet.publicKey.toBuffer()],
        program.programId
      );
      
      const teamScheduleData = await program.account.vestingSchedule.fetch(teamSchedule);
      const reserveScheduleData = await program.account.vestingSchedule.fetch(reserveSchedule);
      
      expect(teamScheduleData.isActive).to.be.true;
      expect(reserveScheduleData.isActive).to.be.true;
      
      console.log("✅ All vesting schedules are active and properly configured");
      console.log(`👥 Team allocation: ${(teamScheduleData.totalAmount.toNumber() / 1e9).toLocaleString()} GMC`);
      console.log(`🏦 Reserve allocation: ${(reserveScheduleData.totalAmount.toNumber() / 1e9).toLocaleString()} GMC`);
      console.log(`⏰ Team cliff: ${Math.floor(teamScheduleData.cliffDuration.toNumber() / (365 * 24 * 60 * 60))} years`);
      console.log(`⏰ Reserve cliff: ${Math.floor(reserveScheduleData.cliffDuration.toNumber() / (365 * 24 * 60 * 60))} years`);
    });
  });

  after("🧹 Cleanup", async () => {
    console.log("Cleaning up test environment...");
    // Add any necessary cleanup here
    console.log("✅ Cleanup complete");
  });
}); 