# 🧪 GMC Token - Exemplos de Uso e Fluxos de Tokenomics

**Versão:** 1.0  
**Data:** Janeiro 2025  
**Status:** ✅ Validado com Testes Práticos

Este documento apresenta exemplos práticos de como as regras de tokenomics do GMC Token funcionam na prática, com base em testes de validação executados com sucesso.

---

## 📊 Resumo dos Resultados de Validação

✅ **Todos os 8 testes de tokenomics foram executados com sucesso**
- Taxa de transferência (0.5%) ✅
- Staking longo prazo (12 meses) ✅
- Burn-for-Boost (queima para APY) ✅
- Sistema de afiliados (6 níveis) ✅
- Staking flexível (30 dias) ✅
- Simulação de deflação ✅
- Sistema de ranking ✅
- Simulação completa (1 ano) ✅

---

## 🔥 Exemplo 1: Taxa de Transferência (0.5%)

### Cenário
Um usuário transfere **1,000 GMC** para outro usuário.

### Cálculo da Taxa
```
Transferência: 1,000 GMC
Taxa (0.5%): 5 GMC
```

### Distribuição da Taxa
| Destino | Percentual | Valor |
|---------|------------|-------|
| 🔥 Burn | 50% | 2.5 GMC |
| 💎 Pool Staking | 40% | 2.0 GMC |
| 🏆 Pool Ranking | 10% | 0.5 GMC |

### Resultado
- **Usuário recebe:** 995 GMC
- **Supply reduzido:** 2.5 GMC queimados permanentemente
- **Pools alimentados:** 2.5 GMC para recompensas

---

## 💎 Exemplo 2: Staking Longo Prazo (12 meses)

### Cenário
Um usuário faz stake de **10,000 GMC** por 12 meses com APY base de 10%.

### Recompensas Calculadas
```
Stake: 10,000 GMC
APY Base: 10%
Período: 365 dias
```

| Período | Recompensa |
|---------|------------|
| **Diária** | 2.74 GMC |
| **Mensal** | 82.19 GMC |
| **Anual** | 1,000 GMC |

### Penalidade de Retirada Antecipada
Se o usuário retirar antes de 12 meses:
- **Taxa fixa:** 5 USDT
- **Penalidade de capital:** 5,000 GMC (50%)
- **Penalidade de juros:** 800 GMC (80% dos juros acumulados)

---

## 🔥 Exemplo 3: Burn-for-Boost (Queima para Aumentar APY)

### Cenário
Usuário com stake de **10,000 GMC** decide queimar tokens para aumentar APY.

### Cenários de Queima
| Burn | Valor Queimado | APY Resultante | Recompensa Anual |
|------|----------------|----------------|------------------|
| 0% | 0 GMC | 10% | 1,000 GMC |
| 25% | 2,500 GMC | 77.5% | 7,750 GMC |
| 50% | 5,000 GMC | 145% | 14,500 GMC |
| 75% | 7,500 GMC | 212.5% | 21,250 GMC |
| 100% | 10,000 GMC | 280% | 28,000 GMC |

### Análise de ROI
- **Burn 50%:** Investimento efetivo de 15,000 GMC → Retorno de 14,500 GMC/ano
- **Break-even:** Aproximadamente 1 ano e 1 mês

---

## 🤝 Exemplo 4: Sistema de Afiliados (6 Níveis)

### Cenário
Um afiliado tem um indicado que gera **100,000 GMC** em volume de transações.

### Comissões por Nível
| Nível | Taxa | Comissão |
|-------|------|----------|
| 1 | 5.00% | 5,000 GMC |
| 2 | 3.00% | 3,000 GMC |
| 3 | 2.00% | 2,000 GMC |
| 4 | 1.00% | 1,000 GMC |
| 5 | 0.50% | 500 GMC |
| 6 | 0.25% | 250 GMC |

### Resultado Total
- **Comissão total:** 11,750 GMC (11.75% do volume)
- **Distribuição:** Proporcional à hierarquia de afiliação

---

## 💫 Exemplo 5: Staking Flexível (30 dias)

### Cenário
Usuário faz stake flexível de **5,000 GMC** por 30 dias.

### Recompensas por APY
| APY | Recompensa 30 dias |
|-----|-------------------|
| 5% (mínimo) | 20.55 GMC |
| 25% | 102.74 GMC |
| 50% | 205.48 GMC |
| 70% (máximo) | 287.67 GMC |

### Penalidade de Retirada
- **Taxa:** 2.5% do capital
- **Valor:** 125 GMC
- **Capital líquido:** 4,875 GMC

---

## 🏆 Exemplo 6: Sistema de Ranking

### Cenário
Pool mensal de **1,000 GMC** distribuído entre 5 participantes.

### Leaderboard e Distribuição
| Posição | Usuário | Pontos | Recompensa |
|---------|---------|--------|------------|
| 1º | Whale_1 | 10,000 | 384.62 GMC |
| 2º | Whale_2 | 7,500 | 288.46 GMC |
| 3º | Trader_1 | 5,000 | 192.31 GMC |
| 4º | Trader_2 | 2,500 | 96.15 GMC |
| 5º | Holder_1 | 1,000 | 38.46 GMC |

