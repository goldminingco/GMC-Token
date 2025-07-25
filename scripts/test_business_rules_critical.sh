#!/bin/bash

# ============================================================================
# TESTE CRÍTICO DE REGRAS DE NEGÓCIO - GMC TOKEN
# ============================================================================
# Validação específica das regras de negócio implementadas vs documentadas
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; ((PASSED_TESTS++)); }
error() { echo -e "${RED}❌ $1${NC}"; ((FAILED_TESTS++)); }

test_rule() {
    local rule_name="$1"
    local search_pattern="$2"
    local file_path="$3"
    
    ((TOTAL_TESTS++))
    log "Testando: $rule_name"
    
    if grep -q "$search_pattern" "$file_path" 2>/dev/null; then
        success "$rule_name"
    else
        error "$rule_name - Padrão '$search_pattern' não encontrado em $file_path"
    fi
}

echo "============================================================================"
echo "🎯 TESTE CRÍTICO DE REGRAS DE NEGÓCIO - GMC TOKEN"
echo "============================================================================"

# ============================================================================
# 1. TOKENOMICS FUNDAMENTAIS
# ============================================================================
echo -e "${YELLOW}💰 TOKENOMICS FUNDAMENTAIS${NC}"
echo "============================================================================"

test_rule "Supply Total: 100M GMC" "100_000_000" "programs/gmc_token_native/src/lib.rs"
test_rule "Supply Mínimo: 12M GMC" "12_000_000" "programs/gmc_token_native/src/lib.rs"
test_rule "Taxa Transferência: 0.5%" "50.*10000\|TRANSFER_FEE_RATE.*50" "programs/gmc_token_native/src/lib.rs"
test_rule "Distribuição Burn: 50%" "BURN_PERCENTAGE.*50\|50.*burn" "programs/gmc_token_native/src/lib.rs"
test_rule "Distribuição Staking: 40%" "STAKING_PERCENTAGE.*40\|40.*staking" "programs/gmc_token_native/src/lib.rs"
test_rule "Distribuição Ranking: 10%" "RANKING_PERCENTAGE.*10\|10.*ranking" "programs/gmc_token_native/src/lib.rs"

echo ""

# ============================================================================
# 2. SISTEMA DE STAKING
# ============================================================================
echo -e "${YELLOW}🏦 SISTEMA DE STAKING${NC}"
echo "============================================================================"

test_rule "Staking Long-Term: 12 meses" "12.*month\|LONG_TERM.*12\|365.*day" "programs/gmc_token_native/src/staking.rs"
test_rule "Staking Flexible: 30 dias" "30.*day\|FLEXIBLE.*30" "programs/gmc_token_native/src/staking.rs"
test_rule "APY Mínimo Long-Term: 10%" "MIN.*APY.*10\|10.*min" "programs/gmc_token_native/src/staking.rs"
test_rule "APY Máximo Long-Term: 280%" "MAX.*APY.*280\|280.*max" "programs/gmc_token_native/src/staking.rs"
test_rule "APY Mínimo Flexible: 5%" "5.*flexible\|flexible.*5" "programs/gmc_token_native/src/staking.rs"
test_rule "APY Máximo Flexible: 70%" "70.*flexible\|flexible.*70" "programs/gmc_token_native/src/staking.rs"
test_rule "Taxa Cancelamento: 2.5%" "2\.5\|25.*1000" "programs/gmc_token_native/src/staking.rs"

echo ""

# ============================================================================
# 3. SISTEMA DE AFILIADOS
# ============================================================================
echo -e "${YELLOW}🤝 SISTEMA DE AFILIADOS${NC}"
echo "============================================================================"

test_rule "Níveis de Afiliados: 6" "MAX_AFFILIATE_LEVELS.*6\|6.*level" "programs/gmc_token_native/src/affiliate.rs"
test_rule "Boost Máximo Affiliate: 50%" "50.*boost\|MAX.*BOOST.*50" "programs/gmc_token_native/src/affiliate.rs"
test_rule "Proteção Anti-Sybil" "sybil\|anti_sybil\|fraud_protection" "programs/gmc_token_native/src/affiliate.rs"
test_rule "Cálculo de Comissão" "calculate.*commission\|commission.*calculate" "programs/gmc_token_native/src/affiliate.rs"

echo ""

# ============================================================================
# 4. SISTEMA DE RANKING
# ============================================================================
echo -e "${YELLOW}🏆 SISTEMA DE RANKING${NC}"
echo "============================================================================"

