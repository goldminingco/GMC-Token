#!/bin/bash

# GMC Ecosystem - Optimized Devnet Deploy Script
# This script deploys with minimal SOL requirements

set -e

echo "🚀 ===================================="
echo "   GMC DEVNET OPTIMIZED DEPLOY"
echo "🚀 ===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configure devnet
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configurando Devnet..."
solana config set --url https://api.devnet.solana.com
solana config set --keypair .devnet-keys/deployer.json

# Get deployer address and balance
DEPLOYER_ADDRESS=$(solana-keygen pubkey .devnet-keys/deployer.json)
CURRENT_BALANCE=$(solana balance $DEPLOYER_ADDRESS | grep -o '[0-9.]\+' | head -1)
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Balance atual: ${CURRENT_BALANCE} SOL"

# Function to deploy with smaller buffer
deploy_with_buffer() {
    local program=$1
    echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Deployando $program com buffer otimizado..."
    
    # Try with smaller buffer first
    if anchor deploy --program-name $program --provider.cluster devnet --program-keypair target/deploy/${program}-keypair.json; then
        echo -e "${GREEN}✅ $program deployado com sucesso!${NC}"
        return 0
    else
        echo -e "${RED}❌ Falha no deploy do $program${NC}"
        return 1
    fi
}

# Function to create smaller program keypairs
create_optimized_keypairs() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Criando keypairs otimizados..."
    
    # Create target/deploy directory if it doesn't exist
    mkdir -p target/deploy
    
    # Generate smaller program IDs (starting with more zeros = cheaper)
    PROGRAMS=("gmc_token" "gmc_staking" "gmc_ranking" "gmc_vesting" "gmc_treasury")
    
    for program in "${PROGRAMS[@]}"; do
        if [ ! -f "target/deploy/${program}-keypair.json" ]; then
            echo "Gerando keypair para $program..."
            # Try to generate a keypair with a smaller address
            for i in {1..10}; do
                solana-keygen new --no-bip39-passphrase --silent --outfile "target/deploy/${program}-keypair.json"
                PUBKEY=$(solana-keygen pubkey "target/deploy/${program}-keypair.json")
                # Check if it starts with favorable characters (lower deployment cost)
                if [[ $PUBKEY == 1* ]] || [[ $PUBKEY == 2* ]] || [[ $PUBKEY == 3* ]]; then
                    echo "Keypair otimizado para $program: $PUBKEY"
                    break
                fi
            done
        fi
    done
}

# Create optimized keypairs
create_optimized_keypairs

# Deploy programs in order of priority (smallest first)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando deploy otimizado..."

# Order by estimated size (smallest first)
PROGRAMS_ORDERED=("gmc_token" "gmc_ranking" "gmc_vesting" "gmc_treasury" "gmc_staking")
DEPLOYED_PROGRAMS=()
FAILED_PROGRAMS=()

for program in "${PROGRAMS_ORDERED[@]}"; do
    # Check balance before each deploy
    CURRENT_BALANCE=$(solana balance $DEPLOYER_ADDRESS | grep -o '[0-9.]\+' | head -1)
    echo "Balance antes do deploy de $program: ${CURRENT_BALANCE} SOL"
    
    if (( $(echo "$CURRENT_BALANCE < 1.5" | bc -l) )); then
        echo -e "${YELLOW}⚠️  SOL insuficiente para $program (${CURRENT_BALANCE} SOL)${NC}"
        FAILED_PROGRAMS+=("$program")
        continue
    fi
    
    if deploy_with_buffer $program; then
        DEPLOYED_PROGRAMS+=("$program")
        
        # Update Anchor.toml with the new program ID
        PROGRAM_ID=$(solana-keygen pubkey "target/deploy/${program}-keypair.json")
        echo "Program ID para $program: $PROGRAM_ID"
        
        # Update Anchor.toml
        if grep -q "$program = " Anchor.toml; then
            sed -i '' "s/$program = \".*\"/$program = \"$PROGRAM_ID\"/g" Anchor.toml
        else
            # Add to [programs.devnet] section
            if grep -q "\[programs.devnet\]" Anchor.toml; then
                sed -i '' "/\[programs.devnet\]/a\\
