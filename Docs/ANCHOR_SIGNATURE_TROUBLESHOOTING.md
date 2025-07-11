# 🔐 Resolução de Problemas de Assinatura - GMC Ecosystem

## 📋 Resumo Executivo

**Problema:** "Signature verification failed. Missing signature for public key [...]"  
**Contexto:** Testes Anchor no GMC Ecosystem  
**Causa Principal:** Contas que deveriam assinar não estão assinando a transação  

---

## 🎯 **Diagnóstico do Problema**

### **Erro Típico:**
```bash
Error: Signature verification failed. Missing signature for public key [ABC123...]
```

### **Principais Causas no GMC Ecosystem:**

| Causa | Explicação | Impacto |
|-------|------------|---------|
| **Conta esperada como signer, mas só passou PublicKey** | O Anchor espera `Signer` mas recebeu apenas `PublicKey` | ❌ Crítico |
| **Signer não incluído na lista de signers** | `Keypair` existe mas não foi adicionado em `.signers([])` | ❌ Crítico |
| **Provider/carteira mal configurados** | `AnchorProvider` não está configurado para assinar | ❌ Crítico |
| **PDA marcado incorretamente como signer** | PDAs não podem assinar transações | ❌ Crítico |
| **Authority/Admin não configurado** | Funções admin sem signer apropriado | ❌ Crítico |

---

## 🔧 **Soluções Específicas para GMC Ecosystem**

### **1. Correção para Testes de Token (GMC Token Contract)**

#### ❌ **Problema Comum:**
```typescript
// ERRO: Apenas PublicKey, sem capacidade de assinar
const authority = new anchor.web3.PublicKey("ABC123...");

await program.methods
  .initialize()
  .accounts({
    authority: authority, // ❌ Não pode assinar
  })
  .rpc();
```

#### ✅ **Solução Correta:**
```typescript
// ✅ CORRETO: Usar Keypair para poder assinar
const authority = anchor.web3.Keypair.generate();

// Airdrop para ter SOL para taxas
await provider.connection.requestAirdrop(
  authority.publicKey, 
  10 * anchor.web3.LAMPORTS_PER_SOL
);

await program.methods
  .initialize()
  .accounts({
    authority: authority.publicKey,
    payer: authority.publicKey,
  })
  .signers([authority]) // ✅ Incluir o keypair como signer
  .rpc();
```

### **2. Correção para Testes de Staking**

#### ❌ **Problema Comum:**
```typescript
// ERRO: User como PublicKey apenas
const user = provider.wallet.publicKey;

await stakingProgram.methods
  .stakeLongTerm(new anchor.BN(1000))
  .accounts({
    user: user, // ❌ Se marcado como signer no Rust, falhará
    userStakeInfo: userStakeInfoPda,
  })
  .rpc();
```

#### ✅ **Solução Correta:**
```typescript
// ✅ CORRETO: Provider wallet já está configurado para assinar
const user = provider.wallet as anchor.Wallet;

await stakingProgram.methods
  .stakeLongTerm(new anchor.BN(1000))
  .accounts({
    user: user.publicKey,
    userStakeInfo: userStakeInfoPda,
  })
  .rpc(); // Provider wallet assina automaticamente

// ✅ OU: Usar keypair específico
const staker = anchor.web3.Keypair.generate();
await provider.connection.requestAirdrop(staker.publicKey, 10 * anchor.web3.LAMPORTS_PER_SOL);

await stakingProgram.methods
  .stakeLongTerm(new anchor.BN(1000))
  .accounts({
    user: staker.publicKey,
    userStakeInfo: userStakeInfoPda,
  })
  .signers([staker])
  .rpc();
```

### **3. Correção para Testes de Ranking (Merkle Tree)**

#### ❌ **Problema Comum:**
```typescript
// ERRO: Admin não configurado corretamente
const admin = new anchor.web3.PublicKey("DEF456...");

await rankingProgram.methods
  .setRewardsMerkleRoot(rootArray)
  .accounts({
    authority: admin, // ❌ Não pode assinar
    rankingState: rankingStatePda,
  })
  .rpc();
```

