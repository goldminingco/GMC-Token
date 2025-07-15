#!/bin/bash

# GMC Ecosystem - Devnet Airdrop and Deploy Script
# This script handles airdrop rate limits and deploys all contracts

set -e

echo "🚀 ===================================="
echo "   GMC DEVNET AIRDROP & DEPLOY"
echo "🚀 ===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to attempt airdrop with retries
airdrop_with_retry() {
    local address=$1
    local amount=$2
    local max_attempts=10
    local attempt=1
    local wait_time=30
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tentando airdrop de ${amount} SOL para ${address}..."
    
    while [ $attempt -le $max_attempts ]; do
        echo "Tentativa ${attempt}/${max_attempts}..."
        
        if solana airdrop $amount $address; then
            echo -e "${GREEN}✅ Airdrop de ${amount} SOL bem-sucedido!${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Tentativa ${attempt} falhou. Aguardando ${wait_time}s...${NC}"
            sleep $wait_time
            attempt=$((attempt + 1))
            # Increase wait time for subsequent attempts
            wait_time=$((wait_time + 10))
        fi
    done
    
    echo -e "${RED}❌ Falha ao obter airdrop após ${max_attempts} tentativas${NC}"
    return 1
}

# Function to check balance
check_balance() {
    local address=$1
    local balance=$(solana balance $address | grep -o '[0-9.]\+' | head -1)
    echo $balance
}

# Configure devnet
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configurando Devnet..."
solana config set --url https://api.devnet.solana.com
solana config set --keypair .devnet-keys/deployer.json

# Get deployer address
DEPLOYER_ADDRESS=$(solana-keygen pubkey .devnet-keys/deployer.json)
echo "Deployer: $DEPLOYER_ADDRESS"

# Check current balance
CURRENT_BALANCE=$(check_balance $DEPLOYER_ADDRESS)
echo "Balance atual: ${CURRENT_BALANCE} SOL"

# Calculate needed SOL (each program needs ~2.5 SOL, we have 5 programs)
NEEDED_SOL=15
CURRENT_SOL_INT=$(echo $CURRENT_BALANCE | cut -d'.' -f1)

if [ $CURRENT_SOL_INT -lt $NEEDED_SOL ]; then
    AIRDROP_AMOUNT=$((NEEDED_SOL - CURRENT_SOL_INT))
    echo "Precisamos de mais ${AIRDROP_AMOUNT} SOL para o deploy..."
    
    # Try multiple smaller airdrops to avoid rate limits
    while [ $AIRDROP_AMOUNT -gt 0 ]; do
        if [ $AIRDROP_AMOUNT -ge 2 ]; then
            CURRENT_AIRDROP=2
        else
            CURRENT_AIRDROP=1
        fi
        
        if airdrop_with_retry $DEPLOYER_ADDRESS $CURRENT_AIRDROP; then
            AIRDROP_AMOUNT=$((AIRDROP_AMOUNT - CURRENT_AIRDROP))
            echo "Restam ${AIRDROP_AMOUNT} SOL para solicitar..."
        else
            echo -e "${RED}❌ Não foi possível obter SOL suficiente${NC}"
            echo "Tentando continuar com o balance atual..."
            break
        fi
        
        # Wait between airdrops
        if [ $AIRDROP_AMOUNT -gt 0 ]; then
            echo "Aguardando 60s antes da próxima tentativa..."
            sleep 60
        fi
    done
fi

# Final balance check
FINAL_BALANCE=$(check_balance $DEPLOYER_ADDRESS)
echo "Balance final: ${FINAL_BALANCE} SOL"

# Deploy programs one by one
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando deploy dos contratos..."

PROGRAMS=("gmc_token" "gmc_staking" "gmc_ranking" "gmc_vesting" "gmc_treasury")
DEPLOYED_PROGRAMS=()