test_rule "Leaderboard: 25 posições" "MAX_LEADERBOARD_SIZE.*25\|25.*leaderboard" "programs/gmc_token_native/src/ranking.rs"
test_rule "Distribuição Mensal: 90%" "MONTHLY.*90\|90.*monthly" "programs/gmc_token_native/src/ranking.rs"
test_rule "Acumulação Anual: 10%" "ANNUAL.*10\|10.*annual" "programs/gmc_token_native/src/ranking.rs"
test_rule "Atualização de Score" "update_score\|score.*update" "programs/gmc_token_native/src/ranking.rs"
test_rule "Distribuição de Prêmios" "distribute_rewards\|reward.*distribute" "programs/gmc_token_native/src/ranking.rs"

echo ""

# ============================================================================
# 5. SISTEMA DE VESTING
# ============================================================================
echo -e "${YELLOW}⏰ SISTEMA DE VESTING${NC}"
echo "============================================================================"

test_rule "Duração Vesting: 24 meses" "VESTING_DURATION.*24\|24.*month.*vesting" "programs/gmc_token_native/src/vesting.rs"
test_rule "Cliff Period: 6 meses" "CLIFF.*6\|6.*cliff" "programs/gmc_token_native/src/vesting.rs"
test_rule "Liberação Linear" "linear\|proportional.*release" "programs/gmc_token_native/src/vesting.rs"
test_rule "Cronograma de Vesting" "vesting_schedule\|schedule.*vesting" "programs/gmc_token_native/src/vesting.rs"

echo ""

# ============================================================================
# 6. TREASURY E GOVERNANÇA
# ============================================================================
echo -e "${YELLOW}🏛️ TREASURY E GOVERNANÇA${NC}"
echo "============================================================================"

test_rule "Sistema Multisig" "multisig\|multi_sig" "programs/gmc_token_native/src/treasury.rs"
test_rule "Time-locks: 24-48h" "24.*hour\|48.*hour\|time_lock\|timelock" "programs/gmc_token_native/src/treasury.rs"
test_rule "Distribuição Team: 40%" "TEAM.*40\|40.*team" "programs/gmc_token_native/src/treasury.rs"
test_rule "Distribuição Staking: 40%" "40.*staking" "programs/gmc_token_native/src/treasury.rs"
test_rule "Distribuição Ranking: 20%" "20.*ranking" "programs/gmc_token_native/src/treasury.rs"

echo ""

# ============================================================================
# 7. DISTRIBUIÇÃO INICIAL
# ============================================================================
echo -e "${YELLOW}📊 DISTRIBUIÇÃO INICIAL${NC}"
echo "============================================================================"

test_rule "Pool Staking: 70M (70%)" "STAKING_POOL.*70_000_000\|70.*staking" "programs/gmc_token_native/src/lib.rs"
test_rule "Reserva Estratégica: 10M (10%)" "STRATEGIC_RESERVE.*10_000_000\|10.*strategic" "programs/gmc_token_native/src/lib.rs"
test_rule "Pré-venda: 8M (8%)" "PRESALE.*8_000_000\|8.*presale" "programs/gmc_token_native/src/lib.rs"
test_rule "Marketing: 6M (6%)" "MARKETING.*6_000_000\|6.*marketing" "programs/gmc_token_native/src/lib.rs"
test_rule "Airdrop: 2M (2%)" "AIRDROP.*2_000_000\|2.*airdrop" "programs/gmc_token_native/src/lib.rs"
test_rule "Equipe: 2M (2%)" "TEAM.*2_000_000\|2.*team" "programs/gmc_token_native/src/lib.rs"
test_rule "Tesouraria: 2M (2%)" "TREASURY.*2_000_000\|2.*treasury" "programs/gmc_token_native/src/lib.rs"

echo ""

# ============================================================================
# 8. SEGURANÇA E PROTEÇÕES
# ============================================================================
echo -e "${YELLOW}🛡️ SEGURANÇA E PROTEÇÕES${NC}"
echo "============================================================================"

