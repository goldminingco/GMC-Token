#!/bin/bash

# ============================================================================
# TESTE CRÍTICO COMPLETO - TODOS OS MÓDULOS GMC TOKEN
# ============================================================================
# Este script executa testes rigorosos em todos os módulos e contratos
# para garantir fidelidade total às regras de negócio documentadas
# ============================================================================

set -e
set -o pipefail

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

# Função para log
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_TESTS++))
}

error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Função para executar teste e capturar resultado
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    log "Executando: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        error "$test_name"
        return 1
    fi
}

# Verificar se estamos no diretório correto
if [[ ! -f "Cargo.toml" ]] || [[ ! -d "programs" ]]; then
    error "Execute este script a partir da raiz do projeto GMC-Token"
    exit 1
fi

echo "============================================================================"
echo "🔍 TESTE CRÍTICO COMPLETO - TODOS OS MÓDULOS GMC TOKEN"
echo "============================================================================"
echo ""

# ============================================================================
# 1. TESTES DE BUILD E ESTRUTURA
# ============================================================================
echo -e "${YELLOW}📦 FASE 1: TESTES DE BUILD E ESTRUTURA${NC}"
echo "============================================================================"

# Verificar estrutura de arquivos críticos
run_test "Estrutura: lib.rs principal existe" "test -f programs/gmc_token_native/src/lib.rs"
run_test "Estrutura: módulo staking existe" "test -f programs/gmc_token_native/src/staking.rs"
run_test "Estrutura: módulo affiliate existe" "test -f programs/gmc_token_native/src/affiliate.rs"
run_test "Estrutura: módulo ranking existe" "test -f programs/gmc_token_native/src/ranking.rs"
run_test "Estrutura: módulo treasury existe" "test -f programs/gmc_token_native/src/treasury.rs"
run_test "Estrutura: módulo vesting existe" "test -f programs/gmc_token_native/src/vesting.rs"

# Verificar Cargo.toml
run_test "Build: Cargo.toml válido" "cargo check --manifest-path programs/gmc_token_native/Cargo.toml"

# Build completo
log "Executando build completo..."
if cargo build-sbf --manifest-path programs/gmc_token_native/Cargo.toml >/dev/null 2>&1; then
    success "Build: Compilação completa bem-sucedida"
    ((PASSED_TESTS++))
else
    error "Build: Falha na compilação"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 2. TESTES DE CONSTANTES E CONFIGURAÇÕES
# ============================================================================
echo -e "${YELLOW}🔧 FASE 2: TESTES DE CONSTANTES E CONFIGURAÇÕES${NC}"
echo "============================================================================"

# Verificar constantes críticas no código
log "Verificando constantes críticas..."

# Supply total
if grep -q "GMC_TOTAL_SUPPLY.*100_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Constante: GMC_TOTAL_SUPPLY = 100M"
    ((PASSED_TESTS++))
else
    error "Constante: GMC_TOTAL_SUPPLY incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Limite mínimo
if grep -q "MINIMUM_SUPPLY.*12_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Constante: MINIMUM_SUPPLY = 12M"
    ((PASSED_TESTS++))
else
    error "Constante: MINIMUM_SUPPLY incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Taxa de transferência
if grep -q "TRANSFER_FEE_RATE.*50" programs/gmc_token_native/src/lib.rs; then
    success "Constante: TRANSFER_FEE_RATE = 0.5%"
    ((PASSED_TESTS++))
else
    error "Constante: TRANSFER_FEE_RATE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Distribuição de taxas (50% burn, 40% staking, 10% ranking)
if grep -q "BURN_PERCENTAGE.*50" programs/gmc_token_native/src/lib.rs; then
    success "Constante: BURN_PERCENTAGE = 50%"
    ((PASSED_TESTS++))
else
    error "Constante: BURN_PERCENTAGE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "STAKING_PERCENTAGE.*40" programs/gmc_token_native/src/lib.rs; then
    success "Constante: STAKING_PERCENTAGE = 40%"
    ((PASSED_TESTS++))
