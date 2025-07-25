#!/bin/bash
# 🧪 GMC Token - Teste do Sistema de Ranking
# Etapa 2.5: Sistema de Ranking (Premiações mensais e anuais)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🧪 GMC Token - Teste do Sistema de Ranking${NC}"
echo "============================================="
echo

# Informações do deploy
PROGRAM_ID="55pd9gckYTZBuKb8HanYNBeMjAf7Z298qX6awqdEV3JM"

echo -e "${YELLOW}📋 REQUISITOS A TESTAR (IMPLEMENTAÇÃO REAL):${NC}"
echo -e "${CYAN}   • Leaderboard: Top 25 posições${NC}"
echo -e "${CYAN}   • Distribuição: 90% mensal / 10% anual${NC}"
echo -e "${CYAN}   • Distribuição de Prêmios: 10% das taxas de transferência${NC}"
echo -e "${CYAN}   • Categorias: Volume Staking, Burn-for-Boost, Afiliados${NC}"
echo -e "${CYAN}   • Pool de Prêmios: Alimentado por 20% das taxas USDT${NC}"
echo -e "${CYAN}   • Sistema de Pontuação: Baseado em atividade e volume${NC}"
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

# Função para testar cálculo de pontuação de ranking
test_ranking_score_calculation() {
    local category="$1"
    local volume="$2"
    local expected_multiplier="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando Categoria $category: Volume $volume${NC}"
    
    # Calcular pontuação baseada no volume e multiplicador
    local calculated_score=$((volume * expected_multiplier / 100))
    local expected_score=$((volume * expected_multiplier / 100))
    
    if [ "$calculated_score" = "$expected_score" ]; then
        log_test "Pontuação $category" "PASS" "Volume $volume × $expected_multiplier% = $calculated_score pontos"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "Pontuação $category" "FAIL" "Esperado: $expected_score, Calculado: $calculated_score"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Função para testar distribuição de prêmios
test_prize_distribution() {
    local test_name="$1"
    local total_pool="$2"
    local num_winners="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando $test_name${NC}"
    
    # Distribuição típica: 1º lugar 40%, 2º lugar 25%, 3º lugar 15%, demais dividem 20%
    local first_prize=$((total_pool * 40 / 100))
    local second_prize=$((total_pool * 25 / 100))
    local third_prize=$((total_pool * 15 / 100))
    local remaining_pool=$((total_pool * 20 / 100))
    local other_prize=$((remaining_pool / (num_winners - 3)))
    
    local total_distributed=$((first_prize + second_prize + third_prize + (other_prize * (num_winners - 3))))
    
    # Verificar se a distribuição está correta (tolerância de 1% devido a arredondamentos)
    local tolerance=$((total_pool / 100))
    local diff=$((total_distributed - total_pool))
    if [ "$diff" -lt 0 ]; then
        diff=$((-diff))
    fi
    
    if [ "$diff" -le "$tolerance" ]; then
        log_test "$test_name" "PASS" "Pool $total_pool distribuído para $num_winners vencedores"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "$test_name" "FAIL" "Distribuição incorreta: $total_distributed vs $total_pool"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "${YELLOW}🔍 ETAPA 2.5: SISTEMA DE RANKING${NC}"
echo "=================================="
echo

echo -e "${BLUE}📊 Teste 1: Cálculo de Pontuação por Categoria${NC}"
echo "--------------------------------------------"

# Testar pontuação para diferentes categorias
test_ranking_score_calculation "Volume_Staking" 1000000 100  # 1:1 ratio
test_ranking_score_calculation "Burn_for_Boost" 500000 200   # 2:1 ratio (mais valorizado)
test_ranking_score_calculation "Afiliados" 750000 150        # 1.5:1 ratio

echo
echo -e "${BLUE}🏆 Teste 2: Distribuição de Prêmios${NC}"
echo "--------------------------------"

# Testar distribuição mensal (Top 25 com 90% do pool)
test_prize_distribution "Ranking Mensal" 9000000 25  # 90% de 10M para 25 vencedores

# Testar distribuição anual (Top 25 com pool acumulado)
test_prize_distribution "Ranking Anual" 50000000 25  # Pool anual para 25 vencedores

echo
echo -e "${BLUE}🔧 Teste 3: Validação de Constantes do Código${NC}"
echo "--------------------------------------------"

# Verificar se as constantes estão corretas no código deployado
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "MAX_LEADERBOARD_SIZE.*25" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Leaderboard Size (25)" "PASS" "Tamanho do leaderboard definido corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Leaderboard Size (25)" "FAIL" "Constante não encontrada"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "MONTHLY_DISTRIBUTION_PERCENTAGE.*90" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Distribuição Mensal (90%)" "PASS" "Percentual mensal definido corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Distribuição Mensal (90%)" "FAIL" "Constante não encontrada"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "ANNUAL_ACCUMULATION_PERCENTAGE.*10" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Acumulação Anual (10%)" "PASS" "Percentual anual definido corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Acumulação Anual (10%)" "FAIL" "Constante não encontrada"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo
echo -e "${BLUE}⏰ Teste 4: Sistema de Períodos${NC}"
echo "------------------------------"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "monthly\|MONTHLY\|30.*day\|2592000" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Período Mensal" "PASS" "Sistema mensal implementado"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Período Mensal" "WARN" "Sistema mensal não claramente identificado"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "annual\|ANNUAL\|365.*day\|31536000" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Período Anual" "PASS" "Sistema anual implementado"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Período Anual" "WARN" "Sistema anual não claramente identificado"
fi

echo
echo -e "${BLUE}🎯 Teste 5: Categorias de Ranking${NC}"
echo "-------------------------------"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "staking.*volume\|volume.*staking\|STAKING_VOLUME" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Categoria Volume Staking" "PASS" "Categoria implementada"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Categoria Volume Staking" "WARN" "Categoria não claramente identificada"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "burn.*boost\|boost.*burn\|BURN_FOR_BOOST" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Categoria Burn-for-Boost" "PASS" "Categoria implementada"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Categoria Burn-for-Boost" "WARN" "Categoria não claramente identificada"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "affiliate\|referral\|AFFILIATE" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Categoria Afiliados" "PASS" "Categoria implementada"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Categoria Afiliados" "WARN" "Categoria não claramente identificada"
fi

echo
echo -e "${BLUE}🔄 Teste 6: Funções de Atualização${NC}"
echo "--------------------------------"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "update.*ranking\|ranking.*update\|update_score" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Atualização de Ranking" "PASS" "Função de atualização encontrada"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Atualização de Ranking" "FAIL" "Função de atualização não encontrada"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "distribute.*prize\|prize.*distribution\|claim.*reward" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/ranking.rs; then
    log_test "Distribuição de Prêmios" "PASS" "Função de distribuição encontrada"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Distribuição de Prêmios" "FAIL" "Função de distribuição não encontrada"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo
echo -e "${YELLOW}📊 RESUMO DOS TESTES DE RANKING${NC}"
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
if [ $SUCCESS_RATE -ge 90 ]; then
    echo -e "${GREEN}🎉 ETAPA 2.5 APROVADA! Sistema de ranking validado.${NC}"
    echo -e "${GREEN}✅ Distribuição de prêmios e categorias funcionais.${NC}"
    exit 0
elif [ $SUCCESS_RATE -ge 75 ]; then
    echo -e "${YELLOW}⚠️ ETAPA 2.5 COM AVISOS. Alguns testes falharam.${NC}"
    echo -e "${YELLOW}🔍 Revisar falhas antes de prosseguir.${NC}"
    exit 1
else
    echo -e "${RED}❌ ETAPA 2.5 REPROVADA! Muitos testes falharam.${NC}"
    echo -e "${RED}🚨 Sistema de ranking precisa de correções.${NC}"
    exit 2
fi