#### ✅ **Solução Correta:**
```typescript
// ✅ CORRETO: Admin como Keypair
const admin = anchor.web3.Keypair.generate();

// Airdrop para admin
await provider.connection.requestAirdrop(
  admin.publicKey, 
  10 * anchor.web3.LAMPORTS_PER_SOL
);

await rankingProgram.methods
  .setRewardsMerkleRoot(rootArray)
  .accounts({
    authority: admin.publicKey,
    rankingState: rankingStatePda,
  })
  .signers([admin]) // ✅ Admin assina a transação
  .rpc();
```

### **4. Correção para Testes de Vesting**

#### ❌ **Problema Comum:**
```typescript
// ERRO: Beneficiary sem capacidade de assinar
await vestingProgram.methods
  .release()
  .accounts({
    beneficiary: beneficiaryPubkey, // ❌ Se precisa assinar, falhará
    vestingSchedule: schedulePda,
  })
  .rpc();
```

#### ✅ **Solução Correta:**
```typescript
// ✅ CORRETO: Beneficiary como signer
const beneficiary = anchor.web3.Keypair.generate();

await vestingProgram.methods
  .release()
  .accounts({
    beneficiary: beneficiary.publicKey,
    vestingSchedule: schedulePda,
  })
  .signers([beneficiary]) // ✅ Beneficiary assina
  .rpc();
```

---

## 🏗️ **Padrões Corretos para Contratos GMC**

### **1. Setup Padrão de Teste**

```typescript
describe("GMC Contract Tests", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  
  const program = anchor.workspace.GmcStaking as Program<GmcStaking>;
  
  // ✅ Keypairs para entidades que precisam assinar
  const admin = anchor.web3.Keypair.generate();
  const user1 = anchor.web3.Keypair.generate();
  const user2 = anchor.web3.Keypair.generate();
  
  before(async () => {
    // ✅ Airdrop para todos os signers
    const airdrops = [admin, user1, user2].map(keypair =>
      provider.connection.requestAirdrop(
        keypair.publicKey,
        10 * anchor.web3.LAMPORTS_PER_SOL
      )
    );
    await Promise.all(airdrops);
  });
});
```

### **2. Padrão para Funções Admin**

```typescript
// ✅ Função admin com signer correto
it("Admin can initialize contract", async () => {
  await program.methods
    .initialize()
    .accounts({
      authority: admin.publicKey,
      globalState: globalStatePda,
      systemProgram: anchor.web3.SystemProgram.programId,
    })
    .signers([admin]) // ✅ Admin assina
    .rpc();
});
```

### **3. Padrão para Funções de Usuário**

```typescript
// ✅ Função de usuário com signer correto
it("User can stake tokens", async () => {
  await program.methods
    .stakeLongTerm(new anchor.BN(1000))
    .accounts({
      user: user1.publicKey,
      userStakeInfo: userStakeInfoPda,
      stakePosition: stakePositionPda,
    })
    .signers([user1]) // ✅ User assina
    .rpc();
});
```

### **4. Padrão para PDAs (Não Assinam)**

```typescript
// ✅ PDAs não precisam assinar
const [userStakeInfoPda] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("user_stake_info"), user1.publicKey.toBuffer()],
  program.programId
);

// ✅ PDA usado sem signer
await program.methods
  .someMethod()
  .accounts({
    userStakeInfo: userStakeInfoPda, // ✅ PDA não assina
    user: user1.publicKey,
  })
  .signers([user1]) // ✅ Apenas user assina
  .rpc();
```

---

## 🚨 **Verificações de Segurança no Rust**

### **1. Contas que DEVEM ser Signers:**

