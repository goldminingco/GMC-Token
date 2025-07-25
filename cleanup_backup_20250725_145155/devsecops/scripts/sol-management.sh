#!/bin/bash

# 🪙 GMC Ecosystem - SOL Management & Collection Automation
# Script unificado para gerenciamento de SOL em Devnet, Testnet e Mainnet
# Consolidação e otimização de todos os scripts de airdrop existentes

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
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")")
LOG_DIR="$PROJECT_ROOT/logs/sol-management"
REPORT_DIR="$PROJECT_ROOT/reports/sol-management"
CONFIG_DIR="$PROJECT_ROOT/devsecops/config"

# Criar diretórios necessários
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Timestamp para logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/sol_management_$TIMESTAMP.log"

# Configurações padrão
ENVIRONMENT="${ENVIRONMENT:-devnet}"
STRATEGY="${STRATEGY:-smart}"
TARGET_BALANCE="${TARGET_BALANCE:-10.0}"
MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-2}"
PARALLEL_REQUESTS="${PARALLEL_REQUESTS:-3}"
TIMEOUT="${TIMEOUT:-30}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Arrays de endpoints por ambiente
declare -A DEVNET_ENDPOINTS=(
    ["official"]="https://api.devnet.solana.com"
    ["alchemy"]="https://solana-devnet.g.alchemy.com/v2/demo"
    ["quicknode"]="https://api.devnet.solana.com"
    ["helius"]="https://devnet.helius-rpc.com/?api-key=demo"
    ["syndica"]="https://solana-devnet.syndica.io/access-token/demo"
)

declare -A TESTNET_ENDPOINTS=(
    ["official"]="https://api.testnet.solana.com"
    ["alchemy"]="https://solana-testnet.g.alchemy.com/v2/demo"
    ["quicknode"]="https://api.testnet.solana.com"
)

declare -A MAINNET_ENDPOINTS=(
    ["official"]="https://api.mainnet-beta.solana.com"
    ["alchemy"]="https://solana-mainnet.g.alchemy.com/v2/demo"
    ["quicknode"]="https://api.mainnet-beta.solana.com"
    ["helius"]="https://mainnet.helius-rpc.com/?api-key=demo"
)

# Configurações de rate limiting por endpoint
declare -A RATE_LIMITS=(
    ["official"]="10"
    ["alchemy"]="5"
    ["quicknode"]="15"
    ["helius"]="20"
    ["syndica"]="25"
)

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
        "SOL")
            echo -e "${CYAN}[$timestamp] [SOL]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Função para verificar dependências
check_dependencies() {
    log "INFO" "Verificando dependências..."
    
    local deps=("solana" "curl" "jq" "bc")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Dependências faltando: ${missing_deps[*]}"
        log "INFO" "Instale as dependências faltando e tente novamente."
        exit 1
    fi
    
    log "SUCCESS" "Todas as dependências estão instaladas."
}

# Função para obter endpoints por ambiente
get_endpoints_for_environment() {
    local env=$1
    local -n endpoints_ref=$2
    
    case $env in
        "devnet")
            for key in "${!DEVNET_ENDPOINTS[@]}"; do
                endpoints_ref["$key"]="${DEVNET_ENDPOINTS[$key]}"
            done
            ;;
        "testnet")
            for key in "${!TESTNET_ENDPOINTS[@]}"; do
                endpoints_ref["$key"]="${TESTNET_ENDPOINTS[$key]}"
            done
            ;;
        "mainnet")
            for key in "${!MAINNET_ENDPOINTS[@]}"; do
                endpoints_ref["$key"]="${MAINNET_ENDPOINTS[$key]}"
            done
            ;;
        *)
            log "ERROR" "Ambiente não suportado: $env"
            return 1
            ;;
    esac
    
    return 0
}