for program in "${PROGRAMS[@]}"; do
    echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Fazendo deploy do $program..."
    
    if anchor deploy --program-name $program --provider.cluster devnet; then
        echo -e "${GREEN}✅ $program deployado com sucesso!${NC}"
        DEPLOYED_PROGRAMS+=("$program")
    else
        echo -e "${RED}❌ Falha no deploy do $program${NC}"
        
        # Check if we need more SOL
        CURRENT_BALANCE=$(check_balance $DEPLOYER_ADDRESS)
        echo "Balance atual: ${CURRENT_BALANCE} SOL"
        
        if (( $(echo "$CURRENT_BALANCE < 3" | bc -l) )); then
            echo "Tentando obter mais SOL..."
            if airdrop_with_retry $DEPLOYER_ADDRESS 2; then
                echo "Tentando deploy novamente..."
                if anchor deploy --program-name $program --provider.cluster devnet; then
                    echo -e "${GREEN}✅ $program deployado com sucesso na segunda tentativa!${NC}"
                    DEPLOYED_PROGRAMS+=("$program")
                else
                    echo -e "${RED}❌ Falha definitiva no deploy do $program${NC}"
                fi
            fi
        fi
    fi
done

echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Resumo do Deploy:"
echo "Programas deployados com sucesso: ${#DEPLOYED_PROGRAMS[@]}/${#PROGRAMS[@]}"
for program in "${DEPLOYED_PROGRAMS[@]}"; do
    echo -e "${GREEN}✅ $program${NC}"
done

# Get program IDs and update .env.devnet
if [ ${#DEPLOYED_PROGRAMS[@]} -gt 0 ]; then
    echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Atualizando .env.devnet com Program IDs..."
    
    # Parse Anchor.toml to get program IDs
    if [ -f "Anchor.toml" ]; then
        echo "# Program IDs (Updated after deploy)" >> .env.devnet.tmp
        
        for program in "${DEPLOYED_PROGRAMS[@]}"; do
            PROGRAM_ID=$(grep "$program = " Anchor.toml | cut -d'"' -f2)
            if [ ! -z "$PROGRAM_ID" ]; then
                UPPER_PROGRAM=$(echo $program | tr '[:lower:]' '[:upper:]')
                echo "${UPPER_PROGRAM}_PROGRAM_ID=\"$PROGRAM_ID\"" >> .env.devnet.tmp
            fi
        done
        
        # Replace the old .env.devnet
        cat .env.devnet | grep -v "_PROGRAM_ID=" > .env.devnet.base
        cat .env.devnet.base .env.devnet.tmp > .env.devnet
        rm .env.devnet.tmp .env.devnet.base
        
        echo -e "${GREEN}✅ .env.devnet atualizado com Program IDs${NC}"
    fi
fi

# Run initialization if all programs deployed
if [ ${#DEPLOYED_PROGRAMS[@]} -eq ${#PROGRAMS[@]} ]; then
    echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Todos os programas deployados! Executando inicialização..."
    
    if node scripts/initialize_devnet.js; then
        echo -e "${GREEN}✅ Inicialização concluída com sucesso!${NC}"
        
        echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Executando testes de validação..."
        if node scripts/devnet_tests.js; then
            echo -e "${GREEN}✅ Testes de validação passaram!${NC}"
        else
            echo -e "${YELLOW}⚠️  Alguns testes falharam, mas o deploy foi bem-sucedido${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Deploy concluído, mas inicialização falhou${NC}"
        echo "Você pode tentar executar manualmente: node scripts/initialize_devnet.js"
    fi
else
    echo -e "${YELLOW}⚠️  Deploy parcial concluído. Alguns programas podem precisar ser deployados manualmente.${NC}"
fi

echo "\n🎉 ===================================="
echo "   DEPLOY DEVNET CONCLUÍDO"
echo "🎉 ===================================="
echo "Balance final: $(check_balance $DEPLOYER_ADDRESS) SOL"
echo "Programas deployados: ${#DEPLOYED_PROGRAMS[@]}/${#PROGRAMS[@]}"
echo "Configuração: .env.devnet"
echo "===================================="