```rust
#[derive(Accounts)]
pub struct InitializeContract<'info> {
    #[account(mut)]
    pub authority: Signer<'info>, // ✅ DEVE assinar
    
    #[account(
        init,
        payer = authority,
        space = 8 + GlobalState::LEN,
        seeds = [b"global_state"],
        bump
    )]
    pub global_state: Account<'info, GlobalState>, // ✅ PDA - NÃO assina
}
```

### **2. Contas que NÃO devem ser Signers:**

```rust
#[derive(Accounts)]
pub struct StakeLongTerm<'info> {
    #[account(mut)]
    pub user: Signer<'info>, // ✅ User DEVE assinar
    
    #[account(
        init_if_needed,
        payer = user,
        space = 8 + UserStakeInfo::LEN,
        seeds = [b"user_stake_info", user.key().as_ref()],
        bump
    )]
    pub user_stake_info: Account<'info, UserStakeInfo>, // ✅ PDA - NÃO assina
}
```

---

## 🔍 **Debugging de Problemas de Assinatura**

### **1. Verificar Logs Detalhados**

```typescript
// ✅ Adicionar logs para debug
console.log("Signers:", [admin.publicKey.toString()]);
console.log("Accounts:", {
  authority: admin.publicKey.toString(),
  globalState: globalStatePda.toString(),
});

try {
  await program.methods
    .initialize()
    .accounts({
      authority: admin.publicKey,
      globalState: globalStatePda,
    })
    .signers([admin])
    .rpc();
} catch (error) {
  console.error("Transaction failed:", error);
  console.error("Error logs:", error.logs);
}
```

### **2. Verificar Configuração do Provider**

```typescript
// ✅ Verificar se provider está correto
console.log("Provider wallet:", provider.wallet.publicKey.toString());
console.log("Connection endpoint:", provider.connection.rpcEndpoint);

// ✅ Verificar se wallet tem SOL
const balance = await provider.connection.getBalance(provider.wallet.publicKey);
console.log("Wallet balance:", balance / anchor.web3.LAMPORTS_PER_SOL, "SOL");
```

### **3. Verificar se Accounts Existem**

```typescript
// ✅ Verificar se contas existem antes de usar
const accountInfo = await provider.connection.getAccountInfo(somePda);
if (!accountInfo) {
  console.log("Account does not exist, needs to be initialized");
}
```

---

## 🛠️ **Script de Verificação de Assinatura**

Vou criar um script para ajudar a diagnosticar problemas de assinatura:

```typescript
// scripts/check_signature_setup.ts
import * as anchor from "@coral-xyz/anchor";

export async function checkSignatureSetup() {
  const provider = anchor.AnchorProvider.env();
  
  console.log("🔍 Verificando configuração de assinatura...");
  
  // 1. Verificar provider
  console.log("Provider wallet:", provider.wallet.publicKey.toString());
  
  // 2. Verificar saldo
  const balance = await provider.connection.getBalance(provider.wallet.publicKey);
  console.log("Saldo da wallet:", balance / anchor.web3.LAMPORTS_PER_SOL, "SOL");
  
  if (balance < anchor.web3.LAMPORTS_PER_SOL) {
    console.warn("⚠️ Saldo baixo! Faça airdrop:");
    console.log(`solana airdrop 10 ${provider.wallet.publicKey.toString()}`);
  }
  
  // 3. Verificar conexão
  try {
    const slot = await provider.connection.getSlot();
    console.log("✅ Conexão OK, slot atual:", slot);
  } catch (error) {
    console.error("❌ Problema de conexão:", error);
  }
  
  // 4. Verificar se pode assinar
  try {
    const message = new anchor.web3.Transaction();
    message.add(
      anchor.web3.SystemProgram.transfer({
        fromPubkey: provider.wallet.publicKey,
        toPubkey: provider.wallet.publicKey,
        lamports: 0,
      })
    );
    
    const signed = await provider.wallet.signTransaction(message);
    console.log("✅ Wallet pode assinar transações");
  } catch (error) {
    console.error("❌ Problema ao assinar:", error);
  }
}
```