# Função para testar conectividade de endpoint
test_endpoint() {
    local endpoint=$1
    local timeout=${2:-10}
    
    log "DEBUG" "Testando endpoint: $endpoint"
    
    local response
    response=$(curl -s --max-time "$timeout" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getVersion"}' \
        "$endpoint" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]] && echo "$response" | jq -e '.result' > /dev/null 2>&1; then
        log "DEBUG" "Endpoint ativo: $endpoint"
        return 0
    else
        log "DEBUG" "Endpoint inativo: $endpoint"
        return 1
    fi
}

# Função para obter endpoints ativos
get_active_endpoints() {
    local env=$1
    local -n active_endpoints_ref=$2
    
    declare -A available_endpoints
    get_endpoints_for_environment "$env" available_endpoints
    
    log "INFO" "Testando conectividade dos endpoints..."
    
    local active_count=0
    for name in "${!available_endpoints[@]}"; do
        local endpoint="${available_endpoints[$name]}"
        
        if test_endpoint "$endpoint" 5; then
            active_endpoints_ref["$name"]="$endpoint"
            ((active_count++))
            log "SUCCESS" "Endpoint ativo: $name ($endpoint)"
        else
            log "WARN" "Endpoint inativo: $name ($endpoint)"
        fi
    done
    
    log "INFO" "Endpoints ativos encontrados: $active_count"
    
    if [[ $active_count -eq 0 ]]; then
        log "ERROR" "Nenhum endpoint ativo encontrado para $env!"
        return 1
    fi
    
    return 0
}

# Função para obter saldo atual
get_current_balance() {
    local wallet_path=$1
    local endpoint=$2
    
    log "DEBUG" "Obtendo saldo de $wallet_path via $endpoint"
    
    local balance
    balance=$(solana balance "$wallet_path" --url "$endpoint" 2>/dev/null | \
        grep -o '[0-9]*\.[0-9]*' | head -1 || echo "0")
    
    echo "$balance"
}

# Função para solicitar airdrop
request_airdrop() {
    local wallet_path=$1
    local amount=$2
    local endpoint=$3
    local endpoint_name=$4
    
    log "SOL" "Solicitando airdrop de $amount SOL via $endpoint_name..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Simulando airdrop de $amount SOL"
        return 0
    fi
    
    # Aplicar rate limiting
    local rate_limit=${RATE_LIMITS[$endpoint_name]:-10}
    local delay=$(echo "scale=2; 60 / $rate_limit" | bc)
    
    log "DEBUG" "Aplicando rate limit: $delay segundos entre requests"
    sleep "$delay"
    
    # Tentar airdrop com timeout
    local result
    if timeout "$TIMEOUT" solana airdrop "$amount" "$wallet_path" --url "$endpoint" 2>/dev/null; then
        log "SUCCESS" "Airdrop de $amount SOL realizado via $endpoint_name"
        return 0
    else
        log "ERROR" "Falha no airdrop via $endpoint_name"
        return 1
    fi
}

# Função para aguardar confirmação de transação
wait_for_confirmation() {
    local wallet_path=$1
    local expected_balance=$2
    local endpoint=$3
    local max_wait=${4:-30}
    
    log "INFO" "Aguardando confirmação (máximo $max_wait segundos)..."
    
    local wait_time=0
    local check_interval=2
    
    while [[ $wait_time -lt $max_wait ]]; do
        local current_balance
        current_balance=$(get_current_balance "$wallet_path" "$endpoint")
        
        if (( $(echo "$current_balance >= $expected_balance" | bc -l) )); then
            log "SUCCESS" "Transação confirmada! Saldo atual: $current_balance SOL"
            return 0
        fi
        
        log "DEBUG" "Aguardando... Saldo atual: $current_balance SOL (esperado: $expected_balance SOL)"
        sleep $check_interval
        ((wait_time += check_interval))
    done
    
    log "WARN" "Timeout na confirmação da transação"
    return 1
}

# =============================================================================
# ESTRATÉGIAS DE COLETA DE SOL
# =============================================================================

# Estratégia Simples: Um airdrop por vez
strategy_simple() {
    local wallet_path=$1
    local target_balance=$2
    local environment=$3
    
    log "INFO" "Executando estratégia SIMPLES..."
    
    declare -A active_endpoints
    if ! get_active_endpoints "$environment" active_endpoints; then
        return 1
    fi
    
    local current_balance
    current_balance=$(get_current_balance "$wallet_path" "${active_endpoints[official]}")
    log "SOL" "Saldo inicial: $current_balance SOL (meta: $target_balance SOL)"
    
    if (( $(echo "$current_balance >= $target_balance" | bc -l) )); then
        log "SUCCESS" "Meta já atingida!"
        return 0
    fi
    
    local needed_amount
    needed_amount=$(echo "$target_balance - $current_balance" | bc -l)
    
    # Usar primeiro endpoint ativo
    local endpoint_name="${!active_endpoints[*]}"
    endpoint_name=${endpoint_name%% *}  # Pegar primeiro
    local endpoint="${active_endpoints[$endpoint_name]}"
    
    local retry_count=0
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        if request_airdrop "$wallet_path" "$needed_amount" "$endpoint" "$endpoint_name"; then
            if wait_for_confirmation "$wallet_path" "$target_balance" "$endpoint"; then
                return 0
            fi
        fi
        
        ((retry_count++))
        log "WARN" "Tentativa $retry_count/$MAX_RETRIES falhou. Aguardando $RETRY_DELAY segundos..."
        sleep "$RETRY_DELAY"
    done
    
    log "ERROR" "Estratégia simples falhou após $MAX_RETRIES tentativas"
    return 1
}

# Estratégia Multi-Endpoint: Rotacionar entre endpoints
strategy_multi_endpoint() {
    local wallet_path=$1
    local target_balance=$2
    local environment=$3
    
    log "INFO" "Executando estratégia MULTI-ENDPOINT..."
    
    declare -A active_endpoints
    if ! get_active_endpoints "$environment" active_endpoints; then
        return 1
    fi
    
    local current_balance
    current_balance=$(get_current_balance "$wallet_path" "${active_endpoints[official]}")
    log "SOL" "Saldo inicial: $current_balance SOL (meta: $target_balance SOL)"
    
    if (( $(echo "$current_balance >= $target_balance" | bc -l) )); then
        log "SUCCESS" "Meta já atingida!"
        return 0
    fi
    
    local needed_amount
    needed_amount=$(echo "$target_balance - $current_balance" | bc -l)
    
    # Dividir quantidade entre endpoints
    local endpoint_count=${#active_endpoints[@]}
    local amount_per_endpoint
    amount_per_endpoint=$(echo "scale=2; $needed_amount / $endpoint_count" | bc -l)
    
    log "INFO" "Dividindo $needed_amount SOL entre $endpoint_count endpoints ($amount_per_endpoint SOL cada)"
    
    local success_count=0
    for endpoint_name in "${!active_endpoints[@]}"; do
        local endpoint="${active_endpoints[$endpoint_name]}"
        
        if request_airdrop "$wallet_path" "$amount_per_endpoint" "$endpoint" "$endpoint_name"; then
            ((success_count++))
        fi
        
        # Pequeno delay entre requests
        sleep 1
    done
    
    if [[ $success_count -gt 0 ]]; then
        log "INFO" "$success_count/$endpoint_count airdrops enviados. Aguardando confirmações..."
        
        if wait_for_confirmation "$wallet_path" "$target_balance" "${active_endpoints[official]}" 60; then
            return 0
        fi
    fi
    
    log "ERROR" "Estratégia multi-endpoint falhou"
    return 1
}

# Estratégia Paralela: Requests simultâneos
strategy_parallel() {
    local wallet_path=$1
    local target_balance=$2
    local environment=$3
    
    log "INFO" "Executando estratégia PARALELA..."
    
    declare -A active_endpoints
    if ! get_active_endpoints "$environment" active_endpoints; then
        return 1
    fi
    
    local current_balance
    current_balance=$(get_current_balance "$wallet_path" "${active_endpoints[official]}")
    log "SOL" "Saldo inicial: $current_balance SOL (meta: $target_balance SOL)"
    
    if (( $(echo "$current_balance >= $target_balance" | bc -l) )); then
        log "SUCCESS" "Meta já atingida!"
        return 0
    fi
    
    local needed_amount
    needed_amount=$(echo "$target_balance - $current_balance" | bc -l)
    
    # Criar arquivo temporário para resultados
    local temp_dir
    temp_dir=$(mktemp -d)
    local results_file="$temp_dir/results"
    
    log "INFO" "Executando $PARALLEL_REQUESTS requests paralelos..."
    
    # Lançar requests paralelos
    local pids=()
    local request_count=0
    
    for endpoint_name in "${!active_endpoints[@]}"; do
        if [[ $request_count -ge $PARALLEL_REQUESTS ]]; then
            break
        fi
        
        local endpoint="${active_endpoints[$endpoint_name]}"
        local amount_per_request
        amount_per_request=$(echo "scale=2; $needed_amount / $PARALLEL_REQUESTS" | bc -l)
        
        (
            if request_airdrop "$wallet_path" "$amount_per_request" "$endpoint" "$endpoint_name"; then
                echo "SUCCESS:$endpoint_name" >> "$results_file"
            else
                echo "FAILED:$endpoint_name" >> "$results_file"
            fi
        ) &
        
        pids+=("$!")
        ((request_count++))
    done
    
    # Aguardar conclusão de todos os processos
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Analisar resultados
    local success_count=0
    if [[ -f "$results_file" ]]; then
        success_count=$(grep -c "SUCCESS:" "$results_file" || echo "0")
    fi
    
    log "INFO" "$success_count/$request_count requests paralelos bem-sucedidos"
    
    # Limpar arquivos temporários
    rm -rf "$temp_dir"
    
    if [[ $success_count -gt 0 ]]; then
        if wait_for_confirmation "$wallet_path" "$target_balance" "${active_endpoints[official]}" 90; then
            return 0
        fi
    fi
    
    log "ERROR" "Estratégia paralela falhou"
    return 1
}

# Estratégia Inteligente: Adaptativa baseada em condições
strategy_smart() {
    local wallet_path=$1
    local target_balance=$2
    local environment=$3
    
    log "INFO" "Executando estratégia INTELIGENTE..."
    
    declare -A active_endpoints
    if ! get_active_endpoints "$environment" active_endpoints; then
        return 1
    fi
    
    local endpoint_count=${#active_endpoints[@]}
    local current_balance
    current_balance=$(get_current_balance "$wallet_path" "${active_endpoints[official]}")
    
    log "SOL" "Análise inicial: $current_balance SOL atual, $endpoint_count endpoints ativos"
    
    if (( $(echo "$current_balance >= $target_balance" | bc -l) )); then
        log "SUCCESS" "Meta já atingida!"
        return 0
    fi
    
    local needed_amount
    needed_amount=$(echo "$target_balance - $current_balance" | bc -l)
    
    # Decidir estratégia baseada em condições
    local chosen_strategy
    
    if [[ $endpoint_count -eq 1 ]]; then
        chosen_strategy="simple"
        log "INFO" "Apenas 1 endpoint ativo → Estratégia SIMPLES"
    elif (( $(echo "$needed_amount <= 2.0" | bc -l) )); then
        chosen_strategy="simple"
        log "INFO" "Quantidade pequena ($needed_amount SOL) → Estratégia SIMPLES"
    elif [[ $endpoint_count -ge 3 ]] && (( $(echo "$needed_amount >= 5.0" | bc -l) )); then
        chosen_strategy="parallel"
        log "INFO" "Múltiplos endpoints + quantidade grande → Estratégia PARALELA"
    else
        chosen_strategy="multi_endpoint"
        log "INFO" "Condições médias → Estratégia MULTI-ENDPOINT"
    fi
    
    # Executar estratégia escolhida
    case $chosen_strategy in
        "simple")
            strategy_simple "$wallet_path" "$target_balance" "$environment"
            ;;
        "multi_endpoint")
            strategy_multi_endpoint "$wallet_path" "$target_balance" "$environment"
            ;;
        "parallel")
            strategy_parallel "$wallet_path" "$target_balance" "$environment"
            ;;
    esac
    
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        log "SUCCESS" "Estratégia inteligente bem-sucedida!"
    else
        log "WARN" "Estratégia principal falhou. Tentando fallback..."
        
        # Fallback para estratégia simples
        if [[ "$chosen_strategy" != "simple" ]]; then
            log "INFO" "Executando fallback: estratégia simples"
            strategy_simple "$wallet_path" "$target_balance" "$environment"
            result=$?
        fi
    fi
    
    return $result
}

