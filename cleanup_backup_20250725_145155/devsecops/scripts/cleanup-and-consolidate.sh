#!/bin/bash

# 🧹 GMC Ecosystem - Cleanup and Consolidation Script
# Script para limpeza, consolidação e organização dos arquivos do projeto
# Remove redundâncias e otimiza a estrutura DevSecOps

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES GLOBAIS
# =============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
BACKUP_DIR="$PROJECT_ROOT/backup/scripts_$(date +"%Y%m%d_%H%M%S")"
LOG_DIR="$PROJECT_ROOT/logs/cleanup"
REPORT_DIR="$PROJECT_ROOT/reports/cleanup"

# Criar diretórios necessários
mkdir -p "$BACKUP_DIR" "$LOG_DIR" "$REPORT_DIR"

# Timestamp para logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/cleanup_$TIMESTAMP.log"

# Configurações
DRY_RUN="${DRY_RUN:-false}"
CREATE_BACKUP="${CREATE_BACKUP:-true}"
VERBOSE="${VERBOSE:-false}"
FORCE="${FORCE:-false}"

# =============================================================================
# FUNÇÕES UTILITÁRIAS
# =============================================================================

# Função de logging
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[$timestamp] [INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] [WARN]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] [SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${PURPLE}[$timestamp] [DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            fi
            ;;
        "CLEANUP")
            echo -e "${CYAN}[$timestamp] [CLEANUP]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Função para criar backup
create_backup() {
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        log "INFO" "Criando backup dos scripts existentes..."
        
        if [[ -d "$SCRIPTS_DIR" ]]; then
            cp -r "$SCRIPTS_DIR" "$BACKUP_DIR/"
            log "SUCCESS" "Backup criado em: $BACKUP_DIR"
        else
            log "WARN" "Diretório de scripts não encontrado: $SCRIPTS_DIR"
        fi
    else
        log "INFO" "Backup desabilitado."
    fi
}

# Função para analisar arquivos
analyze_files() {
    log "INFO" "Analisando estrutura de arquivos..."
    
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        log "ERROR" "Diretório de scripts não encontrado: $SCRIPTS_DIR"
        return 1
    fi
    
    # Contar arquivos por tipo
    local total_files
    total_files=$(find "$SCRIPTS_DIR" -type f | wc -l)
    
    local js_files
    js_files=$(find "$SCRIPTS_DIR" -name "*.js" | wc -l)
    
    local ts_files
    ts_files=$(find "$SCRIPTS_DIR" -name "*.ts" | wc -l)
    
    local sh_files
    sh_files=$(find "$SCRIPTS_DIR" -name "*.sh" | wc -l)
    
    local json_files
    json_files=$(find "$SCRIPTS_DIR" -name "*.json" | wc -l)
    
    log "INFO" "Análise de arquivos:"
    log "INFO" "  Total: $total_files arquivos"
    log "INFO" "  JavaScript: $js_files arquivos"
    log "INFO" "  TypeScript: $ts_files arquivos"
    log "INFO" "  Shell: $sh_files arquivos"
    log "INFO" "  JSON: $json_files arquivos"
    
    return 0
}

# =============================================================================
# IDENTIFICAÇÃO DE ARQUIVOS REDUNDANTES
# =============================================================================

# Scripts redundantes de Devnet identificados
declare -a REDUNDANT_DEVNET_SCRIPTS=(
    "devnet_simple_airdrop.js"
    "devnet_multi_strategy_airdrop.js"
    "devnet_focused_collector.js"
    "devnet_final_strategy.js"
    "devnet_classic_airdrop.js"
    "devnet_ultimate_airdrop.js"
    "devnet_direct_airdrop.js"
    "devnet_deploy_minimal.js"
    "devnet_airdrop_and_deploy.sh"
)

# Scripts redundantes de SOL collection
declare -a REDUNDANT_SOL_SCRIPTS=(
    "sol_collector_v1.js"
    "sol_collector_v2.js"
    "sol_collector_optimized.js"
    "sol_airdrop_basic.js"
    "sol_airdrop_advanced.js"
    "collect_sol_devnet.sh"
    "collect_sol_testnet.sh"
)

# Scripts de deployment redundantes
declare -a REDUNDANT_DEPLOY_SCRIPTS=(
    "deploy_basic.js"
    "deploy_simple.sh"
    "deploy_old.ts"
    "deployment_v1.js"
    "deployment_v2.js"
)

# Scripts de teste redundantes
declare -a REDUNDANT_TEST_SCRIPTS=(
    "test_basic.js"
    "test_simple.ts"
    "test_old.js"
    "integration_test_old.js"
)

# Arquivos temporários e de backup
declare -a TEMP_FILES=(
    "*.tmp"
    "*.bak"
    "*.old"
    "*~"
    ".DS_Store"
    "Thumbs.db"
    "*.log"
    "node_modules"
    "target/debug"
    "target/release"
)

# =============================================================================
# FUNÇÕES DE LIMPEZA
# =============================================================================

# Função para remover scripts redundantes
remove_redundant_scripts() {
    log "CLEANUP" "Removendo scripts redundantes..."
    
    local removed_count=0
    local total_size=0
    
    # Combinar todas as listas de scripts redundantes
    local all_redundant=()
    all_redundant+=("${REDUNDANT_DEVNET_SCRIPTS[@]}")
    all_redundant+=("${REDUNDANT_SOL_SCRIPTS[@]}")
    all_redundant+=("${REDUNDANT_DEPLOY_SCRIPTS[@]}")
    all_redundant+=("${REDUNDANT_TEST_SCRIPTS[@]}")
    
    for script in "${all_redundant[@]}"; do
        local script_path="$SCRIPTS_DIR/$script"
        
        if [[ -f "$script_path" ]]; then
            local file_size
            file_size=$(stat -f%z "$script_path" 2>/dev/null || stat -c%s "$script_path" 2>/dev/null || echo "0")
            
            log "CLEANUP" "Removendo script redundante: $script ($file_size bytes)"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                rm "$script_path"
            fi
            
            ((removed_count++))
            ((total_size += file_size))
        else
            log "DEBUG" "Script não encontrado (já removido?): $script"
        fi
    done
    
    log "SUCCESS" "Scripts redundantes removidos: $removed_count ($(echo "scale=2; $total_size / 1024" | bc -l) KB)"
    
    return 0
}

# Função para remover arquivos temporários
remove_temp_files() {
    log "CLEANUP" "Removendo arquivos temporários..."
    
    local removed_count=0
    local total_size=0
    
    for pattern in "${TEMP_FILES[@]}"; do
        while IFS= read -r -d '' file; do
            local file_size
            file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            
            log "CLEANUP" "Removendo arquivo temporário: $(basename "$file") ($file_size bytes)"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                rm -rf "$file"
            fi
            
            ((removed_count++))
            ((total_size += file_size))
        done < <(find "$SCRIPTS_DIR" -name "$pattern" -print0 2>/dev/null || true)
    done
    
    log "SUCCESS" "Arquivos temporários removidos: $removed_count ($(echo "scale=2; $total_size / 1024" | bc -l) KB)"
    
    return 0
}

# Função para consolidar scripts similares
consolidate_similar_scripts() {
    log "CLEANUP" "Consolidando scripts similares..."
    
    # Identificar grupos de scripts similares (compatível com Bash 3.x)
    local groups=("airdrop" "deploy" "test" "collect")
    
    for group in "${groups[@]}"; do
        local files=()
        
        # Buscar arquivos por padrão
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "$SCRIPTS_DIR" -name "*${group}*" -type f -print0 2>/dev/null)
        
        local file_count=${#files[@]}
        
        if [[ $file_count -gt 1 ]]; then
            log "INFO" "Grupo '$group' tem $file_count scripts similares:"
            
            for file in "${files[@]}"; do
                if [[ -n "$file" ]]; then
                    log "INFO" "  - $(basename "$file")"
                fi
            done
            
            # Sugerir consolidação (não executar automaticamente)
            log "WARN" "Considere consolidar scripts do grupo '$group' manualmente."
        fi
    done
    
    return 0
}

# =============================================================================
# ORGANIZAÇÃO E ESTRUTURAÇÃO
# =============================================================================

# Função para criar nova estrutura organizada
create_organized_structure() {
    log "INFO" "Criando estrutura organizada..."
    
    # Criar diretórios organizados
    local organized_dirs=(
        "$SCRIPTS_DIR/devnet"
        "$SCRIPTS_DIR/testnet"
        "$SCRIPTS_DIR/mainnet"
        "$SCRIPTS_DIR/common"
        "$SCRIPTS_DIR/deprecated"
        "$SCRIPTS_DIR/utils"
    )
    
    for dir in "${organized_dirs[@]}"; do
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$dir"
        fi
        log "INFO" "Diretório criado: $(basename "$dir")"
    done
    
    return 0
}

# Função para mover scripts para estrutura organizada
organize_scripts() {
    log "INFO" "Organizando scripts por ambiente e funcionalidade..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Simulando organização de scripts..."
        return 0
    fi
    
    # Mover scripts por ambiente
    find "$SCRIPTS_DIR" -maxdepth 1 -name "devnet_*" -type f -exec mv {} "$SCRIPTS_DIR/devnet/" \; 2>/dev/null || true
    find "$SCRIPTS_DIR" -maxdepth 1 -name "testnet_*" -type f -exec mv {} "$SCRIPTS_DIR/testnet/" \; 2>/dev/null || true
    find "$SCRIPTS_DIR" -maxdepth 1 -name "mainnet_*" -type f -exec mv {} "$SCRIPTS_DIR/mainnet/" \; 2>/dev/null || true
    
    # Mover utilitários
    find "$SCRIPTS_DIR" -maxdepth 1 -name "*helper*" -type f -exec mv {} "$SCRIPTS_DIR/utils/" \; 2>/dev/null || true
    find "$SCRIPTS_DIR" -maxdepth 1 -name "*util*" -type f -exec mv {} "$SCRIPTS_DIR/utils/" \; 2>/dev/null || true
    
    # Mover scripts comuns
    find "$SCRIPTS_DIR" -maxdepth 1 -name "setup_*" -type f -exec mv {} "$SCRIPTS_DIR/common/" \; 2>/dev/null || true
    
    log "SUCCESS" "Scripts organizados por estrutura."
    
    return 0
}

# =============================================================================
# CRIAÇÃO DE SCRIPTS CONSOLIDADOS
# =============================================================================

# Função para criar script master de deployment
create_master_deployment_script() {
    log "INFO" "Criando script master de deployment..."
    
    local master_script="$SCRIPTS_DIR/deploy-master.sh"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > "$master_script" << 'EOF'
#!/bin/bash

# 🚀 GMC Ecosystem - Master Deployment Script
# Script consolidado para deployment em todos os ambientes
# Substitui múltiplos scripts de deployment redundantes

set -euo pipefail

# Importar script de deployment automation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVSECOPS_DIR="$(dirname "$SCRIPT_DIR")/devsecops"

if [[ -f "$DEVSECOPS_DIR/scripts/deployment-automation.sh" ]]; then
    source "$DEVSECOPS_DIR/scripts/deployment-automation.sh"
else
    echo "❌ Script de deployment automation não encontrado!"
    echo "Execute primeiro: ./devsecops/scripts/deployment-automation.sh"
    exit 1
fi

# Executar deployment com os argumentos passados
main "$@"
EOF
        
        chmod +x "$master_script"
        log "SUCCESS" "Script master criado: $master_script"
    else
        log "INFO" "[DRY-RUN] Script master seria criado em: $master_script"
    fi
    
    return 0
}

# Função para criar script master de SOL management
create_master_sol_script() {
    log "INFO" "Criando script master de SOL management..."
    
    local master_script="$SCRIPTS_DIR/sol-master.sh"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > "$master_script" << 'EOF'
#!/bin/bash

# 🪙 GMC Ecosystem - Master SOL Management Script
# Script consolidado para gerenciamento de SOL em todos os ambientes
# Substitui múltiplos scripts de airdrop e coleta redundantes

set -euo pipefail

# Importar script de SOL management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVSECOPS_DIR="$(dirname "$SCRIPT_DIR")/devsecops"

if [[ -f "$DEVSECOPS_DIR/scripts/sol-management.sh" ]]; then
    source "$DEVSECOPS_DIR/scripts/sol-management.sh"
else
    echo "❌ Script de SOL management não encontrado!"
    echo "Execute primeiro: ./devsecops/scripts/sol-management.sh"
    exit 1
fi

# Executar SOL management com os argumentos passados
main "$@"
EOF
        
        chmod +x "$master_script"
        log "SUCCESS" "Script master criado: $master_script"
    else
        log "INFO" "[DRY-RUN] Script master seria criado em: $master_script"
    fi
    
    return 0
}

# =============================================================================
# VALIDAÇÃO E VERIFICAÇÃO
# =============================================================================

# Função para validar integridade após limpeza
validate_cleanup() {
    log "INFO" "Validando integridade após limpeza..."
    
    # Verificar se scripts essenciais ainda existem
    local essential_scripts=(
        "deploy_ecosystem_automated.ts"
        "mainnet_deploy_ceremony.ts"
        "setup_environment.sh"
    )
    
    local missing_count=0
    
    for script in "${essential_scripts[@]}"; do
        local script_path="$SCRIPTS_DIR/$script"
        
        if [[ ! -f "$script_path" ]]; then
            log "ERROR" "Script essencial removido acidentalmente: $script"
            ((missing_count++))
        else
            log "SUCCESS" "Script essencial preservado: $script"
        fi
    done
    
    if [[ $missing_count -gt 0 ]]; then
        log "ERROR" "$missing_count scripts essenciais foram removidos!"
        log "ERROR" "Restaure do backup: $BACKUP_DIR"
        return 1
    fi
    
    log "SUCCESS" "Validação de integridade concluída."
    return 0
}

# Função para gerar relatório de limpeza
generate_cleanup_report() {
    log "INFO" "Gerando relatório de limpeza..."
    
    local report_file="$REPORT_DIR/cleanup_report_$TIMESTAMP.json"
    
    # Contar arquivos após limpeza
    local files_after=0
    if [[ -d "$SCRIPTS_DIR" ]]; then
        files_after=$(find "$SCRIPTS_DIR" -type f | wc -l)
    fi
    
    cat > "$report_file" << EOF
{
  "cleanup_report": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "project_root": "$PROJECT_ROOT",
    "scripts_directory": "$SCRIPTS_DIR",
    "dry_run": "$DRY_RUN",
    "backup_created": "$CREATE_BACKUP",
    "backup_location": "$BACKUP_DIR"
  },
  "statistics": {
    "files_after_cleanup": "$files_after",
    "redundant_scripts_identified": "${#REDUNDANT_DEVNET_SCRIPTS[@]}",
    "temp_file_patterns": "${#TEMP_FILES[@]}"
  },
  "actions_performed": [
    "Backup creation",
    "Redundant script removal",
    "Temporary file cleanup",
    "Directory organization",
    "Master script creation",
    "Integrity validation"
  ],
  "new_structure": {
    "organized_directories": [
      "devnet/",
      "testnet/",
      "mainnet/",
      "common/",
      "deprecated/",
      "utils/"
    ],
    "master_scripts": [
      "deploy-master.sh",
      "sol-master.sh"
    ]
  },
  "recommendations": [
    "Use os scripts master para operações futuras",
    "Revise scripts na pasta deprecated/ antes de remover",
    "Mantenha a estrutura organizada para novos scripts",
    "Execute testes após a limpeza"
  ],
  "artifacts": {
    "log_file": "$LOG_FILE",
    "report_file": "$report_file",
    "backup_directory": "$BACKUP_DIR"
  }
}
EOF
    
    log "SUCCESS" "Relatório gerado: $report_file"
    echo "$report_file"
}

