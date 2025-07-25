#!/bin/bash

# 🎯 VALIDAÇÃO COMPLETA DAS REGRAS DE NEGÓCIO - GMC TOKEN
# Análise sistemática de TODOS os requisitos antes da TestNet

set -e
cd "$(dirname "$0")/.."

echo "🎯 =================================================="
echo "🎯 VALIDAÇÃO COMPLETA DAS REGRAS DE NEGÓCIO"
echo "🎯 =================================================="
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Contadores
TOTAL_RULES=0
IMPLEMENTED_RULES=0
MISSING_RULES=0
PARTIAL_RULES=0

# Função para validar regra
validate_rule() {
    local rule_category="$1"
    local rule_name="$2"
    local validation_command="$3"
    local status=""
    
    echo -e "${BLUE} [$rule_category] $rule_name${NC}"
    TOTAL_RULES=$((TOTAL_RULES + 1))
    
    if eval "$validation_command"; then
        echo -e "${GREEN} IMPLEMENTADO: $rule_name${NC}"
        IMPLEMENTED_RULES=$((IMPLEMENTED_RULES + 1))
        status="IMPLEMENTADO"
    else
        echo -e "${RED} AUSENTE/INCOMPLETO: $rule_name${NC}"
        MISSING_RULES=$((MISSING_RULES + 1))
        status="AUSENTE"
    fi
    
    # Verificar Nível 1: 20% do poder dos afiliados
    if grep -q "AffiliateLevelConfig" "$LIB_FILE" 2>/dev/null && grep -q "commission_percentage" "$LIB_FILE" 2>/dev/null; then
        echo " IMPLEMENTADO: Nível 1: 20% do poder dos afiliados"
        ((implemented++))
    else
        echo " AUSENTE/INCOMPLETO: Nível 1: 20% do poder dos afiliados"
        ((missing++))
    fi
    echo "   Status: $([ $(grep -c "AffiliateLevelConfig" "$LIB_FILE" 2>/dev/null || echo 0) -gt 0 ] && echo "IMPLEMENTADO" || echo "AUSENTE")"
    
    # Verificar Vesting da Equipe: Liberação gradual
    if grep -q "calculate_team_vesting_release" "$LIB_FILE" 2>/dev/null && grep -q "TeamVestingSchedule" "$LIB_FILE" 2>/dev/null; then
        echo "✅ IMPLEMENTADO: Vesting da Equipe: Liberação gradual"
        ((implemented++))
    else
        echo "❌ AUSENTE/INCOMPLETO: Vesting da Equipe: Liberação gradual"
        ((missing++))
    fi
    echo "   Status: $([ $(grep -c "calculate_team_vesting_release" "$LIB_FILE" 2>/dev/null || echo 0) -gt 0 ] && echo "IMPLEMENTADO" || echo "AUSENTE")"
    
    echo "   Status: $status"
    echo ""
    return 0
}

# Função para validar regra parcial
validate_partial_rule() {
    local rule_category="$1"
    local rule_name="$2"
    local validation_command="$3"
    local notes="$4"
    
    echo -e "${BLUE}📋 [$rule_category] $rule_name${NC}"
    TOTAL_RULES=$((TOTAL_RULES + 1))
    
    if eval "$validation_command"; then
        echo -e "${YELLOW}⚠️ PARCIALMENTE IMPLEMENTADO: $rule_name${NC}"
        echo -e "${YELLOW}   Notas: $notes${NC}"
        PARTIAL_RULES=$((PARTIAL_RULES + 1))
    else
        echo -e "${RED}❌ AUSENTE: $rule_name${NC}"
        MISSING_RULES=$((MISSING_RULES + 1))
    fi
    echo ""
    return 0
}

echo "🚀 Iniciando Validação Sistemática das Regras de Negócio..."
echo ""

# =============================================================================
# 1. REGRAS DO TOKEN GMC
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DO TOKEN GMC =====${NC}"
echo ""

validate_rule "TOKEN" "Supply Total: 100 Milhões GMC" \
    "grep -q 'GMC_TOTAL_SUPPLY.*100_000_000_000_000_000' programs/gmc_token_native/src/lib.rs"

