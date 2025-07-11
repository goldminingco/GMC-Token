// ---
// EN: GMC Vesting Setup Script
//     This script handles the creation and management of vesting schedules for the GMC ecosystem.
//     It creates schedules for team allocation and strategic reserve according to tokenomics.
// PT: Script de Configuração de Vesting GMC
//     Este script gerencia a criação e gestão de cronogramas de vesting para o ecossistema GMC.
//     Cria cronogramas para alocação da equipe e reserva estratégica de acordo com tokenomics.
// ---

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import { 
  TOKEN_PROGRAM_ID, 
  ASSOCIATED_TOKEN_PROGRAM_ID,
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
} from "@solana/spl-token";
import { GmcVesting } from "../target/types/gmc_vesting";

// EN: Constants based on tokenomics documentation
// PT: Constantes baseadas na documentação de tokenomics
// Constants based on documentation
const TEAM_ALLOCATION = 2_000_000_000_000_000; // EN: 2M GMC (9 decimals) | PT: 2M GMC (9 decimais)
const STRATEGIC_RESERVE = 10_000_000_000_000_000; // EN: 10M GMC (9 decimals) | PT: 10M GMC (9 decimais)
const FIVE_YEARS_IN_SECONDS = 5 * 365 * 24 * 60 * 60; // EN: 5 years | PT: 5 anos
const ONE_YEAR_IN_SECONDS = 365 * 24 * 60 * 60; // EN: 1 year (cliff for team) | PT: 1 ano (cliff para equipe)

/**
 * EN: Vesting Setup Script
 *     This script creates vesting schedules for:
 *     1. Team allocation: 2M GMC with 1-year cliff, 4-year linear vesting
 *     2. Strategic Reserve: 10M GMC with 5-year linear vesting, no cliff
 * 
 * PT: Script de Configuração de Vesting
 *     Este script cria cronogramas de vesting para:
 *     1. Alocação da equipe: 2M GMC com cliff de 1 ano, vesting linear de 4 anos
 *     2. Reserva Estratégica: 10M GMC com vesting linear de 5 anos, sem cliff
 * 
 * Vesting Setup Script
 * 
 * This script creates vesting schedules for:
 * 1. Team allocation: 2M GMC with 1-year cliff, 4-year linear vesting
 * 2. Strategic Reserve: 10M GMC with 5-year linear vesting, no cliff
 */
export class VestingSetup {
  private program: Program<GmcVesting>;
  private provider: anchor.AnchorProvider;
  private authority: Keypair;
  private gmcMint: PublicKey;

  constructor(
    program: Program<GmcVesting>,
    provider: anchor.AnchorProvider,
    authority: Keypair,
    gmcMint: PublicKey
  ) {
    this.program = program;
    this.provider = provider;
    this.authority = authority;
    this.gmcMint = gmcMint;
  }

  /**
   * EN: Initialize the vesting program
   * PT: Inicializa o programa de vesting
   * 
   * Initialize the vesting program
   */
  async initializeVesting(): Promise<void> {
    console.log("🚀 Initializing GMC Vesting Program...");

    // EN: Generate the vesting state PDA
    // PT: Gera o PDA do estado de vesting
    const [vestingState] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_state")],
      this.program.programId
    );

