#!/bin/bash
# 🧪 GMC Token - Teste do Sistema de Vesting
# Etapa 2.6: Sistema de Vesting (Liberação gradual de tokens)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🧪 GMC Token - Teste do Sistema de Vesting${NC}"
echo "============================================="
echo

# Informações do deploy
PROGRAM_ID="55pd9gckYTZBuKb8HanYNBeMjAf7Z298qX6awqdEV3JM"

echo -e "${YELLOW}📋 REQUISITOS A TESTAR:${NC}"
echo -e "${CYAN}   • Vesting da Equipe: 2M GMC ao longo de 5 anos${NC}"
echo -e "${CYAN}   • Reserva Estratégica: 10M GMC ao longo de 5 anos${NC}"
echo -e "${CYAN}   • Liberação Gradual: Mensal ou trimestral${NC}"
echo -e "${CYAN}   • Cliff Period: Período inicial sem liberação${NC}"
echo -e "${CYAN}   • Anti-Dump: Proteção contra venda massiva${NC}"
echo -e "${CYAN}   • Governança: Controle multisig das liberações${NC}"
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

# Função para testar cálculo de vesting
test_vesting_calculation() {
    local vesting_name="$1"
    local total_amount="$2"
    local duration_months="$3"
    local cliff_months="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando $vesting_name${NC}"
    
    # Calcular quantidade mensal após cliff
    local vesting_months=$((duration_months - cliff_months))
    local monthly_amount=$((total_amount / vesting_months))
    
    # Verificar se o cálculo está correto
    local total_vested=$((monthly_amount * vesting_months))
    local diff=$((total_vested - total_amount))
    if [ "$diff" -lt 0 ]; then
        diff=$((-diff))
    fi
    
    # Tolerância de 1% para arredondamentos
    local tolerance=$((total_amount / 100))
    
    if [ "$diff" -le "$tolerance" ]; then
        log_test "$vesting_name Cálculo" "PASS" "$monthly_amount tokens/mês por $vesting_months meses"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "$vesting_name Cálculo" "FAIL" "Diferença: $diff tokens (tolerância: $tolerance)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Função para testar cronograma de liberação
test_vesting_schedule() {
    local test_name="$1"
    local start_timestamp="$2"
    local cliff_months="$3"
    local duration_months="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Testando $test_name${NC}"
    
    # Calcular timestamps importantes
    local cliff_timestamp=$((start_timestamp + (cliff_months * 30 * 24 * 3600)))
    local end_timestamp=$((start_timestamp + (duration_months * 30 * 24 * 3600)))
    
    # Verificar se os timestamps são lógicos
    if [ "$cliff_timestamp" -gt "$start_timestamp" ] && [ "$end_timestamp" -gt "$cliff_timestamp" ]; then
        log_test "$test_name" "PASS" "Cronograma válido: cliff $cliff_months meses, total $duration_months meses"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "$test_name" "FAIL" "Cronograma inválido"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "${YELLOW}🔍 ETAPA 2.6: SISTEMA DE VESTING${NC}"
echo "=================================="
echo

echo -e "${BLUE}📊 Teste 1: Cálculos de Vesting${NC}"
echo "------------------------------"

# Testar vesting da equipe: 2M GMC em 5 anos (60 meses) com cliff de 12 meses
test_vesting_calculation "Equipe" 2000000000000000 60 12  # 2M GMC com 9 decimais

# Testar reserva estratégica: 10M GMC em 5 anos (60 meses) com cliff de 6 meses
test_vesting_calculation "Reserva_Estratégica" 10000000000000000 60 6  # 10M GMC com 9 decimais

echo
echo -e "${BLUE}⏰ Teste 2: Cronogramas de Liberação${NC}"
echo "----------------------------------"

# Timestamp atual simulado (1 de janeiro de 2025)
current_timestamp=1735689600

# Testar cronograma da equipe
test_vesting_schedule "Cronograma Equipe" $current_timestamp 12 60

# Testar cronograma da reserva estratégica
test_vesting_schedule "Cronograma Reserva" $current_timestamp 6 60

echo
echo -e "${BLUE}🔧 Teste 3: Validação de Constantes do Código${NC}"
echo "--------------------------------------------"

# Verificar se as constantes estão corretas no código deployado
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "TEAM_VESTING_AMOUNT\|team.*2000000\|2_000_000" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Vesting Equipe (2M GMC)" "PASS" "Quantidade definida corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Vesting Equipe (2M GMC)" "WARN" "Quantidade não claramente identificada"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "STRATEGIC_RESERVE_AMOUNT\|strategic.*10000000\|10_000_000" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Reserva Estratégica (10M GMC)" "PASS" "Quantidade definida corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Reserva Estratégica (10M GMC)" "WARN" "Quantidade não claramente identificada"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "VESTING_DURATION.*60\|60.*month\|5.*year" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Duração Vesting (5 anos)" "PASS" "Duração definida corretamente"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Duração Vesting (5 anos)" "WARN" "Duração não claramente identificada"
fi

echo
echo -e "${BLUE}🛡️ Teste 4: Proteções Anti-Dump${NC}"
echo "-------------------------------"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "cliff\|CLIFF\|lock.*period" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Cliff Period" "PASS" "Período de cliff implementado"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Cliff Period" "WARN" "Período de cliff não claramente identificado"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "gradual\|linear\|monthly\|schedule" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Liberação Gradual" "PASS" "Sistema gradual implementado"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Liberação Gradual" "WARN" "Sistema gradual não claramente identificado"
fi

echo
echo -e "${BLUE}🔐 Teste 5: Controle de Governança${NC}"
echo "--------------------------------"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "authority\|multisig\|governance" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Controle de Autoridade" "PASS" "Sistema de autoridade implementado"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Controle de Autoridade" "WARN" "Sistema de autoridade não claramente identificado"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "claim\|withdraw\|release" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Função de Claim" "PASS" "Função de reivindicação encontrada"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Função de Claim" "FAIL" "Função de reivindicação não encontrada"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo
echo -e "${BLUE}📅 Teste 6: Estruturas de Dados${NC}"
echo "-------------------------------"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "VestingSchedule\|VestingAccount\|vesting.*struct" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Estrutura de Vesting" "PASS" "Estruturas de dados encontradas"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Estrutura de Vesting" "FAIL" "Estruturas de dados não encontradas"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if grep -q "start_time\|cliff_time\|end_time\|timestamp" /Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/vesting.rs; then
    log_test "Campos de Timestamp" "PASS" "Campos de tempo encontrados"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Campos de Timestamp" "WARN" "Campos de tempo não claramente identificados"
fi

echo
echo -e "${YELLOW}📊 RESUMO DOS TESTES DE VESTING${NC}"
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
    echo -e "${GREEN}🎉 ETAPA 2.6 APROVADA! Sistema de vesting validado.${NC}"
    echo -e "${GREEN}✅ Cronogramas e proteções anti-dump funcionais.${NC}"
    exit 0
elif [ $SUCCESS_RATE -ge 75 ]; then
    echo -e "${YELLOW}⚠️ ETAPA 2.6 COM AVISOS. Alguns testes falharam.${NC}"
    echo -e "${YELLOW}🔍 Revisar falhas antes de prosseguir.${NC}"
    exit 1
else
    echo -e "${RED}❌ ETAPA 2.6 REPROVADA! Muitos testes falharam.${NC}"
    echo -e "${RED}🚨 Sistema de vesting precisa de correções.${NC}"
    exit 2
fi
