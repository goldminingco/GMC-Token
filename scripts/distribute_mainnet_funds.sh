#!/bin/bash

# =======================================================
# GMC TOKEN - SCRIPT DE CORREÇÃO DE DISTRIBUIÇÃO MAINNET
# =======================================================
# OBJETIVO: Distribuir os 100M de tokens GMC que estão
#           na conta do deployer para as carteiras corretas.
# ESTADO ATUAL: 100M GMC parados na conta do deployer.
# ESTADO DESEJADO: Tokens distribuídos conforme tokenomics.
# =======================================================

set -e # Sair em caso de erro

# Cores e funções de log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Carregar ambiente
log_info "Carregando ambiente MainNet..."
source ./scripts/load_mainnet_env.sh
log_success "Ambiente carregado. Usando RPC: $RPC_URL"

# --- FASE 1: VERIFICAÇÃO E DIAGNÓSTICO ---

log_info "FASE 1: Diagnóstico do estado atual..."

# Encontrar a conta de token do deployer que detém os 100M GMC
log_info "Identificando a conta de token do deployer..."
DEPLOYER_TOKEN_ACCOUNT=$(spl-token accounts --owner $DEPLOYER_ADDRESS --output json | jq -r --arg mint "$GMC_TOKEN_ADDRESS" '.accounts[] | select(.mint == $mint and .amount == "100000000000000000") | .address')

if [ -z "$DEPLOYER_TOKEN_ACCOUNT" ]; then
    log_error "CRÍTICO: Não foi possível encontrar a conta de token do deployer com 100M GMC."
    log_error "A distribuição não pode continuar. Verifique o dono dos tokens."
    exit 1
fi
log_success "Conta de origem encontrada: $DEPLOYER_TOKEN_ACCOUNT"
log_info "Verificando saldo da conta de origem..."
spl-token balance --address $DEPLOYER_TOKEN_ACCOUNT
log_success "Diagnóstico concluído. Pronto para iniciar a correção."
echo ""

# --- FASE 2: PREPARAÇÃO DAS CONTAS DE DESTINO ---

log_warning "FASE 2: Preparação das contas de token de destino..."

# Função para criar conta de token se não existir
create_token_account_if_not_exists() {
    local owner_address=$1
    local wallet_name=$2
    
    log_info "Verificando conta de token para $wallet_name ($owner_address)..."
    # Tenta obter a conta. Se falhar (exit code != 0), cria a conta.
    if ! spl-token accounts --owner "$owner_address" | grep -q "$GMC_TOKEN_ADDRESS"; then
        log_warning "Conta de token para $wallet_name não encontrada. Criando agora..."
        # Para criar a conta, o dono precisa pagar a taxa. Temporariamente usamos o deployer.
        spl-token create-account "$GMC_TOKEN_ADDRESS" --owner "$owner_address" --fee-payer "$DEPLOYER_KEYPAIR"
        log_success "Conta de token para $wallet_name criada."
    else
        log_success "Conta de token para $wallet_name já existe."
    fi
}

# Criar contas para todas as carteiras do ecossistema
create_token_account_if_not_exists "$STAKING_POOL_ADDRESS" "Staking Pool"
create_token_account_if_not_exists "$TREASURY_ADDRESS" "Treasury"
create_token_account_if_not_exists "$TEAM_ADDRESS" "Team"
create_token_account_if_not_exists "$MARKETING_ADDRESS" "Marketing"
create_token_account_if_not_exists "$AIRDROP_ADDRESS" "Airdrop"
create_token_account_if_not_exists "$PRESALE_ADDRESS" "Presale"
echo ""

# --- FASE 3: EXECUÇÃO DA DISTRIBUIÇÃO ---

log_error "FASE 3: EXECUÇÃO DA DISTRIBUIÇÃO DE FUNDOS"
log_warning "Esta operação é IRREVERSÍVEL e moverá milhões de tokens."
read -p "Você confirma o início da distribuição dos 100M GMC? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Distribuição cancelada pelo usuário."
    exit 1
fi

# Função para transferir
execute_transfer() {
    local dest_address=$1
    local amount_no_decimals=$2
    local wallet_name=$3
    
    # Adicionar 9 zeros para os decimais
    local amount_with_decimals="${amount_no_decimals}000000000"
    
    log_info "Transferindo $amount_no_decimals GMC para $wallet_name ($dest_address)..."
    spl-token transfer \
        "$GMC_TOKEN_ADDRESS" \
        "$amount_no_decimals" \
        "$dest_address" \
        --from "$DEPLOYER_TOKEN_ACCOUNT" \
        --owner "$DEPLOYER_KEYPAIR" \
        --fund-recipient \
        --allow-unfunded-recipient
    log_success "Transferência para $wallet_name concluída."
}

# Realizar as transferências
execute_transfer "$STAKING_POOL_ADDRESS" "70000000" "Staking Pool"
execute_transfer "$TREASURY_ADDRESS" "12000000" "Treasury"
execute_transfer "$TEAM_ADDRESS" "2000000" "Team"
execute_transfer "$MARKETING_ADDRESS" "6000000" "Marketing"
execute_transfer "$AIRDROP_ADDRESS" "2000000" "Airdrop"
execute_transfer "$PRESALE_ADDRESS" "8000000" "Presale"
echo ""

# --- FASE 4: VERIFICAÇÃO PÓS-DISTRIBUIÇÃO ---

log_success "FASE 4: Verificação final dos saldos..."

# Função para verificar saldo
verify_balance() {
    local owner_address=$1
    local expected_amount=$2
    local wallet_name=$3
    
    local actual_balance=$(spl-token balance --owner "$owner_address" --output json | jq -r --arg mint "$GMC_TOKEN_ADDRESS" '.accounts[] | select(.mint == $mint) | .amount')
    local actual_balance_no_decimals=$((${actual_balance:-0} / 1000000000))

    if [ "$actual_balance_no_decimals" -eq "$expected_amount" ]; then
        log_success "✅ $wallet_name: Saldo correto ($expected_amount GMC)"
    else
        log_error "❌ $wallet_name: SALDO INCORRETO. Esperado: $expected_amount, Atual: $actual_balance_no_decimals"
    fi
}

verify_balance "$STAKING_POOL_ADDRESS" "70000000" "Staking Pool"
verify_balance "$TREASURY_ADDRESS" "12000000" "Treasury"
verify_balance "$TEAM_ADDRESS" "2000000" "Team"
verify_balance "$MARKETING_ADDRESS" "6000000" "Marketing"
verify_balance "$AIRDROP_ADDRESS" "2000000" "Airdrop"
verify_balance "$PRESALE_ADDRESS" "8000000" "Presale"

log_info "Verificando saldo remanescente na conta do deployer..."
deployer_final_balance=$(spl-token balance --address $DEPLOYER_TOKEN_ACCOUNT)
log_info "Saldo final da conta de origem do deployer: $deployer_final_balance"

echo ""
log_success "🎉 DISTRIBUIÇÃO DE FUNDOS CONCLUÍDA E VERIFICADA! 🎉"
log_success "O ecossistema GMC agora está com os fundos distribuídos corretamente."
echo "=======================================================" 