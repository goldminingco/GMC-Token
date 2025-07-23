# 🏗️ GMC Ecosystem - Arquitetura do Sistema

## Visão Geral

O GMC Ecosystem é um ecossistema DeFi completo construído na blockchain Solana, composto por cinco programas principais que trabalham em conjunto para fornecer funcionalidades de token, staking, ranking, vesting e treasury management.

## Arquitetura de Alto Nível

```
┌─────────────────────────────────────────────────────────────┐
│                    GMC ECOSYSTEM                           │
├─────────────────────────────────────────────────────────────┤
│  Frontend (React/Next.js)                                  │
├─────────────────────────────────────────────────────────────┤
│  SDK TypeScript                                            │
├─────────────────────────────────────────────────────────────┤
│  Solana Programs (Rust/)                             │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │ GMC Token   │ Staking     │ Ranking     │ Vesting     │  │
│  │ Program     │ Program     │ Program     │ Program     │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              Treasury Program                           │  │
│  └─────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Solana Runtime                                            │
└─────────────────────────────────────────────────────────────┘
```

## Programas do Ecossistema

### 1. GMC Token Program
**Responsabilidade**: Gerenciamento do token GMC (SPL Token)

**Funcionalidades**:
- Mint e burn de tokens
- Transferências
- Aprovações e delegações
- Metadados do token

**Contas Principais**:
- `TokenMint`: Conta do mint do token GMC
- `TokenAccount`: Contas de token dos usuários
- `TokenMetadata`: Metadados do token

### 2. Staking Program
**Responsabilidade**: Sistema de staking com recompensas

**Funcionalidades**:
- Stake de tokens GMC
- Unstake com período de cooldown
- Cálculo e distribuição de recompensas
- Múltiplos pools de staking

**Contas Principais**:
- `StakingPool`: Configuração do pool
- `UserStake`: Stake individual do usuário
- `RewardVault`: Vault de recompensas

### 3. Ranking Program
**Responsabilidade**: Sistema de ranking e afiliados

**Funcionalidades**:
- Cálculo de ranking baseado em atividade
- Sistema de referência/afiliados
- Recompensas por ranking
- Leaderboards

**Contas Principais**:
- `UserRanking`: Ranking individual
- `ReferralData`: Dados de referência
- `LeaderBoard`: Classificação global

### 4. Vesting Program
**Responsabilidade**: Vesting de tokens para equipe e investidores

**Funcionalidades**:
- Criação de schedules de vesting
- Release gradual de tokens
- Cliff periods
- Cancelamento de vesting

**Contas Principais**:
- `VestingSchedule`: Cronograma de vesting
- `VestingAccount`: Conta de vesting individual
- `VestingVault`: Vault de tokens em vesting

### 5. Treasury Program
**Responsabilidade**: Gerenciamento do tesouro do protocolo com controle multisig

**Funcionalidades**:
- Sistema multisig (3-de-N) para governança financeira
- Propostas de transação com assinaturas múltiplas
- Distribuição automática de fundos (40% equipe, 40% staking, 20% ranking)
- Controle de emergência para pausar operações
- Execução de transações aprovadas
- Gestão transparente de fundos USDT e GMC

**Contas Principais**:
- `TreasuryState`: Estado principal do tesouro incluindo signatários e balanços
- `PendingTransaction`: Transações pendentes de aprovação multisig
- `TokenAccounts`: Contas de tokens para USDT e GMC

**Fluxo de Operações**:
- Proposta → Assinaturas múltiplas → Execução
- Distribuição automática periódica para pools de recompensas
- Relatórios transparentes de todas transações

## Fluxos de Dados

### Fluxo de Staking
```
1. Usuário → GMC Token Program (approve)
2. Usuário → Staking Program (stake)
3. Staking Program → GMC Token Program (transfer)
4. Staking Program → Ranking Program (update activity)
5. Staking Program → Treasury Program (fees)
```

### Fluxo de Recompensas
```
1. Treasury Program → Staking Program (fund rewards)
2. Staking Program → cálculo de recompensas
3. Staking Program → GMC Token Program (mint rewards)
4. Staking Program → Ranking Program (update points)
```

## Segurança

### Controles de Acesso
- **Program Derived Addresses (PDAs)**: Todas as contas críticas são PDAs
- **Signer Verification**: Verificação rigorosa de assinantes
- **Owner Checks**: Verificação de proprietário de contas
- **Multisig**: Operações críticas requerem múltiplas assinaturas

### Validações
- **Input Validation**: Validação de todos os inputs
- **State Validation**: Verificação de estado das contas
- **Arithmetic Safety**: Operações matemáticas seguras
- **Reentrancy Protection**: Proteção contra reentrância

## Otimizações

### Compute Units
- Algoritmos otimizados para baixo uso de CU
- Batch operations quando possível
- Lazy loading de dados

### Memória
- Estruturas de dados compactas
- Zero-copy deserialization
- Reutilização de contas

### Network
- Address Lookup Tables (ALUTs)
- Transações compostas
- Priorização de fees

## Deployment

### Ambientes
- **Localnet**: Desenvolvimento local
- **Devnet**: Testes de desenvolvimento
- **Testnet**: Testes de staging
- **Mainnet**: Produção

### Program IDs
Cada ambiente possui Program IDs únicos para evitar conflitos:

```json
{
  "localnet": {
    "gmc_token": "",
    "gmc_staking": "",
    "gmc_ranking": "",
    "gmc_vesting": "",
    "gmc_treasury": ""
  }
}
```

## Monitoramento

### Métricas
- Total Value Locked (TVL)
- Número de usuários ativos
- Volume de transações
- Fees coletadas
- Recompensas distribuídas

### Alertas
- Falhas de transação
- Uso excessivo de CU
- Atividade suspeita
- Problemas de liquidez

## Roadmap Técnico

### Fase 1: Core (Atual)
-  Implementação dos 5 programas principais
-  Testes de integração
-  Auditoria de segurança

### Fase 2: Otimização
- 🔄 Otimizações de performance
- 🔄 Implementação de ALUTs
- 🔄 Batch operations

### Fase 3: Expansão
- 📋 Integração com outros protocolos
- 📋 Cross-chain bridges


## Considerações de Upgrade

### Program Upgrades
- Uso de upgrade authority
- Upgrades serão gerenciados pela equipe principal com total transparência e comunicação prévia à comunidade.
- Backward compatibility
- Migration scripts

### Data Migration
- Estratégias de migração de dados
- Versioning de estruturas
- Rollback procedures

---

**Última Atualização**: 2024-12-19
**Versão**: 1.0.0
**Autor**: GMC Development Team