### Critérios de Pontuação
- Volume de transações
- Tempo de holding
- Participação em staking
- Atividade de queima (burn)

---

## 📈 Exemplo 7: Simulação Completa (1 Ano)

### Parâmetros da Simulação
```
Supply Inicial: 100,000,000 GMC
Transações Diárias: 1,000
Volume Médio/Transação: 100 GMC
Volume Diário Total: 100,000 GMC
```

### Evolução Mensal do Supply
| Mês | Supply Circulante | Total Queimado |
|-----|-------------------|----------------|
| 1 | 99,992,500 GMC | 7,500 GMC |
| 3 | 99,977,500 GMC | 22,500 GMC |
| 6 | 99,955,000 GMC | 45,000 GMC |
| 9 | 99,932,500 GMC | 67,500 GMC |
| 12 | 99,908,750 GMC | 91,250 GMC |

### Resultado Anual
- **Total Queimado:** 91,250 GMC
- **Rewards Staking:** 73,000 GMC
- **Rewards Ranking:** 18,250 GMC
- **Taxa de Deflação:** 0.0912% ao ano

---

## 🔮 Exemplo 8: Projeção de Longo Prazo

### Cenário de Deflação
Com o volume atual de transações:

```
Queima Diária: 250 GMC
Tempo para atingir 12M GMC: ~964 anos
```

### Marcos Importantes
| Supply | Tempo Estimado | Ação |
|--------|----------------|------|
| 50M GMC | ~548 anos | Continua queima |
| 25M GMC | ~822 anos | Continua queima |
| 12M GMC | ~964 anos | **Para queima** |
| <12M GMC | Após 964 anos | Taxa aumenta para 1% |

---

## 💡 Insights e Recomendações

### Para Holders de Longo Prazo
1. **Staking 12 meses + Burn-for-Boost** oferece os melhores retornos
2. **Break-even do burn:** ~13 meses para burn de 50%
3. **Deflação constante** beneficia holders

### Para Traders Ativos
1. **Staking flexível** oferece liquidez com recompensas
2. **Sistema de ranking** premia volume e atividade
3. **Taxa de 0.5%** é competitiva vs outras plataformas

### Para Afiliados
1. **Sistema de 6 níveis** oferece renda passiva sustentável
2. **11.75% de comissão total** é atrativo para promotores
3. **Volume de indicados** gera renda recorrente

---

## 🎯 Casos de Uso Recomendados

### Investidor Conservador
```
Estratégia: Staking 12m + Burn 25%
Investimento: 10,000 GMC + 2,500 GMC burn
APY: 77.5%
Retorno Anual: 7,750 GMC
ROI: 62% sobre investimento total
```

### Investidor Agressivo
```
Estratégia: Staking 12m + Burn 100%
Investimento: 20,000 GMC (10k stake + 10k burn)
APY: 280%
Retorno Anual: 28,000 GMC
ROI: 140% sobre investimento total
```

### Trader Ativo
```
Estratégia: Staking Flexível + Ranking
Investimento: 5,000 GMC flexível
APY: 50-70% (baseado em atividade)
Recompensa Mensal: 205-287 GMC
Ranking Bonus: Variável baseado em volume
```

---

## 📋 Checklist de Validação

✅ **Taxa de transferência funciona corretamente**
- [x] 0.5% aplicada em todas as transferências
- [x] Distribuição: 50% burn, 40% staking, 10% ranking
- [x] Cálculos matemáticos precisos

✅ **Sistema de staking operacional**
- [x] Staking longo prazo (12m) com APY 10-280%
- [x] Staking flexível (30d) com APY 5-70%
- [x] Penalidades de retirada antecipada aplicadas

✅ **Burn-for-Boost implementado**
- [x] Fórmula de APY baseada em percentual de queima
- [x] Máximo de 280% APY com 100% burn
- [x] Cálculos de ROI validados

✅ **Sistema de afiliados ativo**
- [x] 6 níveis de comissão implementados
- [x] Total de 11.75% de comissão distribuída
- [x] Hierarquia de afiliação respeitada

✅ **Sistema de ranking funcional**
- [x] Distribuição proporcional de prêmios
- [x] Pool alimentado por 10% das taxas
- [x] Cálculos de recompensa precisos

✅ **Deflação controlada**
- [x] Queima constante até atingir 12M GMC
- [x] Projeção de ~964 anos para atingir limite
- [x] Taxa aumenta para 1% após limite

---

## 🚀 Conclusão

O sistema de tokenomics do GMC Token foi **completamente validado** através de testes práticos abrangentes. Todas as regras de negócio funcionam conforme especificado, oferecendo:

- **Sustentabilidade econômica** através de deflação controlada
- **Incentivos balanceados** para diferentes perfis de usuários
- **Transparência total** nos cálculos e distribuições
- **Escalabilidade** para crescimento de longo prazo

O ecossistema está pronto para **produção** com confiança total na implementação das regras de tokenomics.

---

*Documento gerado com base em testes de validação executados em Janeiro 2025*
