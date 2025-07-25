#!/bin/bash
# 🧪 GMC Token - Teste de Funcionalidade Básica
# Etapa 1.1: Verificação de Deploy e Conectividade

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🧪 GMC Token - Teste de Funcionalidade Básica${NC}"
echo "=============================================="
echo

# Informações do deploy
PROGRAM_ID="55pd9gckYTZBuKb8HanYNBeMjAf7Z298qX6awqdEV3JM"
TOKEN_MINT="48h1Nsg5vrpjtfWg5jHk3YwaVgvUSR7P9Ry2GEoBU8dv"
EXPECTED_SUPPLY="100000000" # 100 milhões (spl-token exibe sem decimais)
EXPECTED_DECIMALS="9"

echo -e "${YELLOW}📋 INFORMAÇÕES DO DEPLOY:${NC}"
echo -e "${CYAN}   • Program ID: ${GREEN}$PROGRAM_ID${NC}"
echo -e "${CYAN}   • Token Mint: ${GREEN}$TOKEN_MINT${NC}"
echo -e "${CYAN}   • Expected Supply: ${GREEN}100,000,000 GMC${NC}"
echo -e "${CYAN}   • Expected Decimals: ${GREEN}$EXPECTED_DECIMALS${NC}"
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

# Função para executar teste
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}🔍 Executando: $test_name${NC}"
    
    if output=$(eval "$test_command" 2>&1); then
        if [ -n "$expected_pattern" ]; then
            if echo "$output" | grep -q "$expected_pattern"; then
                log_test "$test_name" "PASS" "Padrão encontrado: $expected_pattern"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                return 0
            else
                log_test "$test_name" "FAIL" "Padrão não encontrado: $expected_pattern"
                echo -e "${RED}Output: $output${NC}"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                return 1
            fi
        else
            log_test "$test_name" "PASS" "Comando executado com sucesso"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        fi
    else
        log_test "$test_name" "FAIL" "Comando falhou"
        echo -e "${RED}Erro: $output${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

echo -e "${YELLOW}🔍 ETAPA 1.1: VERIFICAÇÃO DE DEPLOY E CONECTIVIDADE${NC}"
echo "================================================="
echo

# Teste 1: Verificar conectividade RPC
echo -e "${BLUE}📡 Teste 1: Conectividade RPC${NC}"
run_test "Conectividade DevNet" "solana config get" "devnet"

# Teste 2: Verificar saldo da wallet deployer
echo -e "${BLUE}💰 Teste 2: Saldo da Wallet Deployer${NC}"
WALLET_ADDRESS=$(solana address)
run_test "Saldo da Wallet" "solana balance" "SOL"
echo -e "${CYAN}   └─ Wallet: $WALLET_ADDRESS${NC}"

# Teste 3: Verificar se o programa existe na rede
echo -e "${BLUE}🔍 Teste 3: Existência do Programa${NC}"
run_test "Programa Deployado" "solana program show $PROGRAM_ID" "$PROGRAM_ID"

# Teste 4: Verificar informações do token SPL
echo -e "${BLUE}🪙 Teste 4: Informações do Token SPL${NC}"
if TOKEN_INFO=$(spl-token supply "$TOKEN_MINT" 2>&1); then
    log_test "Token SPL Existe" "PASS" "Mint: $TOKEN_MINT"
    echo -e "${CYAN}   └─ Supply atual: $TOKEN_INFO${NC}"
    
    # Verificar se o supply está correto
    if echo "$TOKEN_INFO" | grep -q "$EXPECTED_SUPPLY"; then
        log_test "Supply Correto" "PASS" "100,000,000 GMC confirmado"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "Supply Correto" "FAIL" "Esperado: $EXPECTED_SUPPLY, Atual: $TOKEN_INFO"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    log_test "Token SPL Existe" "FAIL" "Erro ao consultar token: $TOKEN_INFO"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Teste 5: Verificar decimais do token
echo -e "${BLUE}🔢 Teste 5: Decimais do Token${NC}"
if TOKEN_ACCOUNT_INFO=$(spl-token account-info "$TOKEN_MINT" 2>&1); then
    if echo "$TOKEN_ACCOUNT_INFO" | grep -q "Decimals: $EXPECTED_DECIMALS"; then
        log_test "Decimais Corretos" "PASS" "$EXPECTED_DECIMALS decimais confirmados"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_test "Decimais Corretos" "FAIL" "Esperado: $EXPECTED_DECIMALS decimais"
        echo -e "${RED}Info: $TOKEN_ACCOUNT_INFO${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    log_test "Consulta de Decimais" "FAIL" "Erro ao consultar info do token"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Teste 6: Verificar se conseguimos interagir com o programa
echo -e "${BLUE}🔧 Teste 6: Interação com o Programa${NC}"
# Teste básico de chamada do programa (sem modificar estado)
if solana program show "$PROGRAM_ID" >/dev/null 2>&1; then
    log_test "Programa Acessível" "PASS" "Programa responde a consultas"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_test "Programa Acessível" "FAIL" "Programa não responde"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo
echo -e "${YELLOW}📊 RESUMO DOS TESTES BÁSICOS${NC}"
echo "================================"
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
    echo -e "${GREEN}🎉 ETAPA 1.1 APROVADA! Funcionalidade básica validada.${NC}"
    echo -e "${GREEN}✅ Pronto para prosseguir para os testes de regras de negócio.${NC}"
    exit 0
elif [ $SUCCESS_RATE -ge 70 ]; then
    echo -e "${YELLOW}⚠️ ETAPA 1.1 COM AVISOS. Alguns testes falharam.${NC}"
    echo -e "${YELLOW}🔍 Revisar falhas antes de prosseguir.${NC}"
    exit 1
else
    echo -e "${RED}❌ ETAPA 1.1 REPROVADA! Muitos testes falharam.${NC}"
    echo -e "${RED}🚨 Necessário corrigir problemas antes de prosseguir.${NC}"
    exit 2
fi
