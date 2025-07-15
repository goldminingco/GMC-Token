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

describe("GMC Staking Contract - Long-Term Staking", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = (provider.wallet as any).payer as Keypair;
  const staker = Keypair.generate();

  let gmcMint: PublicKey;
  let stakerGmcAta: PublicKey;

  const STAKE_AMOUNT = new anchor.BN(100 * 10**9); // 100 GMC

  before(async () => {
    // Setup environment
    await provider.connection.requestAirdrop(staker.publicKey, 2 * LAMPORTS_PER_SOL);
    const gmcMintKP = Keypair.generate();
    gmcMint = gmcMintKP.publicKey;
    await createMint(provider.connection, authority, gmcMint, null, 9, gmcMintKP, {}, TOKEN_2022_PROGRAM_ID);
    stakerGmcAta = await createAssociatedTokenAccount(provider.connection, staker, gmcMint, staker.publicKey, {}, TOKEN_2022_PROGRAM_ID);
    await mintTo(provider.connection, authority, gmcMint, stakerGmcAta, authority, BigInt(STAKE_AMOUNT.muln(2).toString()), [], {}, TOKEN_2022_PROGRAM_ID);
  });

  it("Should allow a user to stake GMC for the long term", async () => {
    // Initialize user account first
    const [userStakeInfoPDA, _] = PublicKey.findProgramAddressSync(
        [Buffer.from("user_stake_info"), staker.publicKey.toBuffer()],
        program.programId
    );
    await program.methods
        .initializeUser()
        .accounts({ userStakeInfo: userStakeInfoPDA, user: staker.publicKey, systemProgram: SystemProgram.programId })
        .signers([staker])
        .rpc();
    
    const userInfoAccountBefore = await program.account.userStakeInfo.fetch(userStakeInfoPDA);
    const stakeCount = userInfoAccountBefore.stakeCount;

    // Derive PDAs for the stake instruction
    const [stakePositionPDA, __] = PublicKey.findProgramAddressSync(
      [Buffer.from("stake_position"), staker.publicKey.toBuffer(), stakeCount.toBuffer('le', 8)],
      program.programId
    );
    const [gmcVaultPDA, ___] = PublicKey.findProgramAddressSync(
      [Buffer.from("gmc_vault")],
      program.programId
    );
    const [globalConfigPDA, ____] = PublicKey.findProgramAddressSync(
      [Buffer.from("global_config")],
      program.programId
    );
    
    // Execute the stake
    await program.methods
      .stakeLongTerm(STAKE_AMOUNT)
      .accounts({
        stakePosition: stakePositionPDA,
        userStakeInfo: userStakeInfoPDA,
        globalConfig: globalConfigPDA, // Assuming it's already initialized
        staker: staker.publicKey,
        gmcMint: gmcMint,
        stakerGmcAta: stakerGmcAta,
        gmcVault: gmcVaultPDA,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .signers([staker])
      .rpc();

    // Assertions
    const positionAccount = await program.account.stakePosition.fetch(stakePositionPDA);
    assert.ok(positionAccount.owner.equals(staker.publicKey));
    assert.equal(positionAccount.principalAmount.toString(), STAKE_AMOUNT.toString());
    assert.ok('longTerm' in positionAccount.stakeType);

    const vaultAccount = await getAccount(provider.connection, gmcVaultPDA, "confirmed", TOKEN_2022_PROGRAM_ID);
    assert.equal(vaultAccount.amount.toString(), STAKE_AMOUNT.toString());

    const userInfoAccountAfter = await program.account.userStakeInfo.fetch(userStakeInfoPDA);
    assert.equal(userInfoAccountAfter.stakeCount.toString(), "1");
    
    console.log("✅ Staking successful and state correctly updated.");
  });
}); 