# 🚀 Guia de Deploy Inicial - GMC Token

Este documento fornece instruções passo a passo para o deploy inicial completo do ecossistema GMC Token, incluindo a distribuição automatizada dos 100 milhões de tokens conforme o tokenomics oficial.

## 📋 Pré-requisitos

### 1. Ambiente de Desenvolvimento

```bash
# Node.js e npm/yarn
node --version  # v18+ recomendado
npm --version   # ou yarn --version

# Rust e Cargo
rustc --version  # 1.70+ recomendado
cargo --version

# Solana CLI
solana --version  # v1.18+ recomendado
```

### 2. Ferramentas Específicas

```bash
# Instalar cargo-contract para build
cargo install cargo-contract --force --locked

# Configurar Solana CLI para cluster desejado
solana config set --url devnet  # ou testnet/mainnet
```

### 3. Chaves e Configuração

```bash
# Gerar chave da autoridade (ou usar existente)
mkdir -p .devnet-keys
solana-keygen new --outfile .devnet-keys/authority.json

# Verificar saldo (necessário para transações)
solana balance .devnet-keys/authority.json
```

## 🔧 Preparação do Ambiente

### 1. Clone e Setup

```bash
# Clonar o repositório
git clone <GMC-Token-Repo>
cd GMC-Token

# Instalar dependências
npm install
# ou
yarn install
```

### 2. Configuração de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```env
# Configuração do cluster
CLUSTER=devnet
RPC_URL=https://api.devnet.solana.com

# Chaves
AUTHORITY_KEYPAIR_PATH=./.devnet-keys/authority.json

# Endereços de destinatários (configurar conforme necessário)
STAKING_POOL_ADDRESS=...
TREASURY_ADDRESS=...
MARKETING_ADDRESS=...
ICO_PRESALE_ADDRESS=...
STRATEGIC_RESERVE_ADDRESS=...
AIRDROP_ADDRESS=...
TEAM_ADDRESS=...
```

### 3. Build do Programa

```bash
# Build usando o script estável
./build_stable.sh
```

Você deve ver uma saída similar a:
```
🎉 BUILD CONCLUÍDO COM SUCESSO!
📦 Artefato: deploy/gmc_token.so
📏 Tamanho: 243K
```

## 🚀 Deploy e Distribuição

### 1. Deploy do Programa Principal

```bash
# Deploy do programa nativo GMC Token
solana program deploy deploy/gmc_token.so --keypair .devnet-keys/authority.json

# Anotar o Program ID retornado
echo "PROGRAM_ID=<Program_ID_retornado>" >> .env
```

### 2. Preparar Endereços de Destinatários

Antes de executar a distribuição, você precisa ter os endereços de destino prontos:

```bash
# Exemplo de geração de chaves para teste
solana-keygen new --outfile .devnet-keys/staking_pool.json
solana-keygen new --outfile .devnet-keys/treasury.json
solana-keygen new --outfile .devnet-keys/marketing.json
# ... repetir para todos os destinatários
```

### 3. Executar Distribuição Inicial

```bash
# Executar o script de distribuição automatizada
npx ts-node scripts/initial_distribution.ts
```

### 4. Monitoramento da Execução

O script irá:

1. **Criar o mint do token GMC** (9 decimais)
2. **Mintar 100,000,000 GMC** para a autoridade
3. **Distribuir conforme tokenomics:**
   - 70M GMC → Pool de Staking
   - 8M GMC → ICO/Pré-venda
   - 10M GMC → Reserva Estratégica (+ vesting)
   - 2M GMC → Treasury
   - 6M GMC → Marketing
   - 2M GMC → Airdrop
   - 2M GMC → Equipe (+ vesting)
4. **Configurar cronogramas de vesting**
5. **Gerar relatório completo**

### 5. Verificação Pós-Deploy

```bash
# Verificar saldos dos destinatários
solana account <token_account_address>

# Verificar supply total do mint
spl-token supply <mint_address>

# Verificar relatório gerado
ls reports/initial_distribution_*.json
```

## 📊 Validação e Testes

### 1. Executar Suite de Testes

```bash
# Testes unitários
cargo test

# Testes específicos de tokenomics
npm run test:tokenomics
```

### 2. Validação Manual

```bash
# Verificar constantes implementadas
grep -n "INITIAL_SUPPLY\|BURN_CAP\|TOKEN_DECIMALS" programs/gmc_token_native/src/lib.rs

# Testar burn cap
# (executar transação de queima e verificar validação)
```

## 🔐 Configurações de Segurança

### 1. Multisig Treasury

```bash
# Configurar signatários do treasury
# (executar através de programa específico)
```

### 2. Transferência de Autoridade

```bash
# Para produção, transferir autoridade para multisig
# solana-keygen new --outfile .keys/multisig.json
# spl-token authorize <mint_address> mint <multisig_address>
```

## 📋 Checklist de Deploy

### Pré-Deploy
- [ ] Ambiente configurado (Rust, Solana CLI, Node.js)
- [ ] Chaves geradas e com saldo suficiente
- [ ] Endereços de destinatários definidos
- [ ] Build bem-sucedido (243K artefato)
- [ ] Testes unitários passando (44 testes)

### Deploy
- [ ] Programa deployado com sucesso
- [ ] Program ID anotado e configurado
- [ ] Script de distribuição executado
- [ ] Relatório de distribuição gerado
- [ ] Saldos verificados manualmente

### Pós-Deploy
- [ ] Vesting configurado para equipe e reserva
- [ ] Treasury configurado com multisig
- [ ] Limites de burn validados
- [ ] Documentação atualizada com endereços reais

## 📈 Monitoramento

### 1. Métricas Chave

- **Supply Total:** 100,000,000 GMC
- **Total Queimado:** Max 12,000,000 GMC
- **Distribuição:** Conforme tokenomics
- **Vesting:** Cronogramas ativos

### 2. Dashboards Recomendados

- Solana Explorer para o mint e transações
- Análise de saldos dos pools principais
- Monitoramento de transações de burn

## 🆘 Troubleshooting

### Erros Comuns

1. **"Insufficient funds"**
   ```bash
   # Solicitar airdrop
   solana airdrop 2 .devnet-keys/authority.json
   ```

2. **"Program deployment failed"**
   ```bash
   # Verificar se o artefato existe
   ls -la deploy/gmc_token.so
   # Re-executar build
   ./build_stable.sh
   ```

3. **"Token account not found"**
   ```bash
   # Criar conta de token associada
   spl-token create-account <mint_address>
   ```

### Logs e Debug

```bash
# Verificar logs do Solana
solana logs

# Debug do script de distribuição
DEBUG=1 npx ts-node scripts/initial_distribution.ts
```

## 📞 Suporte

Para problemas técnicos:
1. Verificar documentação em `/Docs`
2. Executar testes para isolar o problema
3. Revisar logs e relatórios gerados
4. Consultar troubleshooting específico

## 🎯 Conclusão

Após seguir este guia, você terá:

✅ **GMC Token deployado** com todas as funcionalidades  
✅ **100M GMC distribuídos** conforme tokenomics oficial  
✅ **Vesting configurado** para equipe e reserva estratégica  
✅ **Burn cap ativo** protegendo contra queima excessiva  
✅ **Treasury multisig** para governança financeira  
✅ **Relatórios completos** para auditoria  

O ecossistema GMC Token estará 100% operacional e pronto para uso em produção! 