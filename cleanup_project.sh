#!/bin/bash

# ============================================================================
# SCRIPT DE HIGIENIZAÇÃO DO PROJETO GMC TOKEN
# ============================================================================
# Remove arquivos desnecessários e mantém apenas o essencial para produção
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

echo "============================================================================"
echo "🧹 HIGIENIZAÇÃO DO PROJETO GMC TOKEN"
echo "============================================================================"

# Verificar se estamos no diretório correto
if [[ ! -f "Cargo.toml" ]] || [[ ! -d "programs" ]]; then
    error "Execute este script a partir da raiz do projeto GMC-Token"
    exit 1
fi

# Criar backup antes da higienização
log "Criando backup de segurança..."
backup_dir="cleanup_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# ============================================================================
# 1. REMOVER ARQUIVOS DESNECESSÁRIOS NA RAIZ
# ============================================================================
echo -e "${YELLOW}📁 LIMPANDO ARQUIVOS DA RAIZ${NC}"

# Arquivos temporários e de teste na raiz
files_to_remove=(
    "tokenomics_validation_standalone.rs"
    "usdt_fees_validation_corrected"
    "usdt_fees_validation_corrected.rs"
    "usdt_fees_validation_standalone.rs"
    "test_staking_percentage_fees.log"
    "build_all.sh"
    "docker-build.sh"
    "setup_environment.sh"
)

for file in "${files_to_remove[@]}"; do
    if [[ -f "$file" ]]; then
        log "Removendo arquivo: $file"
        mv "$file" "$backup_dir/" 2>/dev/null || rm -f "$file"
        success "Removido: $file"
    fi
done

# ============================================================================
# 2. LIMPAR DIRETÓRIO DE PROGRAMAS
# ============================================================================
echo -e "${YELLOW}🔧 LIMPANDO DIRETÓRIO DE PROGRAMAS${NC}"

# Arquivos desnecessários no src/
program_files_to_remove=(
    "programs/gmc_token_native/src/cpi_batch_optimization_broken.rs"
    "programs/gmc_token_native/src/lib.rs.backup"
    "programs/gmc_token_native/src/lib_minimal.rs"
    "programs/gmc_token_native/src/staking_optimized.rs"
    "programs/gmc_token_native/src/zero_copy_optimization.rs"
    "programs/gmc_token_native/src/critical_tests.rs"
)

for file in "${program_files_to_remove[@]}"; do
    if [[ -f "$file" ]]; then
        log "Removendo arquivo: $(basename $file)"
        mv "$file" "$backup_dir/" 2>/dev/null || rm -f "$file"
        success "Removido: $(basename $file)"
    fi
done

# ============================================================================
# 3. CONSOLIDAR SCRIPTS ESSENCIAIS
# ============================================================================
echo -e "${YELLOW}📜 CONSOLIDANDO SCRIPTS${NC}"

# Manter apenas scripts essenciais
essential_scripts=(
    "create_gmc_token_distribution_correct.sh"
    "test_business_rules_critical.sh"
    "test_integration_modules.sh"
    "validate_all_business_rules.sh"
)

