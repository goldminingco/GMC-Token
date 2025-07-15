import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import { assert } from "chai";
import { Keypair } from "@solana/web3.js";

describe("GMC Staking Contract - Initialization", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = (provider.wallet as any).payer as Keypair;

  const [globalConfigPDA, globalConfigBump] =
    anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("global_config")],
      program.programId
    );

  // Mock addresses for other contracts and wallets, as per requirements
  const mockGmcMint = Keypair.generate().publicKey;
  const mockUsdtMint = Keypair.generate().publicKey;
  const mockRankingContract = Keypair.generate().publicKey;
  const mockVestingContract = Keypair.generate().publicKey;
  const mockTeamWallet = Keypair.generate().publicKey;
  const mockTreasuryWallet = Keypair.generate().publicKey;
  
  it("Is initialized with correct global configuration!", async () => {
    // RED: This test will fail because the `initialize` instruction
    // in the Rust program does not handle all these parameters yet.
    
    await program.methods
      .initialize(
        mockTeamWallet,
        mockTreasuryWallet,
        mockRankingContract,
        mockVestingContract
      )
      .accounts({
        globalConfig: globalConfigPDA,
        gmcMint: mockGmcMint,
        usdtMint: mockUsdtMint,
        authority: authority.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([authority])
      .rpc();

    // Fetch the created account from the blockchain
    const globalConfigAccount = await program.account.globalConfig.fetch(
      globalConfigPDA
    );

    // Assertions to validate the state
    assert.ok(globalConfigAccount.authority.equals(authority.publicKey), "Authority does not match");
    assert.ok(globalConfigAccount.gmcMint.equals(mockGmcMint), "GMC mint address is incorrect");
    assert.ok(globalConfigAccount.usdtMint.equals(mockUsdtMint), "USDT mint address is incorrect");
    assert.ok(globalConfigAccount.teamWallet.equals(mockTeamWallet), "Team wallet address is incorrect");
    assert.ok(globalConfigAccount.treasuryWallet.equals(mockTreasuryWallet), "Treasury wallet address is incorrect");
    assert.ok(globalConfigAccount.rankingContract.equals(mockRankingContract), "Ranking contract address is incorrect");
    assert.ok(globalConfigAccount.vestingContract.equals(mockVestingContract), "Vesting contract address is incorrect");
    assert.equal(globalConfigAccount.isPaused, false, "Contract should not be paused on initialization");

    console.log("✅ GlobalConfig initialized successfully with all required addresses.");
  });
});
