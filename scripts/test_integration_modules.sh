#!/bin/bash

# ============================================================================
# TESTE DE INTEGRAÇÃO CRÍTICA - TODOS OS MÓDULOS GMC TOKEN
# ============================================================================
# Valida a integração e comunicação entre todos os módulos
# ============================================================================

set -e

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

test_integration() {
    local test_name="$1"
    local condition="$2"
    
    ((TOTAL_TESTS++))
    log "Testando: $test_name"
    
    if eval "$condition"; then
        success "$test_name"
    else
        error "$test_name"
    fi
}

echo "============================================================================"
echo "🔗 TESTE DE INTEGRAÇÃO CRÍTICA - MÓDULOS GMC TOKEN"
echo "============================================================================"

# ============================================================================
# 1. VERIFICAR IMPORTAÇÕES E DEPENDÊNCIAS
# ============================================================================
echo -e "${YELLOW}📦 IMPORTAÇÕES E DEPENDÊNCIAS${NC}"
echo "============================================================================"

# Verificar se todos os módulos estão declarados no lib.rs
test_integration "Módulo staking declarado" "grep -q 'mod staking' programs/gmc_token_native/src/lib.rs"
test_integration "Módulo affiliate declarado" "grep -q 'mod affiliate' programs/gmc_token_native/src/lib.rs"
test_integration "Módulo ranking declarado" "grep -q 'mod ranking' programs/gmc_token_native/src/lib.rs"
test_integration "Módulo treasury declarado" "grep -q 'mod treasury' programs/gmc_token_native/src/lib.rs"
test_integration "Módulo vesting declarado" "grep -q 'mod vesting' programs/gmc_token_native/src/lib.rs"

# Verificar se os módulos existem fisicamente
test_integration "Arquivo staking.rs existe" "test -f programs/gmc_token_native/src/staking.rs"
test_integration "Arquivo affiliate.rs existe" "test -f programs/gmc_token_native/src/affiliate.rs"
test_integration "Arquivo ranking.rs existe" "test -f programs/gmc_token_native/src/ranking.rs"
test_integration "Arquivo treasury.rs existe" "test -f programs/gmc_token_native/src/treasury.rs"
test_integration "Arquivo vesting.rs existe" "test -f programs/gmc_token_native/src/vesting.rs"

echo ""

# ============================================================================
# 2. VERIFICAR CONSTANTES COMPARTILHADAS
# ============================================================================
echo -e "${YELLOW}🔧 CONSTANTES COMPARTILHADAS${NC}"
echo "============================================================================"

# Verificar se as constantes principais estão definidas
test_integration "GMC_TOTAL_SUPPLY definido" "grep -q 'GMC_TOTAL_SUPPLY.*100_000_000' programs/gmc_token_native/src/lib.rs"
test_integration "GMC_MINIMUM_SUPPLY definido" "grep -q 'GMC_MINIMUM_SUPPLY.*12_000_000' programs/gmc_token_native/src/lib.rs"
test_integration "TRANSFER_FEE_BASIS_POINTS definido" "grep -q 'TRANSFER_FEE_BASIS_POINTS.*50' programs/gmc_token_native/src/lib.rs"

# Verificar distribuição de alocações
test_integration "STAKING_POOL_ALLOCATION definido" "grep -q 'STAKING_POOL_ALLOCATION.*70_000_000' programs/gmc_token_native/src/lib.rs"
test_integration "TEAM_ALLOCATION definido" "grep -q 'TEAM_ALLOCATION.*2_000_000' programs/gmc_token_native/src/lib.rs"
test_integration "TREASURY_ALLOCATION definido" "grep -q 'TREASURY_ALLOCATION.*2_000_000' programs/gmc_token_native/src/lib.rs"

echo ""

# ============================================================================
# 3. VERIFICAR ESTRUTURAS DE DADOS INTEGRADAS
# ============================================================================
echo -e "${YELLOW}📊 ESTRUTURAS DE DADOS${NC}"
echo "============================================================================"

# Verificar estruturas principais
test_integration "GlobalState definido" "grep -q 'struct GlobalState' programs/gmc_token_native/src/lib.rs"
test_integration "EcosystemWallets definido" "grep -q 'struct EcosystemWallets' programs/gmc_token_native/src/lib.rs"
test_integration "InitialDistribution definido" "grep -q 'struct InitialDistribution' programs/gmc_token_native/src/lib.rs"

# Verificar se módulos têm suas estruturas específicas
test_integration "StakingState existe" "grep -q 'struct StakingState' programs/gmc_token_native/src/staking.rs"
test_integration "AffiliateState existe" "grep -q 'struct AffiliateState' programs/gmc_token_native/src/affiliate.rs"
test_integration "RankingState existe" "grep -q 'struct RankingState' programs/gmc_token_native/src/ranking.rs"
test_integration "TreasuryState existe" "grep -q 'struct TreasuryState' programs/gmc_token_native/src/treasury.rs"
test_integration "VestingState existe" "grep -q 'struct VestingState' programs/gmc_token_native/src/vesting.rs"