# Estratégia Agressiva: Máxima velocidade e paralelismo
strategy_aggressive() {
    local wallet_path=$1
    local target_balance=$2
    local environment=$3
    
    log "INFO" "Executando estratégia AGRESSIVA..."
    
    declare -A active_endpoints
    if ! get_active_endpoints "$environment" active_endpoints; then
        return 1
    fi
    
    local current_balance
    current_balance=$(get_current_balance "$wallet_path" "${active_endpoints[official]}")
    log "SOL" "Saldo inicial: $current_balance SOL (meta: $target_balance SOL)"
    
    if (( $(echo "$current_balance >= $target_balance" | bc -l) )); then
        log "SUCCESS" "Meta já atingida!"
        return 0
    fi
    
    local needed_amount
    needed_amount=$(echo "$target_balance - $current_balance" | bc -l)
    
    # Usar TODOS os endpoints simultaneamente
    local temp_dir
    temp_dir=$(mktemp -d)
    local results_file="$temp_dir/results"
    
    log "INFO" "Lançando requests em TODOS os $endpoint_count endpoints simultaneamente..."
    
    # Lançar múltiplos requests por endpoint
    local pids=()
    local total_requests=0
    
    for endpoint_name in "${!active_endpoints[@]}"; do
        local endpoint="${active_endpoints[$endpoint_name]}"
        
        # Múltiplos requests por endpoint
        for i in {1..2}; do
            local amount_per_request
            amount_per_request=$(echo "scale=2; $needed_amount / 4" | bc -l)
            
            (
                if request_airdrop "$wallet_path" "$amount_per_request" "$endpoint" "$endpoint_name-$i"; then
                    echo "SUCCESS:$endpoint_name-$i" >> "$results_file"
                else
                    echo "FAILED:$endpoint_name-$i" >> "$results_file"
                fi
            ) &
            
            pids+=("$!")
            ((total_requests++))
            
            # Pequeno delay para evitar sobrecarga
            sleep 0.1
        done
    done
    
    log "INFO" "$total_requests requests agressivos lançados. Aguardando..."
    
    # Aguardar todos os processos
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Analisar resultados
    local success_count=0
    if [[ -f "$results_file" ]]; then
        success_count=$(grep -c "SUCCESS:" "$results_file" || echo "0")
    fi
    
    log "INFO" "$success_count/$total_requests requests agressivos bem-sucedidos"
    
    # Limpar
    rm -rf "$temp_dir"
    
    if [[ $success_count -gt 0 ]]; then
        if wait_for_confirmation "$wallet_path" "$target_balance" "${active_endpoints[official]}" 120; then
            return 0
        fi
    fi
    
    log "ERROR" "Estratégia agressiva falhou"
    return 1
}

