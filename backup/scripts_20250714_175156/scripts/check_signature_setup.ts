import * as anchor from "@coral-xyz/anchor";

/**
 * 🔍 Script de Verificação de Configuração de Assinatura
 * 
 * Este script ajuda a diagnosticar problemas comuns de assinatura
 * no GMC Ecosystem, verificando:
 * - Configuração do provider
 * - Saldos das wallets
 * - Conectividade
 * - Capacidade de assinar transações
 */

export async function checkSignatureSetup() {
  console.log("🔍 GMC Ecosystem - Verificação de Configuração de Assinatura");
  console.log("============================================================");
  
  try {
    // 1. Verificar Provider
    console.log("\n📋 1. Verificando Provider...");
    const provider = anchor.AnchorProvider.env();
    console.log("✅ Provider configurado");
    console.log("   Wallet:", provider.wallet.publicKey.toString());
    console.log("   Endpoint:", provider.connection.rpcEndpoint);
    
    // 2. Verificar Saldo da Wallet Principal
    console.log("\n💰 2. Verificando Saldos...");
    const balance = await provider.connection.getBalance(provider.wallet.publicKey);
    const balanceSOL = balance / anchor.web3.LAMPORTS_PER_SOL;
    
    console.log(`   Saldo da wallet principal: ${balanceSOL.toFixed(4)} SOL`);
    
    if (balance < anchor.web3.LAMPORTS_PER_SOL) {
      console.warn("   ⚠️ Saldo baixo! Recomendado fazer airdrop:");
      console.warn(`   solana airdrop 10 ${provider.wallet.publicKey.toString()}`);
    } else {
      console.log("   ✅ Saldo suficiente para testes");
    }
    
    // 3. Verificar Conectividade
    console.log("\n🌐 3. Verificando Conectividade...");
    try {
      const slot = await provider.connection.getSlot();
      const version = await provider.connection.getVersion();
      console.log("   ✅ Conexão estabelecida");
      console.log(`   Slot atual: ${slot}`);
      console.log(`   Versão Solana: ${version["solana-core"]}`);
    } catch (error: any) {
      console.error("   ❌ Problema de conexão:", error.message || error);
      return false;
    }
    
    // 4. Verificar Capacidade de Assinatura
    console.log("\n✍️  4. Verificando Capacidade de Assinatura...");
    try {
      // Criar uma transação simples (transferência de 0 SOL para si mesmo)
      const testTransaction = new anchor.web3.Transaction();
      testTransaction.add(
        anchor.web3.SystemProgram.transfer({
          fromPubkey: provider.wallet.publicKey,
          toPubkey: provider.wallet.publicKey,
          lamports: 0,
        })
      );
      
      // Tentar assinar (não enviar)
      const recentBlockhash = await provider.connection.getRecentBlockhash();
      testTransaction.recentBlockhash = recentBlockhash.blockhash;
      testTransaction.feePayer = provider.wallet.publicKey;
      
      const signed = await provider.wallet.signTransaction(testTransaction);
      console.log("   ✅ Wallet pode assinar transações");
      console.log(`   Assinatura gerada: ${signed.signatures[0].signature ? "✅" : "❌"}`);
    } catch (error: any) {
      console.error("   ❌ Problema ao assinar:", error.message || error);
      return false;
    }
    
    // 5. Verificar Programas GMC
    console.log("\n📦 5. Verificando Programas GMC...");
    const expectedPrograms = [
      "gmc_token",
      "gmc_staking", 
      "gmc_vesting",
      "gmc_ranking",
      "gmc_treasury"
    ];
    
    for (const programName of expectedPrograms) {
      try {
        // Tentar carregar o programa do workspace
        const workspace = anchor.workspace as any;
        const program = workspace[programName];
        if (program && program.programId) {
          console.log(`   ✅ ${programName}: ${program.programId.toString()}`);
        } else {
          console.log(`   ⚠️ ${programName}: Não encontrado no workspace`);
        }
      } catch (error: any) {
        console.log(`   ❌ ${programName}: Erro ao carregar - ${error.message || error}`);
      }
    }
    
    // 6. Teste de Criação de Keypairs
    console.log("\n🔑 6. Testando Criação de Keypairs...");
    try {
      const testKeypairs: anchor.web3.Keypair[] = [];
      for (let i = 0; i < 3; i++) {
        const keypair = anchor.web3.Keypair.generate();
        testKeypairs.push(keypair);
        console.log(`   ✅ Keypair ${i + 1}: ${keypair.publicKey.toString()}`);
      }
      
      // Testar airdrop para um keypair de teste
      console.log("\n💧 7. Testando Airdrop...");
      const testKeypair = testKeypairs[0];
      
      try {
        const airdropSignature = await provider.connection.requestAirdrop(
          testKeypair.publicKey,
          anchor.web3.LAMPORTS_PER_SOL
        );
        
        // Aguardar confirmação
        await provider.connection.confirmTransaction(airdropSignature);
        
        const newBalance = await provider.connection.getBalance(testKeypair.publicKey);
        console.log(`   ✅ Airdrop realizado: ${newBalance / anchor.web3.LAMPORTS_PER_SOL} SOL`);
      } catch (error: any) {
        console.warn(`   ⚠️ Airdrop falhou (normal em mainnet): ${error.message || error}`);
      }
      
    } catch (error: any) {
      console.error("   ❌ Erro ao criar keypairs:", error.message || error);
      return false;
    }
    
    // 8. Resumo Final
    console.log("\n📊 RESUMO DA VERIFICAÇÃO");
    console.log("========================");
    console.log("✅ Provider configurado corretamente");
    console.log("✅ Conectividade estabelecida");
    console.log("✅ Wallet pode assinar transações");
    console.log("✅ Keypairs podem ser gerados");
    
    if (balanceSOL >= 1.0) {
      console.log("✅ Saldo suficiente para testes");
    } else {
      console.log("⚠️ Saldo baixo - considere fazer airdrop");
    }
    
    console.log("\n🎉 CONFIGURAÇÃO DE ASSINATURA OK!");
    console.log("\n📚 Próximos passos:");
    console.log("   • anchor test     # Executar testes");
    console.log("   • anchor build    # Compilar contratos");
    
    return true;
    
  } catch (error: any) {
    console.error("\n❌ ERRO CRÍTICO:", error.message || error);
    console.error("\n🔧 Possíveis soluções:");
    console.error("   • Verificar se Anchor.toml está correto");
    console.error("   • Verificar se solana-test-validator está rodando");
    console.error("   • Verificar variáveis de ambiente (ANCHOR_PROVIDER_URL, ANCHOR_WALLET)");
    console.error("   • Executar: solana config get");
    
    return false;
  }
}

