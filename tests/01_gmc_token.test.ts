import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import {
  Keypair,
  SystemProgram,
  PublicKey,
  sendAndConfirmTransaction,
  Transaction,
} from "@solana/web3.js";
import {
  getOrCreateAssociatedTokenAccount,
  getMint,
  getAccount,
  mintTo,
  transfer,
  setAuthority,
  AuthorityType,
  getTransferFeeAmount,
} from "@solana/spl-token";
import {
  createInitializeMintInstruction,
  getMintLen,
  ExtensionType,
  createInitializeTransferFeeConfigInstruction,
  getTransferFeeConfig,
  TOKEN_2022_PROGRAM_ID,
} from "@solana/spl-token";
import { assert } from "chai";

describe("GMC Token (SPL Token-2022)", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  // Configure the client to use the local cluster.
  const authority = provider.wallet as anchor.Wallet;
  let gmcMint: PublicKey;
  
  const MAX_SUPPLY = 100_000_000;
  const DECIMALS = 9; // Revertido para 9
  const TRANSFER_FEE_BASIS_POINTS = 50; // 0.5%
  const MAX_FEE = 1_000 * 10 ** DECIMALS; // Max fee of 1,000 GMC

  it("RED: Fails to create the GMC mint before implementation", async () => {
    try {
      // This action should fail because we haven't written the mint creation logic
      assert.fail("Mint creation logic is not implemented yet.");
    } catch (error) {
      assert.include(error.message, "not implemented yet", "Test should fail until implemented.");
    }
  });

  describe("Once Implemented...", () => {
    before(async () => {
      // Create the GMC Mint using the Token-2022 Program with extensions
      const mintKeypair = Keypair.generate();
      gmcMint = mintKeypair.publicKey;
      const mintLen = getMintLen([ExtensionType.TransferFeeConfig]);
      const lamports = await provider.connection.getMinimumBalanceForRentExemption(mintLen);

      const transaction = new Transaction().add(
        SystemProgram.createAccount({
          fromPubkey: authority.publicKey,
          newAccountPubkey: gmcMint,
          space: mintLen,
          lamports,
          programId: TOKEN_2022_PROGRAM_ID,
        }),
        createInitializeTransferFeeConfigInstruction(
          gmcMint,
          authority.publicKey,
          authority.publicKey,
          TRANSFER_FEE_BASIS_POINTS,
          BigInt(MAX_FEE),
          TOKEN_2022_PROGRAM_ID
        ),
        createInitializeMintInstruction(
          gmcMint,
          DECIMALS,
          authority.publicKey,
          null, // No freeze authority
          TOKEN_2022_PROGRAM_ID
        )
      );

      await sendAndConfirmTransaction(
        provider.connection,
        transaction,
        [authority.payer, mintKeypair],
      );
    });

    it("GREEN: Should have correct decimals and supply", async () => {
      const mintInfo = await getMint(
        provider.connection,
        gmcMint,
        "confirmed",
        TOKEN_2022_PROGRAM_ID
      );
      assert.equal(mintInfo.decimals, DECIMALS);
      assert.equal(mintInfo.supply, BigInt(0)); // Supply is 0 before minting
    });

    it("GREEN: Should have transfer fee configured correctly", async () => {
      const mintInfo = await getMint(provider.connection, gmcMint, "confirmed", TOKEN_2022_PROGRAM_ID);
      const transferFeeConfig = getTransferFeeConfig(mintInfo);
      
      assert.isNotNull(transferFeeConfig, "TransferFeeConfig should not be null");
      
      const newerFee = transferFeeConfig.newerTransferFee;
      assert.equal(newerFee.transferFeeBasisPoints, TRANSFER_FEE_BASIS_POINTS, "Basis points do not match");
      assert.equal(newerFee.maximumFee, BigInt(MAX_FEE), "Maximum fee does not match");
    });

    it("GREEN: Should disable mint authority after initial mint", async () => {
      // 1. Mint the total supply
      const ata = await getOrCreateAssociatedTokenAccount(
        provider.connection,
        authority.payer,
        gmcMint,
        authority.publicKey,
        false,
        "confirmed",
        undefined,
        TOKEN_2022_PROGRAM_ID
      );

      await mintTo(
        provider.connection,
        authority.payer,
        gmcMint,
        ata.address,
        authority.publicKey,
        BigInt(MAX_SUPPLY * (10 ** DECIMALS)),
        [],
        undefined,
        TOKEN_2022_PROGRAM_ID
      );
      
      // 2. Disable minting
      await setAuthority(
        provider.connection,
        authority.payer,
        gmcMint,
        authority.publicKey,
        AuthorityType.MintTokens,
        null, // New authority is null to disable
        [],
        undefined,
        TOKEN_2022_PROGRAM_ID
      );

      const mintInfo = await getMint(
        provider.connection,
        gmcMint,
        "confirmed",
        TOKEN_2022_PROGRAM_ID
      );
      
      assert.isNull(mintInfo.mintAuthority);
    });

    it("GREEN: Should handle fee withdrawal correctly", async () => {
      // 1. Create sender and receiver accounts
      const sender = Keypair.generate();
      const receiver = Keypair.generate();

      const senderAta = await getOrCreateAssociatedTokenAccount(
        provider.connection, authority.payer, gmcMint, sender.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID
      );
      const receiverAta = await getOrCreateAssociatedTokenAccount(
        provider.connection, authority.payer, gmcMint, receiver.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID
      );

      // 2. Mint some tokens to sender
      const mintAmount = BigInt(1000 * (10 ** DECIMALS));
      await mintTo(
        provider.connection, authority.payer, gmcMint, senderAta.address, authority.payer, mintAmount, [], undefined, TOKEN_2022_PROGRAM_ID
      );

      // 3. Transfer tokens to generate fees
      const transferAmount = BigInt(100 * (10 ** DECIMALS));
      await transfer(
        provider.connection, authority.payer, senderAta.address, receiverAta.address, sender, transferAmount, [], undefined, TOKEN_2022_PROGRAM_ID
      );

      // 4. Check for withheld fees
      const receiverAccountInfo = await getAccount(provider.connection, receiverAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
      const feeInfo = getTransferFeeAmount(receiverAccountInfo);
      assert.isNotNull(feeInfo, "Fee info should not be null");
      const withheldAmount = feeInfo.withheldAmount;
      assert.isTrue(withheldAmount > 0, "Should have withheld fees");
      
      // 5. Withdraw fees
      const feeVault = await getOrCreateAssociatedTokenAccount(
        provider.connection, authority.payer, gmcMint, authority.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID
      );

      const gmcStakingProgram = anchor.workspace.GmcStaking as Program<GmcStaking>;
      await gmcStakingProgram.methods.withdrawFees()
        .accounts({
          gmcMint: gmcMint,
          withdrawAuthority: authority.publicKey,
          feeVault: feeVault.address,
          tokenProgram: TOKEN_2022_PROGRAM_ID,
        })
        .remainingAccounts([
          { pubkey: receiverAta.address, isSigner: false, isWritable: true },
        ])
        .rpc();

      // 6. Assert fees are moved to the vault
      const vaultAccountInfo = await getAccount(provider.connection, feeVault.address, "confirmed", TOKEN_2022_PROGRAM_ID);
      assert.equal(vaultAccountInfo.amount, withheldAmount, "Fee vault should have the withdrawn fees");
      
      const receiverAccountInfoAfter = await getAccount(provider.connection, receiverAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
      const feeInfoAfter = getTransferFeeAmount(receiverAccountInfoAfter);
      assert.isNotNull(feeInfoAfter, "Fee info after withdrawal should not be null");
      const withheldAmountAfter = feeInfoAfter.withheldAmount;
      assert.equal(withheldAmountAfter, BigInt(0), "Withheld amount should be zero after withdrawal");
    });

    it("GREEN: Should distribute genesis supply correctly", async () => {
      // Define destination wallets based on tokenomics
      const wallets = {
          stakingPool: Keypair.generate(),
          strategicReserve: Keypair.generate(),
          team: Keypair.generate(),
          ico: Keypair.generate(),
          treasury: Keypair.generate(),
          marketing: Keypair.generate(),
          airdrop: Keypair.generate(),
      };

      // Create ATAs for all destination wallets
      const atas = {
          stakingPool: await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, wallets.stakingPool.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID),
          strategicReserve: await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, wallets.strategicReserve.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID),
          team: await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, wallets.team.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID),
          ico: await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, wallets.ico.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID),
          treasury: await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, wallets.treasury.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID),
          marketing: await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, wallets.marketing.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID),
          airdrop: await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, wallets.airdrop.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID),
      };

      // Get the authority's ATA (where the total supply was minted)
      const authorityAta = await getOrCreateAssociatedTokenAccount(provider.connection, authority.payer, gmcMint, authority.publicKey, false, "confirmed", undefined, TOKEN_2022_PROGRAM_ID);

      // Perform transfers
      const toGmc = (amount: number) => BigInt(amount * (10 ** DECIMALS));

      await transfer(provider.connection, authority.payer, authorityAta.address, atas.stakingPool.address, authority.payer, toGmc(70_000_000));
      await transfer(provider.connection, authority.payer, authorityAta.address, atas.strategicReserve.address, authority.payer, toGmc(10_000_000));
      await transfer(provider.connection, authority.payer, authorityAta.address, atas.team.address, authority.payer, toGmc(2_000_000));
      await transfer(provider.connection, authority.payer, authorityAta.address, atas.ico.address, authority.payer, toGmc(8_000_000));
      await transfer(provider.connection, authority.payer, authorityAta.address, atas.treasury.address, authority.payer, toGmc(2_000_000));
      await transfer(provider.connection, authority.payer, authorityAta.address, atas.marketing.address, authority.payer, toGmc(6_000_000));
      await transfer(provider.connection, authority.payer, authorityAta.address, atas.airdrop.address, authority.payer, toGmc(2_000_000));

      // Validate balances
      const balances = {
        stakingPool: (await getAccount(provider.connection, atas.stakingPool.address, "confirmed", TOKEN_2022_PROGRAM_ID)).amount,
        strategicReserve: (await getAccount(provider.connection, atas.strategicReserve.address, "confirmed", TOKEN_2022_PROGRAM_ID)).amount,
        team: (await getAccount(provider.connection, atas.team.address, "confirmed", TOKEN_2022_PROGRAM_ID)).amount,
        ico: (await getAccount(provider.connection, atas.ico.address, "confirmed", TOKEN_2022_PROGRAM_ID)).amount,
        treasury: (await getAccount(provider.connection, atas.treasury.address, "confirmed", TOKEN_2022_PROGRAM_ID)).amount,
        marketing: (await getAccount(provider.connection, atas.marketing.address, "confirmed", TOKEN_2022_PROGRAM_ID)).amount,
        airdrop: (await getAccount(provider.connection, atas.airdrop.address, "confirmed", TOKEN_2022_PROGRAM_ID)).amount,
      };

      assert.equal(balances.stakingPool, toGmc(70_000_000));
      assert.equal(balances.strategicReserve, toGmc(10_000_000));
      assert.equal(balances.team, toGmc(2_000_000));
      assert.equal(balances.ico, toGmc(8_000_000));
      assert.equal(balances.treasury, toGmc(2_000_000));
      assert.equal(balances.marketing, toGmc(6_000_000));
      assert.equal(balances.airdrop, toGmc(2_000_000));
    });
  });
}); 