# =============================================================================
# FUNÇÕES PRINCIPAIS
# =============================================================================

# Função para coletar SOL
collect_sol() {
    local wallet_path=$1
    local target_balance=$2
    local environment=$3
    local strategy=$4
    
    log "INFO" "🪙 Iniciando coleta de SOL..."
    log "INFO" "Carteira: $wallet_path"
    log "INFO" "Meta: $target_balance SOL"
    log "INFO" "Ambiente: $environment"
    log "INFO" "Estratégia: $strategy"
    
    # Verificar se é ambiente que suporta airdrop
    if [[ "$environment" == "mainnet" ]]; then
        log "ERROR" "Airdrop não disponível em mainnet!"
        log "INFO" "Use faucets manuais ou transfira SOL de outra carteira."
        return 1
    fi
    
    # Verificar se carteira existe
    if [[ ! -f "$wallet_path" ]]; then
        log "ERROR" "Arquivo de carteira não encontrado: $wallet_path"
        return 1
    fi
    
    # Executar estratégia
    case $strategy in
        "simple")
            strategy_simple "$wallet_path" "$target_balance" "$environment"
            ;;
        "multi")
            strategy_multi_endpoint "$wallet_path" "$target_balance" "$environment"
            ;;
        "parallel")
            strategy_parallel "$wallet_path" "$target_balance" "$environment"
            ;;
        "smart")
            strategy_smart "$wallet_path" "$target_balance" "$environment"
            ;;
        "aggressive")
            strategy_aggressive "$wallet_path" "$target_balance" "$environment"
            ;;
        *)
            log "ERROR" "Estratégia inválida: $strategy"
            return 1
            ;;
    esac
    
    local result=$?
    
    # Verificar resultado final
    declare -A final_endpoints
    get_active_endpoints "$environment" final_endpoints
    
    local final_balance
    final_balance=$(get_current_balance "$wallet_path" "${final_endpoints[official]}")
    
    log "SOL" "Saldo final: $final_balance SOL"
    
    if (( $(echo "$final_balance >= $target_balance" | bc -l) )); then
        log "SUCCESS" "🎉 Meta atingida! Coletados $(echo "$final_balance - $current_balance" | bc -l) SOL"
        return 0
    else
        log "WARN" "Meta não atingida. Saldo atual: $final_balance SOL (meta: $target_balance SOL)"
        return $result
    fi
}

