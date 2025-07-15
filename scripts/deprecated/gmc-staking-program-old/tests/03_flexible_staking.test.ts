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

describe("GMC Staking Contract - Flexible Staking", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  const authority = (provider.wallet as any).payer as Keypair;
  const staker = Keypair.generate();

  let gmcMint: PublicKey;
  let stakerGmcAta: PublicKey;
  
  // According to requirements, minimum for flexible staking is 50 GMC
  const STAKE_AMOUNT = new anchor.BN(50 * 10**9); 

  before(async () => {
    // Basic setup: airdrop SOL, create GMC mint, create user's token account and mint some GMC
    await provider.connection.requestAirdrop(staker.publicKey, 2 * LAMPORTS_PER_SOL);
    const gmcMintKP = Keypair.generate();
    gmcMint = gmcMintKP.publicKey;
    await createMint(provider.connection, authority, gmcMint, null, 9, gmcMintKP, {}, TOKEN_2022_PROGRAM_ID);
    stakerGmcAta = await createAssociatedTokenAccount(provider.connection, staker, gmcMint, staker.publicKey, {}, TOKEN_2022_PROGRAM_ID);
    await mintTo(provider.connection, authority, gmcMint, stakerGmcAta, authority, BigInt(STAKE_AMOUNT.toString()), [], {}, TOKEN_2022_PROGRAM_ID);
    
    // Initialize user stake info account, as it's a prerequisite for staking
    const [userStakeInfoPDA, _] = PublicKey.findProgramAddressSync(
        [Buffer.from("user_stake_info"), staker.publicKey.toBuffer()],
        program.programId
    );
    // This assumes the main initialize test has run and created the global config
    // We also need to initialize the user before they can stake.
    try {
        await program.methods
            .initializeUser()
            .accounts({ userStakeInfo: userStakeInfoPDA, user: staker.publicKey, systemProgram: SystemProgram.programId })
            .signers([staker])
            .rpc();
    } catch (e) {
        // Ignore if already initialized in another test run
    }
  });

  it("Should allow a user to stake GMC flexibly", async () => {
    // RED: This will fail as stake_flexible is not implemented

    const userInfo = await program.account.userStakeInfo.fetch(
        (await PublicKey.findProgramAddress(
            [Buffer.from("user_stake_info"), staker.publicKey.toBuffer()],
            program.programId
        ))[0]
    );
    const stakeCount = userInfo.stakeCount;

    // Derive PDAs
    const [stakePositionPDA, _] = PublicKey.findProgramAddressSync(
      [Buffer.from("stake_position"), staker.publicKey.toBuffer(), stakeCount.toBuffer('le', 8)],
      program.programId
    );
    const [gmcVaultPDA, __] = PublicKey.findProgramAddressSync([Buffer.from("gmc_vault")], program.programId);
    const [globalConfigPDA, ___] = PublicKey.findProgramAddressSync([Buffer.from("global_config")], program.programId);

    await program.methods
      .stakeFlexible(STAKE_AMOUNT)
      .accounts({
        stakePosition: stakePositionPDA,
        userStakeInfo: (await PublicKey.findProgramAddress([Buffer.from("user_stake_info"), staker.publicKey.toBuffer()], program.programId))[0],
        globalConfig: globalConfigPDA,
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
    assert.ok(positionAccount.owner.equals(staker.publicKey), "Owner should be the staker");
    assert.equal(positionAccount.principalAmount.toString(), STAKE_AMOUNT.toString(), "Principal amount is incorrect");
    assert.ok('flexible' in positionAccount.stakeType, "Stake type should be Flexible");

    const vaultAccount = await getAccount(provider.connection, gmcVaultPDA, "confirmed", TOKEN_2022_PROGRAM_ID);
    assert.isTrue(vaultAccount.amount >= BigInt(STAKE_AMOUNT.toString()), "Vault balance should increase");
  });
}); 