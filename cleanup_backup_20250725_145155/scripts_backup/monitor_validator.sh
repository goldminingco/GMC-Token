#!/bin/bash

# Script de Monitoramento do Validador Solana
# Monitora o status, performance e logs do validador em tempo real

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
CONTAINER_NAME="gmc-validator"
RPC_URL="http://localhost:8899"
REFRESH_INTERVAL=5

# Funções utilitárias
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${CYAN}$1${NC}"
}

# Verificar se contêiner está rodando
check_container() {
    if ! docker ps --format 'table {{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Contêiner ${CONTAINER_NAME} não está rodando"
        log_info "Execute: ./scripts/deploy_and_test.sh para iniciar"
        exit 1
    fi
}

# Obter informações do cluster
get_cluster_info() {
    local info=$(docker exec ${CONTAINER_NAME} solana cluster-version 2>/dev/null || echo "N/A")
    echo "$info"
}

# Obter informações do slot atual
get_slot_info() {
    local slot=$(docker exec ${CONTAINER_NAME} solana slot 2>/dev/null || echo "N/A")
    echo "$slot"
}

# Obter informações de epoch
get_epoch_info() {
    local epoch=$(docker exec ${CONTAINER_NAME} solana epoch-info --output json 2>/dev/null || echo '{}')
    echo "$epoch"
}

# Obter saldo da conta principal
get_balance() {
    local balance=$(docker exec ${CONTAINER_NAME} solana balance 2>/dev/null || echo "N/A")
    echo "$balance"
}

# Obter informações do programa
get_program_info() {
    if [ ! -f .program_id ]; then
        echo "Program ID não encontrado"
        return
    fi
    
    local program_id=$(cat .program_id)
    local info=$(docker exec ${CONTAINER_NAME} solana program show ${program_id} 2>/dev/null || echo "Erro ao obter informações")
    echo "$info"
}

# Obter estatísticas de transações
get_transaction_stats() {
    local stats=$(docker exec ${CONTAINER_NAME} solana transaction-count 2>/dev/null || echo "N/A")
    echo "$stats"
}

# Obter logs recentes
get_recent_logs() {
    docker logs --tail 10 ${CONTAINER_NAME} 2>/dev/null | grep -E "(Processed Slot|Error|Warning)" || echo "Nenhum log relevante"
}

# Mostrar dashboard completo
show_dashboard() {
    clear
    
    log_header "🎯 GMC Token - Monitor do Validador Solana"
    log_header "=========================================="
    echo ""
    
    # Status do contêiner
    log_header "📦 Status do Contêiner:"
    docker ps --filter name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || log_error "Erro ao obter status"
    echo ""
    
    # Informações do cluster
    log_header "🌐 Informações do Cluster:"
    local cluster_info=$(get_cluster_info)
    if [ "$cluster_info" != "N/A" ]; then
        echo "$cluster_info"
    else
        log_warning "Cluster não responsivo"
    fi
    echo ""
    
    # Slot atual
    log_header "🎰 Slot Atual:"
    local current_slot=$(get_slot_info)
    echo "Slot: $current_slot"
    echo ""
    
    # Informações de época
    log_header "📅 Informações da Época:"
    local epoch_info=$(get_epoch_info)
    if [ "$epoch_info" != "{}" ]; then
        echo "$epoch_info" | jq -r 'if type == "object" then "Época: \(.epoch // "N/A")\nSlot na Época: \(.slotIndex // "N/A")\nSlots por Época: \(.slotsInEpoch // "N/A")" else . end' 2>/dev/null || echo "$epoch_info"
    else
        log_warning "Informações de época não disponíveis"
    fi
    echo ""
    
    # Saldo da conta
    log_header "💰 Saldo da Conta:"
    local balance=$(get_balance)
    echo "Saldo: $balance"
    echo ""
    
    # Estatísticas de transações
    log_header "📊 Transações Processadas:"
    local tx_count=$(get_transaction_stats)
    echo "Total: $tx_count"
    echo ""
    
    # Informações do programa
    if [ -f .program_id ]; then
        log_header "🔧 Programa GMC Token:"
        echo "Program ID: $(cat .program_id)"
        local program_info=$(get_program_info)
        if [[ "$program_info" != *"Erro"* ]]; then
            echo "$program_info" | grep -E "(Owner|Balance|Data Length)" || echo "$program_info"
        else
            log_warning "Erro ao obter informações do programa"
        fi
        echo ""
    fi
    
    # Logs recentes
    log_header "📋 Logs Recentes:"
    get_recent_logs
    echo ""
    
    # Informações de atualização
    log_info "Atualizado: $(date)"
    log_info "Próxima atualização em ${REFRESH_INTERVAL}s (Ctrl+C para sair)"
}

