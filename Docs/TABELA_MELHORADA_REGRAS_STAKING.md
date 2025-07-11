# 📊 Tabela Melhorada - Regras de Staking GMC Ecosystem

## 🎯 **Melhorias Implementadas**

Esta versão melhorada da tabela de regras de staking corrige inconsistências, adiciona informações faltantes e melhora a clareza das informações baseada na documentação completa do projeto GMC Token Ecosystem.

---

## **Tabela 1: Regras Completas de Taxas do Ecossistema GMC**

| # | Tipo de Taxa | Valor Sugerido | Forma de Pagamento | Destino / Finalidade | Status |
|:---|:---|:---|:---|:---|:---|
| **1** | **Taxa de Transação GMC** | **0,5%** por transação | GMC | **50%** Queima • **40%** Fundo de Staking • **10%** Programa de Ranking e Recompensas por Desempenho | ✅ **Implementado** |
| **2** | **Fee de Entrada no Staking** (Longo e Flexível) | **Taxa variável em USDT** calculada sobre o valor em GMC que você decide colocar em staking:<br>• **Até 1.000 GMC:** Taxa é de **10%** do valor em GMC<br>• **1.001 a 10.000 GMC:** Taxa cai para **5%** do valor em GMC<br>• **10.001 a 100.000 GMC:** Taxa é reduzida para **2,5%** do valor em GMC<br>• **100.001 a 500.000 GMC:** Taxa é de **1%** do valor em GMC<br>• **Acima de 500.000 GMC:** Taxa mínima é de **0,5%** do valor em GMC | **Para garantir um sistema justo e escalonado, aplicamos uma taxa de serviço em USDT sobre o valor em GMC que você decide colocar em staking. Essa taxa é calculada com base no valor total de GMC em unidade que será depositado, não no preço de mercado. Quanto maior o valor que você coloca em staking, menor a porcentagem da taxa.<br><br>**Veja como funciona a nossa estrutura de taxas:**<br>• **Até 1.000 GMC:** A taxa é de **10%** do valor em GMC.<br>• **Exemplo:** Se você depositar 100 GMC, a taxa será de 10 USDT.<br>• **De 1.001 GMC a 10.000 GMC:** A taxa cai para **5%** do valor em GMC.<br>• **De 10.001 GMC a 100.000 GMC:** A taxa é reduzida para **2,5%** do valor em GMC.<br>• **De 100.001 GMC a 500.000 GMC:** A taxa é de **1%** do valor em GMC.<br>• **Acima de 500.000 GMC:** A taxa mínima é de **0,5%** do valor em GMC. | **40%** Equipe • **40%** Fundo Staking • **20%** Programa de Ranking e Recompensas por Desempenho | ✅ **Implementado** |
| **3** | **Penalidade de Saque Antecipado** (Staking Longo) | **5 USDT** + **50%** do capital + **80%** dos juros | GMC | **30%** Queima • **50%** Fundo de Staking • **20%** Programa de Ranking e Recompensas por Desempenho | ✅ **Implementado** |
| **4** | **Taxas de Cancelamento Staking Flexível** | **2,5%** sobre o capital | GMC | **40%** Equipe • **40%** Fundo de Staking • **20%** Programa de Ranking e Recompensas por Desempenho | ✅ **Implementado** |
| **5** | **Taxa de Saque de Juros (GMC)** | **1%** sobre o valor sacado | GMC | **40%** Queima • **50%** Fundo de Staking • **10%** Programa de Ranking e Recompensas por Desempenho | ✅ **Implementado** |
| **6** | **🆕 Taxa de Claim de Afiliados** | **0,5%** sobre recompensas de afiliados | GMC | **30%** Queima • **50%** Fundo de Staking • **20%** Programa de Ranking | 🔄 **Sugerido** |
| **7** | **Fee para Burn-for-Boost** | **0,8 USDT** + **10%** do GMC (da queima) por operação | USDT-SPL | **40%** Equipe • **50%** Fundo de Staking • **10%** Programa de Ranking e Recompensas por Desempenho | ✅ **Implementado** |
| **8** | **Taxa de Saque de Recompensas (em USDT)** | **0,3%** sobre valor sacado | USDT-SPL | **40%** Equipe • **40%** Fundo de Staking • **20%** Programa de Ranking e Recompensas por Desempenho | ✅ **Implementado** |
| **9** | **🆕 Taxa de Transferência Entre Pools** | **0,1%** para mudanças de tipo de staking | GMC | **100%** Fundo de Staking | 🔄 **Sugerido** |

---

## **Tabela 2: Planos de Staking Detalhados**

| Característica | Staking de Longo Prazo (Staking Burn) | Staking Flexível | Fundo Inicial Pool de Staking |
|:---|:---|:---|:---|
| **APY (Rendimento)** | **10% - 280%** APY por Ano | **5% - 70%** APY por Ano | **70.000.000 GMC** |
| **Período de Bloqueio** | **12 meses** obrigatório | **Sem prazo fixo** | - |
| **Pagamento dos Juros** | **Pagamento diário** dos Juros | **Pagamento 30 dias** dos Juros | - |
| **Investimento Mínimo** | **100 GMC** | **50 GMC** | - |
| **Burn-for-Boost** | ✅ **Disponível** (até 280% APY) | ❌ **Não disponível** | - |
| **Sistema de Afiliados** | ✅ **Boost até 50%** | ✅ **Boost até 35%** | - |
| **Saque Antecipado** | ⚠️ **Penalidade severa** | ✅ **Taxa de 2,5%** | - |
| **Flexibilidade** | 🔒 **Baixa** (12 meses) | 🔓 **Alta** (sem prazo) | - |