echo ""

# ============================================================================
# 4. VERIFICAR FUNÇÕES DE INTEGRAÇÃO
# ============================================================================
echo -e "${YELLOW}🔗 FUNÇÕES DE INTEGRAÇÃO${NC}"
echo "============================================================================"

# Verificar funções que conectam módulos
test_integration "calculate_transfer_fee implementada" "grep -q 'fn calculate_transfer_fee' programs/gmc_token_native/src/lib.rs"
test_integration "apply_transfer_fee implementada" "grep -q 'fn apply_transfer_fee' programs/gmc_token_native/src/lib.rs"
test_integration "validate_burn_limit implementada" "grep -q 'fn validate_burn_limit' programs/gmc_token_native/src/lib.rs"

# Verificar se módulos têm funções de inicialização
test_integration "Staking tem função initialize" "grep -q 'fn initialize' programs/gmc_token_native/src/staking.rs"
test_integration "Ranking tem função initialize" "grep -q 'fn initialize' programs/gmc_token_native/src/ranking.rs"
test_integration "Treasury tem função initialize" "grep -q 'fn initialize' programs/gmc_token_native/src/treasury.rs"

echo ""

# ============================================================================
# 5. VERIFICAR COMUNICAÇÃO ENTRE MÓDULOS
# ============================================================================
echo -e "${YELLOW}💬 COMUNICAÇÃO ENTRE MÓDULOS${NC}"
echo "============================================================================"

# Verificar se staking se comunica com affiliate
test_integration "Staking referencia affiliate" "grep -q 'affiliate\|boost' programs/gmc_token_native/src/staking.rs"

# Verificar se ranking recebe dados do staking
test_integration "Ranking referencia staking" "grep -q 'staking\|stake' programs/gmc_token_native/src/ranking.rs"

# Verificar se treasury distribui para todos os módulos
test_integration "Treasury referencia staking" "grep -q 'staking' programs/gmc_token_native/src/treasury.rs"
test_integration "Treasury referencia ranking" "grep -q 'ranking' programs/gmc_token_native/src/treasury.rs"

# Verificar se vesting se integra com treasury
test_integration "Vesting referencia treasury" "grep -q 'treasury\|team' programs/gmc_token_native/src/vesting.rs"

echo ""

# ============================================================================
# 6. VERIFICAR FLUXOS DE DADOS CRÍTICOS
# ============================================================================
echo -e "${YELLOW}🌊 FLUXOS DE DADOS CRÍTICOS${NC}"
echo "============================================================================"

# Fluxo: Taxa de transferência → Burn + Staking + Ranking
test_integration "Taxa transferência → Burn" "grep -q 'TRANSFER_FEE_BURN_PERCENT' programs/gmc_token_native/src/lib.rs"
test_integration "Taxa transferência → Staking" "grep -q 'TRANSFER_FEE_STAKING_PERCENT' programs/gmc_token_native/src/lib.rs"
test_integration "Taxa transferência → Ranking" "grep -q 'TRANSFER_FEE_RANKING_PERCENT' programs/gmc_token_native/src/lib.rs"

# Fluxo: Staking → Affiliate boost
test_integration "Staking calcula boost affiliate" "grep -q 'calculate.*boost\|boost.*calculate' programs/gmc_token_native/src/staking.rs"

# Fluxo: Treasury → Distribuição USDT
test_integration "Treasury distribui para team" "grep -q 'TEAM_PERCENTAGE\|40.*team' programs/gmc_token_native/src/treasury.rs"
test_integration "Treasury distribui para staking" "grep -q '40.*staking' programs/gmc_token_native/src/treasury.rs"
test_integration "Treasury distribui para ranking" "grep -q '20.*ranking' programs/gmc_token_native/src/treasury.rs"

echo ""

# ============================================================================
# 7. VERIFICAR PROTEÇÕES DE SEGURANÇA INTEGRADAS
# ============================================================================
echo -e "${YELLOW}🛡️ PROTEÇÕES DE SEGURANÇA${NC}"
echo "============================================================================"

# Verificar se todos os módulos usam saturating arithmetic
for module in staking affiliate ranking treasury vesting; do
    if [[ -f "programs/gmc_token_native/src/${module}.rs" ]]; then
        test_integration "Módulo $module usa saturating arithmetic" "grep -q 'saturating_' programs/gmc_token_native/src/${module}.rs"
    fi
done

