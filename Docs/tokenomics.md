Tokenomics e Mecânica de Staking – Gold Mining Token (GMC) Projeto: Gold Mining Token (GMC) Versão do Documento: 2.4 Data: Janeiro 2025 Assunto: Definição das regras de negócio para a criação do token GMC e seu sistema de recompensas (staking) para aprovação final.

1. Resumo Executivo Este documento detalha a estrutura econômica e funcional do token GMC, com o objetivo de criar um ecossistema robusto que recompense os detentores de longo prazo, incentive a redução da oferta circulante do token e promova o engajamento contínuo da comunidade. A mecânica central é um sistema de "Staking Evolutivo" e "Staking Flexível", onde os usuários são recompensados não apenas por bloquear seus tokens, mas também por contribuir ativamente para a sua escassez através de um mecanismo de queima voluntária. Adicionalmente, um programa de afiliados será implementado para expandir a base de usuários e recompensar promotores do ecossistema. Os pilares fundamentais do GMC são: Fornecimento Fixo: Uma quantidade máxima de tokens que nunca poderá ser aumentada. Sistema de Staking Duplo: Inclui o "Staking Evolutivo" (longo prazo com boosts por queima) e o "Staking Flexível" (curto prazo com liquidez imediata). Taxa para colocar o GMC no Staking: Quando o usuário coloca o staking a taxa é cobrada em $USDT. Taxa sobre Transações: Uma pequena taxa aplicada a cada transferência do token GMC, que contribui passivamente para a queima e para o fundo de recompensas. Programa de Afiliados: Recompensa afiliados com 50% do poder de mineração gerado por seus indicados. Observação: A queima de tokens será interrompida quando o supply total atingir 12 milhões de tokens.  
     
2. O Token GMC (Gold Mining Coin) O GMC é o pilar central do ecossistema. Suas características fundamentais são: Nome do Token: Gold Mining Token Símbolo: GMC Padrão Técnico: SPL Token-2022 (essencial para implementar a taxa de transferência). Fornecimento Máximo Fixo: 100.000.000 (cem milhões) de GMC. Nenhum token adicional poderá ser criado após o lançamento, garantindo escassez programada. Distribuição Inicial: O fornecimento total será alocado no momento da criação da seguinte forma: Fundo Pool de Staking : 70.000.000 GMC Finalidade: Financia os juros do sistema de staking. Pré-venda (ICO): 8.000.000 GMC (será distribuído via script automatizado para carteiras designadas). Reserva estratégica Gold Mining: 10.000.000 GMC (Regra de vesting para ir liberando o fundo ao longo de 5 anos) Tesouraria: 2.000.000 GMC Marketing e Expansão: 6.000.000 GMC Airdrop (Distribuição Comunitária): 2.000.000 GMC Equipe (com cronograma de liberação): 2.000.000 GMC  
     
3. Mecanismos Fundamentais 3.1. Mecanismo Passivo: Taxa sobre Transações GMC Uma taxa será aplicada a cada transferência do token GMC realizada na rede (ex: transferências entre carteiras, negociações em exchanges descentralizadas). Taxa Total por Transação: 0,5% Distribuição da Taxa: 50% para Queima: Metade da taxa é enviada para um endereço de queima, sendo permanentemente removida da circulação. 40% para o Fundo de Staking: Para financiar recompensas. 10% para o Programa de Ranking: Para premiações mensais/anuais. Exemplo: Se um usuário vende 1.000 GMC em uma DEX, uma taxa de 5 GMC (0,5%) é aplicada. O comprador recebe 995 GMC. Dos 5 GMC da taxa, 2.5 são queimados, 2 para staking e 0.5 para ranking. Benefício: Cria uma pressão deflacionária constante e reabastece o pool de recompensas, tornando o ecossistema mais sustentável a longo prazo.  
     