validate_rule "TOKEN" "Decimais: 9" \
    "grep -q 'GMC_DECIMALS.*9' programs/gmc_token_native/src/lib.rs"

validate_rule "TOKEN" "Taxa de Transferência: 0.5%" \
    "grep -q '50.*basis.*points\|0\.5.*percent' programs/gmc_token_native/src/lib.rs"

validate_rule "TOKEN" "Distribuição Taxa: 50% Burn + 40% Staking + 10% Ranking" \
    "grep -q '50.*burn\|40.*staking\|10.*ranking' programs/gmc_token_native/src/lib.rs"

# =============================================================================
# 2. REGRAS DE STAKING
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE STAKING =====${NC}"
echo ""

validate_rule "STAKING" "Staking Long-Term: 12 meses" \
    "grep -q '365.*days\|12.*month' programs/gmc_token_native/src/staking.rs"

validate_rule "STAKING" "Staking Flexível: 30 dias" \
    "grep -q '30.*days' programs/gmc_token_native/src/staking.rs"

validate_rule "STAKING" "APY Long-Term: 10% a 280%" \
    "grep -q '1000.*basis.*points\|28000.*basis.*points' programs/gmc_token_native/src/staking.rs"

validate_rule "STAKING" "APY Flexível: 5% a 70%" \
    "grep -q '500.*basis.*points\|7000.*basis.*points' programs/gmc_token_native/src/staking.rs"

validate_rule "STAKING" "Burn-for-Boost: Queima para aumentar APY" \
    "grep -q 'burn.*boost\|calculate.*burn.*boost' programs/gmc_token_native/src/staking.rs"

# =============================================================================
# 3. REGRAS DE TAXAS (PERCENTUAIS)
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE TAXAS (PERCENTUAIS) =====${NC}"
echo ""

validate_rule "TAXAS" "Taxa Entrada Staking: Percentual sobre valor" \
    "grep -q 'calculate_usdt_fee_by_amount' programs/gmc_token_native/src/staking.rs"

validate_rule "TAXAS" "Tier 1 (até 1M GMC): 10%" \
    "grep -q 'TIER_1.*1000.*basis.*points\|10.*percent' programs/gmc_token_native/src/staking.rs"

validate_rule "TAXAS" "Tier 2 (1M-10M GMC): 5%" \
    "grep -q 'TIER_2.*500.*basis.*points\|5.*percent' programs/gmc_token_native/src/staking.rs"

validate_rule "TAXAS" "Tier 3 (10M-100M GMC): 2.5%" \
    "grep -q 'TIER_3.*250.*basis.*points\|2\.5.*percent' programs/gmc_token_native/src/staking.rs"

validate_rule "TAXAS" "Tier 4 (100M-500M GMC): 1%" \
    "grep -q 'TIER_4.*100.*basis.*points\|1.*percent' programs/gmc_token_native/src/staking.rs"

validate_rule "TAXAS" "Tier 5 (500M+ GMC): 0.5%" \
    "grep -q 'TIER_5.*50.*basis.*points\|0\.5.*percent' programs/gmc_token_native/src/staking.rs"

validate_rule "TAXAS" "Distribuição Taxa Entrada: 40% Equipe + 40% Staking + 20% Ranking" \
    "grep -q '40.*team\|40.*staking\|20.*ranking' programs/gmc_token_native/src/staking.rs"

# =============================================================================
# 4. REGRAS DE AFFILIATE BOOST
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE AFFILIATE BOOST =====${NC}"
echo ""

validate_rule "AFFILIATE" "Lógica: EU CONVIDO → AMIGO FAZ STAKING → MEU APY AUMENTA" \
    "grep -q 'EU CONVIDO.*AMIGO FAZ STAKING.*MEU APY AUMENTA' programs/gmc_token_native/src/staking.rs"

validate_rule "AFFILIATE" "6 Níveis de Afiliados" \
    "grep -q 'AFFILIATE_LEVEL_PERCENTAGES.*\[20, 15, 8, 4, 2, 1\]' programs/gmc_token_native/src/staking.rs"

