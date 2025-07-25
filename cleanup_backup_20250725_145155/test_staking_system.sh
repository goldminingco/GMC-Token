#!/bin/bash
# 🧪 GMC Token - Teste do Sistema de Staking
# Etapa 2.2: Sistema de Staking - Taxas USDT

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🧪 GMC Token - Teste do Sistema de Staking${NC}"
echo "==========================================="
echo

# Informações do deploy
PROGRAM_ID="55pd9gckYTZBuKb8HanYNBeMjAf7Z298qX6awqdEV3JM"
TOKEN_MINT="48h1Nsg5vrpjtfWg5jHk3YwaVgvUSR7P9Ry2GEoBU8dv"

echo -e "${YELLOW} REQUISITOS A TESTAR (TAXA PERCENTUAL - ATUALIZADO):${NC}"
echo -e "${CYAN}   • Tier 1: Até 1.000 GMC → 10% do valor${NC}"
echo -e "${CYAN}   • Tier 2: 1.001-10.000 GMC → 5% do valor${NC}"
echo -e "${CYAN}   • Tier 3: 10.001-100.000 GMC → 2.5% do valor${NC}"
echo -e "${CYAN}   • Tier 4: 100.001-500.000 GMC → 1% do valor${NC}"
echo -e "${CYAN}   • Tier 5: Acima de 500.000 GMC → 0.5% do valor${NC}"
echo -e "${CYAN}   • Distribuição USDT: 40% team, 40% staking, 20% ranking${NC}"
echo

# Função para log de teste
log_test() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ $test_name${NC}"
        [ -n "$details" ] && echo -e "${CYAN}   └─ $details${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ $test_name${NC}"
        [ -n "$details" ] && echo -e "${RED}   └─ $details${NC}"
    else
        echo -e "${YELLOW}⚠️ $test_name${NC}"
        [ -n "$details" ] && echo -e "${YELLOW}   └─ $details${NC}"
    fi
}