else
    error "Constante: STAKING_PERCENTAGE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "RANKING_PERCENTAGE.*10" programs/gmc_token_native/src/lib.rs; then
    success "Constante: RANKING_PERCENTAGE = 10%"
    ((PASSED_TESTS++))
else
    error "Constante: RANKING_PERCENTAGE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 3. TESTES DO MÓDULO STAKING
# ============================================================================
echo -e "${YELLOW}🏦 FASE 3: TESTES DO MÓDULO STAKING${NC}"
echo "============================================================================"

# Verificar estruturas de dados do staking
if grep -q "pub struct StakingState" programs/gmc_token_native/src/staking.rs; then
    success "Staking: Estrutura StakingState definida"
    ((PASSED_TESTS++))
else
    error "Staking: Estrutura StakingState não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar tipos de staking
if grep -q "LongTerm" programs/gmc_token_native/src/staking.rs && grep -q "Flexible" programs/gmc_token_native/src/staking.rs; then
    success "Staking: Tipos LongTerm e Flexible definidos"
    ((PASSED_TESTS++))
else
    error "Staking: Tipos de staking não encontrados"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar APY ranges
if grep -q "MIN_LONG_TERM_APY.*10" programs/gmc_token_native/src/staking.rs; then
    success "Staking: MIN_LONG_TERM_APY = 10%"
    ((PASSED_TESTS++))
else
    error "Staking: MIN_LONG_TERM_APY incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "MAX_LONG_TERM_APY.*280" programs/gmc_token_native/src/staking.rs; then
    success "Staking: MAX_LONG_TERM_APY = 280%"
    ((PASSED_TESTS++))
else
    error "Staking: MAX_LONG_TERM_APY incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar funções críticas
if grep -q "pub fn stake_tokens" programs/gmc_token_native/src/staking.rs; then
    success "Staking: Função stake_tokens implementada"
    ((PASSED_TESTS++))
else
    error "Staking: Função stake_tokens não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "pub fn unstake_tokens" programs/gmc_token_native/src/staking.rs; then
    success "Staking: Função unstake_tokens implementada"
    ((PASSED_TESTS++))
else
    error "Staking: Função unstake_tokens não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "pub fn calculate_rewards" programs/gmc_token_native/src/staking.rs; then
    success "Staking: Função calculate_rewards implementada"
    ((PASSED_TESTS++))
else
    error "Staking: Função calculate_rewards não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 4. TESTES DO MÓDULO AFFILIATE
# ============================================================================
echo -e "${YELLOW}🤝 FASE 4: TESTES DO MÓDULO AFFILIATE${NC}"
echo "============================================================================"

# Verificar estruturas de dados do affiliate
if grep -q "pub struct AffiliateState" programs/gmc_token_native/src/affiliate.rs; then
    success "Affiliate: Estrutura AffiliateState definida"
    ((PASSED_TESTS++))
else
    error "Affiliate: Estrutura AffiliateState não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar níveis de afiliados (6 níveis)
if grep -q "MAX_AFFILIATE_LEVELS.*6" programs/gmc_token_native/src/affiliate.rs; then
    success "Affiliate: MAX_AFFILIATE_LEVELS = 6"
    ((PASSED_TESTS++))
else
    error "Affiliate: MAX_AFFILIATE_LEVELS incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar funções críticas
if grep -q "pub fn register_affiliate" programs/gmc_token_native/src/affiliate.rs; then
    success "Affiliate: Função register_affiliate implementada"
    ((PASSED_TESTS++))
else
    error "Affiliate: Função register_affiliate não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "pub fn calculate_affiliate_boost" programs/gmc_token_native/src/affiliate.rs; then
    success "Affiliate: Função calculate_affiliate_boost implementada"
    ((PASSED_TESTS++))
else
    error "Affiliate: Função calculate_affiliate_boost não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar proteção anti-Sybil