---

## **Tabela 3: 🆕 Sistema de Afiliados Multi-Nível**

| Nível | Percentual de Recompensa | Boost Máximo no APY | Condições |
|:---|:---|:---|:---|
| **Nível 1** (Diretos) | **20%** das recompensas do afiliado | **10%** boost | Mínimo 5 afiliados ativos |
| **Nível 2** | **15%** das recompensas | **8%** boost | Mínimo 10 afiliados no nível 1 |
| **Nível 3** | **8%** das recompensas | **5%** boost | Mínimo 15 afiliados nos níveis anteriores |
| **Nível 4** | **4%** das recompensas | **3%** boost | Mínimo 25 afiliados nos níveis anteriores |
| **Nível 5** | **2%** das recompensas | **2%** boost | Mínimo 50 afiliados nos níveis anteriores |
| **Nível 6** | **1%** das recompensas | **1%** boost | Mínimo 100 afiliados nos níveis anteriores |

**Boost Total Máximo:** **50%** (somando todos os níveis)

---

## **Tabela 4: 🆕 Programa de Ranking e Premiação**

### **Ranking Mensal**

| Categoria | Prêmio por Posição | Total de Premiados | Pool de Premiação |
|:---|:---|:---|:---|
| **🔥 Top Queimadores** | **1º:** 2.000 GMC + 1.000 USDT<br>**2º-3º:** 1.500 GMC + 750 USDT<br>**4º-7º:** 1.000 GMC + 500 USDT | **Top 7** | **9.000 GMC + 4.500 USDT** |
| **👥 Top Recrutadores** | **1º:** 2.000 GMC + 1.000 USDT<br>**2º-3º:** 1.500 GMC + 750 USDT<br>**4º-7º:** 1.000 GMC + 500 USDT | **Top 7** | **9.000 GMC + 4.500 USDT** |
| **💰 Top Transacionadores** | **1º:** 2.000 GMC + 1.000 USDT<br>**2º-3º:** 1.500 GMC + 750 USDT<br>**4º-7º:** 1.000 GMC + 500 USDT | **Top 7** | **9.000 GMC + 4.500 USDT** |

**Total Mensal:** **27.000 GMC + 13.500 USDT**

### **Ranking Anual**

| Categoria | Prêmio por Posição | Total de Premiados | Pool de Premiação |
|:---|:---|:---|:---|
| **🔥 Top 12 Queimadores do Ano** | **1º:** 500 GMC + 250 USDT<br>**2º-6º:** 300 GMC + 150 USDT<br>**7º-12º:** 200 GMC + 100 USDT | **Top 12** | **4.000 GMC + 2.000 USDT** |

**Exclusão:** Top 20 holders de GMC são automaticamente excluídos dos rankings para promover descentralização.

---

## **🔧 Melhorias Técnicas Sugeridas**

### **1. 📱 Interface de Usuário**
- **Dashboard de Staking:** Mostrar APY atual, próximo pagamento, histórico
- **Calculadora de Burn-for-Boost:** Simular aumento de APY antes da operação
- **Ranking em Tempo Real:** Posição atual do usuário nos rankings

### **2. 🔒 Segurança Aprimorada**
- **Multisig para Funções Admin:** Proteção adicional para operações críticas
- **Time-lock para Mudanças:** Período de espera para alterações importantes
- **Emergency Pause:** Capacidade de pausar contratos em emergências

### **3. 📊 Analytics e Métricas**
- **TVL Dashboard:** Total Value Locked em tempo real
- **Burn Tracking:** Quantidade total queimada e impacto no supply
- **APY Histórico:** Gráficos de evolução dos rendimentos

### **4. 🎯 Gamificação Adicional**
- **NFT Badges:** Conquistas por milestones de staking/burn
- **Leaderboards:** Rankings públicos com recompensas sociais
- **Challenges Mensais:** Desafios especiais com prêmios extras

---

## **📈 Impacto das Melhorias**

### **Para Usuários:**
- ✅ **Maior Clareza:** Regras mais transparentes e fáceis de entender
- ✅ **Mais Opções:** Flexibilidade entre staking longo prazo e flexível
- ✅ **Recompensas Justas:** Sistema de afiliados e ranking bem estruturado

### **Para o Ecossistema:**
- ✅ **Sustentabilidade:** Distribuição equilibrada de taxas
- ✅ **Crescimento:** Incentivos para expansão da comunidade
- ✅ **Deflação Controlada:** Mecanismos de queima bem distribuídos

### **Para Desenvolvedores:**
- ✅ **Implementação Clara:** Especificações técnicas detalhadas
- ✅ **Testabilidade:** Cenários bem definidos para testes
- ✅ **Manutenibilidade:** Estrutura modular e documentada

---

## **🚀 Próximos Passos**

1. **✅ Validação:** Revisar melhorias com stakeholders
2. **🔧 Implementação:** Atualizar contratos conforme necessário  
3. **🧪 Testes:** Validar novas funcionalidades em testnet
4. **📚 Documentação:** Atualizar guias de usuário
5. **🎯 Deploy:** Implementar melhorias em produção

---

**Documento criado em:** Janeiro 2025  
**Versão:** 2.0 (Melhorada)  
**Status:** Pronto para implementação  
**Próxima Revisão:** Após feedback dos stakeholders 