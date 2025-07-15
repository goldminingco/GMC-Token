import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { GmcStaking } from "../target/types/gmc_staking";
import { assert } from "chai";
import { Keypair, SystemProgram } from "@solana/web3.js";

describe("GMC Staking Contract - User Info", () => {
    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);

    const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
    const user = (provider.wallet as any).payer as Keypair;

    it("Initializes the user stake info account", async () => {
        // RED: This test will fail as the instruction is not implemented
        const [userStakeInfoPDA, _] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from("user_stake_info"), user.publicKey.toBuffer()],
            program.programId
        );

        await program.methods
            .initializeUser()
            .accounts({
                userStakeInfo: userStakeInfoPDA,
                user: user.publicKey,
                systemProgram: SystemProgram.programId,
            })
            .signers([user])
            .rpc();

        const account = await program.account.userStakeInfo.fetch(userStakeInfoPDA);
        assert.ok(account.user.equals(user.publicKey));
        assert.equal(account.stakeCount, 0);
    });
}); 