# Função para verificar saldo
check_balance() {
    local wallet_path=$1
    local environment=$2
    
    log "INFO" "Verificando saldo..."
    
    declare -A active_endpoints
    if ! get_active_endpoints "$environment" active_endpoints; then
        return 1
    fi
    
    local balance
    balance=$(get_current_balance "$wallet_path" "${active_endpoints[official]}")
    
    log "SOL" "Saldo atual: $balance SOL"
    echo "$balance"
    
    return 0
}

# Função para gerar relatório
generate_report() {
    local wallet_path=$1
    local environment=$2
    local strategy=$3
    local initial_balance=$4
    local final_balance=$5
    local status=$6
    
    local report_file="$REPORT_DIR/sol_management_${environment}_$TIMESTAMP.json"
    
    cat > "$report_file" << EOF
{
  "sol_management": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "environment": "$environment",
    "strategy": "$strategy",
    "wallet_path": "$wallet_path",
    "status": "$status"
  },
  "balances": {
    "initial": "$initial_balance",
    "final": "$final_balance",
    "collected": "$(echo "$final_balance - $initial_balance" | bc -l)",
    "target": "$TARGET_BALANCE"
  },
  "configuration": {
    "max_retries": "$MAX_RETRIES",
    "retry_delay": "$RETRY_DELAY",
    "parallel_requests": "$PARALLEL_REQUESTS",
    "timeout": "$TIMEOUT",
    "dry_run": "$DRY_RUN"
  },
  "artifacts": {
    "log_file": "$LOG_FILE",
    "report_file": "$report_file"
  }
}
EOF
    
    log "INFO" "Relatório gerado: $report_file"
    echo "$report_file"
}

