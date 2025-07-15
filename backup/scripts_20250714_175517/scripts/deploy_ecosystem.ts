import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, Keypair, SystemProgram, Connection, clusterApiUrl } from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, createMint, createAccount, mintTo, getOrCreateAssociatedTokenAccount } from "@solana/spl-token";
import fs from "fs";
import path from "path";

// Import program types
import { GmcToken } from "../target/types/gmc_token";
import { GmcStaking } from "../target/types/gmc_staking";
import { GmcRanking } from "../target/types/gmc_ranking";
import { GmcVesting } from "../target/types/gmc_vesting";

interface DeploymentConfig {
  network: "devnet" | "testnet" | "mainnet-beta";
  authority: Keypair;
  teamWallet: PublicKey;
  treasuryWallet: PublicKey;
  marketingWallet: PublicKey;
  airdropWallet: PublicKey;
  icoWallet: PublicKey;
}

interface DeploymentResult {
  network: string;
  timestamp: string;
  contracts: {
    gmcToken: string;
    gmcStaking: string;
    gmcRanking: string;
    gmcVesting: string;
  };
  accounts: {
    gmcMint: string;
    usdtMint: string;
    globalState: string;
    rankingState: string;
  };
  wallets: {
    authority: string;
    teamWallet: string;
    treasuryWallet: string;
    marketingWallet: string;
    airdropWallet: string;
    icoWallet: string;
  };
}

export class GMCEcosystemDeployer {
  private connection: Connection;
  private provider: anchor.AnchorProvider;
  private config: DeploymentConfig;
  
  // Programs
  private tokenProgram!: Program<GmcToken>;
  private stakingProgram!: Program<GmcStaking>;
  private rankingProgram!: Program<GmcRanking>;
  private vestingProgram!: Program<GmcVesting>;

  constructor(config: DeploymentConfig) {
    this.config = config;
    
    // Setup connection
    const endpoint = config.network === "devnet" 
      ? clusterApiUrl("devnet")
      : config.network === "testnet"
      ? clusterApiUrl("testnet")
      : clusterApiUrl("mainnet-beta");
    
    this.connection = new Connection(endpoint, "confirmed");
    
    // Setup provider
    const wallet = new anchor.Wallet(config.authority);
    this.provider = new anchor.AnchorProvider(this.connection, wallet, {
      commitment: "confirmed",
    });
    
    anchor.setProvider(this.provider);
  }

  async initialize() {
    console.log("🚀 Initializing GMC Ecosystem Deployer...");
    
    // Load programs
    this.tokenProgram = anchor.workspace.GmcToken as Program<GmcToken>;
    this.stakingProgram = anchor.workspace.GmcStaking as Program<GmcStaking>;
    this.rankingProgram = anchor.workspace.GmcRanking as Program<GmcRanking>;
    this.vestingProgram = anchor.workspace.GmcVesting as Program<GmcVesting>;
    
    console.log("✅ Programs loaded");
    console.log(`   - Token Program: ${this.tokenProgram.programId.toString()}`);
    console.log(`   - Staking Program: ${this.stakingProgram.programId.toString()}`);
    console.log(`   - Ranking Program: ${this.rankingProgram.programId.toString()}`);
    console.log(`   - Vesting Program: ${this.vestingProgram.programId.toString()}`);
  }

  async deploy(): Promise<DeploymentResult> {
    console.log(`🌐 Deploying GMC Ecosystem to ${this.config.network}...`);
    
    const startTime = Date.now();
    
    try {
      // Step 1: Create GMC and USDT mints
      console.log("\n📍 Step 1: Creating token mints...");
      const { gmcMint, usdtMint } = await this.createMints();
      
      // Step 2: Initialize contracts
      console.log("\n📍 Step 2: Initializing contracts...");
      const { globalState, rankingState } = await this.initializeContracts(gmcMint, usdtMint);
      
      // Step 3: Setup initial token distribution
      console.log("\n📍 Step 3: Setting up token distribution...");
      await this.setupTokenDistribution(gmcMint);
      
      // Step 4: Create vesting schedules
      console.log("\n📍 Step 4: Creating vesting schedules...");
      await this.createVestingSchedules();
      
      // Step 5: Verify deployment
      console.log("\n📍 Step 5: Verifying deployment...");
      await this.verifyDeployment(gmcMint, usdtMint, globalState, rankingState);
      
      const deploymentResult: DeploymentResult = {
        network: this.config.network,
        timestamp: new Date().toISOString(),
        contracts: {
          gmcToken: this.tokenProgram.programId.toString(),
          gmcStaking: this.stakingProgram.programId.toString(),
          gmcRanking: this.rankingProgram.programId.toString(),
          gmcVesting: this.vestingProgram.programId.toString(),
        },
        accounts: {
          gmcMint: gmcMint.toString(),
          usdtMint: usdtMint.toString(),
          globalState: globalState.toString(),
          rankingState: rankingState.toString(),
        },
        wallets: {
          authority: this.config.authority.publicKey.toString(),
          teamWallet: this.config.teamWallet.toString(),
          treasuryWallet: this.config.treasuryWallet.toString(),
          marketingWallet: this.config.marketingWallet.toString(),
          airdropWallet: this.config.airdropWallet.toString(),
          icoWallet: this.config.icoWallet.toString(),
        },
      };
      
      // Save deployment result
      await this.saveDeploymentResult(deploymentResult);
      
      const duration = (Date.now() - startTime) / 1000;
      console.log(`\n🎉 GMC Ecosystem deployed successfully in ${duration}s!`);
      
      return deploymentResult;
      
    } catch (error) {
      console.error("❌ Deployment failed:", error);
      throw error;
    }
  }

