import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import {
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
  SystemProgram,
} from "@solana/web3.js";
import {
  TOKEN_PROGRAM_ID,
  createMint,
  createAccount,
  mintTo,
  getAccount,
} from "@solana/spl-token";
import { assert } from "chai";

describe("GMC Staking - Flexible Withdrawals", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;

  let gmcMint: PublicKey;
  let authority: Keypair;
  let user: Keypair;

  let globalState: PublicKey;
  let stakingVault: PublicKey;
  let teamTreasury: PublicKey;
  let rankingFund: PublicKey;
  let userInfo: PublicKey;
  let userTokenAccount: PublicKey;

  const FLEX_STAKE_AMOUNT = new anchor.BN(1000 * 10 ** 9); // 1000 GMC
  const WITHDRAW_AMOUNT = new anchor.BN(400 * 10 ** 9); // 400 GMC

  before(async () => {
    // --- Configuração inicial ---
    authority = Keypair.generate();
    user = Keypair.generate();

    // Airdrop SOL
    await provider.connection.requestAirdrop(
      authority.publicKey,
      2 * LAMPORTS_PER_SOL
    );
    await provider.connection.requestAirdrop(user.publicKey, 2 * LAMPORTS_PER_SOL);

    // Criar Mints e Contas de Token
    gmcMint = await createMint(
      provider.connection,
      authority,
      authority.publicKey,
      null,
      9
    );

    userTokenAccount = await createAccount(
      provider.connection,
      user,
      gmcMint,
      user.publicKey
    );
    teamTreasury = await createAccount(
      provider.connection,
      authority,
      gmcMint,
      authority.publicKey
    );
    rankingFund = await createAccount(
      provider.connection,
      authority,
      gmcMint,
      authority.publicKey
    );

    // Mint de tokens para o usuário
    await mintTo(
      provider.connection,
      user,
      gmcMint,
      userTokenAccount,
      authority,
      FLEX_STAKE_AMOUNT.muln(2) // Dar tokens suficientes para o stake
    );

    // --- PDAs ---
    [globalState] = PublicKey.findProgramAddressSync(
      [Buffer.from("global_state")],
      program.programId
    );
    [stakingVault] = PublicKey.findProgramAddressSync(
      [Buffer.from("staking_vault"), globalState.toBuffer()],
      program.programId
    );
    [userInfo] = PublicKey.findProgramAddressSync(
      [Buffer.from("user_info"), user.publicKey.toBuffer()],
      program.programId
    );

    // --- Inicializar o programa de Staking ---
    await program.methods
      .initialize()
      .accounts({
        globalState,
        stakingVault,
        gmcMint,
        teamTreasury,
        rankingFund,
        authority: authority.publicKey,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .signers([authority])
      .rpc();

    // --- Fazer o stake flexível inicial ---
    await program.methods
      .stakeFlexible(FLEX_STAKE_AMOUNT)
      .accounts({
        globalState,
        userInfo,
        userTokenAccount,
        stakingVault,
        user: user.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId,
      })
      .signers([user])
      .rpc();
  });

  it("✅ Should withdraw from flexible stake and distribute fees correctly", async () => {
    const userInfoBefore = await program.account.userInfo.fetch(userInfo);
    const userTokenAccBefore = await getAccount(provider.connection, userTokenAccount);
    const teamTreasuryBefore = await getAccount(provider.connection, teamTreasury);
    const rankingFundBefore = await getAccount(provider.connection, rankingFund);
    const vaultBefore = await getAccount(provider.connection, stakingVault);

    // --- Executar o saque ---
    await program.methods
      .withdrawFlexible(WITHDRAW_AMOUNT)
      .accounts({
        globalState,
        userInfo,
        stakingVault,
        userTokenAccount,
        teamTreasury,
        rankingFund,
        user: user.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .signers([user])
      .rpc();

    // --- Validações ---
    const userInfoAfter = await program.account.userInfo.fetch(userInfo);
    const userTokenAccAfter = await getAccount(provider.connection, userTokenAccount);
    const teamTreasuryAfter = await getAccount(provider.connection, teamTreasury);
    const rankingFundAfter = await getAccount(provider.connection, rankingFund);
    const vaultAfter = await getAccount(provider.connection, stakingVault);

    // 1. Validar estado do UserInfo
    const expectedStakeRemaining = userInfoBefore.flexibleStaked.sub(WITHDRAW_AMOUNT);
    assert.ok(
      userInfoAfter.flexibleStaked.eq(expectedStakeRemaining),
      "Flexible stake amount should be correctly reduced."
    );

    // 2. Validar taxas e valor recebido pelo usuário
    const feeBps = new anchor.BN(250); // 2.5%
    const totalFee = WITHDRAW_AMOUNT.mul(feeBps).div(new anchor.BN(10000));
    const amountToUser = WITHDRAW_AMOUNT.sub(totalFee);

    const userReceived = userTokenAccAfter.amount - userTokenAccBefore.amount;
    assert.ok(
      new anchor.BN(userReceived.toString()).eq(amountToUser),
      `User should receive the correct amount after fee. Expected: ${amountToUser}, Got: ${userReceived}`
    );

    // 3. Validar distribuição de taxas
    const teamFeeBps = new anchor.BN(4000); // 40%
    const rankingFeeBps = new anchor.BN(2000); // 20%
    
    const expectedTeamFee = totalFee.mul(teamFeeBps).div(new anchor.BN(10000));
    const expectedRankingFee = totalFee.mul(rankingFeeBps).div(new anchor.BN(10000));

    const teamReceived = teamTreasuryAfter.amount - teamTreasuryBefore.amount;
    const rankingReceived = rankingFundAfter.amount - rankingFundBefore.amount;

    assert.ok(
      new anchor.BN(teamReceived.toString()).eq(expectedTeamFee),
      `Team treasury should receive 40% of the fee. Expected: ${expectedTeamFee}, Got: ${teamReceived}`
    );
    assert.ok(
      new anchor.BN(rankingReceived.toString()).eq(expectedRankingFee),
      `Ranking fund should receive 20% of the fee. Expected: ${expectedRankingFee}, Got: ${rankingReceived}`
    );
    
    // 4. Validar o cofre (vault)
    const totalPaidOut = amountToUser.add(expectedTeamFee).add(expectedRankingFee);
    const vaultDecrease = vaultBefore.amount - vaultAfter.amount;

    assert.ok(
        new anchor.BN(vaultDecrease.toString()).eq(totalPaidOut),
        `Vault balance should decrease by the total amount paid out. Expected: ${totalPaidOut}, Got: ${vaultDecrease}`
    );

    console.log(`Withdraw successful. User received ${amountToUser.toString()}. Total fee ${totalFee.toString()} distributed.`);
  });

  it("❌ Should fail to withdraw more than staked", async () => {
    const userInfo = await program.account.userInfo.fetch(userInfo);
    const amountToWithdraw = userInfo.flexibleStaked.add(new anchor.BN(1)); // 1 lamport a mais

    try {
      await program.methods
        .withdrawFlexible(amountToWithdraw)
        .accounts({
            globalState,
            userInfo,
            stakingVault,
            userTokenAccount,
            teamTreasury,
            rankingFund,
            user: user.publicKey,
            tokenProgram: TOKEN_PROGRAM_ID,
        })
        .signers([user])
        .rpc();
      assert.fail("Transaction should have failed.");
    } catch (err) {
      assert.equal(err.error.errorCode.code, "InsufficientFlexibleStake");
      console.log("\n✅ Correctly failed to withdraw more than available.");
    }
  });

  it("❌ Should fail to withdraw zero amount", async () => {
    try {
      await program.methods
        .withdrawFlexible(new anchor.BN(0))
        .accounts({
            globalState,
            userInfo,
            stakingVault,
            userTokenAccount,
            teamTreasury,
            rankingFund,
            user: user.publicKey,
            tokenProgram: TOKEN_PROGRAM_ID,
        })
        .signers([user])
        .rpc();
      assert.fail("Transaction should have failed.");
    } catch (err) {
      assert.equal(err.error.errorCode.code, "InvalidAmount");
      console.log("✅ Correctly failed to withdraw zero amount.");
    }
  });
}); 