import * as anchor from "@coral-xyz/anchor";
import {
  createMint as createSplMint,
  createAccount,
  mintTo as mintToSpl,
  TOKEN_PROGRAM_ID,
} from "@solana/spl-token";

// Wrapper functions to simplify test setup

export async function createMint(
  provider: anchor.AnchorProvider
): Promise<anchor.web3.PublicKey> {
  const mint = anchor.web3.Keypair.generate();
  const authority = provider.wallet.publicKey;

  await createSplMint(
    provider.connection,
    (provider.wallet as any).payer, // The payer
    authority, // Mint authority
    null, // Freeze authority
    9, // Decimals
    mint // Keypair for the new mint
  );

  return mint.publicKey;
}

export async function createTokenAccount(
  provider: anchor.AnchorProvider,
  mint: anchor.web3.PublicKey,
  owner: anchor.web3.PublicKey
): Promise<anchor.web3.PublicKey> {
  const tokenAccount = await createAccount(
    provider.connection,
    (provider.wallet as any).payer,
    mint,
    owner
  );
  return tokenAccount;
}

export async function mintTo(
  provider: anchor.AnchorProvider,
  mint: anchor.web3.PublicKey,
  destination: anchor.web3.PublicKey,
  amount: number | bigint
): Promise<void> {
  await mintToSpl(
    provider.connection,
    (provider.wallet as any).payer,
    mint,
    destination,
    provider.wallet.publicKey, // Authority
    amount
  );
} 