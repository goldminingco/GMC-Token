import * as anchor from "@coral-xyz/anchor";
import { Keypair, SystemProgram } from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  createInitializeMintInstruction,
  getMintLen,
  ExtensionType,
  createInitializeTransferFeeConfigInstruction,
  createAssociatedTokenAccountIdempotent,
  mintTo,
  setAuthority,
  AuthorityType
} from "@solana/spl-token";
import fs from "fs";
import path from "path";

// Constants from our validated logic
const GMC_CONSTANTS = {
  DECIMALS: 9,
  TOTAL_SUPPLY_UNITS: 100_000_000,
  TRANSFER_FEE_BASIS_POINTS: 50, // 0.5%
  MAX_TRANSFER_FEE_UNITS: 1_000,
  DISTRIBUTION: {
    STAKING_POOL: 70_000_000,
    STRATEGIC_RESERVE: 10_000_000,
    TEAM: 2_000_000,
    PRESALE: 8_000_000,
    TREASURY: 2_000_000,
    MARKETING: 6_000_000,
    AIRDROP: 2_000_000
  }
} as const;

function toTokenAmount(units: number, decimals: number = GMC_CONSTANTS.DECIMALS): bigint {
  return BigInt(units) * (BigInt(10) ** BigInt(decimals));
}

async function main() {
  console.log("🚀 Starting GMC Token Deployment Script...");

  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const authority = (provider.wallet as any).payer as Keypair;
  
  console.log(`🔑 Deploying Authority: ${authority.publicKey.toBase58()}`);
  
  // --- 1. Create the GMC Mint with Transfer Fee Extension ---
  const gmcMintKeypair = Keypair.generate();
  console.log(`✨ GMC Mint Address: ${gmcMintKeypair.publicKey.toBase58()}`);

  const extensions = [ExtensionType.TransferFeeConfig];
  const mintLen = getMintLen(extensions);
  const rentExemption = await provider.connection.getMinimumBalanceForRentExemption(mintLen);
  const maxFee = toTokenAmount(GMC_CONSTANTS.MAX_TRANSFER_FEE_UNITS);

  const createMintAccountIx = SystemProgram.createAccount({
    fromPubkey: authority.publicKey,
    newAccountPubkey: gmcMintKeypair.publicKey,
    space: mintLen,
    lamports: rentExemption,
    programId: TOKEN_2022_PROGRAM_ID,
  });

  const initTransferFeeIx = createInitializeTransferFeeConfigInstruction(
    gmcMintKeypair.publicKey,
    authority.publicKey, // Transfer fee config authority
    authority.publicKey, // Withdraw withheld authority
    GMC_CONSTANTS.TRANSFER_FEE_BASIS_POINTS,
    maxFee,
    TOKEN_2022_PROGRAM_ID
  );

  const initMintIx = createInitializeMintInstruction(
    gmcMintKeypair.publicKey,
    GMC_CONSTANTS.DECIMALS,
    authority.publicKey, // Mint authority
    null, // No freeze authority
    TOKEN_2022_PROGRAM_ID
  );

  const setupTransaction = new anchor.web3.Transaction()
    .add(createMintAccountIx)
    .add(initTransferFeeIx)
    .add(initMintIx);

  const setupSig = await provider.sendAndConfirm(setupTransaction, [gmcMintKeypair, authority]);
  console.log(`✅ Mint created successfully! Signature: ${setupSig}`);
  
  // --- 2. Mint the Total Supply ---
  const totalSupply = toTokenAmount(GMC_CONSTANTS.TOTAL_SUPPLY_UNITS);
  
  // Create a temporary Associated Token Account for the authority to hold the total supply initially
  const authorityAta = await createAssociatedTokenAccountIdempotent(
    provider.connection,
    authority,
    gmcMintKeypair.publicKey,
    authority.publicKey,
    {},
    TOKEN_2022_PROGRAM_ID
  );
  console.log(`🏦 Authority's ATA: ${authorityAta.toBase58()}`);
  
  const mintSig = await mintTo(
    provider.connection,
    authority,
    gmcMintKeypair.publicKey,
    authorityAta,
    authority,
    totalSupply,
    [],
    { commitment: "confirmed" },
    TOKEN_2022_PROGRAM_ID
  );
  console.log(`✅ Total supply of ${GMC_CONSTANTS.TOTAL_SUPPLY_UNITS} GMC minted! Signature: ${mintSig}`);

  // --- 3. Disable Future Minting (Set Mint Authority to null) ---
  const disableMintSig = await setAuthority(
    provider.connection,
    authority,
    gmcMintKeypair.publicKey,
    authority,
    AuthorityType.MintTokens,
    null, // Set authority to null
    [],
    { commitment: "confirmed" },
    TOKEN_2022_PROGRAM_ID
  );
  console.log(`🔒 Minting authority disabled permanently! Signature: ${disableMintSig}`);
  console.log("Token supply is now fixed.");

  // --- 4. Prepare for Distribution (Create wallets/ATAs for each allocation) ---
  // In a real scenario, these would be PDAs or specific keypairs.
  // For this script, we generate new keypairs to represent each fund.
  const wallets = {
      stakingPool: Keypair.generate(),
      strategicReserve: Keypair.generate(),
      team: Keypair.generate(),
      presale: Keypair.generate(),
      treasury: Keypair.generate(),
      marketing: Keypair.generate(),
      airdrop: Keypair.generate()
  };
  
  console.log("\n--- Wallet Addresses for Token Distribution ---");
  for (const [name, keypair] of Object.entries(wallets)) {
      console.log(`${name.padEnd(20)}: ${keypair.publicKey.toBase58()}`);
  }
  console.log("-------------------------------------------\n");

  // Save keypairs and addresses to files
  const outputDir = path.join(__dirname, '..', 'deployment-keys');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir);
  }
  fs.writeFileSync(path.join(outputDir, 'gmc_mint.json'), JSON.stringify(Array.from(gmcMintKeypair.secretKey)));
  for (const [name, keypair] of Object.entries(wallets)) {
    fs.writeFileSync(path.join(outputDir, `${name}_wallet.json`), JSON.stringify(Array.from(keypair.secretKey)));
  }
  console.log(`🔑 All keys saved to '${outputDir}' directory.`);


  console.log("\n💥 Deployment Script Finished Successfully! 💥");
}

main().catch(err => {
  console.error(err);
  process.exit(1);
}); 