    try {
      const tx = await this.program.methods
        .initializeVesting()
        .accounts({
          vestingState,
          authority: this.authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([this.authority])
        .rpc();

      console.log("✅ Vesting program initialized");
      console.log("📋 Transaction signature:", tx);
      console.log("🏛️ Vesting State:", vestingState.toString());
    } catch (error) {
      console.error("❌ Failed to initialize vesting:", error);
      throw error;
    }
  }

  /**
   * EN: Create team vesting schedule
   *     2M GMC with 1-year cliff and 4-year linear vesting
   * PT: Cria cronograma de vesting da equipe
   *     2M GMC com cliff de 1 ano e vesting linear de 4 anos
   * 
   * Create team vesting schedule
   * 2M GMC with 1-year cliff and 4-year linear vesting
   */
  async createTeamVesting(teamWallet: PublicKey): Promise<void> {
    console.log("👥 Creating Team Vesting Schedule...");

    // EN: Current timestamp for vesting start
    // PT: Timestamp atual para início do vesting
    const startTimestamp = Math.floor(Date.now() / 1000); // Current timestamp
    const cliffDuration = ONE_YEAR_IN_SECONDS; // EN: 1 year cliff | PT: cliff de 1 ano
    const totalDuration = FIVE_YEARS_IN_SECONDS; // EN: 5 years total (1 year cliff + 4 years vesting) | PT: 5 anos total (1 ano cliff + 4 anos vesting)

    await this.createVestingSchedule(
      teamWallet,
      TEAM_ALLOCATION,
      startTimestamp,
      totalDuration,
      { team: {} }, // VestingType::Team
      cliffDuration,
      "Team"
    );
  }

  /**
   * EN: Create strategic reserve vesting schedule
   *     10M GMC with 5-year linear vesting, no cliff
   * PT: Cria cronograma de vesting da reserva estratégica
   *     10M GMC com vesting linear de 5 anos, sem cliff
   * 
   * Create strategic reserve vesting schedule
   * 10M GMC with 5-year linear vesting, no cliff
   */
  async createStrategicReserveVesting(reserveWallet: PublicKey): Promise<void> {
    console.log("🏦 Creating Strategic Reserve Vesting Schedule...");

    // EN: Current timestamp for vesting start
    // PT: Timestamp atual para início do vesting
    const startTimestamp = Math.floor(Date.now() / 1000); // Current timestamp
    const totalDuration = FIVE_YEARS_IN_SECONDS; // EN: 5 years | PT: 5 anos
    const cliffDuration = 0; // EN: No cliff | PT: Sem cliff

    await this.createVestingSchedule(
      reserveWallet,
      STRATEGIC_RESERVE,
      startTimestamp,
      totalDuration,
      { strategicReserve: {} }, // VestingType::StrategicReserve
      cliffDuration,
      "Strategic Reserve"
    );
  }

  /**
   * EN: Generic function to create a vesting schedule
   * PT: Função genérica para criar um cronograma de vesting
   * 
   * Generic function to create a vesting schedule
   */
  private async createVestingSchedule(
    beneficiary: PublicKey,
    totalAmount: number,
    startTimestamp: number,
    durationSeconds: number,
    scheduleType: any,
    cliffDuration: number,
    typeName: string
  ): Promise<void> {
    // EN: Generate PDAs for vesting state and schedule
    // PT: Gera PDAs para estado de vesting e cronograma
    const [vestingState] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_state")],
      this.program.programId
    );

    const [vestingSchedule] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_schedule"), beneficiary.toBuffer()],
      this.program.programId
    );

    // EN: Get token vault address (should be created beforehand)
    // PT: Obtém endereço do cofre de tokens (deve ser criado previamente)
    // Get token vault address (should be created beforehand)
    const tokenVault = await getAssociatedTokenAddress(
      this.gmcMint,
      vestingState,
      true
    );

    try {
      const tx = await this.program.methods
        .createVestingSchedule(
          beneficiary,
          new anchor.BN(totalAmount),
          new anchor.BN(startTimestamp),
          new anchor.BN(durationSeconds),
          new anchor.BN(cliffDuration)
        )
        .accounts({
          vestingState,
          vestingSchedule,
          authority: this.authority.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([this.authority])
        .rpc();

      console.log(`✅ ${typeName} vesting schedule created`);
      console.log("📋 Transaction signature:", tx);
      console.log("👤 Beneficiary:", beneficiary.toString());
      console.log("💰 Total Amount:", (totalAmount / 1e9).toLocaleString(), "GMC");
      console.log("⏰ Duration:", Math.floor(durationSeconds / (365 * 24 * 60 * 60)), "years");
      console.log("🧗 Cliff Duration:", Math.floor(cliffDuration / (365 * 24 * 60 * 60)), "years");
      console.log("📅 Schedule Address:", vestingSchedule.toString());
    } catch (error) {
      console.error(`❌ Failed to create ${typeName} vesting:`, error);
      throw error;
    }
  }

  /**
   * EN: Create token vault and fund it with the required tokens
   * PT: Cria cofre de tokens e o financia com os tokens necessários
   * 
   * Create token vault and fund it with the required tokens
   */
  async setupTokenVault(): Promise<PublicKey> {
    console.log("🏦 Setting up token vault...");

    // EN: Generate vesting state PDA
    // PT: Gera PDA do estado de vesting
    const [vestingState] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_state")],
      this.program.programId
    );

    // EN: Get associated token account for the vault
    // PT: Obtém conta de token associada para o cofre
    const tokenVault = await getAssociatedTokenAddress(
      this.gmcMint,
      vestingState,
      true
    );

    // EN: Check if vault exists, create if not
    // PT: Verifica se o cofre existe, cria se não existir
    // Check if vault exists, create if not
    try {
      const vaultInfo = await this.provider.connection.getAccountInfo(tokenVault);
      if (!vaultInfo) {
        console.log("🔧 Creating token vault...");
        const createVaultIx = createAssociatedTokenAccountInstruction(
          this.authority.publicKey,
          tokenVault,
          vestingState,
          this.gmcMint
        );

        const tx = new anchor.web3.Transaction().add(createVaultIx);
        await this.provider.sendAndConfirm(tx, [this.authority]);
        console.log("✅ Token vault created:", tokenVault.toString());
      } else {
        console.log("ℹ️ Token vault already exists:", tokenVault.toString());
      }
    } catch (error) {
      console.error("❌ Failed to setup token vault:", error);
      throw error;
    }

    return tokenVault;
  }

