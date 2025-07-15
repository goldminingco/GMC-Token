import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking.js";
import { GmcToken } from "../target/types/gmc_token.js";
import { expect } from "chai";
import {
  TOKEN_2022_PROGRAM_ID,
  createMint,
  createAccount,
  mintTo,
  getAccount,
} from "@solana/spl-token";
import { Keypair, SystemProgram, LAMPORTS_PER_SOL } from "@solana/web3.js";

describe("CRITICAL-002: Emergency Unstake Penalty Correction (TDD)", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const gmcStakingProgram = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const gmcTokenProgram = anchor.workspace.GmcToken as Program<GmcToken>;

  let gmcMint: anchor.web3.PublicKey;
  let usdtMint: anchor.web3.PublicKey;
  let userGmcAccount: anchor.web3.PublicKey;
  let userUsdtAccount: anchor.web3.PublicKey;
  let stakingVault: anchor.web3.PublicKey;
  let penaltyVault: anchor.web3.PublicKey;
  let treasuryUsdtAccount: anchor.web3.PublicKey;
  let user: Keypair;
  let stakePosition: anchor.web3.PublicKey;

  // Test constants
  const STAKE_AMOUNT = 10000 * 10**9; // 10,000 GMC
  const USDT_PENALTY_AMOUNT = 5 * 10**6; // 5 USDT (6 decimals)
  const CAPITAL_PENALTY_RATE = 0.5; // 50%
  const INTEREST_PENALTY_RATE = 0.8; // 80%
  const SIMULATED_INTEREST = 1000 * 10**9; // 1,000 GMC earned interest
  const STAKE_DURATION_DAYS = 30; // 30 days staked

  before(async () => {
    user = Keypair.generate();

    // Airdrop SOL for testing
    await provider.connection.requestAirdrop(user.publicKey, 10 * LAMPORTS_PER_SOL);
    await provider.connection.requestAirdrop(provider.wallet.publicKey, 10 * LAMPORTS_PER_SOL);
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Create GMC Token
    gmcMint = await createMint(
      provider.connection,
      provider.wallet.payer,
      provider.wallet.publicKey,
      null,
      9, // decimals
      undefined,
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    // Create USDT Token (simulated)
    usdtMint = await createMint(
      provider.connection,
      provider.wallet.payer,
      provider.wallet.publicKey,
      null,
      6, // USDT has 6 decimals
      undefined,
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    // Create token accounts
    userGmcAccount = await createAccount(
      provider.connection,
      provider.wallet.payer,
      gmcMint,
      user.publicKey,
      undefined,
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    userUsdtAccount = await createAccount(
      provider.connection,
      provider.wallet.payer,
      usdtMint,
      user.publicKey,
      undefined,
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    stakingVault = await createAccount(
      provider.connection,
      provider.wallet.payer,
      gmcMint,
      provider.wallet.publicKey,
      undefined,
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    penaltyVault = await createAccount(
      provider.connection,
      provider.wallet.payer,
      gmcMint,
      provider.wallet.publicKey,
      undefined,
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    treasuryUsdtAccount = await createAccount(
      provider.connection,
      provider.wallet.payer,
      usdtMint,
      provider.wallet.publicKey,
      undefined,
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    // Mint tokens to user
    await mintTo(
      provider.connection,
      provider.wallet.payer,
      gmcMint,
      userGmcAccount,
      provider.wallet.publicKey,
      STAKE_AMOUNT * 2, // Extra for testing
      [],
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    await mintTo(
      provider.connection,
      provider.wallet.payer,
      usdtMint,
      userUsdtAccount,
      provider.wallet.publicKey,
      100 * 10**6, // 100 USDT
      [],
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    // Generate stake position PDA
    [stakePosition] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("stake_position"), user.publicKey.toBuffer()],
      gmcStakingProgram.programId
    );
  });

  describe("RED Phase: Tests that should FAIL (correct penalty not implemented)", () => {
    it("Should FAIL: emergency_unstake_long should apply simplified 50% penalty instead of correct formula", async () => {
      // Arrange: Create a stake position first
      try {
        await gmcStakingProgram.methods
          .stake(new anchor.BN(STAKE_AMOUNT))
          .accounts({
            user: user.publicKey,
            userTokenAccount: userGmcAccount,
            stakingVault: stakingVault,
            stakePosition: stakePosition,
            tokenProgram: TOKEN_2022_PROGRAM_ID,
            systemProgram: SystemProgram.programId,
          })
          .signers([user])
          .rpc();
      } catch (error) {
        console.log("Note: Stake function may not exist yet, continuing with penalty test...");
      }

      // Get initial balances
      const initialUserGmcBalance = (await getAccount(
        provider.connection,
        userGmcAccount,
        undefined,
        TOKEN_2022_PROGRAM_ID
      )).amount;

      const initialUserUsdtBalance = (await getAccount(
        provider.connection,
        userUsdtAccount,
        undefined,
        TOKEN_2022_PROGRAM_ID
      )).amount;

      const initialPenaltyVaultBalance = (await getAccount(
        provider.connection,
        penaltyVault,
        undefined,
        TOKEN_2022_PROGRAM_ID
      )).amount;

      const initialTreasuryUsdtBalance = (await getAccount(
        provider.connection,
        treasuryUsdtAccount,
        undefined,
        TOKEN_2022_PROGRAM_ID
      )).amount;

      // Act: Call emergency_unstake_long
      try {
        await gmcStakingProgram.methods
          .emergencyUnstakeLong()
          .accounts({
            user: user.publicKey,
            userGmcAccount: userGmcAccount,
            userUsdtAccount: userUsdtAccount,
            stakingVault: stakingVault,
            penaltyVault: penaltyVault,
            treasuryUsdtAccount: treasuryUsdtAccount,
            stakePosition: stakePosition,
            gmcMint: gmcMint,
            usdtMint: usdtMint,
            tokenProgram: TOKEN_2022_PROGRAM_ID,
          })
          .signers([user])
          .rpc();

        // Get final balances
        const finalUserGmcBalance = (await getAccount(
          provider.connection,
          userGmcAccount,
          undefined,
          TOKEN_2022_PROGRAM_ID
        )).amount;

        const finalUserUsdtBalance = (await getAccount(
          provider.connection,
          userUsdtAccount,
          undefined,
          TOKEN_2022_PROGRAM_ID
        )).amount;

        const finalPenaltyVaultBalance = (await getAccount(
          provider.connection,
          penaltyVault,
          undefined,
          TOKEN_2022_PROGRAM_ID
        )).amount;

        const finalTreasuryUsdtBalance = (await getAccount(
          provider.connection,
          treasuryUsdtAccount,
          undefined,
          TOKEN_2022_PROGRAM_ID
        )).amount;

        // Calculate expected penalties according to correct formula:
        // 1. 5 USDT penalty
        const expectedUsdtPenalty = USDT_PENALTY_AMOUNT;
        
        // 2. 50% of capital penalty
        const expectedCapitalPenalty = Math.floor(STAKE_AMOUNT * CAPITAL_PENALTY_RATE);
        
        // 3. 80% of interest penalty
        const expectedInterestPenalty = Math.floor(SIMULATED_INTEREST * INTEREST_PENALTY_RATE);
        
        // Total GMC penalty = capital penalty + interest penalty
        const expectedTotalGmcPenalty = expectedCapitalPenalty + expectedInterestPenalty;
        
        // User should receive: original stake + interest - penalties
        const expectedUserGmcReceived = STAKE_AMOUNT + SIMULATED_INTEREST - expectedTotalGmcPenalty;

        // Assert: Check if correct penalty formula is applied
        const actualUsdtPenalty = initialUserUsdtBalance - finalUserUsdtBalance;
        const actualGmcPenalty = finalPenaltyVaultBalance - initialPenaltyVaultBalance;
        const actualUserGmcReceived = finalUserGmcBalance - initialUserGmcBalance;

        console.log(`
📊 PENALTY CALCULATION ANALYSIS:

Expected (Correct Formula):
- USDT Penalty: ${expectedUsdtPenalty / 10**6} USDT
- Capital Penalty (50%): ${expectedCapitalPenalty / 10**9} GMC
- Interest Penalty (80%): ${expectedInterestPenalty / 10**9} GMC
- Total GMC Penalty: ${expectedTotalGmcPenalty / 10**9} GMC
- User GMC Received: ${expectedUserGmcReceived / 10**9} GMC

Actual (Current Implementation):
- USDT Penalty: ${Number(actualUsdtPenalty) / 10**6} USDT
- GMC Penalty: ${Number(actualGmcPenalty) / 10**9} GMC
- User GMC Received: ${Number(actualUserGmcReceived) / 10**9} GMC
`);

        // These assertions should fail because current implementation uses simplified 50% penalty
        expect(Number(actualUsdtPenalty)).to.equal(expectedUsdtPenalty, "USDT penalty should be exactly 5 USDT");
        expect(Number(actualGmcPenalty)).to.equal(expectedTotalGmcPenalty, "GMC penalty should be 50% capital + 80% interest");
        expect(Number(actualUserGmcReceived)).to.equal(expectedUserGmcReceived, "User should receive correct amount after penalties");

        throw new Error("Correct penalty formula appears to be implemented - this test should fail in RED phase");
        
      } catch (error) {
        console.log("✅ RED Phase: emergency_unstake_long failed as expected:", error.message);
        expect(error.message).to.satisfy((msg: string) => 
          msg.includes("Method does not exist") || 
          msg.includes("USDT penalty should be") ||
          msg.includes("GMC penalty should be"),
          "Expected method to not exist or use incorrect penalty formula in RED phase"
        );
      }
    });

    it("Should FAIL: calculate_emergency_penalty should not implement complex penalty formula", async () => {
      try {
        // Try to call a method that should calculate the complex penalty
        await gmcStakingProgram.methods
          .calculateEmergencyPenalty(
            new anchor.BN(STAKE_AMOUNT),
            new anchor.BN(SIMULATED_INTEREST),
            STAKE_DURATION_DAYS
          )
          .accounts({
            user: user.publicKey,
          })
          .rpc();

        throw new Error("Complex penalty calculation appears to be implemented - this test should fail in RED phase");
        
      } catch (error) {
        console.log("✅ RED Phase: calculateEmergencyPenalty failed as expected:", error.message);
        expect(error.message).to.include("Method does not exist", "Expected complex penalty calculation to not exist in RED phase");
      }
    });

    it("Should FAIL: USDT penalty collection via CPI should not be implemented", async () => {
      try {
        // Try to call a method that should collect USDT penalty via CPI
        await gmcStakingProgram.methods
          .collectUsdtPenalty(new anchor.BN(USDT_PENALTY_AMOUNT))
          .accounts({
            user: user.publicKey,
            userUsdtAccount: userUsdtAccount,
            treasuryUsdtAccount: treasuryUsdtAccount,
            usdtMint: usdtMint,
            tokenProgram: TOKEN_2022_PROGRAM_ID,
          })
          .signers([user])
          .rpc();

        throw new Error("USDT penalty collection appears to be implemented - this test should fail in RED phase");
        
      } catch (error) {
        console.log("✅ RED Phase: collectUsdtPenalty failed as expected:", error.message);
        expect(error.message).to.include("Method does not exist", "Expected USDT penalty collection to not exist in RED phase");
      }
    });
  });

  describe("GREEN Phase: Implementation Guidelines (for next phase)", () => {
    it("Should provide implementation roadmap for correct emergency penalty", () => {
      console.log(`
🔧 IMPLEMENTATION ROADMAP FOR CRITICAL-002:

1. Data Structures (in state.rs):
   #[account]
   pub struct EmergencyPenalty {
       pub usdt_penalty: u64,        // Fixed 5 USDT (in lamports)
       pub capital_penalty_rate: u16, // 50% in basis points (5000)
       pub interest_penalty_rate: u16, // 80% in basis points (8000)
       pub total_penalty_cap: u64,    // Maximum penalty allowed
   }

   #[account]
   pub struct StakePosition {
       pub user: Pubkey,
       pub amount: u64,
       pub start_time: i64,
       pub accumulated_interest: u64,
       pub last_claim_time: i64,
       pub is_emergency_unstaked: bool,
   }

2. Core Functions (in lib.rs):
   pub fn emergency_unstake_long(ctx: Context<EmergencyUnstakeLong>) -> Result<()> {
       let stake_position = &mut ctx.accounts.stake_position;
       let penalty = calculate_emergency_penalty(
           stake_position.amount,
           stake_position.accumulated_interest
       )?;
       
       // 1. Collect 5 USDT penalty
       collect_usdt_penalty(&ctx, penalty.usdt_penalty)?;
       
       // 2. Calculate GMC penalties
       let capital_penalty = stake_position.amount * 5000 / 10000; // 50%
       let interest_penalty = stake_position.accumulated_interest * 8000 / 10000; // 80%
       
       // 3. Transfer penalties to penalty vault
       transfer_penalty_to_vault(&ctx, capital_penalty + interest_penalty)?;
       
       // 4. Return remaining amount to user
       let remaining_amount = stake_position.amount + stake_position.accumulated_interest
           - capital_penalty - interest_penalty;
       transfer_to_user(&ctx, remaining_amount)?;
       
       // 5. Mark position as emergency unstaked
       stake_position.is_emergency_unstaked = true;
       
       Ok(())
   }

3. Helper Functions:
   fn calculate_emergency_penalty(capital: u64, interest: u64) -> Result<EmergencyPenalty> {
       Ok(EmergencyPenalty {
           usdt_penalty: 5_000_000, // 5 USDT with 6 decimals
           capital_penalty_rate: 5000, // 50% in basis points
           interest_penalty_rate: 8000, // 80% in basis points
           total_penalty_cap: capital + interest, // Cannot exceed total stake
       })
   }
   
   fn collect_usdt_penalty(ctx: &Context<EmergencyUnstakeLong>, amount: u64) -> Result<()> {
       // CPI to transfer USDT from user to treasury
       let cpi_accounts = Transfer {
           from: ctx.accounts.user_usdt_account.to_account_info(),
           to: ctx.accounts.treasury_usdt_account.to_account_info(),
           authority: ctx.accounts.user.to_account_info(),
       };
       let cpi_program = ctx.accounts.token_program.to_account_info();
       let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
       token::transfer(cpi_ctx, amount)
   }

4. Error Handling:
   #[error_code]
   pub enum StakingError {
       #[msg("Insufficient USDT balance for penalty")]
       InsufficientUsdtForPenalty,
       #[msg("Emergency unstake penalty calculation overflow")]
       PenaltyCalculationOverflow,
       #[msg("Stake position not found or already unstaked")]
       InvalidStakePosition,
   }

Expected files to modify:
- programs/gmc_staking/src/lib.rs (main implementation)
- programs/gmc_staking/src/instructions/emergency_unstake.rs (new instruction)
- programs/gmc_staking/src/state.rs (penalty structures)
- programs/gmc_staking/src/errors.rs (penalty errors)
`);
      
      expect(true).to.be.true;
    });
  });

  describe("REFACTOR Phase: Optimization Guidelines (for final phase)", () => {
    it("Should provide optimization roadmap for emergency penalty system", () => {
      console.log(`
⚡ OPTIMIZATION ROADMAP FOR CRITICAL-002:

1. Gas Optimization:
   - Combine penalty calculations in single instruction
   - Use batch transfers for multiple penalty components
   - Optimize penalty calculation algorithms
   - Implement compute budget optimization

2. Precision & Safety:
   - Use checked arithmetic for all penalty calculations
   - Implement penalty calculation with minimal rounding errors
   - Add overflow protection for large stakes
   - Validate penalty amounts before execution

3. User Experience:
   - Provide penalty preview before execution
   - Clear error messages for insufficient balances
   - Implement penalty estimation functions
   - Add emergency unstake confirmation flow

4. Security Measures:
   - Rate limiting for emergency unstakes
   - Maximum penalty validation
   - Audit trail for all penalty collections
   - Emergency pause functionality

5. Monitoring & Analytics:
   - Track emergency unstake frequency
   - Monitor penalty collection amounts
   - Analyze penalty impact on tokenomics
   - Emit detailed penalty events

Performance Targets:
- Penalty calculation: <25,000 compute units
- Precision: 100% accurate to smallest unit
- Gas cost: <0.001 SOL per emergency unstake
- Error rate: <0.1% for penalty calculations

6. Advanced Features:
   - Dynamic penalty rates based on market conditions
   - Penalty reduction for long-term stakers
   - Partial emergency unstake options
   - Penalty payment plans for large amounts
`);
      
      expect(true).to.be.true;
    });
  });
});