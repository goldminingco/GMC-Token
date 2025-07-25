#!/bin/bash
# 🚀 GMC Token - Script de Deploy Testnet
# Deploy seguro e monitorado na testnet da Solana

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configurações
PROGRAM_PATH="deploy/gmc_token.so"
TESTNET_KEYS_DIR=".testnet-keys"
DEPLOYER_KEYPAIR="$TESTNET_KEYS_DIR/deployer.json"

echo -e "${BLUE}🚀 GMC Token - Deploy na Testnet${NC}"
echo "=================================="
echo

# 1. Verificar pré-requisitos
echo -e "${YELLOW}1. Verificando pré-requisitos...${NC}"

if [ ! -f "$PROGRAM_PATH" ]; then
    echo -e "${RED}❌ Artefato não encontrado: $PROGRAM_PATH${NC}"
    echo "Execute: ./build_stable.sh"
    exit 1
fi

if [ ! -f "$DEPLOYER_KEYPAIR" ]; then
    echo -e "${RED}❌ Keypair não encontrada: $DEPLOYER_KEYPAIR${NC}"
    echo "Execute: solana-keygen new -o $DEPLOYER_KEYPAIR"
    exit 1
fi

echo -e "${GREEN}✅ Artefato encontrado: $(ls -lh $PROGRAM_PATH | awk '{print $5}')${NC}"
echo -e "${GREEN}✅ Keypair configurada${NC}"

# 2. Configurar ambiente testnet
echo -e "${YELLOW}2. Configurando ambiente testnet...${NC}"
solana config set --url testnet
solana config set --keypair "$DEPLOYER_KEYPAIR"

# Verificar configuração
CURRENT_URL=$(solana config get | grep "RPC URL" | awk '{print $3}')
CURRENT_KEYPAIR=$(solana config get | grep "Keypair Path" | awk '{print $3}')
WALLET_ADDRESS=$(solana address)

echo -e "${GREEN}✅ RPC URL: $CURRENT_URL${NC}"
echo -e "${GREEN}✅ Keypair: $CURRENT_KEYPAIR${NC}"
echo -e "${GREEN}✅ Wallet: $WALLET_ADDRESS${NC}"

# 3. Verificar saldo
echo -e "${YELLOW}3. Verificando saldo...${NC}"
BALANCE=$(solana balance --lamports)
if [ "$BALANCE" -eq 0 ]; then
    BALANCE_SOL="0.0000"
else
    BALANCE_SOL=$(echo "scale=4; $BALANCE / 1000000000" | bc -l)
fi

echo -e "${GREEN}✅ Saldo: $BALANCE_SOL SOL${NC}"

if (( $(echo "$BALANCE < 2000000000" | bc -l) )); then
    echo -e "${RED}⚠️ Saldo insuficiente para deploy (mínimo: 2 SOL)${NC}"
    echo -e "${YELLOW}📋 Solicite SOL no faucet:${NC}"
    echo -e "${BLUE}   https://faucet.solana.com${NC}"
    echo -e "${BLUE}   Endereço: $WALLET_ADDRESS${NC}"
    echo
    read -p "Pressione Enter após receber SOL para continuar..."
    
    # Verificar novamente após input do usuário
    NEW_BALANCE=$(solana balance --lamports)
    NEW_BALANCE_SOL=$(echo "scale=4; $NEW_BALANCE / 1000000000" | bc -l)
    echo -e "${GREEN}✅ Novo saldo: $NEW_BALANCE_SOL SOL${NC}"
    
    if (( $(echo "$NEW_BALANCE < 2000000000" | bc -l) )); then
        echo -e "${RED}❌ Saldo ainda insuficiente${NC}"
        exit 1
    fi
fi

# 4. Deploy do programa
echo -e "${YELLOW}4. Fazendo deploy do programa...${NC}"
echo -e "${BLUE}📦 Arquivo: $PROGRAM_PATH${NC}"
echo -e "${BLUE}📏 Tamanho: $(ls -lh $PROGRAM_PATH | awk '{print $5}')${NC}"
echo