validate_rule "AFFILIATE" "Nível 1: 20% do poder dos afiliados" \
    "grep -q '20.*percent\|20.*level.*1' programs/gmc_token_native/src/staking.rs"

validate_rule "AFFILIATE" "Boost Máximo Long-Term: 50%" \
    "grep -q 'MAX_AFFILIATE_BOOST_LONG_TERM.*5000\|50.*percent.*long' programs/gmc_token_native/src/staking.rs"

validate_rule "AFFILIATE" "Boost Máximo Flexível: 65%" \
    "grep -q 'MAX_AFFILIATE_BOOST_FLEXIBLE.*6500\|65.*percent.*flexible' programs/gmc_token_native/src/staking.rs"

validate_rule "AFFILIATE" "Verificação Staking Ativo dos Afiliados" \
    "grep -q 'stake_amount == 0\|affiliate.*active.*staking' programs/gmc_token_native/src/staking.rs"

validate_rule "AFFILIATE" "Proteção Anti-Fraude: Mínimo 2 Afiliados" \
    "grep -q 'active_affiliates < 2\|minimum.*2.*affiliate' programs/gmc_token_native/src/staking.rs"

validate_rule "AFFILIATE" "Poder de Mineração Baseado em Stake + Burn" \
    "grep -q 'calculate_mining_power_from_stake' programs/gmc_token_native/src/staking.rs"

# =============================================================================
# 5. REGRAS DE RANKING
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE RANKING =====${NC}"
echo ""

validate_rule "RANKING" "Leaderboard: 25 posições máximas" \
    "grep -q '25.*position\|MAX_LEADERBOARD.*25' programs/gmc_token_native/src/ranking.rs"

validate_rule "RANKING" "Distribuição: 90% mensal + 10% anual" \
    "grep -q '90.*monthly\|10.*annual\|9000.*1000' programs/gmc_token_native/src/ranking.rs"

validate_rule "RANKING" "Sistema de Pontuação Genérico" \
    "grep -q 'score\|points\|ranking.*system' programs/gmc_token_native/src/ranking.rs"

validate_rule "RANKING" "Threshold Mínimo: 100 pontos" \
    "grep -q 'MIN.*SCORE.*100\|threshold.*100' programs/gmc_token_native/src/ranking.rs"

# =============================================================================
# 6. REGRAS DE VESTING
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE VESTING =====${NC}"
echo ""

validate_rule "VESTING" "Vesting da Equipe: Liberação gradual" \
    "grep -q 'team.*vesting\|gradual.*release' programs/gmc_token_native/src/vesting.rs"

validate_rule "VESTING" "Controle de Autoridades" \
    "grep -q 'authority\|multisig\|governance' programs/gmc_token_native/src/vesting.rs"

validate_rule "VESTING" "Time-locks de Segurança" \
    "grep -q 'timelock\|delay\|security.*period' programs/gmc_token_native/src/vesting.rs"

validate_rule "VESTING" "Proteção contra Liberação Antecipada" \
    "grep -q 'cliff\|early.*release\|protection' programs/gmc_token_native/src/vesting.rs"

# =============================================================================
# 7. REGRAS DE PENALIDADES
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE PENALIDADES =====${NC}"
echo ""

validate_rule "PENALIDADES" "Saque Antecipado Long-Term: 5 USDT + 50% capital + 80% juros" \
    "grep -q '5.*USDT\|50.*capital\|80.*interest' programs/gmc_token_native/src/staking.rs"

validate_rule "PENALIDADES" "Cancelamento Flexível: 2.5% sobre capital" \
    "grep -q '2\.5.*percent\|250.*basis.*points.*cancel' programs/gmc_token_native/src/staking.rs"

validate_rule "PENALIDADES" "Taxa Saque Juros: 1% sobre valor sacado" \
    "grep -q '1.*percent.*withdraw\|100.*basis.*points.*claim' programs/gmc_token_native/src/staking.rs"

validate_rule "PENALIDADES" "Taxa Saque USDT: 0.3% sobre valor" \
    "grep -q '0\.3.*percent\|30.*basis.*points.*usdt' programs/gmc_token_native/src/staking.rs"