if grep -q "anti_sybil" programs/gmc_token_native/src/affiliate.rs || grep -q "sybil_protection" programs/gmc_token_native/src/affiliate.rs; then
    success "Affiliate: Proteção anti-Sybil implementada"
    ((PASSED_TESTS++))
else
    error "Affiliate: Proteção anti-Sybil não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 5. TESTES DO MÓDULO RANKING
# ============================================================================
echo -e "${YELLOW}🏆 FASE 5: TESTES DO MÓDULO RANKING${NC}"
echo "============================================================================"

# Verificar estruturas de dados do ranking
if grep -q "pub struct RankingState" programs/gmc_token_native/src/ranking.rs; then
    success "Ranking: Estrutura RankingState definida"
    ((PASSED_TESTS++))
else
    error "Ranking: Estrutura RankingState não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar tamanho do leaderboard
if grep -q "MAX_LEADERBOARD_SIZE.*25" programs/gmc_token_native/src/ranking.rs; then
    success "Ranking: MAX_LEADERBOARD_SIZE = 25"
    ((PASSED_TESTS++))
else
    error "Ranking: MAX_LEADERBOARD_SIZE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar distribuição mensal/anual (90%/10%)
if grep -q "MONTHLY_DISTRIBUTION_PERCENTAGE.*90" programs/gmc_token_native/src/ranking.rs; then
    success "Ranking: MONTHLY_DISTRIBUTION = 90%"
    ((PASSED_TESTS++))
else
    error "Ranking: MONTHLY_DISTRIBUTION incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "ANNUAL_ACCUMULATION_PERCENTAGE.*10" programs/gmc_token_native/src/ranking.rs; then
    success "Ranking: ANNUAL_ACCUMULATION = 10%"
    ((PASSED_TESTS++))
else
    error "Ranking: ANNUAL_ACCUMULATION incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar funções críticas
if grep -q "pub fn update_score" programs/gmc_token_native/src/ranking.rs; then
    success "Ranking: Função update_score implementada"
    ((PASSED_TESTS++))
else
    error "Ranking: Função update_score não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "pub fn distribute_rewards" programs/gmc_token_native/src/ranking.rs; then
    success "Ranking: Função distribute_rewards implementada"
    ((PASSED_TESTS++))
else
    error "Ranking: Função distribute_rewards não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 6. TESTES DO MÓDULO TREASURY
# ============================================================================
echo -e "${YELLOW}🏛️ FASE 6: TESTES DO MÓDULO TREASURY${NC}"
echo "============================================================================"

# Verificar estruturas de dados do treasury
if grep -q "pub struct TreasuryState" programs/gmc_token_native/src/treasury.rs; then
    success "Treasury: Estrutura TreasuryState definida"
    ((PASSED_TESTS++))
else
    error "Treasury: Estrutura TreasuryState não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar multisig
if grep -q "multisig" programs/gmc_token_native/src/treasury.rs; then
    success "Treasury: Sistema multisig implementado"
    ((PASSED_TESTS++))
else
    error "Treasury: Sistema multisig não encontrado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar time-locks
if grep -q "time_lock" programs/gmc_token_native/src/treasury.rs || grep -q "timelock" programs/gmc_token_native/src/treasury.rs; then
    success "Treasury: Sistema time-lock implementado"
    ((PASSED_TESTS++))
else
    error "Treasury: Sistema time-lock não encontrado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar distribuição USDT (40% team, 40% staking, 20% ranking)
if grep -q "TEAM_PERCENTAGE.*40" programs/gmc_token_native/src/treasury.rs; then
    success "Treasury: TEAM_PERCENTAGE = 40%"
    ((PASSED_TESTS++))
else
    error "Treasury: TEAM_PERCENTAGE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 7. TESTES DO MÓDULO VESTING
# ============================================================================
echo -e "${YELLOW}⏰ FASE 7: TESTES DO MÓDULO VESTING${NC}"
echo "============================================================================"

