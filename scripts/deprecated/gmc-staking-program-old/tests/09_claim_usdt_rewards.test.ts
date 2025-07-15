import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import { assert } from "chai";
import { Keypair, LAMPORTS_PER_SOL, PublicKey } from "@solana/web3.js";
import {
  TOKEN_PROGRAM_ID,
  createMint,
  createAssociatedTokenAccount,
  mintTo,
  getAccount,
} from "@solana/spl-token";

describe("GMC Staking Contract - Claim USDT Rewards", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = (provider.wallet as any).payer as Keypair;
  const staker1 = Keypair.generate();
  const staker2 = Keypair.generate();

  let usdtMint: PublicKey;
  let usdtRewardsVault: PublicKey; // PDA to hold USDT rewards
  let staker1UsdtAta: PublicKey;
  
  before(async () => {
    // Basic setup
    await provider.connection.requestAirdrop(staker1.publicKey, 2 * LAMPORTS_PER_SOL);
    const usdtMintKP = Keypair.generate();
    usdtMint = usdtMintKP.publicKey;
    await createMint(provider.connection, authority, usdtMint, null, 6, usdtMintKP);
    
    staker1UsdtAta = await createAssociatedTokenAccount(provider.connection, staker1, usdtMint, staker1.publicKey);
    
    // Simulate USDT rewards accumulating in the vault
    [usdtRewardsVault] = await PublicKey.findProgramAddress([Buffer.from("usdt_rewards_vault")], program.programId);
    await mintTo(provider.connection, authority, usdtMint, usdtRewardsVault, authority, 1_000_000_000); // 1,000 USDT
  });

  it("Should allow a user to claim their proportional share of USDT rewards", async () => {
    // RED: This test will fail as the instruction is not implemented
    
    // Assume staker1 has 10% of the total staking power in the contract
    // We would need a test-only function to set this for a predictable test
    await program.methods
      .setStakingPowerTest(10) // Mocking 10% power
      .accounts({ staker: staker1.publicKey })
      .rpc();
      
    const initialStakerBalance = (await getAccount(provider.connection, staker1UsdtAta)).amount;

    await program.methods
      .claimUsdtRewards()
      .accounts({
        staker: staker1.publicKey,
        stakerUsdtAta: staker1UsdtAta,
        usdtRewardsVault: usdtRewardsVault,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .signers([staker1])
      .rpc();

    // Assertions
    const finalStakerBalance = (await getAccount(provider.connection, staker1UsdtAta)).amount;
    
    const totalRewards = 1_000_000_000; // 1,000 USDT
    const userShare = totalRewards / 10; // 10% = 100 USDT
    const fee = userShare * 3 / 1000; // 0.3%
    const expectedPayout = userShare - fee;
    
    assert.equal(finalStakerBalance.toString(), (initialStakerBalance + BigInt(expectedPayout)).toString(), "Incorrect USDT payout");
  });
}); 