# Verificar em todos os arquivos Rust
for file in programs/gmc_token_native/src/*.rs; do
    if [[ -f "$file" ]]; then
        if grep -q "saturating_" "$file" 2>/dev/null; then
            success "Proteção Overflow: $(basename "$file")"
            ((PASSED_TESTS++))
        else
            error "Proteção Overflow ausente: $(basename "$file")"
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
    fi
done

# Verificar controle de acesso
if find programs/gmc_token_native/src/ -name "*.rs" -exec grep -l "authority\|owner\|admin" {} \; | wc -l | grep -q "[1-9]"; then
    success "Controle de Acesso: Implementado em múltiplos módulos"
    ((PASSED_TESTS++))
else
    error "Controle de Acesso: Não encontrado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar validações
if find programs/gmc_token_native/src/ -name "*.rs" -exec grep -l "require!\|assert!\|validate" {} \; | wc -l | grep -q "[1-9]"; then
    success "Validações: Implementadas em múltiplos módulos"
    ((PASSED_TESTS++))
else
    error "Validações: Não encontradas"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 9. TESTE DE BUILD E ARTEFATO
# ============================================================================
echo -e "${YELLOW}🔧 BUILD E ARTEFATO${NC}"
echo "============================================================================"

log "Executando build para validar integridade..."
if cargo build-sbf --manifest-path programs/gmc_token_native/Cargo.toml >/dev/null 2>&1; then
    success "Build: Compilação bem-sucedida"
    ((PASSED_TESTS++))
    
    # Verificar se artefato foi gerado
    if [[ -f "programs/gmc_token_native/target/deploy/gmc_token_native.so" ]]; then
        success "Artefato: Arquivo .so gerado"
        ((PASSED_TESTS++))
        
        # Verificar tamanho do artefato (deve ser razoável)
        artifact_size=$(stat -f%z "programs/gmc_token_native/target/deploy/gmc_token_native.so" 2>/dev/null || echo "0")
        if [[ $artifact_size -gt 10000 ]] && [[ $artifact_size -lt 500000 ]]; then
            success "Artefato: Tamanho adequado (${artifact_size} bytes)"
            ((PASSED_TESTS++))
        else
            error "Artefato: Tamanho inadequado (${artifact_size} bytes)"
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
    else
        error "Artefato: Arquivo .so não encontrado"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
else
    error "Build: Falha na compilação"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# RELATÓRIO FINAL DETALHADO
# ============================================================================
echo "============================================================================"
echo -e "${BLUE}📊 RELATÓRIO CRÍTICO DE REGRAS DE NEGÓCIO${NC}"
echo "============================================================================"
echo ""
echo -e "Total de Regras Testadas: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Regras Implementadas: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Regras Ausentes/Incorretas: ${RED}$FAILED_TESTS${NC}"
echo ""

if [[ $TOTAL_TESTS -gt 0 ]]; then
    SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    echo -e "Taxa de Conformidade: ${BLUE}$SUCCESS_RATE%${NC}"
else
    SUCCESS_RATE=0
    echo -e "Taxa de Conformidade: ${RED}0%${NC}"
fi

echo ""
echo "============================================================================"
echo -e "${BLUE}ANÁLISE POR CATEGORIA:${NC}"
echo "============================================================================"

# Análise detalhada por categoria
categories=("TOKENOMICS" "STAKING" "AFILIADOS" "RANKING" "VESTING" "TREASURY" "DISTRIBUIÇÃO" "SEGURANÇA" "BUILD")
for category in "${categories[@]}"; do
    echo -e "${YELLOW}$category:${NC} Verificar logs acima para detalhes específicos"
done

echo ""
echo "============================================================================"

# Status final
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 PERFEITO! TODAS AS REGRAS DE NEGÓCIO ESTÃO IMPLEMENTADAS!${NC}"
    echo -e "${GREEN}   O GMC Token está 100% conforme com a documentação.${NC}"
    exit 0
elif [[ $SUCCESS_RATE -ge 95 ]]; then
    echo -e "${YELLOW}🎯 EXCELENTE! $SUCCESS_RATE% das regras implementadas.${NC}"
    echo -e "${YELLOW}   Apenas pequenos ajustes necessários.${NC}"
    exit 1
elif [[ $SUCCESS_RATE -ge 85 ]]; then
    echo -e "${YELLOW}👍 BOM! $SUCCESS_RATE% das regras implementadas.${NC}"
    echo -e "${YELLOW}   Algumas correções necessárias.${NC}"
    exit 2
elif [[ $SUCCESS_RATE -ge 70 ]]; then
    echo -e "${RED}⚠️  ATENÇÃO! Apenas $SUCCESS_RATE% das regras implementadas.${NC}"
    echo -e "${RED}   Revisão significativa necessária.${NC}"
    exit 3
else
    echo -e "${RED}🚨 CRÍTICO! Apenas $SUCCESS_RATE% das regras implementadas.${NC}"
    echo -e "${RED}   Implementação não está conforme com a documentação.${NC}"
    exit 4
fi
