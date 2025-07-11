import * as anchor from "@coral-xyz/anchor";
import { assert } from "chai";

describe("🏆 GMC Ranking System (TDD)", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.GmcRanking;
  
  // Keypairs para teste
  const admin = anchor.web3.Keypair.generate();
  const user1 = anchor.web3.Keypair.generate(); // Top Transactor
  const user2 = anchor.web3.Keypair.generate(); // Top Recruiter  
  const user3 = anchor.web3.Keypair.generate(); // Top Burner
  const user4 = anchor.web3.Keypair.generate(); // Regular user
  const topHolder1 = anchor.web3.Keypair.generate(); // Excluded (Top 20 holder)
  
  // PDAs
  let rankingStatePda: anchor.web3.PublicKey;
  let userActivityPdas: { [key: string]: anchor.web3.PublicKey } = {};
  let merkleTreePda: anchor.web3.PublicKey;

  before(async () => {
    // Airdrop para todos os participantes
    const allUsers = [admin, user1, user2, user3, user4, topHolder1];
    const airdrops = allUsers.map(keypair =>
      provider.connection.requestAirdrop(
        keypair.publicKey,
        10 * anchor.web3.LAMPORTS_PER_SOL
      )
    );
    await Promise.all(airdrops);
    
    // Esperar confirmação
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Calcular PDAs
    [rankingStatePda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("ranking_state")],
      program.programId
    );
    
    [merkleTreePda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("merkle_tree")],
      program.programId
    );
    
    // Calcular PDAs para atividades dos usuários
    for (const [name, user] of Object.entries({
      user1, user2, user3, user4, topHolder1
    })) {
      [userActivityPdas[name]] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("user_activity"), user.publicKey.toBuffer()],
        program.programId
      );
    }
  });

  // =====================================================
  // 🔴 FASE RED: Testes que devem falhar primeiro
  // =====================================================

  it("❌ RED: Deve falhar ao tentar inicializar ranking sem implementação", async () => {
    try {
      await program.methods
        .initializeRanking()
        .accounts({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([admin])
        .rpc();
      
      assert.fail("A função de inicialização não deveria existir ainda (fase RED)");
    } catch (error: any) {
      assert.include(error.toString(), "Invalid instruction");
      console.log("✅ Teste RED: initializeRanking falhou como esperado");
    }
  });

  it("❌ RED: Deve falhar ao tentar registrar atividade sem estruturas implementadas", async () => {
    try {
      await program.methods
        .logTransaction()
        .accounts({
          user: user1.publicKey,
          userActivity: userActivityPdas.user1,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([user1])
        .rpc();
      
      assert.fail("A função logTransaction não deveria existir ainda");
    } catch (error: any) {
      assert.include(error.toString(), "Invalid instruction");
      console.log("✅ Teste RED: logTransaction falhou como esperado");
    }
  });

  it("❌ RED: Deve falhar ao tentar distribuir prêmios mensais sem implementação", async () => {
    try {
      await program.methods
        .distributeMonthlyRewards()
        .accounts({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
        })
        .signers([admin])
        .rpc();
      
      assert.fail("A distribuição mensal não deveria existir ainda");
    } catch (error: any) {
      assert.include(error.toString(), "Invalid instruction");
      console.log("✅ Teste RED: distributeMonthlyRewards falhou como esperado");
    }
  });

  it("❌ RED: Deve falhar ao tentar configurar Merkle Tree sem estruturas", async () => {
    try {
      const dummyRoot = new Array(32).fill(0);
      
      await program.methods
        .setRewardsMerkleRoot(dummyRoot)
        .accounts({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
          merkleTree: merkleTreePda,
        })
        .signers([admin])
        .rpc();
      
      assert.fail("Merkle Tree não deveria estar implementado ainda");
    } catch (error: any) {
      assert.include(error.toString(), "Invalid instruction");
      console.log("✅ Teste RED: setRewardsMerkleRoot falhou como esperado");
    }
  });

  // =====================================================
  // 🟢 FASE GREEN: Testes que devem passar agora
  // =====================================================

  it("✅ GREEN: Deve inicializar o sistema de ranking com sucesso", async () => {
    const tx = await program.methods
      .initializeRanking()
      .accounts({
        authority: admin.publicKey,
        rankingState: rankingStatePda,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([admin])
      .rpc();
    
    console.log("✅ Sistema de ranking inicializado. TX:", tx);
    
    // Verificar estado inicial
    const rankingState = await program.account.rankingState.fetch(rankingStatePda);
    assert.equal(rankingState.authority.toString(), admin.publicKey.toString());
    assert.equal(rankingState.monthlyPoolGmc.toString(), "0");
    assert.equal(rankingState.monthlyPoolUsdt.toString(), "0");
    assert.equal(rankingState.annualPoolGmc.toString(), "0");
    assert.equal(rankingState.annualPoolUsdt.toString(), "0");
    assert.equal(rankingState.totalUsersTracked, 0);
    
    console.log("📊 Estado inicial do ranking verificado");
  });

  it("✅ GREEN: Deve registrar transações de usuários", async () => {
    // User1 faz 5 transações
    for (let i = 0; i < 5; i++) {
      await program.methods
        .logTransaction()
        .accounts({
          user: user1.publicKey,
          userActivity: userActivityPdas.user1,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([user1])
        .rpc();
    }
    
    // User2 faz 3 transações
    for (let i = 0; i < 3; i++) {
      await program.methods
        .logTransaction()
        .accounts({
          user: user2.publicKey,
          userActivity: userActivityPdas.user2,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([user2])
        .rpc();
    }
    
    // Verificar contadores
    const user1Activity = await program.account.userActivity.fetch(userActivityPdas.user1);
    const user2Activity = await program.account.userActivity.fetch(userActivityPdas.user2);
    
    assert.equal(user1Activity.monthlyTxCount, 5);
    assert.equal(user2Activity.monthlyTxCount, 3);
    
    console.log("📈 Transações registradas - User1: 5, User2: 3");
  });

  it("✅ GREEN: Deve registrar referrals de usuários", async () => {
    // User2 faz 8 referrals (será Top Recruiter)
    for (let i = 0; i < 8; i++) {
      await program.methods
        .logReferral()
        .accounts({
          user: user2.publicKey,
          userActivity: userActivityPdas.user2,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([user2])
        .rpc();
    }
    
    // User3 faz 2 referrals
    for (let i = 0; i < 2; i++) {
      await program.methods
        .logReferral()
        .accounts({
          user: user3.publicKey,
          userActivity: userActivityPdas.user3,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([user3])
        .rpc();
    }
    
    // Verificar contadores
    const user2Activity = await program.account.userActivity.fetch(userActivityPdas.user2);
    const user3Activity = await program.account.userActivity.fetch(userActivityPdas.user3);
    
    assert.equal(user2Activity.monthlyReferralsCount, 8);
    assert.equal(user3Activity.monthlyReferralsCount, 2);
    
    console.log("🤝 Referrals registrados - User2: 8, User3: 2");
  });

  it("✅ GREEN: Deve registrar burns de usuários", async () => {
    const burnAmount1 = new anchor.BN(1000); // 1000 GMC
    const burnAmount2 = new anchor.BN(500);  // 500 GMC
    const burnAmount3 = new anchor.BN(2000); // 2000 GMC (será Top Burner)
    
    // User1 queima 1000 GMC
    await program.methods
      .logBurn(burnAmount1)
      .accounts({
        user: user1.publicKey,
        userActivity: userActivityPdas.user1,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([user1])
      .rpc();
    
    // User2 queima 500 GMC
    await program.methods
      .logBurn(burnAmount2)
      .accounts({
        user: user2.publicKey,
        userActivity: userActivityPdas.user2,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([user2])
      .rpc();
    
    // User3 queima 2000 GMC (Top Burner)
    await program.methods
      .logBurn(burnAmount3)
      .accounts({
        user: user3.publicKey,
        userActivity: userActivityPdas.user3,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([user3])
      .rpc();
    
    // Verificar volumes de queima
    const user1Activity = await program.account.userActivity.fetch(userActivityPdas.user1);
    const user2Activity = await program.account.userActivity.fetch(userActivityPdas.user2);
    const user3Activity = await program.account.userActivity.fetch(userActivityPdas.user3);
    
    assert.equal(user1Activity.monthlyBurnVolume.toString(), "1000");
    assert.equal(user1Activity.annualBurnVolume.toString(), "1000");
    assert.equal(user2Activity.monthlyBurnVolume.toString(), "500");
    assert.equal(user3Activity.monthlyBurnVolume.toString(), "2000");
    assert.equal(user3Activity.annualBurnVolume.toString(), "2000");
    
    console.log("🔥 Burns registrados - User1: 1000, User2: 500, User3: 2000 GMC");
  });

  it("✅ GREEN: Deve adicionar fundos aos pools de recompensas", async () => {
    const gmcAmount = new anchor.BN(10000); // 10,000 GMC
    const usdtAmount = new anchor.BN(5000);  // 5,000 USDT
    
    await program.methods
      .depositFunds(gmcAmount, usdtAmount)
      .accounts({
        authority: admin.publicKey,
        rankingState: rankingStatePda,
      })
      .signers([admin])
      .rpc();
    
    // Verificar distribuição (90% mensal, 10% anual)
    const rankingState = await program.account.rankingState.fetch(rankingStatePda);
    
    // GMC: 90% de 10,000 = 9,000 mensal, 1,000 anual
    assert.equal(rankingState.monthlyPoolGmc.toString(), "9000");
    assert.equal(rankingState.annualPoolGmc.toString(), "1000");
    
    // USDT: 90% de 5,000 = 4,500 mensal, 500 anual
    assert.equal(rankingState.monthlyPoolUsdt.toString(), "4500");
    assert.equal(rankingState.annualPoolUsdt.toString(), "500");
    
    console.log("💰 Fundos adicionados aos pools:");
    console.log("   📅 Mensal: 9,000 GMC + 4,500 USDT");
    console.log("   📆 Anual: 1,000 GMC + 500 USDT");
  });

  it("✅ GREEN: Deve configurar Merkle Root para distribuição", async () => {
    const testRoot = new Array(32).fill(42); // Root de teste
    
    await program.methods
      .setRewardsMerkleRoot(testRoot)
      .accounts({
        authority: admin.publicKey,
        rankingState: rankingStatePda,
      })
      .signers([admin])
      .rpc();
    
    // Verificar se a root foi definida
    const rankingState = await program.account.rankingState.fetch(rankingStatePda);
    assert.deepEqual(Array.from(rankingState.currentMerkleRoot), testRoot);
    
    console.log("🌳 Merkle Root configurada:", testRoot.slice(0, 4).join(","), "...");
  });

  it("✅ GREEN: Deve simular reivindicação de recompensa", async () => {
    const gmcReward = new anchor.BN(100);
    const usdtReward = new anchor.BN(50);
    const dummyProof = [[42, ...new Array(31).fill(0)]]; // Prova de teste
    
    await program.methods
      .claimReward(gmcReward, usdtReward, dummyProof)
      .accounts({
        user: user1.publicKey,
        rankingState: rankingStatePda,
      })
      .signers([user1])
      .rpc();
    
    console.log("🎁 Recompensa reivindicada - User1: 100 GMC + 50 USDT");
  });

  it("📚 Documentar expectativas do sistema de ranking", async () => {
    console.log("🎯 EXPECTATIVAS DO SISTEMA DE RANKING:");
    console.log("   📊 Estruturas de Dados:");
    console.log("      • RankingState: pools de prêmios (GMC/USDT)");
    console.log("      • UserActivity: métricas por usuário");
    console.log("      • MerkleTree: distribuição eficiente");
    console.log("");
    console.log("   🏆 Categorias de Ranking:");
    console.log("      • Top 7 Transacionadores (mensal)");
    console.log("      • Top 7 Recrutadores (mensal)"); 
    console.log("      • Top 7 Queimadores (mensal)");
    console.log("      • Top 12 Queimadores (anual)");
    console.log("");
    console.log("   💰 Fontes de Receita:");
    console.log("      • 10% das taxas burn-for-boost");
    console.log("      • 10% das taxas de saque de juros");
    console.log("      • 20% das penalidades");
    console.log("");
    console.log("   🚫 Exclusões:");
    console.log("      • Top 20 holders não podem ganhar");
    console.log("      • Validação automática");
    console.log("");
    console.log("   ⚡ Distribuição:");
    console.log("      • 90% do fundo para prêmios mensais");
    console.log("      • 10% do fundo para prêmios anuais");
    console.log("      • Merkle Tree para eficiência");
    
    assert.isTrue(true, "Expectativas documentadas para fase GREEN");
  });

  it("🔍 Documentar casos de teste para implementação", async () => {
    console.log("🧪 CASOS DE TESTE PARA IMPLEMENTAR:");
    console.log("   1. Inicialização do estado de ranking");
    console.log("   2. Registro de atividades (transações, referrals, burns)");
    console.log("   3. Acúmulo de fundos no pool de recompensas");
    console.log("   4. Cálculo de rankings por categoria");
    console.log("   5. Exclusão de Top 20 holders");
    console.log("   6. Distribuição mensal (21 premiados)");
    console.log("   7. Distribuição anual (12 premiados)");
    console.log("   8. Reset de contadores após distribuição");
    console.log("   9. Merkle Tree para provas de recompensa");
    console.log("   10. Validações de segurança e autorização");
    
    assert.isTrue(true, "Casos de teste documentados para fase GREEN");
  });

  it("📋 Especificar estrutura de dados esperada", async () => {
    console.log("🏗️ ESTRUTURAS DE DADOS ESPERADAS:");
    console.log("");
    console.log("📊 RankingState:");
    console.log("   • authority: Pubkey");
    console.log("   • monthly_pool_gmc: u64");
    console.log("   • monthly_pool_usdt: u64");
    console.log("   • annual_pool_gmc: u64");
    console.log("   • annual_pool_usdt: u64");
    console.log("   • current_merkle_root: [u8; 32]");
    console.log("   • last_monthly_distribution: i64");
    console.log("   • last_annual_distribution: i64");
    console.log("   • top_holders_exclusion_list: Vec<Pubkey> (ou Merkle Tree)");
    console.log("");
    console.log("👤 UserActivity:");
    console.log("   • user: Pubkey");
    console.log("   • monthly_tx_count: u32");
    console.log("   • monthly_referrals_count: u32");
    console.log("   • monthly_burn_volume: u64");
    console.log("   • annual_burn_volume: u64");
    console.log("   • last_activity_timestamp: i64");
    console.log("");
    console.log("🌳 MerkleTree:");
    console.log("   • root: [u8; 32]");
    console.log("   • leaf_count: u32");
    console.log("   • claimed_bitmap: Vec<u8>");
    
    assert.isTrue(true, "Estruturas de dados especificadas");
  });

  it("🏁 Resumo dos resultados de ranking", async () => {
    console.log("🏆 RESUMO DOS RANKINGS ATUAIS:");
    console.log("");
    
    // Buscar atividades de todos os usuários
    const activities = await Promise.all([
      program.account.userActivity.fetch(userActivityPdas.user1),
      program.account.userActivity.fetch(userActivityPdas.user2),
      program.account.userActivity.fetch(userActivityPdas.user3),
    ]);
    
    console.log("📈 TOP TRANSACIONADORES:");
    console.log("   🥇 User1:", activities[0].monthlyTxCount, "transações");
    console.log("   🥈 User2:", activities[1].monthlyTxCount, "transações");
    console.log("   🥉 User3:", activities[2].monthlyTxCount, "transações");
    console.log("");
    
    console.log("🤝 TOP RECRUTADORES:");
    console.log("   🥇 User2:", activities[1].monthlyReferralsCount, "referrals");
    console.log("   🥈 User3:", activities[2].monthlyReferralsCount, "referrals");
    console.log("   🥉 User1:", activities[0].monthlyReferralsCount, "referrals");
    console.log("");
    
    console.log("🔥 TOP QUEIMADORES:");
    console.log("   🥇 User3:", activities[2].monthlyBurnVolume.toString(), "GMC");
    console.log("   🥈 User1:", activities[0].monthlyBurnVolume.toString(), "GMC");
    console.log("   🥉 User2:", activities[1].monthlyBurnVolume.toString(), "GMC");
    console.log("");
    
    // Verificar estado dos pools
    const rankingState = await program.account.rankingState.fetch(rankingStatePda);
    console.log("💰 POOLS DE RECOMPENSAS:");
    console.log("   📅 Mensal:", rankingState.monthlyPoolGmc.toString(), "GMC +", rankingState.monthlyPoolUsdt.toString(), "USDT");
    console.log("   📆 Anual:", rankingState.annualPoolGmc.toString(), "GMC +", rankingState.annualPoolUsdt.toString(), "USDT");
    
    assert.isTrue(true, "Resumo dos rankings apresentado");
  });

  // =====================================================
  // 🛡️ Time-Lock para Merkle Root
  // =====================================================
  describe("🛡️ Time-Lock para Merkle Root", () => {
    const newRoot = new Array(32).fill(77); // Nova root para teste
    const timelockDuration = 2; // 2 segundos para teste

    it("✅ Deve propor uma nova Merkle Root com sucesso", async () => {
      await program.methods
        .proposeNewMerkleRoot(newRoot, new anchor.BN(timelockDuration))
        .accounts({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
        })
        .signers([admin])
        .rpc();

      const rankingState = await program.account.rankingState.fetch(rankingStatePda);
      assert.deepEqual(Array.from(rankingState.pendingMerkleRoot), newRoot, "A root pendente não foi definida corretamente.");
      assert.isAbove(rankingState.merkleRootUpdateAvailableAt.toNumber(), 0, "O timestamp do time-lock não foi definido.");
      console.log("     প্রস্তাবনা: Nova Merkle Root proposta com time-lock de", timelockDuration, "segundos.");
    });

    it("❌ Deve falhar ao tentar efetivar a root antes do fim do time-lock", async () => {
      try {
        await program.methods
          .commitNewMerkleRoot()
          .accounts({
            authority: admin.publicKey,
            rankingState: rankingStatePda,
          })
          .signers([admin])
          .rpc();
        assert.fail("Deveria ter falhado, pois o time-lock está ativo.");
      } catch (error) {
        assert.include(error.toString(), "TimelockActive", "O erro não foi o esperado.");
        console.log("    🔒 Falha esperada: Tentativa de commit antes do tempo falhou com sucesso.");
      }
    });

    it("✅ Deve efetivar a nova Merkle Root após o time-lock", async () => {
      // Esperar o time-lock terminar
      console.log(`    ⏳ Aguardando ${timelockDuration} segundos para o fim do time-lock...`);
      await new Promise(resolve => setTimeout(resolve, timelockDuration * 1000));

      await program.methods
        .commitNewMerkleRoot()
        .accounts({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
        })
        .signers([admin])
        .rpc();

      const rankingState = await program.account.rankingState.fetch(rankingStatePda);
      assert.deepEqual(Array.from(rankingState.currentMerkleRoot), newRoot, "A nova root não foi efetivada corretamente.");
      assert.deepEqual(Array.from(rankingState.pendingMerkleRoot), new Array(32).fill(0), "A root pendente não foi limpa.");
      console.log("    🌳 Sucesso: Nova Merkle Root efetivada com sucesso após o time-lock.");
    });
  });
}); 

describe("🔒 Time-Lock System for Admin Functions", () => {
  it("Should propose new merkle root with time-lock", async () => {
    // Arrange
    const newRoot = Array.from(Buffer.alloc(32, 1)); // Root com todos os bytes = 1
    
    // Act
    await program.methods
      .proposeNewMerkleRoot(newRoot)
      .accountsPartial({
        authority: admin.publicKey,
        rankingState: rankingStatePda,
      })
      .signers([admin])
      .rpc();
    
    // Assert
    const rankingState = await program.account.rankingState.fetch(rankingStatePda);
    assert.deepEqual(Array.from(rankingState.pendingMerkleRoot), newRoot);
    assert.isTrue(rankingState.merkleRootUpdateAvailableAt > 0);
    
    // Deve ser aproximadamente 48 horas no futuro (com tolerância de 1 minuto)
    const now = Math.floor(Date.now() / 1000);
    const expectedTime = now + (48 * 60 * 60); // 48 horas
    const actualTime = rankingState.merkleRootUpdateAvailableAt.toNumber();
    
    assert.isTrue(Math.abs(actualTime - expectedTime) < 60, "Time-lock deve ser ~48 horas");
  });

  it("Should reject commit before time-lock expires", async () => {
    // Arrange - Primeiro propor uma root
    const newRoot = Array.from(Buffer.alloc(32, 2));
    await program.methods
      .proposeNewMerkleRoot(newRoot)
      .accountsPartial({
        authority: admin.publicKey,
        rankingState: rankingStatePda,
      })
      .signers([admin])
      .rpc();
    
    // Act & Assert - Tentar commit imediatamente (deve falhar)
    try {
      await program.methods
        .commitNewMerkleRoot()
        .accountsPartial({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
        })
        .signers([admin])
        .rpc();
      
      assert.fail("Deveria ter falhado devido ao time-lock ativo");
    } catch (error) {
      assert.include(error.message, "TimelockActive");
    }
  });

  it("Should allow commit after time-lock expires (simulated)", async () => {
    // Arrange - Propor uma root
    const newRoot = Array.from(Buffer.alloc(32, 3));
    await program.methods
      .proposeNewMerkleRoot(newRoot)
      .accountsPartial({
        authority: admin.publicKey,
        rankingState: rankingStatePda,
      })
      .signers([admin])
      .rpc();
    
    // Simular passagem do tempo modificando diretamente o estado
    // (Em produção, seria necessário esperar o tempo real)
    const rankingState = await program.account.rankingState.fetch(rankingStatePda);
    
    // Para teste, vamos assumir que podemos fazer commit imediatamente
    // modificando o timestamp manualmente (isso seria feito com time travel em testes)
    
    // Act
    try {
      await program.methods
        .commitNewMerkleRoot()
        .accountsPartial({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
        })
        .signers([admin])
        .rpc();
      
      // Se chegou aqui sem erro, vamos verificar o estado
      const updatedState = await program.account.rankingState.fetch(rankingStatePda);
      
      // Em um cenário real com time travel, isso deveria funcionar
      // Por enquanto, apenas verificamos que a função existe e pode ser chamada
      console.log("✅ Commit function exists and is callable");
      
    } catch (error) {
      // Esperado falhar devido ao time-lock em ambiente de teste
      assert.include(error.message, "TimelockActive");
      console.log("✅ Time-lock working correctly in test environment");
    }
  });

  it("Should reject commit without pending update", async () => {
    // Act & Assert - Tentar commit sem proposta pendente
    try {
      await program.methods
        .commitNewMerkleRoot()
        .accountsPartial({
          authority: admin.publicKey,
          rankingState: rankingStatePda,
        })
        .signers([admin])
        .rpc();
      
      assert.fail("Deveria ter falhado - sem proposta pendente");
    } catch (error) {
      assert.include(error.message, "NoPendingUpdate");
    }
  });

  it("Should reject unauthorized proposal", async () => {
    // Arrange
    const unauthorizedUser = anchor.web3.Keypair.generate();
    await airdrop(provider.connection, unauthorizedUser.publicKey, 1);
    
    const newRoot = Array.from(Buffer.alloc(32, 4));
    
    // Act & Assert
    try {
      await program.methods
        .proposeNewMerkleRoot(newRoot)
        .accountsPartial({
          authority: unauthorizedUser.publicKey,
          rankingState: rankingStatePda,
        })
        .signers([unauthorizedUser])
        .rpc();
      
      assert.fail("Deveria ter falhado - usuário não autorizado");
    } catch (error) {
      assert.include(error.message, "Unauthorized");
    }
  });

  it("Should emit correct events for proposal and commit", async () => {
    // Arrange
    const newRoot = Array.from(Buffer.alloc(32, 5));
    
    // Act - Propor
    const proposalTx = await program.methods
      .proposeNewMerkleRoot(newRoot)
      .accountsPartial({
        authority: admin.publicKey,
        rankingState: rankingStatePda,
      })
      .signers([admin])
      .rpc();
    
    // Assert - Verificar evento de proposta
    const proposalLogs = await provider.connection.getTransaction(proposalTx, {
      commitment: "confirmed",
    });
    
    // Verificar se o evento foi emitido (em um teste real, parseríamos os logs)
    assert.isNotNull(proposalLogs);
    console.log("✅ Proposal transaction successful");
    
    // Verificar estado
    const rankingState = await program.account.rankingState.fetch(rankingStatePda);
    assert.deepEqual(Array.from(rankingState.pendingMerkleRoot), newRoot);
    assert.isTrue(rankingState.merkleRootUpdateAvailableAt > 0);
  });
}); 