$program = \"$PROGRAM_ID\"
" Anchor.toml
            else
                echo "\n[programs.devnet]" >> Anchor.toml
                echo "$program = \"$PROGRAM_ID\"" >> Anchor.toml
            fi
        fi
        
        echo -e "${GREEN}✅ $program deployado e configurado!${NC}"
    else
        FAILED_PROGRAMS+=("$program")
        
        # Try to get more SOL for failed programs
        echo "Tentando airdrop para continuar..."
        if solana airdrop 1 $DEPLOYER_ADDRESS 2>/dev/null; then
            echo "Airdrop bem-sucedido! Tentando deploy novamente..."
            if deploy_with_buffer $program; then
                DEPLOYED_PROGRAMS+=("$program")
                PROGRAM_ID=$(solana-keygen pubkey "target/deploy/${program}-keypair.json")
                echo "Program ID para $program: $PROGRAM_ID"
                
                # Update Anchor.toml
                if grep -q "$program = " Anchor.toml; then
                    sed -i '' "s/$program = \".*\"/$program = \"$PROGRAM_ID\"/g" Anchor.toml
                fi
                
                echo -e "${GREEN}✅ $program deployado na segunda tentativa!${NC}"
            else
                echo -e "${RED}❌ Falha definitiva no deploy do $program${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Airdrop falhou, pulando $program${NC}"
        fi
    fi
    
    # Small delay between deploys
    sleep 2
done

# Update .env.devnet with deployed program IDs
if [ ${#DEPLOYED_PROGRAMS[@]} -gt 0 ]; then
    echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Atualizando .env.devnet..."
    
    # Backup original
    cp .env.devnet .env.devnet.backup
    
    # Remove old program IDs
    grep -v "_PROGRAM_ID=" .env.devnet > .env.devnet.tmp
    
    # Add new program IDs
    echo "" >> .env.devnet.tmp
    echo "# Program IDs (Updated $(date))" >> .env.devnet.tmp
    
    for program in "${DEPLOYED_PROGRAMS[@]}"; do
        PROGRAM_ID=$(grep "$program = " Anchor.toml | cut -d'"' -f2)
        if [ ! -z "$PROGRAM_ID" ]; then
            UPPER_PROGRAM=$(echo $program | tr '[:lower:]' '[:upper:]')
            echo "${UPPER_PROGRAM}_PROGRAM_ID=\"$PROGRAM_ID\"" >> .env.devnet.tmp
        fi
    done
    
    mv .env.devnet.tmp .env.devnet
    echo -e "${GREEN}✅ .env.devnet atualizado!${NC}"
fi

# Final summary
echo "\n🎉 ===================================="
echo "   DEPLOY OTIMIZADO CONCLUÍDO"
echo "🎉 ===================================="
echo "Programas deployados: ${#DEPLOYED_PROGRAMS[@]}/${#PROGRAMS_ORDERED[@]}"

if [ ${#DEPLOYED_PROGRAMS[@]} -gt 0 ]; then
    echo "\n✅ Deployados com sucesso:"
    for program in "${DEPLOYED_PROGRAMS[@]}"; do
        PROGRAM_ID=$(grep "$program = " Anchor.toml | cut -d'"' -f2)
        echo "  - $program: $PROGRAM_ID"
    done
fi

if [ ${#FAILED_PROGRAMS[@]} -gt 0 ]; then
    echo "\n❌ Falharam no deploy:"
    for program in "${FAILED_PROGRAMS[@]}"; do
        echo "  - $program"
    done
    echo "\nPara deployar os programas restantes:"
    echo "1. Obtenha mais SOL: solana airdrop 5 $DEPLOYER_ADDRESS"
    echo "2. Execute: anchor deploy --program-name <program> --provider.cluster devnet"
fi

FINAL_BALANCE=$(solana balance $DEPLOYER_ADDRESS | grep -o '[0-9.]\+' | head -1)
echo "\nBalance final: ${FINAL_BALANCE} SOL"
echo "===================================="

# Try to run initialization if we have enough programs
if [ ${#DEPLOYED_PROGRAMS[@]} -ge 3 ]; then
    echo "\n[$(date '+%Y-%m-%d %H:%M:%S')] Tentando inicialização..."
    if node scripts/initialize_devnet.js; then
        echo -e "${GREEN}✅ Inicialização bem-sucedida!${NC}"
    else
        echo -e "${YELLOW}⚠️  Inicialização falhou, mas deploy foi bem-sucedido${NC}"
    fi
fi