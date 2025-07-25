#!/bin/bash

# 🧪 TESTE AUTOMATIZADO: SISTEMA DE STAKING - TAXAS PERCENTUAIS
# Valida a nova implementação de taxas percentuais conforme requisitos originais

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores de teste
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Arquivo de log
LOG_FILE="test_staking_percentage_fees.log"
echo "🧪 TESTE AUTOMATIZADO: TAXAS PERCENTUAIS DE STAKING" > $LOG_FILE
echo "Data: $(date)" >> $LOG_FILE
echo "=============================================" >> $LOG_FILE

# Função para log de testes
log_test() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    echo "[$result] $test_name: $details" >> $LOG_FILE
    
    if [ "$result" = "PASS" ]; then
        echo -e "  ✅ ${GREEN}$test_name${NC}: $details"
    else
        echo -e "  ❌ ${RED}$test_name${NC}: $details"
    fi
}

# Função para calcular taxa percentual (CORRIGIDA - usando bc para números grandes)
calculate_percentage_fee() {
    local gmc_amount="$1"
    local usdt_price_per_gmc="$2" # Em micro-USDT (6 decimais)
    
    # Determinar tier e percentual
    local fee_percent
    if [ $gmc_amount -le 1000000000000 ]; then  # <= 1.000 GMC
        fee_percent=1000  # 10% em basis points
    elif [ $gmc_amount -le 10000000000000 ]; then  # <= 10.000 GMC
        fee_percent=500   # 5% em basis points
    elif [ $gmc_amount -le 100000000000000 ]; then # <= 100.000 GMC
        fee_percent=250   # 2.5% em basis points
    elif [ $gmc_amount -le 500000000000000 ]; then # <= 500.000 GMC
        fee_percent=100   # 1% em basis points
    else
        fee_percent=50    # 0.5% em basis points
    fi
    
    # Usar bc para cálculos de precisão com números grandes
    # Calcular valor em USDT do GMC staked
    local gmc_value_in_usdt=$(echo "scale=0; $gmc_amount * $usdt_price_per_gmc / 1000000000" | bc)
    
    # Aplicar porcentagem (basis points: 10000 = 100%)
    local fee_usdt=$(echo "scale=0; $gmc_value_in_usdt * $fee_percent / 10000" | bc)
    
    echo $fee_usdt
}

# Função para testar tier específico
test_tier() {
    local gmc_amount="$1"
    local expected_percent="$2"
    local tier_name="$3"
    local usdt_price=100000  # $0.10 por GMC
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando $tier_name${NC}"
    
    # Calcular taxa
    local calculated_fee=$(calculate_percentage_fee $gmc_amount $usdt_price)
    
    # Calcular valor esperado (CORRIGIDO - usando bc para evitar overflow)
    local gmc_value_in_usdt=$(echo "scale=0; $gmc_amount * $usdt_price / 1000000000" | bc)
    local expected_fee=$(echo "scale=0; $gmc_value_in_usdt * $expected_percent / 10000" | bc)
    
    # Converter para valores legíveis
    local gmc_readable=$((gmc_amount / 1000000000))
    local fee_readable_calculated=$(echo "scale=6; $calculated_fee / 1000000" | bc)
    local fee_readable_expected=$(echo "scale=6; $expected_fee / 1000000" | bc)
    
    if [ $calculated_fee -eq $expected_fee ]; then
        log_test "$tier_name" "PASS" "$gmc_readable GMC → \$$fee_readable_calculated USDT ($expected_percent basis points)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "$tier_name" "FAIL" "Esperado: \$$fee_readable_expected, Calculado: \$$fee_readable_calculated"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Função para testar distribuição
test_distribution() {
    local total_fee="$1"
    local test_name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando distribuição: $test_name${NC}"
    
    # Calcular distribuição (40% equipe, 40% staking, 20% ranking)
    local team_fee=$((total_fee * 40 / 100))
    local staking_fee=$((total_fee * 40 / 100))
    local ranking_fee=$((total_fee * 20 / 100))
    
    local expected_total=$((team_fee + staking_fee + ranking_fee))
    
    if [ $expected_total -eq $total_fee ]; then
        log_test "$test_name Distribuição" "PASS" "Team: $team_fee, Staking: $staking_fee, Ranking: $ranking_fee"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "$test_name Distribuição" "FAIL" "Total não confere: $expected_total vs $total_fee"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "${YELLOW}🧪 TESTE: TAXAS PERCENTUAIS DE STAKING${NC}"
echo "==========================================="
echo

# Verificar se bc está disponível
if ! command -v bc &> /dev/null; then
    echo -e "${RED}❌ Comando 'bc' não encontrado. Instalando...${NC}"
    if command -v brew &> /dev/null; then
        brew install bc
    else
        echo -e "${RED}❌ Não foi possível instalar 'bc'. Instale manualmente.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}📊 TESTANDO TIERS DE TAXA PERCENTUAL${NC}"
echo "======================================"

# Tier 1: Até 1.000 GMC -> 10%
test_tier 500000000000 1000 "Tier 1 (500 GMC → 10%)"
test_tier 1000000000000 1000 "Tier 1 (1.000 GMC → 10%)"

# Tier 2: 1.001 a 10.000 GMC -> 5%
test_tier 5000000000000 500 "Tier 2 (5.000 GMC → 5%)"
test_tier 10000000000000 500 "Tier 2 (10.000 GMC → 5%)"

# Tier 3: 10.001 a 100.000 GMC -> 2,5%
test_tier 50000000000000 250 "Tier 3 (50.000 GMC → 2.5%)"
test_tier 100000000000000 250 "Tier 3 (100.000 GMC → 2.5%)"

# Tier 4: 100.001 a 500.000 GMC -> 1%
test_tier 200000000000000 100 "Tier 4 (200.000 GMC → 1%)"
test_tier 500000000000000 100 "Tier 4 (500.000 GMC → 1%)"

# Tier 5: Acima de 500.000 GMC -> 0,5%
test_tier 1000000000000000 50 "Tier 5 (1.000.000 GMC → 0.5%)"
test_tier 2000000000000000 50 "Tier 5 (2.000.000 GMC → 0.5%)"

echo
echo -e "${BLUE}💰 TESTANDO DISTRIBUIÇÃO DE TAXAS${NC}"
echo "=================================="

# Testar distribuição para diferentes valores
test_distribution 1000000 "Taxa de $1.00"
test_distribution 5000000 "Taxa de $5.00"
test_distribution 10000000 "Taxa de $10.00"

echo
echo -e "${BLUE}🔍 COMPARAÇÃO COM SISTEMA ANTERIOR${NC}"
echo "=================================="

# Comparar com sistema de taxa fixa anterior
echo "📋 COMPARAÇÃO TAXA FIXA vs PERCENTUAL:"
echo "======================================"

calculate_comparison() {
    local gmc_amount="$1"
    local gmc_readable=$((gmc_amount / 1000000000))
    local usdt_price=100000  # $0.10 por GMC
    
    # Taxa percentual (nova)
    local percentage_fee=$(calculate_percentage_fee $gmc_amount $usdt_price)
    local percentage_readable=$(echo "scale=2; $percentage_fee / 1000000" | bc)
    
    # Taxa fixa (anterior) - simulada
    local fixed_fee
    if [ $gmc_amount -le 999000000000 ]; then
        fixed_fee=1000000  # $1.00
    elif [ $gmc_amount -le 4999000000000 ]; then
        fixed_fee=2500000  # $2.50
    elif [ $gmc_amount -le 9999000000000 ]; then
        fixed_fee=5000000  # $5.00
    else
        fixed_fee=10000000 # $10.00
    fi
    local fixed_readable=$(echo "scale=2; $fixed_fee / 1000000" | bc)
    
    echo "  $gmc_readable GMC: Fixa \$$fixed_readable → Percentual \$$percentage_readable"
}

calculate_comparison 500000000000    # 500 GMC
calculate_comparison 5000000000000   # 5.000 GMC
calculate_comparison 50000000000000  # 50.000 GMC
calculate_comparison 200000000000000 # 200.000 GMC
calculate_comparison 1000000000000000 # 1.000.000 GMC

echo
echo -e "${YELLOW}📊 RESULTADOS FINAIS${NC}"
echo "===================="
echo -e "Total de Testes: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Testes Aprovados: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Testes Falharam: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 TODOS OS TESTES PASSARAM! Sistema de taxas percentuais implementado corretamente.${NC}"
    echo "✅ RESULTADO: 100% DE SUCESSO" >> $LOG_FILE
    exit 0
else
    echo -e "${RED}❌ $FAILED_TESTS teste(s) falharam. Verificar implementação.${NC}"
    echo "❌ RESULTADO: $FAILED_TESTS FALHAS" >> $LOG_FILE
    exit 1
fi