# Deploy com retry
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo -e "${BLUE}🚀 Tentativa de deploy $(($RETRY_COUNT + 1))/$MAX_RETRIES...${NC}"
    
    if PROGRAM_ID=$(solana program deploy "$PROGRAM_PATH" --output json | jq -r '.programId'); then
        echo -e "${GREEN}✅ Deploy realizado com sucesso!${NC}"
        echo -e "${GREEN}🎯 Program ID: $PROGRAM_ID${NC}"
        break
    else
        RETRY_COUNT=$(($RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}⚠️ Deploy falhou, tentando novamente em 5s...${NC}"
            sleep 5
        else
            echo -e "${RED}❌ Deploy falhou após $MAX_RETRIES tentativas${NC}"
            exit 1
        fi
    fi
done

# 5. Verificar deploy
echo -e "${YELLOW}5. Verificando deploy...${NC}"
if solana program show "$PROGRAM_ID" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Programa verificado na blockchain${NC}"
    
    # Obter informações do programa
    PROGRAM_INFO=$(solana program show "$PROGRAM_ID" --output json)
    PROGRAM_SIZE=$(echo "$PROGRAM_INFO" | jq -r '.programdata.data | length')
    UPGRADE_AUTHORITY=$(echo "$PROGRAM_INFO" | jq -r '.programdata.upgradeAuthority // "None"')
    
    echo -e "${GREEN}📊 Tamanho on-chain: $PROGRAM_SIZE bytes${NC}"
    echo -e "${GREEN}🔑 Upgrade Authority: $UPGRADE_AUTHORITY${NC}"
else
    echo -e "${RED}❌ Erro ao verificar programa${NC}"
    exit 1
fi

# 6. Salvar informações de deploy
echo -e "${YELLOW}6. Salvando informações de deploy...${NC}"

DEPLOY_INFO_FILE="$TESTNET_KEYS_DIR/deploy_info.json"
cat > "$DEPLOY_INFO_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "testnet",
  "programId": "$PROGRAM_ID",
  "deployerAddress": "$WALLET_ADDRESS",
  "programSize": "$PROGRAM_SIZE",
  "upgradeAuthority": "$UPGRADE_AUTHORITY",
  "artifactPath": "$PROGRAM_PATH",
  "artifactSize": "$(stat -f%z "$PROGRAM_PATH")"
}
EOF

echo -e "${GREEN}✅ Deploy info salvo em: $DEPLOY_INFO_FILE${NC}"

# 7. Resumo final
echo
echo -e "${GREEN}🎉 DEPLOY TESTNET CONCLUÍDO COM SUCESSO! 🎉${NC}"
echo "==========================================="
echo -e "${BLUE}📋 INFORMAÇÕES IMPORTANTES:${NC}"
echo -e "${BLUE}   • Program ID: ${GREEN}$PROGRAM_ID${NC}"
echo -e "${BLUE}   • Network: ${GREEN}Solana Testnet${NC}"
echo -e "${BLUE}   • Deployer: ${GREEN}$WALLET_ADDRESS${NC}"
echo -e "${BLUE}   • Explorer: ${GREEN}https://explorer.solana.com/address/$PROGRAM_ID?cluster=testnet${NC}"
echo
echo -e "${YELLOW}🔍 PRÓXIMOS PASSOS:${NC}"
echo -e "${BLUE}   1. Acesse o explorer para verificar o programa${NC}"
echo -e "${BLUE}   2. Execute testes de integração${NC}"
echo -e "${BLUE}   3. Configure frontend para testnet${NC}"
echo -e "${BLUE}   4. Documente as informações para a equipe${NC}"
echo

# Backup das chaves
cp "$DEPLOYER_KEYPAIR" "$TESTNET_KEYS_DIR/deployer_backup_$(date +%Y%m%d_%H%M%S).json"
echo -e "${GREEN}✅ Backup da keypair criado${NC}"

echo -e "${GREEN}Deploy finalizado! 🚀${NC}" 