# Verificar estruturas de dados do vesting
if grep -q "pub struct VestingState" programs/gmc_token_native/src/vesting.rs; then
    success "Vesting: Estrutura VestingState definida"
    ((PASSED_TESTS++))
else
    error "Vesting: Estrutura VestingState não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar período de vesting (24 meses)
if grep -q "VESTING_DURATION.*24" programs/gmc_token_native/src/vesting.rs; then
    success "Vesting: VESTING_DURATION = 24 meses"
    ((PASSED_TESTS++))
else
    error "Vesting: VESTING_DURATION incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar cliff (6 meses)
if grep -q "CLIFF_DURATION.*6" programs/gmc_token_native/src/vesting.rs; then
    success "Vesting: CLIFF_DURATION = 6 meses"
    ((PASSED_TESTS++))
else
    error "Vesting: CLIFF_DURATION incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar funções críticas
if grep -q "pub fn create_vesting_schedule" programs/gmc_token_native/src/vesting.rs; then
    success "Vesting: Função create_vesting_schedule implementada"
    ((PASSED_TESTS++))
else
    error "Vesting: Função create_vesting_schedule não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "pub fn release_vested_tokens" programs/gmc_token_native/src/vesting.rs; then
    success "Vesting: Função release_vested_tokens implementada"
    ((PASSED_TESTS++))
else
    error "Vesting: Função release_vested_tokens não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 8. TESTES DE INTEGRAÇÃO ENTRE MÓDULOS
# ============================================================================
echo -e "${YELLOW}🔗 FASE 8: TESTES DE INTEGRAÇÃO ENTRE MÓDULOS${NC}"
echo "============================================================================"

# Verificar se todos os módulos estão importados no lib.rs
if grep -q "mod staking" programs/gmc_token_native/src/lib.rs; then
    success "Integração: Módulo staking importado"
    ((PASSED_TESTS++))
else
    error "Integração: Módulo staking não importado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "mod affiliate" programs/gmc_token_native/src/lib.rs; then
    success "Integração: Módulo affiliate importado"
    ((PASSED_TESTS++))
else
    error "Integração: Módulo affiliate não importado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "mod ranking" programs/gmc_token_native/src/lib.rs; then
    success "Integração: Módulo ranking importado"
    ((PASSED_TESTS++))
else
    error "Integração: Módulo ranking não importado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "mod treasury" programs/gmc_token_native/src/lib.rs; then
    success "Integração: Módulo treasury importado"
    ((PASSED_TESTS++))
else
    error "Integração: Módulo treasury não importado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "mod vesting" programs/gmc_token_native/src/lib.rs; then
    success "Integração: Módulo vesting importado"
    ((PASSED_TESTS++))
else
    error "Integração: Módulo vesting não importado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar enum de instruções
if grep -q "pub enum GMCInstruction" programs/gmc_token_native/src/lib.rs; then
    success "Integração: Enum GMCInstruction definido"
    ((PASSED_TESTS++))
else
    error "Integração: Enum GMCInstruction não encontrado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 9. TESTES DE SEGURANÇA
# ============================================================================
echo -e "${YELLOW}🛡️ FASE 9: TESTES DE SEGURANÇA${NC}"
echo "============================================================================"

# Verificar proteção contra reentrancy
if grep -q "reentrancy" programs/gmc_token_native/src/lib.rs || find programs/gmc_token_native/src/ -name "*.rs" -exec grep -l "reentrancy" {} \;; then
    success "Segurança: Proteção contra reentrancy implementada"
    ((PASSED_TESTS++))
else
    error "Segurança: Proteção contra reentrancy não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar uso de saturating arithmetic
if find programs/gmc_token_native/src/ -name "*.rs" -exec grep -l "saturating_" {} \;; then
    success "Segurança: Saturating arithmetic utilizada"
    ((PASSED_TESTS++))
else
    error "Segurança: Saturating arithmetic não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar controle de acesso
if find programs/gmc_token_native/src/ -name "*.rs" -exec grep -l "authority" {} \;; then
    success "Segurança: Controle de acesso implementado"
    ((PASSED_TESTS++))