# Mostrar logs em tempo real
show_live_logs() {
    log_info "Mostrando logs em tempo real do validador..."
    log_info "Pressione Ctrl+C para sair"
    echo ""
    
    docker logs -f ${CONTAINER_NAME}
}

# Mostrar estatísticas de performance
show_performance() {
    log_header "📈 Estatísticas de Performance"
    log_header "=============================="
    echo ""
    
    # Uso de CPU e memória do contêiner
    log_header "🖥️  Recursos do Contêiner:"
    docker stats ${CONTAINER_NAME} --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null || log_error "Erro ao obter estatísticas"
    echo ""
    
    # Informações do validador
    log_header "⚡ Performance do Validador:"
    local slot_info=$(get_slot_info)
    local tx_count=$(get_transaction_stats)
    
    echo "Slot Atual: $slot_info"
    echo "Transações Processadas: $tx_count"
    echo ""
    
    # Verificar conectividade RPC
    log_header "🌐 Conectividade RPC:"
    if curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getVersion"}' ${RPC_URL} >/dev/null 2>&1; then
        log_success "RPC endpoint responsivo (${RPC_URL})"
    else
        log_error "RPC endpoint não responsivo (${RPC_URL})"
    fi
    echo ""
}

# Executar diagnóstico completo
run_diagnostics() {
    log_header "🔍 Diagnóstico Completo do Sistema"
    log_header "=================================="
    echo ""
    
    # Verificar Docker
    log_info "Verificando Docker..."
    if docker info >/dev/null 2>&1; then
        log_success "Docker está funcionando"
    else
        log_error "Problema com Docker"
    fi
    
    # Verificar contêiner
    log_info "Verificando contêiner..."
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_success "Contêiner está rodando"
    else
        log_error "Contêiner não está rodando"
    fi
    
    # Verificar conectividade de rede
    log_info "Verificando conectividade de rede..."
    if curl -s ${RPC_URL} >/dev/null 2>&1; then
        log_success "Porta 8899 acessível"
    else
        log_error "Porta 8899 não acessível"
    fi
    
    # Verificar Solana CLI no contêiner
    log_info "Verificando Solana CLI..."
    if docker exec ${CONTAINER_NAME} solana --version >/dev/null 2>&1; then
        local version=$(docker exec ${CONTAINER_NAME} solana --version)
        log_success "Solana CLI funcionando: $version"
    else
        log_error "Problema com Solana CLI"
    fi
    
    # Verificar programa deployado
    if [ -f .program_id ]; then
        log_info "Verificando programa deployado..."
        local program_id=$(cat .program_id)
        if docker exec ${CONTAINER_NAME} solana program show ${program_id} >/dev/null 2>&1; then
            log_success "Programa está ativo: $program_id"
        else
            log_error "Problema com programa deployado"
        fi
    else
        log_warning "Nenhum programa deployado encontrado"
    fi
    
    echo ""
    log_info "Diagnóstico concluído"
}

# Menu interativo
show_menu() {
    echo ""
    log_header "🎛️  Menu de Opções:"
    echo "1) Dashboard em tempo real"
    echo "2) Logs em tempo real"
    echo "3) Estatísticas de performance"
    echo "4) Diagnóstico completo"
    echo "5) Sair"
    echo ""
    read -p "Escolha uma opção (1-5): " choice
    
    case $choice in
        1)
            monitor_dashboard
            ;;
        2)
            show_live_logs
            ;;
        3)
            show_performance
            show_menu
            ;;
        4)
            run_diagnostics
            show_menu
            ;;
        5)
            log_info "Saindo..."
            exit 0
            ;;
        *)
            log_warning "Opção inválida"
            show_menu
            ;;
    esac
}

# Monitor dashboard em loop
monitor_dashboard() {
    while true; do
        show_dashboard
        sleep $REFRESH_INTERVAL
    done
}

# Função principal
main() {
    check_container
    
    case "${1:-}" in
        "dashboard"|"dash"|"d")
            monitor_dashboard
            ;;
        "logs"|"l")
            show_live_logs
            ;;
        "performance"|"perf"|"p")
            show_performance
            ;;
        "diagnostics"|"diag")
            run_diagnostics
            ;;
        "menu"|"m"|"")
            show_menu
            ;;
        *)
            log_error "Opção inválida: $1"
            log_info "Uso: $0 [dashboard|logs|performance|diagnostics|menu]"
            exit 1
            ;;
    esac
}

# Capturar Ctrl+C para saída limpa
trap 'echo ""; log_info "Monitor interrompido pelo usuário"; exit 0' INT

main "$@"