/**
 * Função auxiliar para verificar problemas específicos de assinatura em testes
 */
export async function debugSignatureError(
  programName: string,
  methodName: string,
  accounts: Record<string, anchor.web3.PublicKey>,
  signers: anchor.web3.Keypair[]
) {
  console.log(`🔍 Debugging assinatura para ${programName}.${methodName}`);
  console.log("================================================");
  
  // 1. Verificar contas
  console.log("\n📋 Contas fornecidas:");
  for (const [name, pubkey] of Object.entries(accounts)) {
    console.log(`   ${name}: ${pubkey.toString()}`);
  }
  
  // 2. Verificar signers
  console.log("\n✍️ Signers fornecidos:");
  for (let i = 0; i < signers.length; i++) {
    const signer = signers[i];
    console.log(`   Signer ${i + 1}: ${signer.publicKey.toString()}`);
    
    // Verificar se o signer tem SOL
    const provider = anchor.AnchorProvider.env();
    const balance = await provider.connection.getBalance(signer.publicKey);
    console.log(`   Balance: ${balance / anchor.web3.LAMPORTS_PER_SOL} SOL`);
  }
  
  // 3. Verificar se alguma conta é um signer mas não está na lista
  console.log("\n🔍 Análise de correspondência:");
  const signerPubkeys = signers.map(s => s.publicKey.toString());
  
  for (const [name, pubkey] of Object.entries(accounts)) {
    const isInSigners = signerPubkeys.includes(pubkey.toString());
    if (isInSigners) {
      console.log(`   ✅ ${name} está na lista de signers`);
    } else {
      console.log(`   ⚠️ ${name} NÃO está na lista de signers`);
      console.log(`      Se esta conta precisa assinar, adicione o Keypair em .signers([])`);
    }
  }
  
  // 4. Dicas específicas
  console.log("\n💡 Dicas para resolução:");
  console.log("   • Contas marcadas como Signer<'info> no Rust DEVEM estar em .signers([])");
  console.log("   • PDAs NUNCA devem ser marcados como Signer");
  console.log("   • Use anchor.web3.Keypair.generate() para criar signers de teste");
  console.log("   • Faça airdrop para signers que precisam de SOL");
}

// Executar se chamado diretamente
if (require.main === module) {
  checkSignatureSetup()
    .then((success) => {
      process.exit(success ? 0 : 1);
    })
    .catch((error) => {
      console.error("Erro inesperado:", error);
      process.exit(1);
    });
} 