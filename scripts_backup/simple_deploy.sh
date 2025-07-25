#!/bin/bash
# 🚀 GMC Token - Deploy Simplificado na Testnet

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROGRAM_PATH="deploy/gmc_token.so"

echo -e "${BLUE}🚀 GMC Token - Deploy Simplificado na Testnet${NC}"
echo "==============================================="
echo

# 1. Verificar artefato
echo -e "${YELLOW}1. Verificando artefato...${NC}"
if [ ! -f "$PROGRAM_PATH" ]; then
    echo -e "${RED}❌ Artefato não encontrado: $PROGRAM_PATH${NC}"
    exit 1
fi

ARTIFACT_SIZE=$(ls -lh "$PROGRAM_PATH" | awk '{print $5}')
echo -e "${GREEN}✅ Artefato encontrado: $ARTIFACT_SIZE${NC}"

# 2. Configurar ambiente testnet
echo -e "${YELLOW}2. Configurando ambiente testnet...${NC}"
solana config set --url testnet

# 3. Instruções para configurar carteira
echo -e "${YELLOW}3. Configurando carteira...${NC}"
echo -e "${CYAN}📋 Você precisa executar manualmente:${NC}"
echo -e "${BLUE}   1. solana-keygen recover -o .testnet-keys/main_deployer.json --force${NC}"
echo -e "${BLUE}   2. Cole a seed phrase: maple outside mammal owner right laugh clinic fashion later crowd hotel fee${NC}"
echo -e "${BLUE}   3. Pressione Enter (sem passphrase)${NC}"
echo -e "${BLUE}   4. Digite 'y' para confirmar${NC}"
echo
read -p "Pressione Enter após configurar a carteira..."

# Verificar se foi criada
if [ ! -f ".testnet-keys/main_deployer.json" ]; then
    echo -e "${RED}❌ Carteira não foi configurada${NC}"
    exit 1
fi

# Configurar como padrão
solana config set --keypair .testnet-keys/main_deployer.json

# 4. Verificar configuração
WALLET_ADDRESS=$(solana address)
BALANCE=$(solana balance)

echo -e "${GREEN}✅ Carteira: $WALLET_ADDRESS${NC}"
echo -e "${GREEN}✅ Saldo: $BALANCE${NC}"

# 5. Verificar saldo
if [[ "$BALANCE" == "0 SOL" ]]; then
    echo -e "${RED}❌ Saldo insuficiente para deploy${NC}"
    echo -e "${YELLOW}Verifique se a carteira foi recuperada corretamente${NC}"
    exit 1
fi

# 6. Deploy
echo -e "${YELLOW}4. Fazendo deploy do programa...${NC}"
echo -e "${BLUE}📦 Arquivo: $PROGRAM_PATH${NC}"
echo -e "${BLUE}📏 Tamanho: $ARTIFACT_SIZE${NC}"
echo -e "${BLUE}💰 Carteira: $WALLET_ADDRESS${NC}"
echo -e "${BLUE}💰 Saldo: $BALANCE${NC}"
echo

# Deploy com retry
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo -e "${BLUE}🚀 Tentativa de deploy $(($RETRY_COUNT + 1))/$MAX_RETRIES...${NC}"
    
    if PROGRAM_ID=$(solana program deploy "$PROGRAM_PATH" --output json 2>/dev/null | jq -r '.programId' 2>/dev/null); then
        if [ "$PROGRAM_ID" != "null" ] && [ -n "$PROGRAM_ID" ]; then
            echo -e "${GREEN}✅ Deploy realizado com sucesso!${NC}"
            echo -e "${GREEN}🎯 Program ID: $PROGRAM_ID${NC}"
            break
        else
            echo -e "${YELLOW}⚠️ Deploy retornou resultado inválido, tentando novamente...${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Deploy falhou, tentando novamente...${NC}"
    fi
    
    RETRY_COUNT=$(($RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo -e "${YELLOW}Aguardando 5 segundos...${NC}"
        sleep 5
    else
        echo -e "${RED}❌ Deploy falhou após $MAX_RETRIES tentativas${NC}"
        exit 1
    fi
done

# 7. Verificar deploy
echo -e "${YELLOW}5. Verificando deploy...${NC}"
if solana program show "$PROGRAM_ID" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Programa verificado na blockchain${NC}"
    
    # Obter informações do programa
    PROGRAM_INFO=$(solana program show "$PROGRAM_ID" --output json 2>/dev/null)
    if [ $? -eq 0 ]; then
        UPGRADE_AUTHORITY=$(echo "$PROGRAM_INFO" | jq -r '.programdata.upgradeAuthority // "None"' 2>/dev/null)
        echo -e "${GREEN}🔑 Upgrade Authority: $UPGRADE_AUTHORITY${NC}"
    fi
else
    echo -e "${RED}❌ Erro ao verificar programa${NC}"
    exit 1
fi

# 8. Salvar informações
echo -e "${YELLOW}6. Salvando informações...${NC}"

DEPLOY_INFO_FILE=".testnet-keys/deploy_info_$(date +%Y%m%d_%H%M%S).json"
cat > "$DEPLOY_INFO_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "testnet",
  "programId": "$PROGRAM_ID",
  "deployerAddress": "$WALLET_ADDRESS",
  "artifactPath": "$PROGRAM_PATH",
  "artifactSize": "$ARTIFACT_SIZE"
}
EOF

echo -e "${GREEN}✅ Deploy info salvo em: $DEPLOY_INFO_FILE${NC}"

# 9. Resumo final
echo
echo -e "${GREEN}🎉 DEPLOY TESTNET CONCLUÍDO COM SUCESSO! 🎉${NC}"
echo "=============================================="
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

echo -e "${GREEN}Deploy finalizado! 🚀${NC}" 