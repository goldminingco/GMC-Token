#!/bin/bash

# Script de Deploy e Teste Automatizado - GMC Token Native Rust
# Este script automatiza todo o processo de build, deploy e teste do programa

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
CONTAINER_NAME="gmc-validator"
IMAGE_NAME="gmc-token"
PROGRAM_PATH="/app/deploy/gmc_token.so"
RPC_URL="http://localhost:8899"

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

# Verificar se Docker está rodando
check_docker() {
    log_info "Verificando Docker..."
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker não está rodando. Inicie o Docker e tente novamente."
        exit 1
    fi
    log_success "Docker está rodando"
}

# Limpar contêineres existentes
cleanup_containers() {
    log_info "Limpando contêineres existentes..."
    
    if docker ps -a --format 'table {{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_warning "Parando e removendo contêiner existente: ${CONTAINER_NAME}"
        docker stop ${CONTAINER_NAME} >/dev/null 2>&1 || true
        docker rm ${CONTAINER_NAME} >/dev/null 2>&1 || true
    fi
    
    log_success "Limpeza concluída"
}

# Build da imagem Docker
build_image() {
    log_info "Construindo imagem Docker..."
    
    if ! docker build -t ${IMAGE_NAME} .; then
        log_error "Falha no build da imagem Docker"
        exit 1
    fi
    
    log_success "Imagem Docker construída: ${IMAGE_NAME}"
}

# Iniciar contêiner
start_container() {
    log_info "Iniciando contêiner do validador..."
    
    docker run -d \
        -p 8899:8899 \
        -p 8900:8900 \
        --name ${CONTAINER_NAME} \
        ${IMAGE_NAME}
    
    log_success "Contêiner iniciado: ${CONTAINER_NAME}"
}

# Aguardar validador estar pronto
wait_for_validator() {
    log_info "Aguardando validador estar pronto..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec ${CONTAINER_NAME} solana cluster-version >/dev/null 2>&1; then
            log_success "Validador está pronto!"
            return 0
        fi
        
        log_info "Tentativa $attempt/$max_attempts - aguardando..."
        sleep 2
        ((attempt++))
    done
    
    log_error "Timeout: validador não ficou pronto em tempo hábil"
    exit 1
}

# Configurar Solana CLI no contêiner
setup_solana_cli() {
    log_info "Configurando Solana CLI..."
    
    # Configurar URL
    docker exec ${CONTAINER_NAME} solana config set --url ${RPC_URL}
    
    # Criar keypair se não existir
    if ! docker exec ${CONTAINER_NAME} test -f /root/.config/solana/id.json; then
        log_info "Criando nova keypair..."
        docker exec ${CONTAINER_NAME} solana-keygen new -o /root/.config/solana/id.json --no-bip39-passphrase
    fi
    
    # Verificar saldo e solicitar airdrop se necessário
    local balance=$(docker exec ${CONTAINER_NAME} solana balance | grep -o '[0-9.]*')
    if (( $(echo "$balance < 1" | bc -l) )); then
        log_info "Solicitando airdrop de SOL..."
        docker exec ${CONTAINER_NAME} solana airdrop 2
    fi
    
    log_success "Solana CLI configurado"
}

# Deploy do programa
deploy_program() {
    log_info "Fazendo deploy do programa..."
    
    local output=$(docker exec ${CONTAINER_NAME} solana program deploy ${PROGRAM_PATH} 2>&1)
    local program_id=$(echo "$output" | grep "Program Id:" | awk '{print $3}')
    
    if [ -z "$program_id" ]; then
        log_error "Falha no deploy do programa"
        echo "$output"
        exit 1
    fi
    
    log_success "Programa deployado com sucesso!"
    log_info "Program ID: ${program_id}"
    
    # Salvar Program ID em arquivo
    echo "$program_id" > .program_id
    
    return 0
}

# Verificar programa deployado
verify_program() {
    log_info "Verificando programa deployado..."
    
    if [ ! -f .program_id ]; then
        log_error "Arquivo .program_id não encontrado"
        exit 1
    fi
    
    local program_id=$(cat .program_id)
    
    local output=$(docker exec ${CONTAINER_NAME} solana program show ${program_id} 2>&1)
    
    if echo "$output" | grep -q "Program Id:"; then
        log_success "Programa verificado com sucesso!"
        echo "$output"
    else
        log_error "Falha na verificação do programa"
        echo "$output"
        exit 1
    fi
}

# Executar testes JavaScript
run_js_tests() {
    log_info "Executando testes JavaScript..."
    
    if [ ! -f scripts/interact_with_program.js ]; then
        log_warning "Script de teste JavaScript não encontrado, pulando testes"
        return 0
    fi
    
    # Verificar se Node.js e dependências estão instaladas
    if ! command -v node >/dev/null 2>&1; then
        log_warning "Node.js não encontrado, pulando testes JavaScript"
        return 0
    fi
    
    if [ ! -d node_modules ]; then
        log_info "Instalando dependências Node.js..."
        yarn install
    fi
    
    # Executar script de teste
    if node scripts/interact_with_program.js; then
        log_success "Testes JavaScript executados com sucesso!"
    else
        log_warning "Testes JavaScript falharam, mas continuando..."
    fi
}

# Mostrar logs do validador
show_validator_logs() {
    log_info "Últimos logs do validador:"
    docker logs --tail 20 ${CONTAINER_NAME}
}

# Mostrar informações do ambiente
show_environment_info() {
    log_info "Informações do ambiente:"
    echo "🐳 Contêiner: ${CONTAINER_NAME}"
    echo "🖼️  Imagem: ${IMAGE_NAME}"
    echo "🌐 RPC URL: ${RPC_URL}"
    echo "📁 Program Path: ${PROGRAM_PATH}"
    
    if [ -f .program_id ]; then
        echo "🆔 Program ID: $(cat .program_id)"
    fi
    
    echo ""
    log_info "Status do contêiner:"
    docker ps --filter name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Função principal
main() {
    echo "🚀 GMC Token - Script de Deploy e Teste Automatizado"
    echo "=================================================="
    echo ""
    
    # Verificar pré-requisitos
    check_docker
    
    # Processo de deploy
    cleanup_containers
    build_image
    start_container
    wait_for_validator
    setup_solana_cli
    deploy_program
    verify_program
    
    echo ""
    log_success "Deploy concluído com sucesso!"
    
    # Executar testes
    echo ""
    log_info "Executando testes..."
    run_js_tests
    
    # Mostrar informações finais
    echo ""
    show_environment_info
    
    echo ""
    log_success "Processo completo finalizado!"
    log_info "O validador está rodando em background. Use 'docker logs ${CONTAINER_NAME}' para ver os logs."
    log_info "Para parar: docker stop ${CONTAINER_NAME}"
    log_info "Para remover: docker rm ${CONTAINER_NAME}"
}

# Verificar argumentos da linha de comando
case "${1:-}" in
    "cleanup")
        cleanup_containers
        ;;
    "logs")
        show_validator_logs
        ;;
    "status")
        show_environment_info
        ;;
    "test")
        run_js_tests
        ;;
    *)
        main
        ;;
esac