# =============================================================================
# 8. REGRAS DE DISTRIBUIÇÃO
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE DISTRIBUIÇÃO =====${NC}"
echo ""

validate_rule "DISTRIBUIÇÃO" "Supply Inicial: 100M GMC para circulação" \
    "grep -q '100.*million\|100_000_000.*circulation' programs/gmc_token_native/src/lib.rs"

validate_rule "DISTRIBUIÇÃO" "Queima até Limite: 12M GMC mínimo" \
    "grep -q '12.*million\|12_000_000.*minimum' programs/gmc_token_native/src/lib.rs"

validate_rule "DISTRIBUIÇÃO" "Carteiras Específicas: Equipe, Treasury, Marketing, etc." \
    "grep -q 'team.*wallet\|treasury.*wallet\|marketing.*wallet' programs/gmc_token_native/src/lib.rs"

# =============================================================================
# 9. REGRAS DE SEGURANÇA
# =============================================================================

echo -e "${PURPLE} ===== REGRAS DE SEGURANÇA =====${NC}"
echo ""

validate_rule "SEGURANÇA" "Proteção contra Overflow" \
    "grep -q 'checked_mul\|checked_add\|overflow.*protection' programs/gmc_token_native/src/staking.rs"

validate_rule "SEGURANÇA" "Validação de Entrada" \
    "grep -q 'validate_input_amount\|InvalidInput' programs/gmc_token_native/src/lib.rs"

validate_rule "SEGURANÇA" "Controle de Acesso" \
    "grep -q 'check_access_control\|AccessDenied' programs/gmc_token_native/src/lib.rs"

validate_rule "SEGURANÇA" "Proteção contra Reentrancy" \
    "grep -q 'ReentrancyGuard\|ReentrancyDetected' programs/gmc_token_native/src/lib.rs"

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

echo ""
echo " =================================================="
echo " RELATÓRIO FINAL - VALIDAÇÃO REGRAS DE NEGÓCIO"
echo " =================================================="
echo "🎯 =================================================="
echo "🎯 RELATÓRIO FINAL - VALIDAÇÃO REGRAS DE NEGÓCIO"
echo "🎯 =================================================="
echo ""

# Calcular percentuais
implementation_percentage=$((IMPLEMENTED_RULES * 100 / TOTAL_RULES))
missing_percentage=$((MISSING_RULES * 100 / TOTAL_RULES))
partial_percentage=$((PARTIAL_RULES * 100 / TOTAL_RULES))

echo -e "${BLUE}📊 ESTATÍSTICAS GERAIS:${NC}"
echo -e "   Total de Regras Analisadas: ${TOTAL_RULES}"
echo -e "   ${GREEN}✅ Implementadas: ${IMPLEMENTED_RULES} (${implementation_percentage}%)${NC}"
echo -e "   ${YELLOW}⚠️ Parciais: ${PARTIAL_RULES} (${partial_percentage}%)${NC}"
echo -e "   ${RED}❌ Ausentes: ${MISSING_RULES} (${missing_percentage}%)${NC}"
echo ""

if [ $MISSING_RULES -eq 0 ] && [ $PARTIAL_RULES -eq 0 ]; then
    echo -e "${GREEN}🎉 TODAS AS REGRAS DE NEGÓCIO IMPLEMENTADAS!${NC}"
    echo -e "${GREEN}🚀 SISTEMA PRONTO PARA TESTNET/MAINNET!${NC}"
    echo ""
    exit 0
elif [ $MISSING_RULES -eq 0 ]; then
    echo -e "${YELLOW}⚠️ IMPLEMENTAÇÃO QUASE COMPLETA${NC}"
    echo -e "${YELLOW}📋 Algumas regras estão parcialmente implementadas${NC}"
    echo -e "${YELLOW}🔧 Revisar e completar implementações parciais${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}🚨 IMPLEMENTAÇÃO INCOMPLETA${NC}"
    echo -e "${RED}📋 Existem regras de negócio ausentes${NC}"
    echo -e "${RED}🔧 Implementar regras faltantes antes de prosseguir${NC}"
    echo ""
    exit 1
fi