log "Movendo scripts não essenciais para backup..."
if [[ -d "scripts" ]]; then
    for script in scripts/*.sh; do
        script_name=$(basename "$script")
        is_essential=false
        
        for essential in "${essential_scripts[@]}"; do
            if [[ "$script_name" == "$essential" ]]; then
                is_essential=true
                break
            fi
        done
        
        if [[ "$is_essential" == false ]]; then
            mv "$script" "$backup_dir/" 2>/dev/null
            success "Movido para backup: $script_name"
        else
            success "Mantido script essencial: $script_name"
        fi
    done
fi

# ============================================================================
# 4. LIMPAR DIRETÓRIOS DESNECESSÁRIOS
# ============================================================================
echo -e "${YELLOW}📂 LIMPANDO DIRETÓRIOS DESNECESSÁRIOS${NC}"

# Diretórios que podem ser removidos ou movidos
dirs_to_backup=(
    "scripts_backup"
    "devsecops"
    "audit"
    "reports"
)

for dir in "${dirs_to_backup[@]}"; do
    if [[ -d "$dir" ]]; then
        log "Movendo diretório para backup: $dir"
        mv "$dir" "$backup_dir/" 2>/dev/null
        success "Movido para backup: $dir"
    fi
done

# ============================================================================
# 5. LIMPAR DOCUMENTAÇÃO REDUNDANTE
# ============================================================================
echo -e "${YELLOW}📚 ORGANIZANDO DOCUMENTAÇÃO${NC}"

# Documentos redundantes ou temporários
docs_to_backup=(
    "AUDITORIA_EXTERNA_PREPARACAO_FINAL.md"
    "DEPLOY_READINESS_REPORT.md"
    "DEPLOY_TROUBLESHOOTING.md"
    "README_SIGNATURE_TROUBLESHOOTING.md"
    "RELATORIO_FINAL_CONFORMIDADE.md"
    "SECURITY_AUDIT_CHECKLIST.md"
    "TDD_TODOS_IMPLEMENTATION_ANALYSIS.md"
)

for doc in "${docs_to_backup[@]}"; do
    if [[ -f "$doc" ]]; then
        log "Movendo documento para backup: $doc"
        mv "$doc" "$backup_dir/" 2>/dev/null
        success "Movido para backup: $doc"
    fi
done

# ============================================================================
# 6. LIMPAR ARQUIVOS DE BUILD TEMPORÁRIOS
# ============================================================================
echo -e "${YELLOW}🔨 LIMPANDO ARQUIVOS DE BUILD${NC}"

# Limpar target directory (será regenerado no build)
if [[ -d "target" ]]; then
    log "Limpando diretório target..."
    rm -rf target
    success "Diretório target limpo"
fi

# Limpar deploy directory temporário
if [[ -d "deploy" ]]; then
    log "Movendo diretório deploy para backup..."
    mv deploy "$backup_dir/" 2>/dev/null
    success "Diretório deploy movido para backup"
fi

# ============================================================================
# 7. VERIFICAR ARQUIVOS ESSENCIAIS MANTIDOS
# ============================================================================
echo -e "${YELLOW}✅ VERIFICANDO ARQUIVOS ESSENCIAIS${NC}"

essential_files=(
    "Cargo.toml"
    "Cargo.lock"
    "README.md"
    "RELATORIO_CRITICO_FINAL.md"
    "PLANO_TESTES_DETALHADO.md"
    ".gitignore"
    ".program_id"
    "programs/gmc_token_native/Cargo.toml"
    "programs/gmc_token_native/src/lib.rs"
    "programs/gmc_token_native/src/staking.rs"
    "programs/gmc_token_native/src/affiliate.rs"
    "programs/gmc_token_native/src/ranking.rs"
    "programs/gmc_token_native/src/treasury.rs"
    "programs/gmc_token_native/src/vesting.rs"
    "programs/gmc_token_native/src/cpi_batch_optimization.rs"
)

missing_files=()
for file in "${essential_files[@]}"; do
    if [[ -f "$file" ]]; then
        success "Arquivo essencial presente: $(basename $file)"
    else
        error "Arquivo essencial AUSENTE: $file"
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    error "ATENÇÃO: Arquivos essenciais ausentes detectados!"
    for missing in "${missing_files[@]}"; do
        echo "  - $missing"
    done
    exit 1
fi

# ============================================================================
# 8. VERIFICAR ESTRUTURA FINAL
# ============================================================================
echo -e "${YELLOW}📊 ESTRUTURA FINAL DO PROJETO${NC}"

log "Estrutura mantida:"
echo "📁 GMC-Token/"
echo "  ├── 📄 Cargo.toml"
echo "  ├── 📄 Cargo.lock"
echo "  ├── 📄 README.md"
echo "  ├── 📄 RELATORIO_CRITICO_FINAL.md"
echo "  ├── 📄 PLANO_TESTES_DETALHADO.md"
echo "  ├── 📁 programs/"
echo "  │   └── 📁 gmc_token_native/"
echo "  │       ├── 📄 Cargo.toml"
echo "  │       └── 📁 src/"
echo "  │           ├── 📄 lib.rs (principal)"
echo "  │           ├── 📄 staking.rs"
echo "  │           ├── 📄 affiliate.rs"
echo "  │           ├── 📄 ranking.rs"
echo "  │           ├── 📄 treasury.rs"
echo "  │           ├── 📄 vesting.rs"
echo "  │           └── 📄 cpi_batch_optimization.rs"
echo "  ├── 📁 scripts/ (apenas essenciais)"
echo "  ├── 📁 Docs/"
echo "  └── 📁 config/"

echo ""
echo "============================================================================"
echo -e "${GREEN}🎉 HIGIENIZAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo "============================================================================"
echo ""
echo -e "📦 Backup criado em: ${BLUE}$backup_dir${NC}"
echo -e "🗂️  Arquivos removidos/movidos: ${GREEN}$(find "$backup_dir" -type f | wc -l | tr -d ' ')${NC}"
echo -e "📁 Diretórios movidos: ${GREEN}$(find "$backup_dir" -maxdepth 1 -type d | wc -l | tr -d ' ')${NC}"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "1. Executar build para verificar integridade"
echo "2. Testar deploy na DevNet"
echo "3. Executar testes de integração"
echo "4. Commit das alterações no Git"
echo ""
echo "============================================================================"