4. O Sistema de Staking (Dois Tipos) O staking é o principal mecanismo para os detentores de GMC gerarem rendimentos e participarem ativamente do ecossistema. Ele foi desenhado para ser dinâmico, justo e recompensador. Teremos dois tipos de staking para atender a diferentes perfis de investidores: Staking de Longo Prazo (Evolutivo) e Staking Flexível. 4.1. Staking de Longo Prazo (Staking Burn) Os usuários bloqueiam seus tokens GMC por um período fixo e, em troca, recebem juros. O diferencial é que os usuários podem aumentar sua taxa de juros (APY) a qualquer momento, queimando (destruindo permanentemente) uma quantidade adicional de tokens. Em resumo: quem mais contribui para a escassez do GMC, mais é recompensado. Período de Bloqueio Fixo: Todo o capital principal (tokens GMC) colocado em staking ficará bloqueado por um período obrigatório de 12 meses. APY Base Garantido: Todo usuário em staking inicia com uma taxa de juros base de 10% ao ano (APY). Pagamento de Juros: Diários. Aumento do APY por Queima (Burn-for-Boost): O usuário pode, a qualquer momento, executar uma ação de "queima" para aumentar seu APY. O aumento é calculado com base na proporção entre a quantidade queimada e o capital principal em staking. Teto Máximo de Juros: Para garantir a sustentabilidade do projeto, a taxa de juros máxima que um usuário pode atingir até 280% ao ano (APY). Fee do staking: Taxa variável em USDT (ver tabela no final). 4.1.1. Regra de Retirada Antecipada (Penalidade) para Staking de Longo Prazo A estabilidade do sistema é crucial. Se um usuário decidir quebrar o contrato e retirar seu capital antes do fim dos 12 meses, uma penalidade severa será aplicada: 5 USDT + 50% do capital + 80% dos juros (distribuídos conforme tabela). 4.2. O Conceito de "Poder de Staking" (Staking Power) O Poder de Staking é calculado com base na queima equivalente a 100% do capital para APY máximo de 280%. Fórmula: MIN(100, (queimado / principal) * 100). 4.3. Staking Flexível Este tipo de staking oferece maior liquidez e flexibilidade. Período de Bloqueio: Nenhum. APY: 5% - 70%. Pagamento de Juros: A cada 30 dias. Penalidades de Retirada: 2,5% sobre o capital (apenas para cancelamento).

5. Fluxo de Pagamento de Fees com USDT-SPL para Staking Taxas pagas em USDT-SPL, distribuídas conforme tabela no final do documento.

6. Programa de Afiliados Programa multinível de 6 níveis com boost de até 50% no APY baseado em staking de afiliados.

7. Programa de Ranking e Recompensas por Desempenho Ranking mensal (Top 7 em 3 categorias) e anual (Top 12 queimadores), com premiações de pools alimentados por taxas.

7.1 Tabelas com regras de taxas e staking Ver Docs/tabela.md para detalhes unificados.

8. Fluxo de Ações do Usuário Stake, Burn-for-Boost, Claim, Withdraw, Emergency Unstake, Ações de Afiliado.

9. Treasury Module (Sistema de Tesouro)

O Treasury Module é um componente crítico para a gestão financeira do ecossistema GMC Token, implementando governança financeira segura e distribuição automática de fundos.

9.1 Sistema Multisig (3-de-N)
Todas as transações financeiras significativas exigem aprovação de pelo menos 3 signatários autorizados, garantindo segurança e eliminação de pontos únicos de falha.

9.2 Distribuição Automática de Fundos USDT
O Treasury gerencia a distribuição automática de todos os fundos USDT coletados das taxas conforme a regra:
- 40% para Equipe/Operações
- 40% para Pool de Staking
- 20% para Ranking/Premiações

9.3 Controle de Emergência
O sistema possui mecanismos de pausa de operações que podem ser ativados em situações críticas, exigindo aprovação multisig para reações rápidas a ameaças de segurança.

9.4 Gestão de Propostas
Ciclo completo de gerenciamento de transações:
- Criação de proposta de transação
- Coleta de assinaturas (mínimo 3 signatários autorizados)
- Execução da transação aprovada
- Registro transparente de todas as operações

10. Próximos Passos Desenvolvimento, Testes, Auditoria, Comunicação.

11. Conclusão Implementação do GMC com staking, fees em USDT e programas de incentivo para sustentabilidade e crescimento.

11. Quema para quando o supply total atingir 12 milhões de GMC, ou seja, quando o GMC chegar a 12 milhões de GMC, a quema será interrompida. Aumetaremos a taxa de transação para 1% para manter o Pools alimentado.
