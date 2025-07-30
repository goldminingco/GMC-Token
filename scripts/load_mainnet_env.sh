#!/bin/bash

# ========================================
# GMC TOKEN - CARREGADOR DE AMBIENTE MAINNET
# ========================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Carregando configuração MainNet..."

# Carregar variáveis do .env.mainnet
if [ -f .env.mainnet ]; then
    # Exportar variáveis (ignorando comentários e linhas vazias)
    set -a
    source .env.mainnet
    set +a
    
    log_success "Variáveis MainNet carregadas"
    
    # Configurar Solana CLI para MainNet
    log_info "Configurando Solana CLI para MainNet..."
    solana config set --url $RPC_URL
    solana config set --keypair $DEPLOYER_KEYPAIR
    
    log_success "Solana CLI configurado para MainNet"
    log_info "RPC: $RPC_URL"
    log_info "Deployer: $DEPLOYER_ADDRESS"
    log_info "Network: $NETWORK"
    
    # Verificar conectividade
    log_info "Testando conectividade MainNet..."
    if solana cluster-version >/dev/null 2>&1; then
        log_success "Conectividade MainNet confirmada"
    else
        log_warning "Falha na conectividade MainNet - verifique internet e RPC"
    fi
    
    # Verificar saldo do deployer
    log_info "Verificando saldo do deployer..."
    BALANCE=$(solana balance $DEPLOYER_ADDRESS 2>/dev/null || echo "0")
    log_info "Saldo atual: $BALANCE"
    
    # Verificar se carteiras existem
    log_info "Verificando carteiras..."
    WALLETS_OK=true
    
    if [ ! -f "$DEPLOYER_KEYPAIR" ]; then
        log_error "Carteira deployer não encontrada: $DEPLOYER_KEYPAIR"
        WALLETS_OK=false
    fi
    
    if [ ! -f "$TREASURY_KEYPAIR" ]; then
        log_error "Carteira treasury não encontrada: $TREASURY_KEYPAIR"
        WALLETS_OK=false
    fi
    
    if [ ! -f "$STAKING_POOL_KEYPAIR" ]; then
        log_error "Carteira staking pool não encontrada: $STAKING_POOL_KEYPAIR"
        WALLETS_OK=false
    fi
    
    if [ "$WALLETS_OK" = true ]; then
        log_success "Todas as carteiras encontradas"
    else
        log_warning "Algumas carteiras não foram encontradas"
    fi
    
    echo ""
    log_info "Configuração MainNet carregada:"
    echo "- Rede: $NETWORK"
    echo "- RPC: $RPC_URL"
    echo "- Deployer: $DEPLOYER_ADDRESS"
    echo "- Token: $TOKEN_NAME ($TOKEN_SYMBOL)"
    echo "- Supply: $(printf "%'d" $TOTAL_SUPPLY) $TOKEN_SYMBOL"
    echo ""
    
else
    log_error "Arquivo .env.mainnet não encontrado!"
    log_error "Execute primeiro: cp .env.mainnet.template .env.mainnet"
    exit 1
fi
