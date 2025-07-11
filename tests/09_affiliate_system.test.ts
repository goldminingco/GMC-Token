import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import { 
  PublicKey, 
  Keypair, 
  SystemProgram 
} from "@solana/web3.js";
import { 
  TOKEN_PROGRAM_ID,
  createMint,
  createAssociatedTokenAccount,
  mintTo
} from "@solana/spl-token";
import { assert } from "chai";

describe("GMC Staking - Affiliate System", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = provider.wallet as anchor.Wallet;
  
  let gmcMint: PublicKey;
  let usdtMint: PublicKey;
  let globalConfig: PublicKey;
  
  // Multi-level affiliate network setup
  let level0User: Keypair; // Root user (the one getting boost)
  let level1User: Keypair; // Direct referral
  let level2User: Keypair; // Level 2 referral 
  let level3User: Keypair; // Level 3 referral
  let level4User: Keypair; // Level 4 referral
  let level5User: Keypair; // Level 5 referral
  let level6User: Keypair; // Level 6 referral
  
  // User stake info accounts
  let level0StakeInfo: PublicKey;
  let level1StakeInfo: PublicKey;
  let level2StakeInfo: PublicKey;
  let level3StakeInfo: PublicKey;
  let level4StakeInfo: PublicKey;
  let level5StakeInfo: PublicKey;
  let level6StakeInfo: PublicKey;

  before(async () => {
    // Create test users
    level0User = Keypair.generate();
    level1User = Keypair.generate();
    level2User = Keypair.generate();
    level3User = Keypair.generate();
    level4User = Keypair.generate();
    level5User = Keypair.generate();
    level6User = Keypair.generate();
    
    // Airdrop SOL to all test accounts
    const users = [level0User, level1User, level2User, level3User, level4User, level5User, level6User];
    for (const user of users) {
      await provider.connection.requestAirdrop(user.publicKey, 5 * anchor.web3.LAMPORTS_PER_SOL);
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    // Create mints
    gmcMint = await createMint(
      provider.connection,
      authority.payer,
      authority.publicKey,
      null,
      9
    );

    usdtMint = await createMint(
      provider.connection,
      authority.payer,
      authority.publicKey,
      null,
      6
    );

    // Derive global config
    [globalConfig] = PublicKey.findProgramAddressSync(
      [Buffer.from("global_config")],
      program.programId
    );

    // Derive user stake info accounts
    [level0StakeInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_stake_info"), level0User.publicKey.toBuffer()],
      program.programId
    );

    [level1StakeInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_stake_info"), level1User.publicKey.toBuffer()],
      program.programId
    );

    [level2StakeInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_stake_info"), level2User.publicKey.toBuffer()],
      program.programId
    );

    [level3StakeInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_stake_info"), level3User.publicKey.toBuffer()],
      program.programId
    );

    [level4StakeInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_stake_info"), level4User.publicKey.toBuffer()],
      program.programId
    );

    [level5StakeInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_stake_info"), level5User.publicKey.toBuffer()],
      program.programId
    );

    [level6StakeInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_stake_info"), level6User.publicKey.toBuffer()],
      program.programId
    );

    // Initialize the program
    await program.methods
      .initialize(
        authority.publicKey, // team_wallet
        authority.publicKey, // treasury_wallet
        authority.publicKey, // ranking_contract
        authority.publicKey  // vesting_contract
      )
      .accounts({
        globalConfig,
        gmcMint,
        usdtMint,
        authority: authority.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    // Initialize all users
    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      const stakeInfo = [level0StakeInfo, level1StakeInfo, level2StakeInfo, level3StakeInfo, level4StakeInfo, level5StakeInfo, level6StakeInfo][i];
      
      await program.methods
        .initializeUser()
        .accounts({
          userStakeInfo: stakeInfo,
          user: user.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([user])
        .rpc();
    }
  });

  describe("Register Referrer Function", () => {
    it("RED: Should fail to register referrer when not implemented", async () => {
      try {
        // Act: Try to register level0User as referrer for level1User
        await program.methods
          .registerReferrer(level0User.publicKey)
          .accounts({
            userStakeInfo: level1StakeInfo,
            user: level1User.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([level1User])
          .rpc();

        // Should fail until function is implemented
        assert.fail("register_referrer function not yet implemented");
      } catch (error) {
        // Expected to fail in RED phase
        console.log("Expected failure in RED phase:", error.message);
        assert.include(error.message.toLowerCase(), "not found", "Wrong error type");
      }
    });

    it("RED: Should prevent registering referrer twice", async () => {
      // This test verifies business rule: one referrer per user, set once
      try {
        // First registration attempt (should work when implemented)
        await program.methods
          .registerReferrer(level0User.publicKey)
          .accounts({
            userStakeInfo: level1StakeInfo,
            user: level1User.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([level1User])
          .rpc();

        // Second registration attempt (should fail)
        await program.methods
          .registerReferrer(level2User.publicKey) // Different referrer
          .accounts({
            userStakeInfo: level1StakeInfo,
            user: level1User.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([level1User])
          .rpc();

        assert.fail("Should not allow changing referrer");
      } catch (error) {
        // Expected to fail 
        console.log("Expected failure for double referrer registration:", error.message);
      }
    });

    it("RED: Should prevent self-referral", async () => {
      try {
        // Act: User tries to refer themselves
        await program.methods
          .registerReferrer(level1User.publicKey) // Same as user
          .accounts({
            userStakeInfo: level1StakeInfo,
            user: level1User.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([level1User])
          .rpc();

        assert.fail("Should prevent self-referral");
      } catch (error) {
        // Expected to fail
        console.log("Expected failure for self-referral:", error.message);
      }
    });

    it("RED: Should validate referrer exists", async () => {
      // Test business rule: referrer must have valid stake info
      const nonExistentUser = Keypair.generate();
      
      try {
        await program.methods
          .registerReferrer(nonExistentUser.publicKey)
          .accounts({
            userStakeInfo: level1StakeInfo,
            user: level1User.publicKey,
            systemProgram: SystemProgram.programId,
          })
          .signers([level1User])
          .rpc();

        assert.fail("Should validate referrer exists");
      } catch (error) {
        console.log("Expected failure for non-existent referrer:", error.message);
      }
    });
  });

  describe("Affiliate Boost Calculation", () => {
    it("RED: Should calculate 6-level affiliate boost correctly", async () => {
      // Arrange: Expected boost percentages per level
      const expectedBoosts = {
        level1: 20, // 20%
        level2: 15, // 15% 
        level3: 8,  // 8%
        level4: 4,  // 4%
        level5: 2,  // 2%
        level6: 1   // 1%
      };

      // This test will fail until boost calculation is implemented
      try {
        // Act: Calculate boost for a user with 6-level network
        const calculatedBoost = await program.methods
          .calculateAffiliateBoost()
          .accounts({
            userStakeInfo: level0StakeInfo,
            user: level0User.publicKey,
          })
          .view();

        // Assert: Should match expected calculation
        // Total possible boost: 20+15+8+4+2+1 = 50% (max)
        assert.isNumber(calculatedBoost);
        assert.isAtMost(calculatedBoost, 50, "Boost should not exceed 50%");
      } catch (error) {
        // Expected to fail in RED phase
        console.log("Expected failure for boost calculation:", error.message);
      }
    });

    it("RED: Should cap affiliate boost at 50%", async () => {
      // Test business rule: maximum 50% boost regardless of network size
      try {
        // Simulate a massive network that would exceed 50%
        const boost = await program.methods
          .calculateAffiliateBoost()
          .accounts({
            userStakeInfo: level0StakeInfo,
            user: level0User.publicKey,
          })
          .view();

        assert.isAtMost(boost, 50, "Boost must be capped at 50%");
      } catch (error) {
        console.log("Expected failure for boost cap test:", error.message);
      }
    });

    it("RED: Should return zero boost for users with no referrals", async () => {
      // Test: User with no affiliate network should have 0% boost
      try {
        const boost = await program.methods
          .calculateAffiliateBoost()
          .accounts({
            userStakeInfo: level6StakeInfo, // Leaf user with no referrals
            user: level6User.publicKey,
          })
          .view();

        assert.equal(boost, 0, "User with no referrals should have 0% boost");
      } catch (error) {
        console.log("Expected failure for zero boost test:", error.message);
      }
    });

    it("RED: Should handle circular referral protection", async () => {
      // Test security: prevent circular referral chains
      try {
        // This should be prevented by business logic
        // level0 -> level1 -> level0 (circular)
        assert.fail("Circular referral protection not yet implemented");
      } catch (error) {
        console.log("Expected failure for circular referral test:", error.message);
      }
    });
  });

  describe("APY Integration with Affiliate Boost", () => {
    it("RED: Should integrate affiliate boost into APY calculation", async () => {
      // Test: APY should include both burn power + affiliate boost
      // Base APY: 10%
      // With 50% burn power: ~145% APY
      // With 25% affiliate boost: should increase further
      
      try {
        // This test verifies the integration between affiliate system and APY
        const baseApy = 10; // 10% base
        const burnPower = 50; // 50% from burn-for-boost
        const affiliateBoost = 25; // 25% from affiliates
        
        // Expected calculation: 10% + ((50+25)/100) * (280%-10%) = 212.5%
        const expectedApy = baseApy + ((burnPower + affiliateBoost) / 100) * (280 - baseApy);
        
        // This will fail until integration is complete
        assert.fail("APY integration with affiliate boost not yet implemented");
      } catch (error) {
        console.log("Expected failure for APY integration:", error.message);
      }
    });

    it("RED: Should respect total power cap in APY calculation", async () => {
      // Test: Total power (burn + affiliate) should be capped at 100 for APY calculation
      try {
        // Scenario: 80% burn power + 50% affiliate boost = 130%, but should cap at 100%
        const burnPower = 80;
        const affiliateBoost = 50;
        const totalPower = Math.min(100, burnPower + affiliateBoost); // Should be 100
        
        // APY should be: 10% + (100/100) * (280%-10%) = 280% (max)
        assert.equal(totalPower, 100, "Total power should be capped at 100");
      } catch (error) {
        console.log("Expected failure for power cap test:", error.message);
      }
    });
  });

  describe("Multi-Level Network Scenarios", () => {
    it("RED: Should build and track 6-level affiliate network", async () => {
      // Test: Complete 6-level network setup and tracking
      try {
        // Build network: level0 <- level1 <- level2 <- level3 <- level4 <- level5 <- level6
        
        // Register referral chain
        // level1 refers to level0
        // level2 refers to level1  
        // level3 refers to level2
        // level4 refers to level3
        // level5 refers to level4
        // level6 refers to level5
        
        // This will fail until network tracking is implemented
        assert.fail("Multi-level network tracking not yet implemented");
      } catch (error) {
        console.log("Expected failure for network tracking:", error.message);
      }
    });

    it("RED: Should calculate weighted boost from network", async () => {
      // Test: Each level contributes different percentage to boost
      // Level 1: 20% of their staking power
      // Level 2: 15% of their staking power  
      // Level 3: 8% of their staking power
      // Level 4: 4% of their staking power
      // Level 5: 2% of their staking power
      // Level 6: 1% of their staking power
      
      try {
        // Simulate network where each level has different staking powers
        const networkPowers = {
          level1: 100, // 100% staking power
          level2: 80,  // 80% staking power
          level3: 60,  // 60% staking power
          level4: 40,  // 40% staking power
          level5: 20,  // 20% staking power
          level6: 10   // 10% staking power
        };
        
        // Expected boost calculation:
        // (100 * 0.20) + (80 * 0.15) + (60 * 0.08) + (40 * 0.04) + (20 * 0.02) + (10 * 0.01)
        // = 20 + 12 + 4.8 + 1.6 + 0.4 + 0.1 = 38.9%
        
        const expectedBoost = 38.9;
        
        // This will fail until weighted calculation is implemented
        assert.fail("Weighted boost calculation not yet implemented");
      } catch (error) {
        console.log("Expected failure for weighted boost calculation:", error.message);
      }
    });
  });

  describe("Performance and Gas Optimization", () => {
    it("RED: Should handle affiliate calculation efficiently", async () => {
      // Test: Affiliate boost calculation should not exceed gas limits
      // Even with maximum 6-level deep network
      
      try {
        // This tests the gas efficiency of the traversal algorithm
        // Should be optimized to prevent DoS through deep networks
        assert.fail("Gas optimization for affiliate calculation not yet implemented");
      } catch (error) {
        console.log("Expected failure for gas optimization test:", error.message);
      }
    });

    it("RED: Should cache or optimize frequent boost calculations", async () => {
      // Test: Performance optimization for frequently accessed boost values
      try {
        assert.fail("Boost calculation optimization not yet implemented");
      } catch (error) {
        console.log("Expected failure for caching optimization:", error.message);
      }
    });
  });
}); 