---

## 📚 **Recursos Adicionais**

### **Documentação Relacionada:**
- [`LINTER_GHOST_SOLUTION.md`](./LINTER_GHOST_SOLUTION.md) - Problemas de TypeScript
- [`COMPILATION_ANALYSIS.md`](./COMPILATION_ANALYSIS.md) - Problemas de compilação
- [`SECURITY_AUDIT_PREPARATION.md`](./SECURITY_AUDIT_PREPARATION.md) - Checklist de segurança

### **Links Úteis:**
- [Anchor Signer Documentation](https://www.anchor-lang.com/docs/account-constraints#signer)
- [Solana Web3.js Keypair](https://solana-labs.github.io/solana-web3.js/classes/Keypair.html)
- [Anchor Provider Setup](https://www.anchor-lang.com/docs/anchor-provider)

---

## ✅ **Checklist de Resolução**

### **Antes de Reportar Problemas:**
- [ ] Verifiquei se todas as contas `Signer` no Rust têm `Keypair` correspondente no teste?
- [ ] Incluí todos os `Keypair`s necessários em `.signers([])`?
- [ ] Verifiquei se PDAs não estão marcados como `Signer`?
- [ ] Confirmo que o provider está configurado corretamente?
- [ ] As contas têm saldo suficiente para pagar taxas?

### **Para Novos Testes:**
- [ ] Setup do provider configurado (`anchor.AnchorProvider.env()`)
- [ ] Keypairs gerados para entidades que precisam assinar
- [ ] Airdrop realizado para todas as contas que precisam de SOL
- [ ] Verificação de logs habilitada para debugging
- [ ] Testes isolados (cada teste limpa seu estado)

---

## 🚀 **Scripts e Ferramentas de Diagnóstico**

### **Scripts NPM Disponíveis:**

```bash
# Verificar configuração de assinatura
npm run check:signature

# Verificar problemas de linter
npm run check:linter

# Executar testes com validador local
npm run test

# Executar testes sem validador (unit tests)
npm run test:unit

# Iniciar validador local para testes
npm run start:validator

# Parar validador local
npm run stop:validator
```

### **Exemplo de Uso dos Scripts:**

```bash
# 1. Verificar se ambiente está configurado corretamente
npm run check:signature

# 2. Se houver problemas, iniciar validador local
npm run start:validator

# 3. Em outro terminal, executar testes
npm run test

# 4. Ou executar apenas testes unitários
npm run test:unit
```

### **Arquivo de Exemplo Prático:**

O arquivo `tests/signature_example.test.ts` contém exemplos práticos de:
- ❌ Problemas comuns e suas causas
- ✅ Soluções corretas implementadas
- 🔍 Técnicas de debugging
- 📚 Padrões recomendados

Execute para ver os exemplos em ação:
```bash
npx mocha tests/signature_example.test.ts --timeout 30000
```

---

## 🎯 **Resumo**

O erro "Signature verification failed" no GMC Ecosystem é resolvido seguindo estas práticas:

1. ✅ **Use `Keypair` para contas que precisam assinar**
2. ✅ **Inclua todos os signers em `.signers([])`**
3. ✅ **Configure o provider corretamente**
4. ✅ **Nunca marque PDAs como `Signer`**
5. ✅ **Faça airdrop para contas que precisam de SOL**
6. ✅ **Use logs para debugging**
7. ✅ **Execute `npm run check:signature` para diagnóstico automático**
8. ✅ **Consulte `tests/signature_example.test.ts` para exemplos práticos**

Seguindo essas práticas e usando as ferramentas fornecidas, todos os testes do GMC Ecosystem devem funcionar sem problemas de assinatura.

---

**Documento criado em:** Janeiro 2025  
**Versão:** 1.0  
**Status:** Guia de resolução - Pronto para uso  
**Próxima Revisão:** Conforme necessário 