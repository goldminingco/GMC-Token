#!/bin/bash

# 🚀 GMC Ecosystem - Devnet Deployment Script
# Este script automatiza o deploy completo do ecossistema GMC em Devnet
# Inclui: configuração, deploy, inicialização e validação

set -e  # Exit on any error

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    # Verificar Solana CLI
    if ! command -v solana &> /dev/null; then
        error "Solana CLI não encontrado. Instale: https://docs.solana.com/cli/install-solana-cli-tools"
    fi
    
    # Verificar Anchor CLI
    if ! command -v anchor &> /dev/null; then
        error "Anchor CLI não encontrado. Instale: https://www.anchor-lang.com/docs/installation"
    fi
    
    # Verificar Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js não encontrado. Instale: https://nodejs.org"
    fi
    
    success "Todas as dependências encontradas"
}

# Configurar ambiente Devnet
setup_devnet() {
    log "Configurando ambiente Devnet..."
    
    # Configurar Solana para Devnet
    solana config set --url https://api.devnet.solana.com
    
    # Verificar configuração
    local rpc_url=$(solana config get | grep "RPC URL" | awk '{print $3}')
    if [[ "$rpc_url" != "https://api.devnet.solana.com" ]]; then
        error "Falha ao configurar Devnet"
    fi
    
    success "Devnet configurado: $rpc_url"
}

# Criar e financiar keypairs
setup_keypairs() {
    log "Configurando keypairs..."
    
    # Criar diretório para keypairs
    mkdir -p .devnet-keys
    
    # Gerar keypairs se não existirem
    if [[ ! -f .devnet-keys/deployer.json ]]; then
        solana-keygen new --outfile .devnet-keys/deployer.json --no-bip39-passphrase
        success "Keypair deployer criado"
    fi
    
    if [[ ! -f .devnet-keys/admin.json ]]; then
        solana-keygen new --outfile .devnet-keys/admin.json --no-bip39-passphrase
        success "Keypair admin criado"
    fi
    
    # Definir deployer como keypair padrão
    solana config set --keypair .devnet-keys/deployer.json
    
    # Solicitar airdrop
    local deployer_pubkey=$(solana address)
    local admin_pubkey=$(solana address --keypair .devnet-keys/admin.json)
    
    log "Solicitando airdrop para deployer: $deployer_pubkey"
    solana airdrop 5 "$deployer_pubkey" || warning "Airdrop pode ter falhado"
    
    log "Solicitando airdrop para admin: $admin_pubkey"
    solana airdrop 5 "$admin_pubkey" || warning "Airdrop pode ter falhado"
    
    # Verificar saldos
    local deployer_balance=$(solana balance "$deployer_pubkey" | awk '{print $1}')
    local admin_balance=$(solana balance "$admin_pubkey" | awk '{print $1}')
    
    success "Deployer balance: $deployer_balance SOL"
    success "Admin balance: $admin_balance SOL"
    
    # Salvar endereços
    echo "$deployer_pubkey" > .devnet-keys/deployer.pubkey
    echo "$admin_pubkey" > .devnet-keys/admin.pubkey
}

# Build dos contratos
build_contracts() {
    log "Compilando contratos..."
    
    # Limpar builds anteriores
    anchor clean
    
    # Build completo
    anchor build
    
    success "Contratos compilados com sucesso"
}

# Deploy dos contratos
deploy_contracts() {
    log "Fazendo deploy dos contratos..."
    
    # Deploy usando Anchor
    anchor deploy
    
    # Verificar deploy
    local program_ids=$(anchor keys list)
    
    success "Deploy concluído!"
    echo "$program_ids"
    
    # Salvar program IDs
    echo "$program_ids" > .devnet-keys/program_ids.txt
}

# Inicializar contratos
initialize_contracts() {
    log "Inicializando contratos..."
    
    # Executar script de inicialização
    node scripts/initialize_devnet.js
    
    success "Contratos inicializados"
}

# Validar deployment
validate_deployment() {
    log "Validando deployment..."
    
    # Executar testes básicos
    npm run test:devnet
    
    success "Deployment validado"
}

# Criar configuração de ambiente
create_env_config() {
    log "Criando configuração de ambiente..."
    
    local deployer_pubkey=$(cat .devnet-keys/deployer.pubkey)
    local admin_pubkey=$(cat .devnet-keys/admin.pubkey)
    
    # Criar arquivo .env para Devnet
    cat > .env.devnet << EOF
# GMC Ecosystem - Devnet Configuration
SOLANA_NETWORK=devnet
SOLANA_RPC_URL=https://api.devnet.solana.com
DEPLOYER_KEYPAIR=.devnet-keys/deployer.json
ADMIN_KEYPAIR=.devnet-keys/admin.json
DEPLOYER_PUBKEY=$deployer_pubkey
ADMIN_PUBKEY=$admin_pubkey

# Program IDs (will be populated after deploy)
GMC_TOKEN_PROGRAM_ID=""
GMC_STAKING_PROGRAM_ID=""
GMC_RANKING_PROGRAM_ID=""
GMC_VESTING_PROGRAM_ID=""

# Contract Addresses
GMC_MINT=""
USDT_MINT=""
STAKING_VAULT=""
RANKING_STATE=""
VESTING_STATE=""
EOF
    
    success "Configuração criada: .env.devnet"
}

# Função principal
main() {
    echo -e "${BLUE}"
    echo "🚀 =================================="
    echo "   GMC ECOSYSTEM - DEVNET DEPLOY"
    echo "🚀 =================================="
    echo -e "${NC}"
    
    check_dependencies
    setup_devnet
    setup_keypairs
    create_env_config
    build_contracts
    deploy_contracts
    initialize_contracts
    validate_deployment
    
    echo -e "${GREEN}"
    echo "🎉 =================================="
    echo "   DEPLOY CONCLUÍDO COM SUCESSO!"
    echo "🎉 =================================="
    echo -e "${NC}"
    
    echo ""
    echo "📊 RESUMO DO DEPLOY:"
    echo "   • Network: Devnet"
    echo "   • Deployer: $(cat .devnet-keys/deployer.pubkey)"
    echo "   • Admin: $(cat .devnet-keys/admin.pubkey)"
    echo "   • Configuração: .env.devnet"
    echo "   • Logs: deploy.log"
    echo ""
    echo "🔗 PRÓXIMOS PASSOS:"
    echo "   1. Verificar contratos no Solana Explorer"
    echo "   2. Executar testes E2E em Devnet"
    echo "   3. Monitorar performance e logs"
    echo "   4. Preparar para auditoria"
    echo ""
}

# Executar deploy
main "$@" 2>&1 | tee deploy.log 