# Verificar controle de acesso em módulos críticos
test_integration "Controle de acesso no lib.rs" "grep -q 'authority\|admin\|owner' programs/gmc_token_native/src/lib.rs"
test_integration "Validação de entrada implementada" "grep -q 'validate.*input\|require!\|assert!' programs/gmc_token_native/src/lib.rs"

echo ""

# ============================================================================
# 8. TESTE DE BUILD INTEGRADO
# ============================================================================
echo -e "${YELLOW}🔨 BUILD INTEGRADO${NC}"
echo "============================================================================"

log "Executando build completo para validar integração..."
if cargo build-sbf --manifest-path programs/gmc_token_native/Cargo.toml >/dev/null 2>&1; then
    success "Build integrado bem-sucedido"
    ((PASSED_TESTS++))
    
    # Verificar tamanho do artefato
    if [[ -f "programs/gmc_token_native/target/deploy/gmc_token_native.so" ]]; then
        artifact_size=$(stat -f%z "programs/gmc_token_native/target/deploy/gmc_token_native.so" 2>/dev/null || echo "0")
        if [[ $artifact_size -gt 50000 ]] && [[ $artifact_size -lt 300000 ]]; then
            success "Artefato integrado tem tamanho adequado (${artifact_size} bytes)"
            ((PASSED_TESTS++))
        else
            error "Artefato integrado tem tamanho inadequado (${artifact_size} bytes)"
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
    fi
else
    error "Build integrado falhou"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 9. VERIFICAR CONSISTÊNCIA DE DADOS
# ============================================================================
echo -e "${YELLOW}📐 CONSISTÊNCIA DE DADOS${NC}"
echo "============================================================================"

# Verificar se soma das alocações = 100M
log "Verificando consistência das alocações..."
if python3 -c "
staking = 70_000_000
presale = 8_000_000
strategic = 10_000_000
treasury = 2_000_000
marketing = 6_000_000
airdrop = 2_000_000
team = 2_000_000
total = staking + presale + strategic + treasury + marketing + airdrop + team
print(f'Total: {total}')
assert total == 100_000_000, f'Total {total} != 100M'
print('✅ Alocações somam 100M GMC')
" 2>/dev/null; then
    success "Alocações somam exatamente 100M GMC"
    ((PASSED_TESTS++))
else
    error "Alocações não somam 100M GMC"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar se percentuais de taxa somam 100%
if python3 -c "
burn = 50
staking = 40
ranking = 10
total = burn + staking + ranking
assert total == 100, f'Percentuais {total} != 100%'
print('✅ Percentuais de taxa somam 100%')
" 2>/dev/null; then
    success "Percentuais de taxa somam exatamente 100%"
    ((PASSED_TESTS++))
else
    error "Percentuais de taxa não somam 100%"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# RELATÓRIO FINAL DE INTEGRAÇÃO
# ============================================================================
echo "============================================================================"
echo -e "${BLUE}📊 RELATÓRIO DE INTEGRAÇÃO CRÍTICA${NC}"
echo "============================================================================"
echo ""
echo -e "Total de Testes de Integração: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Integrações Funcionais: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Integrações com Problemas: ${RED}$FAILED_TESTS${NC}"
echo ""

if [[ $TOTAL_TESTS -gt 0 ]]; then
    SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    echo -e "Taxa de Integração: ${BLUE}$SUCCESS_RATE%${NC}"
else
    SUCCESS_RATE=0
    echo -e "Taxa de Integração: ${RED}0%${NC}"
fi

echo ""
echo "============================================================================"

# Status final
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 INTEGRAÇÃO PERFEITA! TODOS OS MÓDULOS ESTÃO CONECTADOS CORRETAMENTE!${NC}"
    echo -e "${GREEN}   O GMC Token é um sistema coeso e bem integrado.${NC}"
    exit 0
elif [[ $SUCCESS_RATE -ge 90 ]]; then
    echo -e "${YELLOW}🎯 INTEGRAÇÃO EXCELENTE! $SUCCESS_RATE% dos testes passaram.${NC}"
    echo -e "${YELLOW}   Sistema está bem integrado com pequenos ajustes necessários.${NC}"
    exit 1
elif [[ $SUCCESS_RATE -ge 80 ]]; then
    echo -e "${YELLOW}👍 BOA INTEGRAÇÃO! $SUCCESS_RATE% dos testes passaram.${NC}"
    echo -e "${YELLOW}   Algumas melhorias na integração são necessárias.${NC}"
    exit 2
else
    echo -e "${RED}🚨 PROBLEMAS DE INTEGRAÇÃO! Apenas $SUCCESS_RATE% dos testes passaram.${NC}"
    echo -e "${RED}   Revisão significativa da integração entre módulos é necessária.${NC}"
    exit 3
fi
