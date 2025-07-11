
---

### **Lista de Tarefas de Desenvolvimento dos Contratos Inteligentes – Gold Mining Token (GMC)**

#### **Fase 0: Preparação e Configuração do Projeto (Sprint 0)**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **0.1** | **Resolução de Inconsistências** | Tomar decisões finais sobre: <br> 1. Penalidade de Saque Antecipado. <br> 2. Pagamento de Juros Flexível. <br> 3. Distribuição da Taxa de Transação. | **Crítica** | `Pendente` | Stakeholders |
| **0.2** | **Configuração do Ambiente de Desenvolvimento** | Instalar e configurar Rust, Solana CLI e o framework Anchor para todos os desenvolvedores. | **Alta** | `Pendente` | - |
| **0.3** | **Estruturação do Repositório do Projeto** | Criar o monorepo com a estrutura de pastas padrão do Anchor (`programs/`, `tests/`, `app/`, etc.). | **Alta** | `✅ Concluído` | Tarefa 0.2 |
| **0.4** | **Definição das Constantes e Endereços** | Criar um arquivo de configuração central para armazenar endereços (Equipe, Tesouraria, Queima) e parâmetros (taxas, APYs base). | **Alta** | `Pendente` | Tarefa 0.1 |

---

#### **Fase 1: Desenvolvimento do Token GMC (`GmcTokenContract`)**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **1.1** | **Implementação do Token GMC (SPL Token-2022)** | Criar o programa para o mint do token GMC, definindo nome, símbolo, decimais e fornecimento máximo. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 0.3 |
| **1.2** | **Configuração da Extensão de Taxa de Transferência** | Configurar a `TransferFeeConfig` com 0.5% (`basis_points: 50`) e definir um `maximum_fee`. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 1.1 |
| **1.3** | **Desenvolvimento da Função de Saque de Taxas** | Implementar a instrução para que uma autoridade (o `StakingContract`) possa sacar as taxas de GMC retidas. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | Tarefa 1.2 |
| **1.4** | **Desenvolvimento do Script de Gênesis e Distribuição** | Criar um script para mintar o fornecimento total e distribuir os tokens para as carteiras designadas (Pool de Staking, Reserva, etc.). <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 1.1 |

---

#### **Fase 2: Lógica Central de Staking (`StakingContract`)**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **2.1** | **Definição das Estruturas de Dados de Staking** | Implementar as contas no Anchor: `GlobalState`, `UserStakeInfo`, e `StakePosition` (com `enum` para tipo de stake). <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 0.3 |
| **2.2** | **Implementação da Instrução `stake_long_term`** | Desenvolver a lógica para staking de longo prazo, incluindo a verificação do fee em USDT e a transferência de GMC para o cofre. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 2.1 |
| **2.3** | **Implementação da Instrução `stake_flexible`** | Desenvolver a lógica para staking flexível, reutilizando a mecânica de fee em USDT. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 2.1 |
| **2.4** | **Implementação de `withdraw_principal_long` (Saque Normal)** | Lógica para saque do principal após o período de 12 meses, sem penalidades. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 2.2 |
| **2.5** | **Implementação de `emergency_unstake_long` (Saque Antecipado)** | Implementar a lógica de penalidade complexa (taxa USDT + % capital + % juros) e a distribuição dos fundos da penalidade. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 2.2 |
| **2.6** | **Implementação de `withdraw_flexible`** | Desenvolver a lógica de saque flexível, incluindo o cálculo e a distribuição da taxa de cancelamento de 2.5%. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 2.3 |

---

#### **Fase 3: Mecânicas de Recompensa e `Burn-for-Boost` (`StakingContract`)**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **3.1** | **Implementação da Instrução `burn_for_boost`** | Desenvolver a lógica que cobra a taxa em USDT e a taxa de 10% em GMC, queima os tokens e recalcula o `StakingPower`. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 2.2 |
| **3.2** | **Implementação do Cálculo de APY** | Criar as funções internas para calcular o APY para Staking de Longo Prazo (base + poder de queima + boost de afiliado) e Flexível. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 3.1 |
| **3.3** | **Implementação da Instrução `claim_rewards` (GMC)** | Desenvolver a lógica para o saque de juros em GMC, aplicando a taxa de saque de 1% e distribuindo-a. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefa 3.2 |
| **3.4** | **Implementação da Instrução `claim_usdt_rewards`** | Desenvolver a lógica para o saque de recompensas em USDT, calculando a parte do usuário e aplicando a taxa de 0.3%. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | Tarefa 2.2 |
| **3.5** | **Implementação da Lógica de Afiliados** | 1. Implementar `register_referrer`. <br> 2. Desenvolver a função (otimizada) `calculate_affiliate_boost` que percorre a árvore de referidos. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Alta** | `✅ Concluído` | Tarefas 2.1, 3.2 |