  /**
   * EN: Get vesting schedule information
   * PT: Obtém informações do cronograma de vesting
   * 
   * Get vesting schedule information
   */
  async getVestingSchedule(beneficiary: PublicKey): Promise<any> {
    // EN: Generate vesting schedule PDA
    // PT: Gera PDA do cronograma de vesting
    const [vestingSchedule] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_schedule"), beneficiary.toBuffer()],
      this.program.programId
    );

    try {
      const schedule = await this.program.account.vestingSchedule.fetch(vestingSchedule);
      return {
        address: vestingSchedule,
        ...schedule,
      };
    } catch (error) {
      console.error("❌ Failed to fetch vesting schedule:", error);
      return null;
    }
  }

  /**
   * EN: Release vested tokens for a beneficiary
   * PT: Libera tokens do vesting para um beneficiário
   * 
   * Release vested tokens for a beneficiary
   */
  async releaseTokens(beneficiary: PublicKey): Promise<void> {
    console.log("🔓 Releasing vested tokens for:", beneficiary.toString());

    // EN: Generate required PDAs
    // PT: Gera PDAs necessários
    const [vestingState] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_state")],
      this.program.programId
    );

    const [vestingSchedule] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_schedule"), beneficiary.toBuffer()],
      this.program.programId
    );

    // EN: Get token accounts
    // PT: Obtém contas de token
    const tokenVault = await getAssociatedTokenAddress(
      this.gmcMint,
      vestingState,
      true
    );

    const beneficiaryTokenAccount = await getAssociatedTokenAddress(
      this.gmcMint,
      beneficiary
    );

    try {
      const tx = await this.program.methods
        .releaseVestedTokens()
        .accounts({
          vestingState,
          vestingSchedule,
          vestingVault: tokenVault,
          beneficiaryTokenAccount,
          beneficiary,
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .rpc();

      console.log("✅ Tokens released successfully");
      console.log("📋 Transaction signature:", tx);
    } catch (error) {
      console.error("❌ Failed to release tokens:", error);
      throw error;
    }
  }

  /**
   * EN: Get program state information
   * PT: Obtém informações do estado do programa
   * 
   * Get program state information
   */
  async getVestingState(): Promise<any> {
    // EN: Generate vesting state PDA
    // PT: Gera PDA do estado de vesting
    const [vestingState] = PublicKey.findProgramAddressSync(
      [Buffer.from("vesting_state")],
      this.program.programId
    );

    try {
      const state = await this.program.account.vestingState.fetch(vestingState);
      return {
        address: vestingState,
        ...state,
      };
    } catch (error) {
      console.error("❌ Failed to fetch vesting state:", error);
      return null;
    }
  }
}

/**
 * EN: Main setup function that orchestrates the entire vesting setup process
 * PT: Função principal de configuração que orquestra todo o processo de setup de vesting
 * 
 * Main setup function
 */
