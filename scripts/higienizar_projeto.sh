#!/bin/bash

# =======================================================
# GMC TOKEN - SCRIPT DE HIGIENIZAÇÃO DO PROJETO
# =======================================================
# OBJETIVO: Limpar o repositório movendo arquivos históricos
#           para a pasta _archive/ e removendo arquivos
#           temporários e gerados automaticamente.
# ATENÇÃO: Esta operação modifica a estrutura de arquivos.
# =======================================================

set -e

# Cores e funções de log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log_info "Iniciando a higienização do projeto GMC Token..."
log_warning "As pastas 'Docs', 'programs', e 'wallets' não serão alteradas."
echo ""

# --- FASE 1: ARQUIVAR ARQUIVOS HISTÓRICOS ---

log_info "FASE 1: Movendo relatórios, backups e análises para a pasta '_archive/'..."

# Criar a pasta de arquivo, se não existir
ARCHIVE_DIR="_archive"
mkdir -p "$ARCHIVE_DIR"
log_success "Pasta '$ARCHIVE_DIR' criada/verificada."

# Lista de arquivos e pastas para mover
TO_ARCHIVE=(
    ANALISE_COMPLETA_POSSIBILIDADES.md
    ANALISE_SEGURANCA_STAKING.md
    BACKUP_SEGURANCA_MAINNET.md
    CORRECAO_ANALISE_STAKING.md
    DEPARA_CRITICO_CODIGO_VS_DEPLOY.md
    FALHA_CRITICA_STAKING_FUND.md
    GUIA_METADADOS_MANUAL.md
    GUIA_VISUALIZACAO_GMC.md
    MAINNET_*.md
    ONDE_ESTAO_MINHAS_CHAVES.md
    PLANO_*.md
    PROBLEMA_REAL_IDENTIFICADO.md
    RELATORIO_*.md
    RESOLVER_PROBLEMA_SEED.md
    SOLUCAO_*.md
    TESTNET_*.md
    backups/
    cleanup_backup_20250725_145155/
    logs/
    mainnet_wallets_20250728_180234.tar.gz
    reports/
    testes_mainnet_*.log
)

# Mover os arquivos para o arquivo morto
for item in "${TO_ARCHIVE[@]}"; do
    # Usar 'find' para lidar com wildcards e arquivos que podem não existir
    find . -maxdepth 1 -name "$item" -exec mv {} "$ARCHIVE_DIR/" \;
    log_info "Arquivado: $item"
done

log_success "Todos os arquivos históricos foram movidos para a pasta '$ARCHIVE_DIR'."
echo ""

# --- FASE 2: REMOVER ARQUIVOS TEMPORÁRIOS E GERÁVEIS ---

log_info "FASE 2: Removendo arquivos temporários, de cache e de build..."

# Lista de arquivos e pastas para remover
TO_REMOVE=(
    .cargo/
    .devnet-keys/
    .testnet-keys/
    .testnet-mint-address
    .testnet-program-id
    .testnet-wallets/
    .program_id
    Cargo.lock
    create_metadata_simple.js
    deploy/
    gmc-metaplex-metadata.json
    gmc_metadata.json
    jupiter_token_list_entry.json
    solana_token_list_entry.json
    solscan_registry.json
    metadata/
    metadata-setup/
    native_metadata/
    metadata_registration_instructions.md
    metadata_registry.json
    native_metadata_account.json
    temp_metadata.json
    token_metadata_native.json
    node_modules/
    package-lock.json
    package.json.temp
    target/
    test_env_config.sh
)

# Remover os arquivos e pastas
for item in "${TO_REMOVE[@]}"; do
    if [ -e "$item" ]; then
        rm -rf "$item"
        log_info "Removido: $item"
    else
        log_warning "Item não encontrado para remoção (ignorado): $item"
    fi
done

log_success "Arquivos temporários e geráveis foram removidos."
echo ""

# --- CONCLUSÃO ---
log_success "🎉 HIGIENIZAÇÃO DO PROJETO CONCLUÍDA! 🎉"
log_info "O repositório está limpo e pronto para as próximas etapas."
echo "=======================================================" 