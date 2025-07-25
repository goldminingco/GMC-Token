# 🔐 Resolução Rápida de Problemas de Assinatura - GMC Ecosystem

## 🚨 **Erro: "Signature verification failed"**

### **Diagnóstico Rápido:**

```bash
# 1. Verificar configuração
npm run check:signature

# 2. Se necessário, iniciar validador
npm run start:validator

# 3. Executar testes
npm run test
```

---

## ⚡ **Soluções Rápidas**

### **❌ PROBLEMA: PublicKey sem capacidade de assinar**
```typescript
// ❌ ERRADO
const authority = new anchor.web3.PublicKey("ABC123...");
await program.methods.initialize().accounts({ authority }).rpc();

// ✅ CORRETO  
const authority = anchor.web3.Keypair.generate();
await program.methods.initialize()
  .accounts({ authority: authority.publicKey })
  .signers([authority])
  .rpc();
```

### **❌ PROBLEMA: Esqueceu de incluir signer**
```typescript
// ❌ ERRADO
const user = anchor.web3.Keypair.generate();
await program.methods.stake().accounts({ user: user.publicKey }).rpc();

// ✅ CORRETO
const user = anchor.web3.Keypair.generate();
await program.methods.stake()
  .accounts({ user: user.publicKey })
  .signers([user])  // ← Incluir aqui!
  .rpc();
```

### **❌ PROBLEMA: PDA marcado como Signer no Rust**
```rust
// ❌ ERRADO no Rust
#[account(mut)]
pub my_pda: Signer<'info>,  // PDAs não podem assinar!

// ✅ CORRETO no Rust  
#[account(mut)]
pub my_pda: Account<'info, MyAccount>,
```

### **❌ PROBLEMA: Sem SOL para taxas**
```typescript
// ✅ SEMPRE fazer airdrop para signers
const user = anchor.web3.Keypair.generate();
await provider.connection.requestAirdrop(
  user.publicKey, 
  10 * anchor.web3.LAMPORTS_PER_SOL
);
```

---

## 🔧 **Scripts Úteis**

| Script | Função |
|--------|--------|
| `npm run check:signature` | Diagnóstico automático |
| `npm run start:validator` | Iniciar validador local |
| `npm run test:unit` | Testes sem validador |
| `npm run test` | Testes completos |

---

## 📚 **Recursos Detalhados**

- **Guia Completo:** [`Docs/ANCHOR_SIGNATURE_TROUBLESHOOTING.md`](./Docs/ANCHOR_SIGNATURE_TROUBLESHOOTING.md)
- **Exemplos Práticos:** [`tests/signature_example.test.ts`](./tests/signature_example.test.ts)
- **Script de Diagnóstico:** [`scripts/check_signature_setup.ts`](./scripts/check_signature_setup.ts)

---

## ✅ **Checklist Rápido**

Antes de reportar problemas:

- [ ] Executei `npm run check:signature`?
- [ ] Todos os `Keypair`s estão em `.signers([])`?
- [ ] PDAs não estão marcados como `Signer` no Rust?
- [ ] Signers têm SOL suficiente?
- [ ] Provider está configurado corretamente?

---

**💡 Dica:** Se o erro persistir, execute o exemplo prático:
```bash
npx mocha tests/signature_example.test.ts --timeout 30000
``` 