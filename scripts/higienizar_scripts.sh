#!/bin/bash

# =======================================================
# GMC TOKEN - SCRIPT DE HIGIENIZAÇÃO DA PASTA SCRIPTS
# =======================================================
# OBJETIVO: Limpar a pasta scripts/, mantendo apenas os
#           arquivos essenciais para a operação da mainnet.
# =======================================================

set -e

# Cores e funções de log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

log_info "Iniciando a higienização da pasta 'scripts/'..."
echo ""

# --- FASE 1: DEFINIR SCRIPTS ESSENCIAIS ---

# Lista de scripts a serem MANTIDOS. Todos os outros serão movidos ou removidos.
ESSENTIAL_SCRIPTS=(
    "load_mainnet_env.sh"
    "distribute_mainnet_funds.sh"
    "executar_testes_mainnet_fixed.sh"
    "create_backup_simple.sh"
    "higienizar_projeto.sh"
    "higienizar_scripts.sh" # O próprio script
)

log_info "Scripts essenciais a serem mantidos:"
for script in "${ESSENTIAL_SCRIPTS[@]}"; do
    echo "  - $script"
done
echo ""

# --- FASE 2: ARQUIVAR SCRIPTS OBSOLETOS ---

ARCHIVE_DIR_SCRIPTS="$PWD/_archive/scripts_obsoletos" # Usar caminho absoluto
mkdir -p "$ARCHIVE_DIR_SCRIPTS"
log_info "Pasta de arquivo para scripts criada/verificada em '$ARCHIVE_DIR_SCRIPTS'"

# Mover todos os scripts que não estão na lista de essenciais
cd scripts/
for file in *; do
    is_essential=false
    for essential in "${ESSENTIAL_SCRIPTS[@]}"; do
        if [[ "$file" == "$essential" ]]; then
            is_essential=true
            break
        fi
    done

    if [ "$is_essential" = false ]; then
        if [ -f "$file" ] || [ -d "$file" ]; then
            mv "$file" "$ARCHIVE_DIR_SCRIPTS/"
            log_info "Arquivado: $file"
        fi
    fi
done
cd .. # Voltar para a raiz

log_success "Todos os scripts não essenciais foram arquivados."
echo ""

# --- CONCLUSÃO ---
log_success "🎉 HIGIENIZAÇÃO DA PASTA SCRIPTS CONCLUÍDA! 🎉"
log_info "A pasta 'scripts/' agora contém apenas os arquivos essenciais."
echo "======================================================="
echo "Conteúdo final da pasta 'scripts/':"
ls -1 scripts/
echo "=======================================================" 