export async function setupVestingSchedules(
  program: Program<GmcVesting>,
  provider: anchor.AnchorProvider,
  authority: Keypair,
  gmcMint: PublicKey,
  teamWallet: PublicKey,
  reserveWallet: PublicKey
): Promise<void> {
  console.log("🎯 Starting GMC Vesting Setup...");
  console.log("=" .repeat(50));

  const vestingSetup = new VestingSetup(program, provider, authority, gmcMint);

  try {
    // EN: Step 1: Initialize vesting program
    // PT: Passo 1: Inicializar programa de vesting
    // Step 1: Initialize vesting program
    await vestingSetup.initializeVesting();

    // EN: Step 2: Setup token vault
    // PT: Passo 2: Configurar cofre de tokens
    // Step 2: Setup token vault
    await vestingSetup.setupTokenVault();

    // EN: Step 3: Create team vesting schedule
    // PT: Passo 3: Criar cronograma de vesting da equipe
    // Step 3: Create team vesting schedule
    await vestingSetup.createTeamVesting(teamWallet);

    // EN: Step 4: Create strategic reserve vesting schedule
    // PT: Passo 4: Criar cronograma de vesting da reserva estratégica
    // Step 4: Create strategic reserve vesting schedule
    await vestingSetup.createStrategicReserveVesting(reserveWallet);

    // EN: Step 5: Display summary
    // PT: Passo 5: Exibir resumo
    // Step 5: Display summary
    console.log("\n" + "=" .repeat(50));
    console.log("📊 VESTING SETUP SUMMARY");
    console.log("=" .repeat(50));

    const state = await vestingSetup.getVestingState();
    console.log("🏛️ Vesting State:", state?.address.toString());
    console.log("📈 Total Schedules:", state?.totalSchedules.toString());
    console.log("💰 Total Vested Amount:", (state?.totalVestedAmount.toNumber() / 1e9).toLocaleString(), "GMC");

    const teamSchedule = await vestingSetup.getVestingSchedule(teamWallet);
    const reserveSchedule = await vestingSetup.getVestingSchedule(reserveWallet);

    console.log("\n👥 Team Schedule:", teamSchedule?.address.toString());
    console.log("🏦 Reserve Schedule:", reserveSchedule?.address.toString());

    console.log("\n✅ Vesting setup completed successfully!");
  } catch (error) {
    console.error("❌ Vesting setup failed:", error);
    throw error;
  }
}

// EN: Helper function to calculate vesting info
// PT: Função auxiliar para calcular informações de vesting
// Helper function to calculate vesting info
export function calculateVestingInfo(
  totalAmount: number,
  startTimestamp: number,
  durationSeconds: number,
  cliffDuration: number,
  currentTimestamp?: number
): {
  totalAmount: number;
  vestedAmount: number;
  releasableAmount: number;
  remainingAmount: number;
  isCliffPassed: boolean;
  isFullyVested: boolean;
  progressPercentage: number;
} {
  const now = currentTimestamp || Math.floor(Date.now() / 1000);
  
  // EN: Check if vesting started
  // PT: Verifica se o vesting começou
  // Check if vesting started
  if (now < startTimestamp) {
    return {
      totalAmount,
      vestedAmount: 0,
      releasableAmount: 0,
      remainingAmount: totalAmount,
      isCliffPassed: false,
      isFullyVested: false,
      progressPercentage: 0,
    };
  }

  // EN: Check cliff period
  // PT: Verifica período de cliff
  // Check cliff period
  const cliffEnd = startTimestamp + cliffDuration;
  const isCliffPassed = now >= cliffEnd;

  if (!isCliffPassed) {
    return {
      totalAmount,
      vestedAmount: 0,
      releasableAmount: 0,
      remainingAmount: totalAmount,
      isCliffPassed: false,
      isFullyVested: false,
      progressPercentage: 0,
    };
  }

  // EN: Calculate vested amount
  // PT: Calcula quantidade liberada
  // Calculate vested amount
  const elapsed = now - startTimestamp;
  const isFullyVested = elapsed >= durationSeconds;
  
  const vestedAmount = isFullyVested 
    ? totalAmount 
    : Math.floor((totalAmount * elapsed) / durationSeconds);

  const progressPercentage = Math.min(100, (elapsed / durationSeconds) * 100);

  return {
    totalAmount,
    vestedAmount,
    releasableAmount: vestedAmount, // EN: Assuming no tokens released yet | PT: Assumindo que nenhum token foi liberado ainda
    remainingAmount: totalAmount - vestedAmount,
    isCliffPassed: true,
    isFullyVested,
    progressPercentage,
  };
} 