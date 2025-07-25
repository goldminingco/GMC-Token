# 🎯 PLANO DE TESTES CRITERIOSOS - GMC TOKEN
## Validação Completa das Regras de Negócio na DevNet

### 📋 **INFORMAÇÕES DO DEPLOY**
- **Smart Contract:** `55pd9gckYTZBuKb8HanYNBeMjAf7Z298qX6awqdEV3JM`
- **Token SPL:** `48h1Nsg5vrpjtfWg5jHk3YwaVgvUSR7P9Ry2GEoBU8dv`
- **Network:** DevNet
- **Supply:** 100,000,000 GMC (conforme tokenomics)

---

## 🔍 **ETAPAS DE TESTE (Pequenas e Detalhadas)**

### **FASE 1: VALIDAÇÃO BÁSICA DO CONTRATO**

#### **Etapa 1.1: Verificação de Deploy e Conectividade**
- [ ] Confirmar Program ID ativo na DevNet
- [ ] Verificar se todas as instruções estão acessíveis
- [ ] Testar conectividade RPC
- [ ] Validar saldo da wallet deployer

#### **Etapa 1.2: Validação do Token SPL**
- [ ] Confirmar Mint Address correto
- [ ] Verificar supply total: 100,000,000 GMC
- [ ] Validar decimais: 9
- [ ] Confirmar autoridades do token

### **FASE 2: TESTES DAS REGRAS DE NEGÓCIO CORE**

#### **Etapa 2.1: Sistema de Taxas (0.5% por transação)**
**Requisito:** Taxa de 0.5% distribuída: 50% queima, 40% staking, 10% ranking
- [ ] Teste de transferência simples
- [ ] Validar cálculo da taxa (0.5%)
- [ ] Confirmar distribuição: 50% queima, 40% staking, 10% ranking
- [ ] Verificar logs de transação

#### **Etapa 2.2: Sistema de Staking - Taxas USDT**
**Requisito:** Taxas em USDT baseadas na quantidade de GMC
- [ ] Tier 1: 0-999 GMC → $1.00 USDT
- [ ] Tier 2: 1000-4999 GMC → $2.50 USDT
- [ ] Tier 3: 5000-9999 GMC → $5.00 USDT
- [ ] Tier 4: 10000+ GMC → $10.00 USDT

#### **Etapa 2.3: Distribuição de Taxas USDT**
**Requisito:** 40% team, 40% staking fund, 20% ranking fund
- [ ] Testar distribuição para cada tier
- [ ] Validar percentuais corretos
- [ ] Confirmar transferências CPI

#### **Etapa 2.4: Sistema de Affiliate (6 níveis)**
**Requisito:** Comissões: 20%, 15%, 8%, 4%, 2%, 1%
- [ ] Registro de afiliado
- [ ] Teste de comissões por nível
- [ ] Validar cálculos de recompensa
- [ ] Verificar anti-Sybil

#### **Etapa 2.5: Sistema de Ranking**
**Requisito:** 25 posições, distribuição proporcional
- [ ] Atualização de score
- [ ] Ordenação do leaderboard
- [ ] Distribuição de prêmios
- [ ] Reset de temporada

#### **Etapa 2.6: Sistema de Vesting**
**Requisito:** Liberação gradual de tokens
- [ ] Criação de cronograma
- [ ] Cálculo de tokens liberados
- [ ] Claim de tokens
- [ ] Validar cliff period

### **FASE 3: TESTES DE INTEGRAÇÃO E EDGE CASES**

#### **Etapa 3.1: Testes de Permissões**
- [ ] Apenas admin pode executar funções administrativas
- [ ] Usuários não podem executar funções restritas
- [ ] Validar assinaturas obrigatórias

#### **Etapa 3.2: Testes de Overflow e Segurança**
- [ ] Testes com valores máximos
- [ ] Validar proteções contra overflow
- [ ] Testar edge cases de cálculos

#### **Etapa 3.3: Testes de Performance**
- [ ] Medir compute units por instrução
- [ ] Validar limites de transação
- [ ] Testar com múltiplas operações

### **FASE 4: VALIDAÇÃO FINAL E RELATÓRIO**

#### **Etapa 4.1: Conformidade com Tokenomics**
- [ ] Supply total correto
- [ ] Distribuição inicial conforme especificação
- [ ] Todas as taxas funcionando
- [ ] Sistemas integrados funcionais

#### **Etapa 4.2: Geração de Relatório**
- [ ] Compilar resultados de todos os testes
- [ ] Documentar não-conformidades (se houver)
- [ ] Criar relatório executivo
- [ ] Preparar para testnet/mainnet

---

## 🛠️ **FERRAMENTAS DE TESTE**

### **Scripts a Criar:**
1. `test_basic_functionality.sh` - Testes básicos
2. `test_staking_system.sh` - Sistema de staking
3. `test_affiliate_system.sh` - Sistema de afiliados
4. `test_ranking_system.sh` - Sistema de ranking
5. `test_vesting_system.sh` - Sistema de vesting
6. `test_security_permissions.sh` - Testes de segurança
7. `generate_test_report.sh` - Relatório final

### **Dados de Teste Necessários:**
- Carteiras de teste com saldos variados
- Tokens USDT para testes de taxa
- Cenários de múltiplos usuários
- Dados de performance e logs

---

## ⚠️ **CRITÉRIOS DE APROVAÇÃO**

### **Obrigatórios para Prosseguir:**
- ✅ Todas as taxas funcionando conforme especificação
- ✅ Sistema de staking com tiers USDT corretos
- ✅ Distribuição de taxas USDT funcionando
- ✅ Sistema de afiliados com 6 níveis
- ✅ Sistema de ranking operacional
- ✅ Sistema de vesting funcional
- ✅ Permissões e segurança validadas
- ✅ Performance dentro dos limites

### **Documentação Obrigatória:**
- ✅ Logs detalhados de cada teste
- ✅ Evidências de funcionamento
- ✅ Relatório de conformidade
- ✅ Plano de correções (se necessário)

---

## 🚀 **PRÓXIMOS PASSOS APÓS APROVAÇÃO**
1. Deploy na TestNet
2. Testes finais em ambiente de produção
3. Preparação para MainNet
4. Integração com frontend
5. Launch oficial

---

**Status:** 🔄 Aguardando execução
**Responsável:** Cascade AI
**Prazo:** Hoje (25/01/2025)