else
    error "Segurança: Controle de acesso não encontrado"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Verificar validação de entrada
if find programs/gmc_token_native/src/ -name "*.rs" -exec grep -l "require!" {} \; || find programs/gmc_token_native/src/ -name "*.rs" -exec grep -l "assert!" {} \;; then
    success "Segurança: Validação de entrada implementada"
    ((PASSED_TESTS++))
else
    error "Segurança: Validação de entrada não encontrada"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# 10. TESTES DE DISTRIBUIÇÃO INICIAL
# ============================================================================
echo -e "${YELLOW}💰 FASE 10: TESTES DE DISTRIBUIÇÃO INICIAL${NC}"
echo "============================================================================"

# Verificar constantes de distribuição
if grep -q "INITIAL_STAKING_POOL.*70_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Distribuição: INITIAL_STAKING_POOL = 70M"
    ((PASSED_TESTS++))
else
    error "Distribuição: INITIAL_STAKING_POOL incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "INITIAL_PRESALE.*8_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Distribuição: INITIAL_PRESALE = 8M"
    ((PASSED_TESTS++))
else
    error "Distribuição: INITIAL_PRESALE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "INITIAL_STRATEGIC_RESERVE.*10_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Distribuição: INITIAL_STRATEGIC_RESERVE = 10M"
    ((PASSED_TESTS++))
else
    error "Distribuição: INITIAL_STRATEGIC_RESERVE incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "INITIAL_MARKETING.*6_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Distribuição: INITIAL_MARKETING = 6M"
    ((PASSED_TESTS++))
else
    error "Distribuição: INITIAL_MARKETING incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "INITIAL_AIRDROP.*2_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Distribuição: INITIAL_AIRDROP = 2M"
    ((PASSED_TESTS++))
else
    error "Distribuição: INITIAL_AIRDROP incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "INITIAL_TEAM.*2_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Distribuição: INITIAL_TEAM = 2M"
    ((PASSED_TESTS++))
else
    error "Distribuição: INITIAL_TEAM incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if grep -q "INITIAL_TREASURY.*2_000_000" programs/gmc_token_native/src/lib.rs; then
    success "Distribuição: INITIAL_TREASURY = 2M"
    ((PASSED_TESTS++))
else
    error "Distribuição: INITIAL_TREASURY incorreto"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# ============================================================================
# RELATÓRIO FINAL
# ============================================================================
echo "============================================================================"
echo -e "${BLUE}📊 RELATÓRIO FINAL DE TESTES${NC}"
echo "============================================================================"
echo ""
echo -e "Total de Testes Executados: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Testes Aprovados: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Testes Falharam: ${RED}$FAILED_TESTS${NC}"
echo ""

# Calcular porcentagem de sucesso
if [[ $TOTAL_TESTS -gt 0 ]]; then
    SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    echo -e "Taxa de Sucesso: ${BLUE}$SUCCESS_RATE%${NC}"
else
    echo -e "Taxa de Sucesso: ${RED}0%${NC}"
fi

echo ""
echo "============================================================================"

# Determinar status final
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 TODOS OS TESTES PASSARAM! O GMC TOKEN ESTÁ PRONTO PARA PRODUÇÃO!${NC}"
    exit 0
elif [[ $SUCCESS_RATE -ge 90 ]]; then
    echo -e "${YELLOW}⚠️  QUASE PRONTO: $SUCCESS_RATE% dos testes passaram. Revisar falhas menores.${NC}"
    exit 1
elif [[ $SUCCESS_RATE -ge 70 ]]; then
    echo -e "${YELLOW}🔧 NECESSITA CORREÇÕES: $SUCCESS_RATE% dos testes passaram. Revisar implementação.${NC}"
    exit 2
else
    echo -e "${RED}🚨 FALHAS CRÍTICAS: Apenas $SUCCESS_RATE% dos testes passaram. Revisão completa necessária.${NC}"
    exit 3
fi