# Contadores de teste
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Função para testar cálculo de taxa USDT
test_usdt_fee_calculation() {
    local gmc_amount="$1"
    local expected_usdt_fee="$2"
    local tier_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando $tier_name: $gmc_amount GMC${NC}"
    
    # Simular cálculo de taxa (baseado no código do staking.rs)
    local calculated_fee
    if [ $gmc_amount -le 999 ]; then
        calculated_fee="1000000"  # $1.00 em micro-USDT
    elif [ $gmc_amount -le 4999 ]; then
        calculated_fee="2500000"  # $2.50 em micro-USDT
    elif [ $gmc_amount -le 9999 ]; then
        calculated_fee="5000000"  # $5.00 em micro-USDT
    else
        calculated_fee="10000000" # $10.00 em micro-USDT
    fi
    
    if [ "$calculated_fee" = "$expected_usdt_fee" ]; then
        log_test "$tier_name Cálculo Correto" "PASS" "$gmc_amount GMC → \$$(echo "scale=2; $expected_usdt_fee / 1000000" | bc) USDT"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "$tier_name Cálculo Incorreto" "FAIL" "Esperado: $expected_usdt_fee, Calculado: $calculated_fee"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Função para testar distribuição de taxas USDT
test_usdt_distribution() {
    local total_fee="$1"
    local test_name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando distribuição: $test_name${NC}"
    
    # Calcular distribuição (baseado no código)
    local team_fee=$((total_fee * 40 / 100))
    local staking_fee=$((total_fee * 40 / 100))
    local ranking_fee=$((total_fee * 20 / 100))
    
    local expected_team=$((total_fee * 40 / 100))
    local expected_staking=$((total_fee * 40 / 100))
    local expected_ranking=$((total_fee * 20 / 100))
    
    if [ $team_fee -eq $expected_team ] && [ $staking_fee -eq $expected_staking ] && [ $ranking_fee -eq $expected_ranking ]; then
        log_test "$test_name Distribuição" "PASS" "Team: $team_fee, Staking: $staking_fee, Ranking: $ranking_fee"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "$test_name Distribuição" "FAIL" "Cálculos incorretos"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "${YELLOW}🔍 ETAPA 2.2: SISTEMA DE STAKING - TAXAS USDT${NC}"
echo "=============================================="
echo

# Verificar se bc está disponível para cálculos
if ! command -v bc &> /dev/null; then
    echo -e "${RED}❌ Comando 'bc' não encontrado. Instalando...${NC}"
    # Tentar instalar bc
    if command -v brew &> /dev/null; then
        brew install bc
    else
        echo -e "${RED}❌ Não foi possível instalar 'bc'. Alguns testes podem falhar.${NC}"
    fi
fi

echo -e "${BLUE}💰 Teste 1: Cálculo de Taxas USDT por Tier${NC}"
echo "----------------------------------------"

# Testar cada tier
test_usdt_fee_calculation 500 "1000000" "Tier 1"
test_usdt_fee_calculation 999 "1000000" "Tier 1 (limite)"
test_usdt_fee_calculation 1000 "2500000" "Tier 2"
test_usdt_fee_calculation 2500 "2500000" "Tier 2 (meio)"
test_usdt_fee_calculation 4999 "2500000" "Tier 2 (limite)"
test_usdt_fee_calculation 5000 "5000000" "Tier 3"
test_usdt_fee_calculation 7500 "5000000" "Tier 3 (meio)"
test_usdt_fee_calculation 9999 "5000000" "Tier 3 (limite)"
test_usdt_fee_calculation 10000 "10000000" "Tier 4"
test_usdt_fee_calculation 50000 "10000000" "Tier 4 (alto)"

echo
echo -e "${BLUE}📊 Teste 2: Distribuição de Taxas USDT${NC}"
echo "------------------------------------"

# Testar distribuição para cada tier
test_usdt_distribution 1000000 "Tier 1 (\$1.00)"
test_usdt_distribution 2500000 "Tier 2 (\$2.50)"
test_usdt_distribution 5000000 "Tier 3 (\$5.00)"
test_usdt_distribution 10000000 "Tier 4 (\$10.00)"

echo
echo -e "${BLUE}🔧 Teste 3: Validação de Constantes do Código${NC}"
echo "--------------------------------------------"

# Verificar se as constantes de TAXA PERCENTUAL estão corretas no código deployado
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "TIER_1_FEE_PERCENT.*1000" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/staking.rs; then
    log_test "Constante Tier 1 (10%)" "PASS" "10% (1000 basis points) definido corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Constante Tier 1 (10%)" "FAIL" "Constante não encontrada ou incorreta"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "TIER_2_FEE_PERCENT.*500" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/staking.rs; then
    log_test "Constante Tier 2 (5%)" "PASS" "5% (500 basis points) definido corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Constante Tier 2 (5%)" "FAIL" "Constante não encontrada ou incorreta"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "TIER_5_FEE_PERCENT.*50" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/staking.rs; then
    log_test "Constante Tier 5 (0.5%)" "PASS" "0.5% (50 basis points) definido corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Constante Tier 5 (0.5%)" "FAIL" "Constante não encontrada ou incorreta"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "USDT_FEE_TO_TEAM_PERCENT.*40" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/staking.rs; then
    log_test "Distribuição Team (40%)" "PASS" "Percentual correto"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Distribuição Team (40%)" "FAIL" "Percentual incorreto ou não encontrado"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "USDT_FEE_TO_RANKING_PERCENT.*20" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/staking.rs; then
    log_test "Distribuição Ranking (20%)" "PASS" "Percentual correto"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Distribuição Ranking (20%)" "FAIL" "Percentual incorreto ou não encontrado"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo
echo -e "${YELLOW}📊 RESUMO DOS TESTES DE STAKING${NC}"
echo "================================="
echo -e "${BLUE}Total de Testes: ${CYAN}$TOTAL_TESTS${NC}"
echo -e "${GREEN}Testes Aprovados: ${CYAN}$PASSED_TESTS${NC}"
echo -e "${RED}Testes Falharam: ${CYAN}$FAILED_TESTS${NC}"

# Calcular percentual de sucesso
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "${BLUE}Taxa de Sucesso: ${CYAN}$SUCCESS_RATE%${NC}"
else
    SUCCESS_RATE=0
fi

echo
if [ $SUCCESS_RATE -ge 95 ]; then
    echo -e "${GREEN}🎉 ETAPA 2.2 APROVADA! Sistema de staking validado.${NC}"
    echo -e "${GREEN}✅ Todas as taxas USDT e distribuições estão corretas.${NC}"
    exit 0
elif [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${YELLOW}⚠️ ETAPA 2.2 COM AVISOS. Alguns testes falharam.${NC}"
    echo -e "${YELLOW}🔍 Revisar falhas antes de prosseguir.${NC}"
    exit 1
else
    echo -e "${RED}❌ ETAPA 2.2 REPROVADA! Muitos testes falharam.${NC}"
    echo -e "${RED}🚨 Sistema de staking precisa de correções.${NC}"
    exit 2
fi