# =============================================================================
# FUNÇÃO DE AJUDA
# =============================================================================

show_help() {
    cat << EOF
🧹 GMC Cleanup and Consolidation Script

Uso: $0 [OPÇÕES]

Opções:
  --dry-run           Simular limpeza sem executar
  --no-backup         Não criar backup dos scripts
  --force             Forçar limpeza sem confirmações
  --verbose           Logs detalhados
  --help              Mostrar esta ajuda

Operações realizadas:
  1. Backup dos scripts existentes
  2. Análise da estrutura atual
  3. Remoção de scripts redundantes
  4. Limpeza de arquivos temporários
  5. Organização em estrutura hierárquica
  6. Criação de scripts master consolidados
  7. Validação de integridade
  8. Geração de relatório

Scripts redundantes identificados:
  - Múltiplos scripts de airdrop Devnet
  - Scripts de coleta SOL duplicados
  - Scripts de deployment obsoletos
  - Arquivos temporários e backup

Nova estrutura:
  scripts/
  ├── devnet/          # Scripts específicos do Devnet
  ├── testnet/         # Scripts específicos do Testnet
  ├── mainnet/         # Scripts específicos do Mainnet
  ├── common/          # Scripts comuns a todos ambientes
  ├── utils/           # Utilitários e helpers
  ├── deprecated/      # Scripts obsoletos (para revisão)
  ├── deploy-master.sh # Script master de deployment
  └── sol-master.sh    # Script master de SOL management

Exemplos:
  $0                   # Limpeza completa com backup
  $0 --dry-run         # Simular limpeza
  $0 --no-backup       # Limpeza sem backup
  $0 --force           # Limpeza forçada

Variáveis de ambiente:
  DRY_RUN             Modo simulação (true|false)
  CREATE_BACKUP       Criar backup (true|false)
  VERBOSE             Logs detalhados (true|false)
  FORCE               Forçar operação (true|false)

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Banner
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "🧹 GMC ECOSYSTEM - CLEANUP AND CONSOLIDATION AUTOMATION 🧹"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            "--dry-run")
                export DRY_RUN="true"
                shift
                ;;
            "--no-backup")
                export CREATE_BACKUP="false"
                shift
                ;;
            "--force")
                export FORCE="true"
                shift
                ;;
            "--verbose")
                export VERBOSE="true"
                shift
                ;;
            "--help")
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar se é dry-run
    if [[ "$DRY_RUN" == "true" ]]; then
        log "WARN" "🔍 MODO DRY-RUN: Nenhuma alteração será feita."
    fi
    
    # Confirmação se não for force
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        echo -e "${YELLOW}⚠️  ATENÇÃO: Esta operação irá:${NC}"
        echo "   - Remover scripts redundantes"
        echo "   - Reorganizar estrutura de diretórios"
        echo "   - Criar scripts master consolidados"
        echo ""
        echo -n "Deseja continuar? (yes/no): "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            log "INFO" "Operação cancelada pelo usuário."
            exit 0
        fi
    fi
    
    # Executar limpeza e consolidação
    log "INFO" "🚀 Iniciando processo de limpeza e consolidação..."
    
    # 1. Criar backup
    create_backup
    
    # 2. Analisar estrutura atual
    analyze_files
    
    # 3. Criar estrutura organizada
    create_organized_structure
    
    # 4. Remover scripts redundantes
    remove_redundant_scripts
    
    # 5. Remover arquivos temporários
    remove_temp_files
    
    # 6. Consolidar scripts similares (análise)
    consolidate_similar_scripts
    
    # 7. Organizar scripts
    organize_scripts
    
    # 8. Criar scripts master
    create_master_deployment_script
    create_master_sol_script
    
    # 9. Validar integridade
    if ! validate_cleanup; then
        log "ERROR" "Falha na validação de integridade!"
        exit 1
    fi
    
    # 10. Gerar relatório
    local report_file
    report_file=$(generate_cleanup_report)
    
    # Resumo final
    log "SUCCESS" "🎉 Limpeza e consolidação concluídas com sucesso!"
    log "INFO" "📊 Relatório: $report_file"
    
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        log "INFO" "💾 Backup: $BACKUP_DIR"
    fi
    
    log "INFO" "📁 Nova estrutura organizada criada"
    log "INFO" "🚀 Scripts master disponíveis:"
    log "INFO" "   - deploy-master.sh (deployment)"
    log "INFO" "   - sol-master.sh (SOL management)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "🔍 Execute sem --dry-run para aplicar as alterações."
    fi
    
    return 0
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi