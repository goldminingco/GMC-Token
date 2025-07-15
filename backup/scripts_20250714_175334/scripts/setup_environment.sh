#!/bin/bash

# 🔧 GMC Ecosystem - Setup de Ambiente para Deploy
# 
# Este script configura as variáveis de ambiente necessárias para deploy
# em Devnet, Testnet e Mainnet de forma segura.

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para gerar keypair se não existir
generate_keypair_if_not_exists() {
    local keypair_path="$1"
    local description="$2"
    
    if [ ! -f "$keypair_path" ]; then
        log "Gerando nova keypair para $description..."
        mkdir -p "$(dirname "$keypair_path")"
        solana-keygen new --no-bip39-passphrase --silent --outfile "$keypair_path"
        success "Keypair gerada: $keypair_path"
    else
        log "Keypair já existe: $keypair_path"
    fi
}

# Função para verificar e solicitar airdrop
check_and_airdrop() {
    local keypair_path="$1"
    local cluster="$2"
    local min_balance="$3"
    
    if [ ! -f "$keypair_path" ]; then
        error "Keypair não encontrada: $keypair_path"
        return 1
    fi
    
    local pubkey=$(solana-keygen pubkey "$keypair_path")
    local balance=$(solana balance "$pubkey" --url "$cluster" 2>/dev/null | awk '{print $1}' || echo "0")
    
    log "Saldo atual de $pubkey: $balance SOL"
    
    if (( $(echo "$balance < $min_balance" | bc -l) )); then
        if [[ "$cluster" == *"devnet"* ]]; then
            log "Solicitando airdrop de 10 SOL..."
            solana airdrop 10 "$pubkey" --url "$cluster" || warning "Airdrop falhou, continue manualmente"
        else
            warning "Saldo insuficiente ($balance SOL < $min_balance SOL) para $cluster"
            warning "Por favor, transfira SOL manualmente para: $pubkey"
        fi
    else
        success "Saldo suficiente: $balance SOL"
    fi
}

# Função principal de setup
setup_environment() {
    local env="$1"
    
    log "🚀 Configurando ambiente: $env"
    
    # Criar diretórios necessários
    mkdir -p keypairs/$env
    mkdir -p config
    mkdir -p deployments
    
    # Configurar URLs por ambiente
    local rpc_url
    case "$env" in
        "devnet")
            rpc_url="https://api.devnet.solana.com"
            ;;
        "testnet")
            rpc_url="https://api.testnet.solana.com"
            ;;
        "mainnet")
            rpc_url="https://api.mainnet-beta.solana.com"
            ;;
        *)
            error "Ambiente inválido: $env"
            return 1
            ;;
    esac
    
    log "RPC URL para $env: $rpc_url"
    
    # Gerar keypairs necessárias
    generate_keypair_if_not_exists "keypairs/$env/deployer.json" "Deployer ($env)"
    generate_keypair_if_not_exists "keypairs/$env/admin.json" "Admin ($env)"
    generate_keypair_if_not_exists "keypairs/$env/team.json" "Team Wallet ($env)"
    generate_keypair_if_not_exists "keypairs/$env/treasury.json" "Treasury Wallet ($env)"
    generate_keypair_if_not_exists "keypairs/$env/marketing.json" "Marketing Wallet ($env)"
    generate_keypair_if_not_exists "keypairs/$env/airdrop.json" "Airdrop Wallet ($env)"
    
    # Verificar saldos e solicitar airdrop se necessário
    local min_balance
    case "$env" in
        "devnet")
            min_balance="5"
            ;;
        "testnet")
            min_balance="10"
            ;;
        "mainnet")
            min_balance="20"
            ;;
    esac
    
    check_and_airdrop "keypairs/$env/deployer.json" "$rpc_url" "$min_balance"
    check_and_airdrop "keypairs/$env/admin.json" "$rpc_url" "1"
    
    # Criar arquivo de configuração de ambiente
    create_env_config "$env" "$rpc_url"
    
    # Criar arquivo .env se não existir
    create_env_file "$env"
    
    success "Ambiente $env configurado com sucesso!"
}

# Função para criar configuração específica do ambiente
create_env_config() {
    local env="$1"
    local rpc_url="$2"
    local config_file="config/$env.json"
    
    log "Criando arquivo de configuração: $config_file"
    
    cat > "$config_file" << EOF
{
  "environment": "$env",
  "cluster": "$env",
  "rpcUrl": "$rpc_url",
  "keypairs": {
    "deployer": "./keypairs/$env/deployer.json",
    "admin": "./keypairs/$env/admin.json",
    "team": "./keypairs/$env/team.json",
    "treasury": "./keypairs/$env/treasury.json",
    "marketing": "./keypairs/$env/marketing.json",
    "airdrop": "./keypairs/$env/airdrop.json"
  },
  "tokenomics": {
    "totalSupply": 100000000,
    "distribution": {
      "stakingPool": 70000000,
      "preICO": 8000000,
      "reserve": 10000000,
      "treasury": 2000000,
      "marketing": 6000000,
      "airdrop": 2000000,
      "team": 2000000
    }
  },
  "fees": {
    "transferFeeBasisPoints": 50,
    "stakingEntryFees": [10, 5, 2.5, 1, 0.5],
    "burnForBoostFee": 0.8
  },
  "security": {
    "requireMultisig": $([ "$env" = "mainnet" ] && echo "true" || echo "false"),
    "maxTransactionSize": $([ "$env" = "mainnet" ] && echo "500000" || echo "1000000"),
    "deploymentTimeout": $([ "$env" = "mainnet" ] && echo "900000" || echo "300000"),
    "verificationRequired": $([ "$env" = "devnet" ] && echo "false" || echo "true")
  }
}
EOF
    
    success "Configuração criada: $config_file"
}

# Função para criar arquivo .env
create_env_file() {
    local env="$1"
    local env_file=".env"
    
    # Criar backup se .env já existe
    if [ -f "$env_file" ]; then
        cp "$env_file" "$env_file.backup.$(date +%s)"
        warning "Backup do .env criado"
    fi
    
    log "Atualizando arquivo .env..."
    
    # Remover variáveis antigas deste ambiente se existirem
    if [ -f "$env_file" ]; then
        sed -i.bak "/^${env^^}_/d" "$env_file"
    fi
    
    # Adicionar novas variáveis
    cat >> "$env_file" << EOF

# GMC $env Environment Variables
${env^^}_DEPLOYER_KEYPAIR=./keypairs/$env/deployer.json
${env^^}_ADMIN_KEYPAIR=./keypairs/$env/admin.json
${env^^}_TEAM_WALLET=./keypairs/$env/team.json
${env^^}_TREASURY_WALLET=./keypairs/$env/treasury.json
${env^^}_MARKETING_WALLET=./keypairs/$env/marketing.json
${env^^}_AIRDROP_WALLET=./keypairs/$env/airdrop.json
EOF
    
    if [ "$env" = "mainnet" ]; then
        echo "MAINNET_RPC_URL=https://api.mainnet-beta.solana.com" >> "$env_file"
    fi
    
    success "Arquivo .env atualizado"
}

# Função para validar setup
validate_setup() {
    local env="$1"
    
    log "🔍 Validando setup do ambiente $env..."
    
    local errors=0
    
    # Verificar arquivos de keypair
    local keypairs=("deployer" "admin" "team" "treasury" "marketing" "airdrop")
    for keypair in "${keypairs[@]}"; do
        local keypair_file="keypairs/$env/$keypair.json"
        if [ ! -f "$keypair_file" ]; then
            error "Keypair não encontrada: $keypair_file"
            ((errors++))
        fi
    done
    
    # Verificar arquivo de configuração
    local config_file="config/$env.json"
    if [ ! -f "$config_file" ]; then
        error "Arquivo de configuração não encontrado: $config_file"
        ((errors++))
    fi
    
    # Verificar variáveis de ambiente
    local env_vars=("${env^^}_DEPLOYER_KEYPAIR" "${env^^}_ADMIN_KEYPAIR")
    for var in "${env_vars[@]}"; do
        if [ -z "${!var}" ]; then
            warning "Variável de ambiente não definida: $var"
            warning "Execute: source .env"
        fi
    done
    
    if [ $errors -eq 0 ]; then
        success "Validação do ambiente $env concluída com sucesso!"
        return 0
    else
        error "Validação falhou com $errors erros"
        return 1
    fi
}

# Função para mostrar informações do ambiente
show_environment_info() {
    local env="$1"
    
    log "📊 Informações do ambiente $env:"
    
    if [ -f "keypairs/$env/deployer.json" ]; then
        local deployer_pubkey=$(solana-keygen pubkey "keypairs/$env/deployer.json")
        log "Deployer: $deployer_pubkey"
    fi
    
    if [ -f "keypairs/$env/admin.json" ]; then
        local admin_pubkey=$(solana-keygen pubkey "keypairs/$env/admin.json")
        log "Admin: $admin_pubkey"
    fi
    
    if [ -f "keypairs/$env/team.json" ]; then
        local team_pubkey=$(solana-keygen pubkey "keypairs/$env/team.json")
        log "Team: $team_pubkey"
    fi
    
    if [ -f "config/$env.json" ]; then
        log "Configuração: config/$env.json"
    fi
}

# Função principal
main() {
    log "🚀 GMC Ecosystem - Setup de Ambiente"
    log "====================================="
    
    # Verificar pré-requisitos
    if ! command_exists solana; then
        error "Solana CLI não encontrado. Instale primeiro:"
        error "sh -c \"\$(curl -sSfL https://release.solana.com/v1.18.24/install)\""
        exit 1
    fi
    
    if ! command_exists bc; then
        error "bc não encontrado. Instale com: apt-get install bc (Ubuntu) ou brew install bc (macOS)"
        exit 1
    fi
    
    local env="${1:-}"
    
    if [ -z "$env" ]; then
        log "Uso: $0 <ambiente>"
        log "Ambientes disponíveis: devnet, testnet, mainnet"
        log ""
        log "Exemplos:"
        log "  $0 devnet    # Configurar para desenvolvimento"
        log "  $0 testnet   # Configurar para testes públicos"
        log "  $0 mainnet   # Configurar para produção"
        exit 1
    fi
    
    case "$env" in
        "devnet"|"testnet"|"mainnet")
            ;;
        "all")
            log "Configurando todos os ambientes..."
            setup_environment "devnet"
            setup_environment "testnet"
            setup_environment "mainnet"
            log ""
            log "🎉 Todos os ambientes configurados!"
            log "⚠️  Lembre-se de executar: source .env"
            exit 0
            ;;
        *)
            error "Ambiente inválido: $env"
            error "Use: devnet, testnet, mainnet, ou all"
            exit 1
            ;;
    esac
    
    # Configurar ambiente específico
    setup_environment "$env"
    
    # Validar setup
    validate_setup "$env"
    
    # Mostrar informações
    show_environment_info "$env"
    
    log ""
    success "🎉 Setup do ambiente $env concluído!"
    log ""
    log "📋 Próximos passos:"
    log "1. Execute: source .env"
    log "2. Verifique os saldos das carteiras"
    log "3. Execute o deploy: npm run deploy:$env"
    log ""
    log "📁 Arquivos criados:"
    log "   - keypairs/$env/*.json (keypairs)"
    log "   - config/$env.json (configuração)"
    log "   - .env (variáveis de ambiente)"
}

# Executar função principal se script for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 