---

#### **Fase 4: Gamificação e Recompensas (`RankingRewardsContract`)**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **4.1** | **Definição das Estruturas de Dados do Ranking** | Implementar as contas `RankingState` (pools de prêmios) e `UserActivity` (contadores de métricas). <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | Tarefa 0.3 |
| **4.2** | **Implementação das Funções de "Log"** | Criar as instruções `log_burn` e `log_referral` para serem chamadas pelo `StakingContract`. Avaliar a viabilidade do `log_transaction`. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | `StakingContract` |
| **4.3** | **Implementação da Distribuição de Prêmios Mensais** | Criar a função de admin para calcular os vencedores, verificar a lista de exclusão, distribuir os prêmios e zerar os contadores. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | Tarefa 4.2 |
| **4.4** | **Implementação da Distribuição do Prêmio Anual** | Similar à função mensal, mas para o ranking anual de "Queimadores". <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Baixa** | `✅ Concluído` | Tarefa 4.2 |

---

#### **Fase 5: Contrato de Vesting (`VestingContract`)**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **5.1** | **Desenvolvimento do Contrato de Vesting** | Implementar a conta `VestingSchedule` e as instruções `create_schedule` (admin) e `release` (pública). <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | Tarefa 0.3 |
| **5.2** | **Criação de Scripts para Configurar Schedules** | Desenvolver scripts para criar os cronogramas de vesting para a Equipe e a Reserva Estratégica. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | Tarefa 5.1 |

---

#### **Fase 6: Testes, Segurança e Integração**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **6.1** | **Escrita de Testes Unitários** | Criar testes para cada instrução em isolamento, cobrindo casos de sucesso, falha e borda (ex: valores zero, valores máximos). <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Crítica** | `✅ Concluído` | Todas as Fases |
| **6.2** | **Escrita de Testes de Integração** | Testar fluxos completos de ponta a ponta. Ex: `Stake -> Burn -> Claim Rewards -> Withdraw`. <br> Testar a comunicação entre `StakingContract` e `RankingRewardsContract`. | **Crítica** | `Pendente` | Todas as Fases |
| **6.2.1** | **Validação em Devnet (Token)** | Criar e executar um conjunto de scripts de teste contra a Devnet para validar a inicialização do Token-2022. | **Crítica** | `Pendente` | Tarefa 6.2 |
| **6.2.2** | **Validação em Devnet (Staking)** | Validar o fluxo completo de staking (initialize, stake, fetch) na Devnet para contornar a instabilidade do `solana-test-validator`. | **Crítica** | `Pendente` | Tarefa 6.2.1 |
| **6.3** | **Preparação e Auditoria de Segurança** | Preparar a documentação para uma empresa de auditoria externa e comissionar a auditoria. Implementar as correções sugeridas. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Crítica** | `✅ Concluído` | Tarefa 6.2 |
| **6.4** | **Documentação Técnica dos Contratos** | Adicionar comentários no padrão NatSpec/Rustdoc em todas as funções públicas e estruturas para explicar o que fazem. <br> **Checklist:** <br> - [x] Testes (Vermelho) <br> - [x] Implementação (Verde) <br> - [x] Refatoração <br> - [x] Revisão de Segurança | **Média** | `✅ Concluído` | Todas as Fases |

---

#### **Fase 7: Implantação e Operações Pós-Lançamento**

| ID | Tarefa | Descrição | Prioridade | Status | Dependências |
|:---|:---|:---|:---|:---|:---|
| **7.1** | **Desenvolvimento de Scripts de Implantação** | Criar scripts automatizados para implantar e inicializar todos os contratos na Devnet, Testnet e Mainnet. <br> **Checklist:** <br> - [ ] Testes (Vermelho) <br> - [ ] Implementação (Verde) <br> - [ ] Refatoração <br> - [ ] Revisão de Segurança | **Alta** | `Pendente` | Tarefa 6.3 |
| **7.2** | **Criação de um Manual de Operações ("Runbook")** | Documentar os processos operacionais: como chamar funções de admin, como gerenciar chaves, como monitorar os fundos dos contratos. | **Média** | `Pendente` | Tarefa 7.1 |
| **7.3** | **Implantação na Testnet e Teste Comunitário** | Publicar os contratos na Testnet e convidar a comunidade para um "bug bounty" ou teste aberto. | **Alta** | `Pendente` | Tarefa 7.1 |
| **7.4** | **Implantação na Mainnet** | Executar os scripts de implantação na Mainnet após a conclusão bem-sucedida de todas as fases anteriores. | **Crítica** | `Pendente` | Tarefa 7.3 |