# =============================================================================
# FUNÇÃO DE AJUDA
# =============================================================================

show_help() {
    cat << EOF
🪙 GMC SOL Management Script

Uso: $0 [COMANDO] [OPÇÕES]

Comandos:
  collect     Coletar SOL via airdrop
  balance     Verificar saldo atual
  test        Testar conectividade dos endpoints
  help        Mostrar esta ajuda

Opções:
  --environment ENV       Ambiente (devnet|testnet|mainnet)
  --strategy STRATEGY     Estratégia (simple|multi|parallel|smart|aggressive)
  --target-balance NUM    Saldo alvo em SOL
  --wallet-path PATH      Caminho para arquivo da carteira
  --max-retries NUM       Máximo de tentativas
  --parallel-requests NUM Requests paralelos
  --timeout NUM           Timeout em segundos
  --dry-run              Simular sem executar
  --verbose              Logs detalhados

Estratégias:
  simple      Um airdrop por vez (mais lento, mais confiável)
  multi       Rotacionar entre endpoints
  parallel    Requests simultâneos (mais rápido)
  smart       Adaptativa baseada em condições (recomendada)
  aggressive  Máxima velocidade e paralelismo

Exemplos:
  $0 collect --environment devnet --target-balance 10.0
  $0 collect --strategy aggressive --target-balance 20.0
  $0 balance --environment testnet
  $0 test --environment devnet

Variáveis de ambiente:
  ENVIRONMENT         Ambiente alvo
  STRATEGY           Estratégia de coleta
  TARGET_BALANCE     Saldo alvo
  MAX_RETRIES        Máximo de tentativas
  PARALLEL_REQUESTS  Requests paralelos
  TIMEOUT            Timeout
  DRY_RUN           Modo simulação
  VERBOSE           Logs detalhados

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Banner
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "🪙 GMC ECOSYSTEM - SOL MANAGEMENT & COLLECTION AUTOMATION 🪙"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    # Verificar dependências
    check_dependencies
    
    # Processar argumentos
    local command=""
    local wallet_path="$HOME/.config/solana/id.json"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            "collect"|"balance"|"test"|"help")
                command="$1"
                shift
                ;;
            "--environment")
                export ENVIRONMENT="$2"
                shift 2
                ;;
            "--strategy")
                export STRATEGY="$2"
                shift 2
                ;;
            "--target-balance")
                export TARGET_BALANCE="$2"
                shift 2
                ;;
            "--wallet-path")
                wallet_path="$2"
                shift 2
                ;;
            "--max-retries")
                export MAX_RETRIES="$2"
                shift 2
                ;;
            "--parallel-requests")
                export PARALLEL_REQUESTS="$2"
                shift 2
                ;;
            "--timeout")
                export TIMEOUT="$2"
                shift 2
                ;;
            "--dry-run")
                export DRY_RUN="true"
                shift
                ;;
            "--verbose")
                export VERBOSE="true"
                shift
                ;;
            *)
                log "ERROR" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar se comando foi especificado
    if [[ -z "$command" ]]; then
        log "ERROR" "Comando não especificado."
        show_help
        exit 1
    fi
    
    # Executar comando
    case $command in
        "collect")
            local initial_balance
            initial_balance=$(check_balance "$wallet_path" "$ENVIRONMENT" 2>/dev/null || echo "0")
            
            if collect_sol "$wallet_path" "$TARGET_BALANCE" "$ENVIRONMENT" "$STRATEGY"; then
                local final_balance
                final_balance=$(check_balance "$wallet_path" "$ENVIRONMENT" 2>/dev/null || echo "0")
                generate_report "$wallet_path" "$ENVIRONMENT" "$STRATEGY" "$initial_balance" "$final_balance" "success"
                log "SUCCESS" "🎉 Coleta de SOL concluída com sucesso!"
                exit 0
            else
                local final_balance
                final_balance=$(check_balance "$wallet_path" "$ENVIRONMENT" 2>/dev/null || echo "0")
                generate_report "$wallet_path" "$ENVIRONMENT" "$STRATEGY" "$initial_balance" "$final_balance" "failed"
                log "ERROR" "❌ Falha na coleta de SOL!"
                exit 1
            fi
            ;;
        "balance")
            check_balance "$wallet_path" "$ENVIRONMENT"
            ;;
        "test")
            declare -A test_endpoints
            get_active_endpoints "$ENVIRONMENT" test_endpoints
            log "SUCCESS" "Teste de conectividade concluído."
            ;;
        "help")
            show_help
            exit 0
            ;;
        *)
            log "ERROR" "Comando inválido: $command"
            show_help
            exit 1
            ;;
    esac
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi