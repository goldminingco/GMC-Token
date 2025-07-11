import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { assert } from "chai";
import { debugSignatureError } from "../scripts/check_signature_setup";

/**
 * 🔐 Exemplo Prático de Resolução de Problemas de Assinatura
 * 
 * Este arquivo demonstra as práticas corretas para evitar erros
 * de "Signature verification failed" no GMC Ecosystem.
 */

describe("Signature Resolution Examples", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  // ✅ CORRETO: Keypairs para entidades que precisam assinar
  const admin = anchor.web3.Keypair.generate();
  const user1 = anchor.web3.Keypair.generate();
  const user2 = anchor.web3.Keypair.generate();

  before(async () => {
    console.log("🔑 Configurando keypairs para testes...");
    
    // ✅ CORRETO: Airdrop para todos os signers
    const airdropPromises = [admin, user1, user2].map(async (keypair) => {
      try {
        const signature = await provider.connection.requestAirdrop(
          keypair.publicKey,
          10 * anchor.web3.LAMPORTS_PER_SOL
        );
        await provider.connection.confirmTransaction(signature);
        console.log(`   ✅ Airdrop para ${keypair.publicKey.toString().slice(0, 8)}...`);
      } catch (error) {
        console.warn(`   ⚠️ Airdrop falhou para ${keypair.publicKey.toString().slice(0, 8)}...`);
      }
    });

    await Promise.all(airdropPromises);
  });

  describe("❌ Exemplos de Problemas Comuns", () => {
    it("PROBLEMA: Usar PublicKey onde Signer é esperado", async () => {
      // ❌ ERRO: Este padrão causará "Signature verification failed"
      
      // const wrongAuthority = new anchor.web3.PublicKey("11111111111111111111111111111111");
      // 
      // await program.methods
      //   .initialize()
      //   .accounts({
      //     authority: wrongAuthority, // ❌ Não pode assinar!
      //   })
      //   .rpc(); // ❌ Falhará com signature error
      
      console.log("❌ Exemplo de erro: Usar PublicKey sem capacidade de assinar");
      console.log("   Solução: Use anchor.web3.Keypair.generate() em vez de PublicKey");
    });

    it("PROBLEMA: Esquecer de incluir signer na lista", async () => {
      // ❌ ERRO: Ter o Keypair mas não incluir em .signers([])
      
      // const authority = anchor.web3.Keypair.generate();
      // 
      // await program.methods
      //   .initialize()
      //   .accounts({
      //     authority: authority.publicKey,
      //   })
      //   // ❌ .signers([authority]) // Esqueceu de incluir!
      //   .rpc(); // ❌ Falhará com signature error
      
      console.log("❌ Exemplo de erro: Esquecer .signers([keypair])");
      console.log("   Solução: Sempre incluir Keypairs em .signers([])");
    });

    it("PROBLEMA: Marcar PDA como Signer no Rust", async () => {
      // ❌ ERRO: No Rust, marcar PDA como Signer<'info>
      
      // #[derive(Accounts)]
      // pub struct BadExample<'info> {
      //     #[account(mut)]
      //     pub my_pda: Signer<'info>, // ❌ PDAs não podem assinar!
      // }
      
      console.log("❌ Exemplo de erro: PDA marcado como Signer no Rust");
      console.log("   Solução: Use Account<'info, T> para PDAs, nunca Signer<'info>");
    });
  });

  describe("✅ Exemplos de Soluções Corretas", () => {
    it("SOLUÇÃO: Configuração correta de admin signer", async () => {
      // ✅ CORRETO: Admin como Keypair que pode assinar
      console.log("✅ Exemplo correto: Admin signer");
      console.log("   Admin pubkey:", admin.publicKey.toString());
      
      // ✅ Verificar se admin tem saldo
      const balance = await provider.connection.getBalance(admin.publicKey);
      console.log("   Admin balance:", balance / anchor.web3.LAMPORTS_PER_SOL, "SOL");
      
      assert.isTrue(balance > 0, "Admin deve ter SOL para pagar taxas");
    });

    it("SOLUÇÃO: Configuração correta de user signer", async () => {
      // ✅ CORRETO: User como Keypair que pode assinar
      console.log("✅ Exemplo correto: User signer");
      console.log("   User1 pubkey:", user1.publicKey.toString());
      console.log("   User2 pubkey:", user2.publicKey.toString());
      
      // ✅ Verificar se users têm saldo
      const balance1 = await provider.connection.getBalance(user1.publicKey);
      const balance2 = await provider.connection.getBalance(user2.publicKey);
      
      console.log("   User1 balance:", balance1 / anchor.web3.LAMPORTS_PER_SOL, "SOL");
      console.log("   User2 balance:", balance2 / anchor.web3.LAMPORTS_PER_SOL, "SOL");
      
      assert.isTrue(balance1 > 0, "User1 deve ter SOL");
      assert.isTrue(balance2 > 0, "User2 deve ter SOL");
    });

    it("SOLUÇÃO: Configuração correta de PDA (não assina)", async () => {
      // ✅ CORRETO: PDA derivado corretamente
      const [userStatePda, bump] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("user_state"), user1.publicKey.toBuffer()],
        new anchor.web3.PublicKey("11111111111111111111111111111111") // Program ID de exemplo
      );
      
      console.log("✅ Exemplo correto: PDA não assina");
      console.log("   PDA:", userStatePda.toString());
      console.log("   Bump:", bump);
      
      // ✅ PDA não precisa estar em .signers([])
      // ✅ No Rust seria: pub user_state: Account<'info, UserState>
      
      assert.isDefined(userStatePda, "PDA deve ser derivado corretamente");
    });

    it("SOLUÇÃO: Padrão completo de transação com signers", async () => {
      // ✅ EXEMPLO COMPLETO: Como estruturar uma transação corretamente
      
      console.log("✅ Exemplo completo: Transação com múltiplos signers");
      
      // 1. ✅ Definir signers necessários
      const authority = admin; // Quem tem permissão admin
      const payer = user1;     // Quem paga as taxas
      const receiver = user2;  // Destinatário (não precisa assinar)
      
      // 2. ✅ Derivar PDAs (não assinam)
      const [configPda] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("config")],
        new anchor.web3.PublicKey("11111111111111111111111111111111")
      );
      
      // 3. ✅ Preparar contas para a transação
      const accounts = {
        authority: authority.publicKey,
        payer: payer.publicKey,
        receiver: receiver.publicKey,
        config: configPda, // PDA - não assina
        systemProgram: anchor.web3.SystemProgram.programId,
      };
      
      // 4. ✅ Preparar signers
      const signers = [authority, payer]; // Apenas quem precisa assinar
      
      // 5. ✅ Debug se necessário
      await debugSignatureError(
        "ExampleProgram",
        "exampleMethod",
        accounts,
        signers
      );
      
      console.log("   Accounts configuradas:", Object.keys(accounts).length);
      console.log("   Signers preparados:", signers.length);
      
      // 6. ✅ Estrutura da transação seria:
      // await program.methods
      //   .exampleMethod(params)
      //   .accounts(accounts)
      //   .signers(signers) // ✅ Incluir todos os signers necessários
      //   .rpc();
      
      assert.equal(signers.length, 2, "Deve ter exatamente 2 signers");
    });
  });

  describe("🔍 Debugging e Verificação", () => {
    it("Verificar configuração do provider", async () => {
      console.log("🔍 Verificando configuração do provider...");
      
      // ✅ Provider deve estar configurado
      assert.isDefined(provider, "Provider deve estar definido");
      assert.isDefined(provider.wallet, "Wallet deve estar definida");
      assert.isDefined(provider.connection, "Connection deve estar definida");
      
      console.log("   Provider wallet:", provider.wallet.publicKey.toString());
      console.log("   Connection endpoint:", provider.connection.rpcEndpoint);
      
      // ✅ Verificar se pode obter informações da blockchain
      const slot = await provider.connection.getSlot();
      console.log("   Current slot:", slot);
      
      assert.isNumber(slot, "Deve conseguir obter slot atual");
    });

    it("Verificar capacidade de assinar", async () => {
      console.log("🔍 Verificando capacidade de assinar...");
      
      // ✅ Criar transação de teste
      const testTx = new anchor.web3.Transaction();
      testTx.add(
        anchor.web3.SystemProgram.transfer({
          fromPubkey: user1.publicKey,
          toPubkey: user2.publicKey,
          lamports: 1, // 1 lamport
        })
      );
      
      // ✅ Configurar transação
      const recentBlockhash = await provider.connection.getRecentBlockhash();
      testTx.recentBlockhash = recentBlockhash.blockhash;
      testTx.feePayer = user1.publicKey;
      
      // ✅ Assinar com user1
      testTx.sign(user1);
      
      console.log("   ✅ Transação assinada com sucesso");
      console.log("   Signature:", testTx.signatures[0].signature ? "Present" : "Missing");
      
      assert.isNotNull(testTx.signatures[0].signature, "Assinatura deve estar presente");
    });
  });

  describe("📚 Referências e Dicas", () => {
    it("Documentar padrões recomendados", () => {
      console.log("📚 Padrões recomendados para GMC Ecosystem:");
      console.log("");
      console.log("✅ SEMPRE FAZER:");
      console.log("   • Use anchor.web3.Keypair.generate() para signers");
      console.log("   • Inclua todos os Keypairs em .signers([])");
      console.log("   • Faça airdrop para contas que precisam de SOL");
      console.log("   • Use Account<'info, T> para PDAs no Rust");
      console.log("   • Configure provider corretamente");
      console.log("");
      console.log("❌ NUNCA FAZER:");
      console.log("   • Usar PublicKey onde Signer é esperado");
      console.log("   • Marcar PDAs como Signer<'info> no Rust");
      console.log("   • Esquecer de incluir signers em .signers([])");
      console.log("   • Assumir que contas têm SOL sem verificar");
      console.log("");
      console.log("🔧 PARA DEBUG:");
      console.log("   • Use debugSignatureError() para análise detalhada");
      console.log("   • Verifique logs de transação em caso de erro");
      console.log("   • Execute npm run check:signature para verificação");
    });
  });
}); 