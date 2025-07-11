import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { assert } from "chai";
import { GmcRanking } from "../target/types/gmc_ranking";
import { MerkleTree } from "merkletreejs";
import { TOKEN_PROGRAM_ID } from "@solana/spl-token";
import { createMint, createTokenAccount } from "./utils";

const keccak256 = require("keccak256");

describe("GMC Ranking Contract - Merkle Tree Rewards", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const wallet = provider.wallet as anchor.Wallet;
  const program = anchor.workspace.GmcRanking as Program<GmcRanking>;

  const admin = anchor.web3.Keypair.generate();
  const winner = anchor.web3.Keypair.generate();
  let rewardMint: anchor.web3.PublicKey;

  before(async () => {
    await provider.connection.requestAirdrop(admin.publicKey, 10 * anchor.web3.LAMPORTS_PER_SOL);
    await provider.connection.requestAirdrop(winner.publicKey, 10 * anchor.web3.LAMPORTS_PER_SOL);
    rewardMint = await createMint(provider);
  });

  it("Allows admin to set a Merkle root and a winner to claim rewards", async () => {
    const [rankingStatePda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("ranking_state_seed")],
      program.programId
    );
    const [rewardsVaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("rewards_vault_seed"), rankingStatePda.toBuffer()],
      program.programId
    );

    await program.methods
      .initializeRanking()
      .accountsPartial({
        rankingState: rankingStatePda,
        authority: admin.publicKey,
        rewardsVault: rewardsVaultPda,
        rewardMint: rewardMint,
      })
      .signers([admin])
      .rpc();

    const winners = [
      { address: anchor.web3.Keypair.generate().publicKey, amount: new anchor.BN(100) },
      { address: winner.publicKey, amount: new anchor.BN(300) },
    ];

    const leaves = winners.map(w => 
      Buffer.from(
        anchor.utils.bytes.hex.encode(
          new anchor.web3.PublicKey(w.address).toBuffer()
        ) + w.amount.toString(16, 16),
        "hex"
      )
    );
    
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const merkleRoot = tree.getRoot();

    // Convert merkleRoot Buffer to number array
    const rootArray = Array.from(merkleRoot);

    await program.methods
      .setRewardsMerkleRoot(rootArray)
      .accountsPartial({
        rankingState: rankingStatePda,
        authority: admin.publicKey,
      })
      .signers([admin])
      .rpc();

    const winnerData = winners[1];
    const leaf = leaves[1];
    const proof = tree.getProof(leaf).map(p => Array.from(p.data));
    const cycle = (await program.account.rankingState.fetch(rankingStatePda)).cycle;

    const [claimStatusPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("claim"), winnerData.address.toBuffer(), cycle.toArrayLike(Buffer, "le", 8)],
      program.programId
    );

    const winnerTokenAccount = await createTokenAccount(provider, rewardMint, winner.publicKey);

    await program.methods
      .claimRankingReward(proof, winnerData.amount, cycle)
      .accountsPartial({
        claimant: winnerData.address,
        rankingState: rankingStatePda,
        claimStatus: claimStatusPda,
        rewardsVault: rewardsVaultPda,
        claimantTokenAccount: winnerTokenAccount,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .signers([winner])
      .rpc();

    const claimedStatus = await program.account.claimStatus.fetch(claimStatusPda);
    assert.isTrue(claimedStatus.isClaimed);
    assert.equal(claimedStatus.amount.toString(), winnerData.amount.toString());
  });
}); 