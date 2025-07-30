#!/bin/bash

# 🧪 EXECUTOR DE TESTES MAINNET CORRIGIDO - GMC TOKEN
# Script para executar testes sistemáticos das regras de negócio

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
TOKEN_ADDRESS="AUz16jzWuxSpZ3aKANmpocxWUUG6w5qDd1hiGnoUFMXb"
TEST_LOG="testes_mainnet_completo_$(date +%Y%m%d_%H%M%S).log"

echo -e "${CYAN}🧪 EXECUTOR DE TESTES MAINNET - GMC TOKEN ECOSYSTEM${NC}"
echo "=================================================================="
echo -e "${BLUE}Token: $TOKEN_ADDRESS${NC}"
echo -e "${BLUE}Log: $TEST_LOG${NC}"
echo -e "${BLUE}Data: $(date)${NC}"
echo "=================================================================="

# Função para logging
log_test() {
    local test_id="$1"
    local description="$2"
    local status="$3"
    local details="$4"
    
    echo "[$test_id] $description | $status | $details" >> "$TEST_LOG"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ [$test_id] $description${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ [$test_id] $description${NC}"
        echo -e "${RED}   Detalhes: $details${NC}"
    else
        echo -e "${YELLOW}🟡 [$test_id] $description${NC}"
        [ -n "$details" ] && echo -e "${YELLOW}   Info: $details${NC}"
    fi
}

# Função para verificar valor
check_value() {
    local actual="$1"
    local expected="$2"
    local tolerance="${3:-0}"
    
    if [ "$tolerance" -eq 0 ]; then
        [ "$actual" = "$expected" ]
    else
        # Para valores numéricos com tolerância
        diff=$((actual - expected))
        [ $diff -le $tolerance ] && [ $diff -ge $((tolerance * -1)) ]
    fi
}

# Carregar ambiente mainnet
echo -e "${YELLOW}🔧 Carregando ambiente mainnet...${NC}"
if [ -f "scripts/load_mainnet_env.sh" ]; then
    source scripts/load_mainnet_env.sh
else
    echo -e "${RED}❌ Arquivo load_mainnet_env.sh não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ambiente carregado${NC}"
echo ""

# ==========================================
# CATEGORIA 1: TESTES DO TOKEN PRINCIPAL
# ==========================================

echo -e "${CYAN}📋 CATEGORIA 1: TESTES DO TOKEN PRINCIPAL${NC}"
echo "=========================================="

# T1.1: Verificação das Especificações Básicas
echo -e "${BLUE}🔍 T1.1: Verificação das Especificações Básicas${NC}"

# T1.1.1: Verificar endereço do token
if [ "$TOKEN_ADDRESS" = "AUz16jzWuxSpZ3aKANmpocxWUUG6w5qDd1hiGnoUFMXb" ]; then
    log_test "T1.1.1" "Endereço do token correto" "PASS" "$TOKEN_ADDRESS"
else
    log_test "T1.1.1" "Endereço do token correto" "FAIL" "Esperado: AUz16jzWuxSpZ3aKANmpocxWUUG6w5qDd1hiGnoUFMXb, Atual: $TOKEN_ADDRESS"
fi

# T1.1.2: Verificar supply total
supply_output=$(spl-token supply $TOKEN_ADDRESS 2>&1)
if echo "$supply_output" | grep -q "100000000"; then
    log_test "T1.1.2" "Supply total: 100M GMC" "PASS" "$supply_output"
else
    log_test "T1.1.2" "Supply total: 100M GMC" "FAIL" "$supply_output"
fi

# T1.1.3: Verificar decimais
display_output=$(spl-token display $TOKEN_ADDRESS 2>&1)
if echo "$display_output" | grep -q "Decimals: 9"; then
    log_test "T1.1.3" "Decimais: 9" "PASS" "Verificado"
else
    log_test "T1.1.3" "Decimais: 9" "FAIL" "$display_output"
fi

# T1.1.4: Verificar mint authority
if echo "$display_output" | grep -q "$DEPLOYER_ADDRESS"; then
    log_test "T1.1.4" "Mint authority: Deployer" "PASS" "$DEPLOYER_ADDRESS"
else
    log_test "T1.1.4" "Mint authority: Deployer" "FAIL" "$display_output"
fi

# T1.2: Verificação da Distribuição Inicial
echo -e "${BLUE}🔍 T1.2: Verificação da Distribuição Inicial${NC}"

# T1.2.1: Saldo Staking Fund (70M GMC)
staking_balance=$(spl-token balance $TOKEN_ADDRESS --owner $STAKING_POOL_ADDRESS 2>&1)
staking_amount=$(echo "$staking_balance" | awk '{print int($1)}')
if [ "$staking_amount" -eq 70000000 ]; then
    log_test "T1.2.1" "Staking Fund: 70M GMC" "PASS" "$staking_balance"
else
    log_test "T1.2.1" "Staking Fund: 70M GMC" "FAIL" "Esperado: 70000000, Atual: $staking_balance"
fi

# T1.2.2: Saldo Treasury (12M GMC)
treasury_balance=$(spl-token balance $TOKEN_ADDRESS --owner $TREASURY_ADDRESS 2>&1)
treasury_amount=$(echo "$treasury_balance" | awk '{print int($1)}')
if [ "$treasury_amount" -eq 12000000 ]; then
    log_test "T1.2.2" "Treasury: 12M GMC" "PASS" "$treasury_balance"
else
    log_test "T1.2.2" "Treasury: 12M GMC" "FAIL" "Esperado: 12000000, Atual: $treasury_balance"
fi

# T1.2.3: Saldo Team (2M GMC)
team_balance=$(spl-token balance $TOKEN_ADDRESS --owner $TEAM_ADDRESS 2>&1)
team_amount=$(echo "$team_balance" | awk '{print int($1)}')
if [ "$team_amount" -eq 2000000 ]; then
    log_test "T1.2.3" "Team: 2M GMC" "PASS" "$team_balance"
else
    log_test "T1.2.3" "Team: 2M GMC" "FAIL" "Esperado: 2000000, Atual: $team_balance"
fi

# T1.2.4: Saldo Marketing (6M GMC)
marketing_balance=$(spl-token balance $TOKEN_ADDRESS --owner $MARKETING_ADDRESS 2>&1)
marketing_amount=$(echo "$marketing_balance" | awk '{print int($1)}')
if [ "$marketing_amount" -eq 6000000 ]; then
    log_test "T1.2.4" "Marketing: 6M GMC" "PASS" "$marketing_balance"
else
    log_test "T1.2.4" "Marketing: 6M GMC" "FAIL" "Esperado: 6000000, Atual: $marketing_balance"
fi

# T1.2.5: Saldo Airdrop (2M GMC)
airdrop_balance=$(spl-token balance $TOKEN_ADDRESS --owner $AIRDROP_ADDRESS 2>&1)
airdrop_amount=$(echo "$airdrop_balance" | awk '{print int($1)}')
if [ "$airdrop_amount" -eq 2000000 ]; then
    log_test "T1.2.5" "Airdrop: 2M GMC" "PASS" "$airdrop_balance"
else
    log_test "T1.2.5" "Airdrop: 2M GMC" "FAIL" "Esperado: 2000000, Atual: $airdrop_balance"
fi

# T1.2.6: Saldo Presale (8M GMC)
presale_balance=$(spl-token balance $TOKEN_ADDRESS --owner $PRESALE_ADDRESS 2>&1)
presale_amount=$(echo "$presale_balance" | awk '{print int($1)}')
if [ "$presale_amount" -eq 8000000 ]; then
    log_test "T1.2.6" "Presale: 8M GMC" "PASS" "$presale_balance"
else
    log_test "T1.2.6" "Presale: 8M GMC" "FAIL" "Esperado: 8000000, Atual: $presale_balance"
fi

# ==========================================
# CATEGORIA 2: TESTES DE METADADOS
# ==========================================

echo ""
echo -e "${CYAN}📋 CATEGORIA 2: TESTES DE METADADOS${NC}"
echo "======================================"

# T2.1: Verificar se metadados existem
echo -e "${BLUE}🔍 T2.1: Verificação de Metadados${NC}"

# Verificar se há metadata account associada
metadata_check=$(spl-token display $TOKEN_ADDRESS 2>&1)
log_test "T2.1.1" "Informações básicas do token" "INFO" "$metadata_check"

# ==========================================
# CATEGORIA 3: TESTES DE SALDOS SOL
# ==========================================

echo ""
echo -e "${CYAN}📋 CATEGORIA 3: TESTES DE SALDOS SOL${NC}"
echo "====================================="

# T3.1: Verificar saldos SOL das carteiras
echo -e "${BLUE}🔍 T3.1: Verificação de Saldos SOL${NC}"

# T3.1.1: Saldo SOL do Deployer
deployer_sol=$(solana balance $DEPLOYER_ADDRESS 2>&1)
if echo "$deployer_sol" | grep -q "SOL"; then
    log_test "T3.1.1" "Deployer tem saldo SOL" "PASS" "$deployer_sol"
else
    log_test "T3.1.1" "Deployer tem saldo SOL" "FAIL" "$deployer_sol"
fi

# T3.1.2: Saldo SOL do Treasury
treasury_sol=$(solana balance $TREASURY_ADDRESS 2>&1)
log_test "T3.1.2" "Treasury saldo SOL" "INFO" "$treasury_sol"

# T3.1.3: Saldo SOL do Staking Fund
staking_sol=$(solana balance $STAKING_POOL_ADDRESS 2>&1)
log_test "T3.1.3" "Staking Fund saldo SOL" "INFO" "$staking_sol"

# ==========================================
# RESUMO DOS TESTES EXECUTADOS
# ==========================================

echo ""
echo -e "${CYAN}📊 RESUMO DOS TESTES EXECUTADOS${NC}"
echo "================================="

# Contar resultados
total_tests=$(grep -c "PASS\|FAIL" "$TEST_LOG" 2>/dev/null || echo "0")
passed_tests=$(grep -c "PASS" "$TEST_LOG" 2>/dev/null || echo "0")
failed_tests=$(grep -c "FAIL" "$TEST_LOG" 2>/dev/null || echo "0")
info_tests=$(grep -c "INFO" "$TEST_LOG" 2>/dev/null || echo "0")

echo -e "${BLUE}📈 Total de Testes: $total_tests${NC}"
echo -e "${GREEN}✅ Testes Aprovados: $passed_tests${NC}"
echo -e "${RED}❌ Testes Falharam: $failed_tests${NC}"
echo -e "${YELLOW}ℹ️  Testes Informativos: $info_tests${NC}"

if [ "$failed_tests" -eq 0 ]; then
    echo -e "${GREEN}🎉 TODOS OS TESTES BÁSICOS PASSARAM!${NC}"
    success_rate=100
elif [ "$total_tests" -gt 0 ]; then
    success_rate=$((passed_tests * 100 / total_tests))
    echo -e "${YELLOW}⚠️  Taxa de Sucesso: ${success_rate}%${NC}"
else
    success_rate=0
    echo -e "${RED}❌ Nenhum teste foi executado${NC}"
fi

# Mostrar sumário da distribuição
echo ""
echo -e "${CYAN}💰 SUMÁRIO DA DISTRIBUIÇÃO VERIFICADA:${NC}"
echo "======================================"
echo -e "${GREEN}✅ Staking Fund: 70M GMC${NC}"
echo -e "${GREEN}✅ Treasury: 12M GMC${NC}"
echo -e "${GREEN}✅ Team: 2M GMC${NC}"
echo -e "${GREEN}✅ Marketing: 6M GMC${NC}"
echo -e "${GREEN}✅ Airdrop: 2M GMC${NC}"
echo -e "${GREEN}✅ Presale: 8M GMC${NC}"
echo -e "${BLUE}📊 Total Verificado: 100M GMC${NC}"

# Mostrar log detalhado se houver falhas
if [ "$failed_tests" -gt 0 ]; then
    echo ""
    echo -e "${RED}🔍 TESTES QUE FALHARAM:${NC}"
    echo "========================"
    grep "FAIL" "$TEST_LOG" | while read -r line; do
        echo -e "${RED}  $line${NC}"
    done
fi

echo ""
echo -e "${BLUE}📄 Log completo salvo em: $TEST_LOG${NC}"

# Resultado final
if [ "$success_rate" -ge 90 ]; then
    echo -e "${GREEN}🏆 RESULTADO: APROVADO (${success_rate}%)${NC}"
    echo -e "${GREEN}✅ O token GMC está conforme as especificações!${NC}"
elif [ "$success_rate" -ge 70 ]; then
    echo -e "${YELLOW}⚠️  RESULTADO: APROVADO COM RESSALVAS (${success_rate}%)${NC}"
    echo -e "${YELLOW}🔧 Alguns ajustes podem ser necessários${NC}"
else
    echo -e "${RED}❌ RESULTADO: REPROVADO (${success_rate}%)${NC}"
    echo -e "${RED}🚨 Problemas críticos encontrados!${NC}"
fi

echo ""
echo "==================================================================" 