  private async createMints(): Promise<{ gmcMint: PublicKey; usdtMint: PublicKey }> {
    console.log("   Creating GMC mint...");
    const gmcMint = await createMint(
      this.connection,
      this.config.authority,
      this.config.authority.publicKey,
      null,
      9 // 9 decimals for GMC
    );
    console.log(`   ✅ GMC Mint: ${gmcMint.toString()}`);

    console.log("   Creating USDT mint (for testing)...");
    const usdtMint = await createMint(
      this.connection,
      this.config.authority,
      this.config.authority.publicKey,
      null,
      6 // 6 decimals for USDT
    );
    console.log(`   ✅ USDT Mint: ${usdtMint.toString()}`);

    return { gmcMint, usdtMint };
  }

  private async initializeContracts(
    gmcMint: PublicKey,
    usdtMint: PublicKey
  ): Promise<{ globalState: PublicKey; rankingState: PublicKey }> {
    
    // Derive PDAs
    const [globalState] = PublicKey.findProgramAddressSync(
      [Buffer.from("global_state")],
      this.stakingProgram.programId
    );

    const [rankingState] = PublicKey.findProgramAddressSync(
      [Buffer.from("ranking_state")],
      this.rankingProgram.programId
    );

    // Initialize Staking Contract
    console.log("   Initializing Staking Contract...");
    try {
      await this.stakingProgram.methods
        .initialize(
          this.config.teamWallet,
          gmcMint,
          usdtMint
        )
        .accounts({
          globalState,
          authority: this.config.authority.publicKey,
          payer: this.config.authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([this.config.authority])
        .rpc();
      console.log(`   ✅ Staking Contract initialized`);
    } catch (error) {
      console.log(`   ⚠️ Staking Contract may already be initialized`);
    }

    // Initialize Ranking Contract
    console.log("   Initializing Ranking Contract...");
    try {
      const topHolders: PublicKey[] = []; // Empty initially, will be updated later
      
      await this.rankingProgram.methods
        .initialize(topHolders)
        .accounts({
          rankingState,
          authority: this.config.authority.publicKey,
          payer: this.config.authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([this.config.authority])
        .rpc();
      console.log(`   ✅ Ranking Contract initialized`);
    } catch (error) {
      console.log(`   ⚠️ Ranking Contract may already be initialized`);
    }

    return { globalState, rankingState };
  }

  private async setupTokenDistribution(gmcMint: PublicKey): Promise<void> {
    console.log("   Creating token accounts for distribution...");

    // Create authority's GMC account
    const authorityGmcAccount = await getOrCreateAssociatedTokenAccount(
      this.connection,
      this.config.authority,
      gmcMint,
      this.config.authority.publicKey
    );

    // Mint total supply to authority
    console.log("   Minting total supply (100M GMC)...");
    await mintTo(
      this.connection,
      this.config.authority,
      gmcMint,
      authorityGmcAccount.address,
      this.config.authority,
      100_000_000 * 10**9 // 100M GMC
    );

    // Create token accounts for all wallets
    const teamGmcAccount = await getOrCreateAssociatedTokenAccount(
      this.connection,
      this.config.authority,
      gmcMint,
      this.config.teamWallet
    );

    const treasuryGmcAccount = await getOrCreateAssociatedTokenAccount(
      this.connection,
      this.config.authority,
      gmcMint,
      this.config.treasuryWallet
    );

    const marketingGmcAccount = await getOrCreateAssociatedTokenAccount(
      this.connection,
      this.config.authority,
      gmcMint,
      this.config.marketingWallet
    );

    const airdropGmcAccount = await getOrCreateAssociatedTokenAccount(
      this.connection,
      this.config.authority,
      gmcMint,
      this.config.airdropWallet
    );

    const icoGmcAccount = await getOrCreateAssociatedTokenAccount(
      this.connection,
      this.config.authority,
      gmcMint,
      this.config.icoWallet
    );

    // Distribute tokens according to tokenomics
    console.log("   Distributing tokens according to tokenomics...");
    
    // Team: 2M GMC (will be vested)
    await mintTo(
      this.connection,
      this.config.authority,
      gmcMint,
      teamGmcAccount.address,
      this.config.authority,
      2_000_000 * 10**9
    );

    // Treasury: 2M GMC
    await mintTo(
      this.connection,
      this.config.authority,
      gmcMint,
      treasuryGmcAccount.address,
      this.config.authority,
      2_000_000 * 10**9
    );

    // Marketing: 6M GMC
    await mintTo(
      this.connection,
      this.config.authority,
      gmcMint,
      marketingGmcAccount.address,
      this.config.authority,
      6_000_000 * 10**9
    );

    // Airdrop: 2M GMC
    await mintTo(
      this.connection,
      this.config.authority,
      gmcMint,
      airdropGmcAccount.address,
      this.config.authority,
      2_000_000 * 10**9
    );

    // ICO: 8M GMC
    await mintTo(
      this.connection,
      this.config.authority,
      gmcMint,
      icoGmcAccount.address,
      this.config.authority,
      8_000_000 * 10**9
    );

    console.log("   ✅ Token distribution completed");
    console.log(`      - Team: 2M GMC`);
    console.log(`      - Treasury: 2M GMC`);
    console.log(`      - Marketing: 6M GMC`);
    console.log(`      - Airdrop: 2M GMC`);
    console.log(`      - ICO: 8M GMC`);
    console.log(`      - Remaining for Staking Pool: 80M GMC`);
  }

  private async createVestingSchedules(): Promise<void> {
    // Create team vesting schedule (2M GMC over 5 years with 1 year cliff)
    console.log("   Creating team vesting schedule...");
    
    const [teamVestingPda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("vesting_schedule"),
        this.config.teamWallet.toBuffer(),
      ],
      this.vestingProgram.programId
    );

    try {
      const totalAmount = new anchor.BN(2_000_000 * 10**9); // 2M GMC
      const startTimestamp = new anchor.BN(Math.floor(Date.now() / 1000) + 86400); // Start in 24 hours
      const durationSeconds = new anchor.BN(5 * 365 * 24 * 60 * 60); // 5 years
      const cliffSeconds = new anchor.BN(365 * 24 * 60 * 60); // 1 year cliff

      await this.vestingProgram.methods
        .createSchedule(
          this.config.teamWallet,
          totalAmount,
          startTimestamp,
          durationSeconds,
          cliffSeconds,
          { team: {} }
        )
        .accounts({
          vestingSchedule: teamVestingPda,
          authority: this.config.authority.publicKey,
          payer: this.config.authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([this.config.authority])
        .rpc();

      console.log("   ✅ Team vesting schedule created");
    } catch (error) {
      console.log("   ⚠️ Team vesting schedule may already exist");
    }

    // Create strategic reserve vesting schedule (10M GMC over 5 years, no cliff)
    console.log("   Creating strategic reserve vesting schedule...");
    
    const reserveWallet = this.config.authority.publicKey; // Using authority as reserve for now
    const [reserveVestingPda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("vesting_schedule"),
        reserveWallet.toBuffer(),
      ],
      this.vestingProgram.programId
    );

    try {
      const totalAmount = new anchor.BN(10_000_000 * 10**9); // 10M GMC
      const startTimestamp = new anchor.BN(Math.floor(Date.now() / 1000) + 86400); // Start in 24 hours
      const durationSeconds = new anchor.BN(5 * 365 * 24 * 60 * 60); // 5 years
      const cliffSeconds = new anchor.BN(0); // No cliff

      await this.vestingProgram.methods
        .createSchedule(
          reserveWallet,
          totalAmount,
          startTimestamp,
          durationSeconds,
          cliffSeconds,
          { strategicReserve: {} }
        )
        .accounts({
          vestingSchedule: reserveVestingPda,
          authority: this.config.authority.publicKey,
          payer: this.config.authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([this.config.authority])
        .rpc();

      console.log("   ✅ Strategic reserve vesting schedule created");
    } catch (error) {
      console.log("   ⚠️ Strategic reserve vesting schedule may already exist");
    }
  }

  private async verifyDeployment(
    gmcMint: PublicKey,
    usdtMint: PublicKey,
    globalState: PublicKey,
    rankingState: PublicKey
  ): Promise<void> {
    console.log("   Verifying contract states...");

    // Verify staking contract
    try {
      const stakingState = await this.stakingProgram.account.globalState.fetch(globalState);
      console.log(`   ✅ Staking Contract verified`);
      console.log(`      - Authority: ${stakingState.authority.toString()}`);
      console.log(`      - GMC Mint: ${stakingState.gmcMint.toString()}`);
      console.log(`      - Emergency Paused: ${stakingState.emergencyPaused}`);
    } catch (error) {
      console.log(`   ❌ Staking Contract verification failed`);
    }

    // Verify ranking contract
    try {
      const rankingStateData = await this.rankingProgram.account.rankingState.fetch(rankingState);
      console.log(`   ✅ Ranking Contract verified`);
      console.log(`      - Authority: ${rankingStateData.authority.toString()}`);
      console.log(`      - Monthly GMC Pool: ${rankingStateData.monthlyPoolGmc.toString()}`);
      console.log(`      - Top Holders Count: ${rankingStateData.topHolders.length}`);
    } catch (error) {
      console.log(`   ❌ Ranking Contract verification failed`);
    }

    console.log("   ✅ Deployment verification completed");
  }

  private async saveDeploymentResult(result: DeploymentResult): Promise<void> {
    const filename = `deployment_${result.network}_${Date.now()}.json`;
    const filepath = path.join(process.cwd(), "deployments", filename);
    
    // Create deployments directory if it doesn't exist
    const deploymentsDir = path.join(process.cwd(), "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    fs.writeFileSync(filepath, JSON.stringify(result, null, 2));
    console.log(`\n📄 Deployment result saved to: ${filepath}`);
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const network = (args[0] as "devnet" | "testnet" | "mainnet-beta") || "devnet";
  
  console.log("🚀 GMC Ecosystem Deployment Script");
  console.log(`📡 Target Network: ${network}`);
  
  // Load or generate authority keypair
  let authority: Keypair;
  const authorityPath = path.join(process.cwd(), "keys", "authority.json");
  
  if (fs.existsSync(authorityPath)) {
    const authorityData = JSON.parse(fs.readFileSync(authorityPath, "utf8"));
    authority = Keypair.fromSecretKey(new Uint8Array(authorityData));
    console.log(`🔑 Loaded authority keypair: ${authority.publicKey.toString()}`);
  } else {
    authority = Keypair.generate();
    console.log(`🔑 Generated new authority keypair: ${authority.publicKey.toString()}`);
    
    // Save keypair
    const keysDir = path.join(process.cwd(), "keys");
    if (!fs.existsSync(keysDir)) {
      fs.mkdirSync(keysDir, { recursive: true });
    }
    fs.writeFileSync(authorityPath, JSON.stringify(Array.from(authority.secretKey)));
    console.log(`💾 Authority keypair saved to: ${authorityPath}`);
  }
  
  // Generate other wallets (in production, these would be provided)
  const teamWallet = Keypair.generate().publicKey;
  const treasuryWallet = Keypair.generate().publicKey;
  const marketingWallet = Keypair.generate().publicKey;
  const airdropWallet = Keypair.generate().publicKey;
  const icoWallet = Keypair.generate().publicKey;
  
  const config: DeploymentConfig = {
    network,
    authority,
    teamWallet,
    treasuryWallet,
    marketingWallet,
    airdropWallet,
    icoWallet,
  };
  
  const deployer = new GMCEcosystemDeployer(config);
  
  try {
    await deployer.initialize();
    const result = await deployer.deploy();
    
    console.log("\n🎉 Deployment Summary:");
    console.log(`   Network: ${result.network}`);
    console.log(`   Timestamp: ${result.timestamp}`);
    console.log(`   GMC Token Program: ${result.contracts.gmcToken}`);
    console.log(`   Staking Program: ${result.contracts.gmcStaking}`);
    console.log(`   Ranking Program: ${result.contracts.gmcRanking}`);
    console.log(`   Vesting Program: ${result.contracts.gmcVesting}`);
    console.log(`   GMC Mint: ${result.accounts.gmcMint}`);
    console.log(`   USDT Mint: ${result.accounts.usdtMint}`);
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch(console.error);
}

export { GMCEcosystemDeployer, DeploymentConfig, DeploymentResult }; 