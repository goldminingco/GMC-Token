# 🔐 Configuração DevSecOps - GMC Token Ecosystem

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Configuração de Variáveis de Ambiente](#configuração-de-variáveis-de-ambiente)
3. [Pipeline CI/CD](#pipeline-cicd)
4. [Segurança e Auditoria](#segurança-e-auditoria)
5. [Monitoramento e Alertas](#monitoramento-e-alertas)
6. [Deploy Automatizado](#deploy-automatizado)
7. [Gestão de Secrets](#gestão-de-secrets)
8. [Checklist de Segurança](#checklist-de-segurança)

## 🎯 Visão Geral

O processo DevSecOps do GMC Token está configurado para garantir:
- **Segurança por Design**: Validações em todas as etapas
- **Deploy Seguro**: Verificações pré e pós-deploy
- **Monitoramento Contínuo**: Alertas em tempo real
- **Auditoria Completa**: Logs e rastreabilidade

## 🔧 Configuração de Variáveis de Ambiente

### Estrutura de Ambientes

```bash
# Devnet - Desenvolvimento
DEVNET_DEPLOYER_KEYPAIR=./keypairs/devnet/deployer.json
DEVNET_ADMIN_KEYPAIR=./keypairs/devnet/admin.json
DEVNET_TEAM_WALLET=./keypairs/devnet/team.json
DEVNET_TREASURY_WALLET=./keypairs/devnet/treasury.json
DEVNET_MARKETING_WALLET=./keypairs/devnet/marketing.json
DEVNET_AIRDROP_WALLET=./keypairs/devnet/airdrop.json

# Testnet - Homologação
TESTNET_DEPLOYER_KEYPAIR=./keypairs/testnet/deployer.json
TESTNET_ADMIN_KEYPAIR=./keypairs/testnet/admin.json
TESTNET_TEAM_WALLET=./keypairs/testnet/team.json
TESTNET_TREASURY_WALLET=./keypairs/testnet/treasury.json
TESTNET_MARKETING_WALLET=./keypairs/testnet/marketing.json
TESTNET_AIRDROP_WALLET=./keypairs/testnet/airdrop.json

# Mainnet - Produção
MAINNET_DEPLOYER_KEYPAIR=./keypairs/mainnet/deployer.json
MAINNET_ADMIN_KEYPAIR=./keypairs/mainnet/admin.json
MAINNET_TEAM_WALLET=./keypairs/mainnet/team.json
MAINNET_TREASURY_WALLET=./keypairs/mainnet/treasury.json
MAINNET_MARKETING_WALLET=./keypairs/mainnet/marketing.json
MAINNET_AIRDROP_WALLET=./keypairs/mainnet/airdrop.json
MAINNET_RPC_URL=https://api.mainnet-beta.solana.com

# Configurações de Segurança
NODE_ENV=production  # Para deploy mainnet
CARGO_NET_GIT_FETCH_WITH_CLI=true  # Para problemas de rede
```

### Configuração Automática

```bash
# Script de configuração automática
./scripts/setup_environment.sh devnet    # Desenvolvimento
./scripts/setup_environment.sh testnet   # Homologação
./scripts/setup_environment.sh mainnet   # Produção
./scripts/setup_environment.sh all       # Todos os ambientes

# Ativar variáveis
source .env
```

## 🚀 Pipeline CI/CD

### Estágios do Pipeline

```yaml
# .github/workflows/deploy.yml (Proposta)
name: GMC Token Deploy Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Rust Security Audit
        run: cargo audit
      
      - name: Dependency Check
        run: cargo tree --duplicates
      
      - name: SAST Analysis
        run: ./scripts/security_scan.sh

  build-and-test:
    runs-on: ubuntu-latest
    needs: security-scan
    steps:
      - name: Setup Solana
        run: |
          sh -c "$(curl -sSfL https://release.solana.com/v1.18.24/install)"
          echo "$HOME/.local/share/solana/install/active_release/bin" >> $GITHUB_PATH
      
      - name: Setup Anchor
        run: |
          npm install -g @coral-xyz/anchor-cli@0.30.1
      
      - name: Build Programs
        run: anchor build
      
      - name: Run Tests
        run: anchor test --skip-local-validator

  deploy-devnet:
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/develop'
    steps:
      - name: Deploy to Devnet
        run: |
          npm run deploy:devnet
        env:
          DEVNET_DEPLOYER_KEYPAIR: ${{ secrets.DEVNET_DEPLOYER_KEYPAIR }}

  deploy-testnet:
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to Testnet
        run: |
          npm run deploy:testnet
        env:
          TESTNET_DEPLOYER_KEYPAIR: ${{ secrets.TESTNET_DEPLOYER_KEYPAIR }}

  deploy-mainnet:
    runs-on: ubuntu-latest
    needs: [build-and-test, security-approval]
    if: github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'
    steps:
      - name: Mainnet Deploy Ceremony
        run: |
          NODE_ENV=production npm run deploy:mainnet
        env:
          MAINNET_DEPLOYER_KEYPAIR: ${{ secrets.MAINNET_DEPLOYER_KEYPAIR }}
          NODE_ENV: production
```

## 🔒 Segurança e Auditoria

### Verificações de Segurança Automáticas

```bash
# Executadas em cada deploy
./scripts/security_check.sh

# Verificações incluem:
# - Cargo audit (vulnerabilidades)
# - Dependency analysis
# - Code quality checks
# - Access control validation
# - Keypair security
# - Balance verification
# - RPC connectivity
# - Program verification
```

### Configurações de Segurança por Ambiente

```typescript
// scripts/deploy_ecosystem_automated.ts
const SECURITY_CONFIG = {
  devnet: {
    requireMultisig: false,
    maxTransactionSize: 1000000,
    deploymentTimeout: 300000,
    verificationRequired: false,
  },
  testnet: {
    requireMultisig: true,
    maxTransactionSize: 1000000,
    deploymentTimeout: 600000,
    verificationRequired: true,
  },
  mainnet: {
    requireMultisig: true,
    maxTransactionSize: 500000,
    deploymentTimeout: 900000,
    verificationRequired: true,
  }
};
```

## 📊 Monitoramento e Alertas

### Configuração de Monitoramento

```json
{
  "alerts": {
    "critical": {
      "channels": ["slack", "email", "sms"],
      "response_time": "< 5 minutes",
      "escalation": "immediate"
    },
    "high": {
      "channels": ["slack", "email"],
      "response_time": "< 15 minutes",
      "escalation": "30 minutes"
    }
  },
  "metrics": [
    "transaction_volume",
    "error_rate",
    "response_time",
    "contract_balance",
    "user_activity",
    "gas_usage",
    "security_events"
  ]
}
```

### Health Checks

```typescript
const healthChecks = [
  {
    name: "Token Contract Health",
    interval: 60000, // 1 minuto
    timeout: 10000,
    critical: true
  },
  {
    name: "Staking Contract Health",
    interval: 120000, // 2 minutos
    timeout: 15000,
    critical: true
  },
  {
    name: "Cross-Contract Integration",
    interval: 300000, // 5 minutos
    timeout: 30000,
    critical: false
  }
];
```

## 🚀 Deploy Automatizado

### Scripts de Deploy

```bash
# Deploy por ambiente
npm run deploy:devnet     # Desenvolvimento
npm run deploy:testnet    # Homologação
npm run deploy:mainnet    # Produção (requer aprovação)

# Deploy completo do ecossistema
npm run deploy:ecosystem:devnet
npm run deploy:ecosystem:testnet
npm run deploy:ecosystem:mainnet
```

### Validações Pré-Deploy

```typescript
// Verificações executadas antes do deploy
const preDeployChecks = [
  "Saldos das carteiras suficientes",
  "Conectividade RPC verificada",
  "Programas compilados corretamente",
  "IDLs gerados com sucesso",
  "Configurações de segurança validadas",
  "Keypairs válidas e acessíveis",
  "Multisig configurado (testnet/mainnet)"
];
```

### Validações Pós-Deploy

```typescript
// Verificações executadas após o deploy
const postDeployChecks = [
  "Contratos deployados corretamente",
  "Estados iniciais validados",
  "Controles de acesso verificados",
  "Distribuição de tokens confirmada",
  "Integração entre contratos testada",
  "Configurações de segurança ativas",
  "Monitoramento integrado"
];
```

## 🔐 Gestão de Secrets

### Secrets Necessários

```bash
# GitHub Secrets (para CI/CD)
DEVNET_DEPLOYER_KEYPAIR     # Base64 encoded keypair
TESTNET_DEPLOYER_KEYPAIR    # Base64 encoded keypair
MAINNET_DEPLOYER_KEYPAIR    # Base64 encoded keypair
SLACK_WEBHOOK_URL           # Para alertas
MONITORING_API_KEY          # Para métricas
```

### Configuração Local

```bash
# Keypairs locais (nunca commitar)
keypairs/
├── devnet/
│   ├── deployer.json
│   ├── admin.json
│   └── ...
├── testnet/
│   ├── deployer.json
│   ├── admin.json
│   └── ...
└── mainnet/
    ├── deployer.json
    ├── admin.json
    └── ...
```

## ✅ Checklist de Segurança

### Pré-Deploy

- [ ] **Auditoria de Código**: Revisão completa dos contratos
- [ ] **Testes de Segurança**: Simulação de ataques
- [ ] **Dependency Audit**: Verificação de vulnerabilidades
- [ ] **Configuração de Multisig**: Para testnet/mainnet
- [ ] **Backup de Keypairs**: Armazenamento seguro
- [ ] **Validação de Saldos**: SOL suficiente para deploy
- [ ] **Teste de Conectividade**: RPC endpoints funcionais
- [ ] **Configuração de Monitoramento**: Alertas ativos

### Durante o Deploy

- [ ] **Verificação de Ambiente**: NODE_ENV correto
- [ ] **Validação de Keypairs**: Arquivos existem e são válidos
- [ ] **Confirmação Manual**: Para deploy mainnet
- [ ] **Log de Transações**: Registro completo
- [ ] **Verificação de Estado**: Contratos inicializados corretamente
- [ ] **Teste de Integração**: Comunicação entre contratos

### Pós-Deploy

- [ ] **Validação Funcional**: Todas as funções operacionais
- [ ] **Monitoramento Ativo**: Alertas configurados
- [ ] **Documentação Atualizada**: Program IDs registrados
- [ ] **Backup de Configurações**: Deploy artifacts salvos
- [ ] **Notificação da Equipe**: Deploy confirmado
- [ ] **Plano de Contingência**: Procedimentos de emergência ativos

## 🚨 Procedimentos de Emergência

### Triggers de Emergência

```typescript
const emergencyTriggers = [
  "Exploração de vulnerabilidade detectada",
  "Perda de acesso a keypairs críticas",
  "Falha crítica no sistema de staking",
  "Anomalia na distribuição de tokens",
  "Comprometimento de segurança"
];
```

### Contatos de Emergência

```typescript
const emergencyContacts = [
  "+55 11 99999-9999", // Lead Developer
  "+55 11 88888-8888", // Security Officer
  "+55 11 77777-7777", // Project Manager
  "alerts@gmc-ecosystem.com" // Email de emergência
];
```

### Plano de Rollback

```typescript
const rollbackPlan = {
  procedures: [
    "Pausar operações críticas",
    "Notificar equipe de emergência",
    "Avaliar impacto da vulnerabilidade",
    "Implementar correções temporárias",
    "Comunicar com a comunidade",
    "Executar deploy de correção",
    "Validar correção implementada",
    "Retomar operações normais"
  ]
};
```

## 📚 Recursos Adicionais

### Documentação Técnica

- [Guia de Setup do Ambiente](./DEV_ENV_SETUP.md)
- [Checklist de Auditoria](./SECURITY_AUDIT_CHECKLIST.md)
- [Preparação para Auditoria](./SECURITY_AUDIT_PREPARATION.md)
- [Troubleshooting de Compilação](./COMPILATION_ANALYSIS.md)

### Scripts Úteis

```bash
# Verificação de saúde do sistema
./scripts/health_check.sh

# Validação de configurações
./scripts/validate_config.sh

# Backup de keypairs
./scripts/backup_keypairs.sh

# Monitoramento de contratos
./scripts/monitor_contracts.sh
```

### Comandos de Emergência

```bash
# Pausar sistema (se implementado)
npm run emergency:pause

# Status do sistema
npm run system:status

# Logs de emergência
npm run logs:emergency

# Backup de estado
npm run backup:state
```

## 🎯 Conclusão

O processo DevSecOps do GMC Token está configurado para garantir:

1. **Segurança Máxima**: Validações em todas as etapas
2. **Deploy Confiável**: Automação com verificações
3. **Monitoramento Contínuo**: Alertas em tempo real
4. **Resposta Rápida**: Procedimentos de emergência
5. **Auditoria Completa**: Rastreabilidade total

**Status**: ✅ **CONFIGURADO** - Sistema pronto para produção

---

*Este documento é parte do GMC Token Ecosystem e deve ser mantido atualizado com as configurações de produção.* 