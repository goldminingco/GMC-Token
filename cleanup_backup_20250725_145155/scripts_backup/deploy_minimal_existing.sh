#!/bin/bash
# 🚀 Deploy Mínimo - Usar artefato existente
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 GMC Token - Deploy com Artefato Existente${NC}"
echo "================================================"
echo

# 1. Verificar artefato
PROGRAM_PATH="deploy/gmc_token.so"
if [ ! -f "$PROGRAM_PATH" ]; then
    echo -e "${RED}❌ Artefato não encontrado: $PROGRAM_PATH${NC}"
    exit 1
fi

ARTIFACT_SIZE=$(ls -lh "$PROGRAM_PATH" | awk '{print $5}')
echo -e "${GREEN}✅ Artefato: $ARTIFACT_SIZE${NC}"

# 2. Verificar configuração
WALLET_ADDRESS=$(solana address)
BALANCE=$(solana balance)
RPC_URL=$(solana config get | grep "RPC URL" | awk '{print $3}')

echo -e "${GREEN}✅ Wallet: $WALLET_ADDRESS${NC}"
echo -e "${GREEN}✅ Saldo: $BALANCE${NC}"
echo -e "${GREEN}✅ RPC: $RPC_URL${NC}"

# Verificar se tem saldo
if [[ "$BALANCE" == "0 SOL" ]]; then
    echo -e "${YELLOW}⚠️ Saldo zero, solicitando airdrop...${NC}"
    solana airdrop 2 || {
        echo -e "${RED}❌ Falha no airdrop${NC}"
        exit 1
    }
    sleep 2
    BALANCE=$(solana balance)
    echo -e "${GREEN}✅ Novo saldo: $BALANCE${NC}"
fi

echo
echo -e "${YELLOW}🚀 Iniciando deploy...${NC}"

# 3. Tentar deploy com diferentes opções
MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo -e "${BLUE}Tentativa $(($RETRY_COUNT + 1))/$MAX_RETRIES${NC}"
    
    # Tentar diferentes abordagens de deploy
    case $RETRY_COUNT in
        0)
            echo -e "${BLUE}▶ Tentando deploy padrão...${NC}"
            DEPLOY_CMD="solana program deploy $PROGRAM_PATH --output json"
            ;;
        1)
            echo -e "${BLUE}▶ Tentando deploy com RPC padrão...${NC}"
            DEPLOY_CMD="solana program deploy $PROGRAM_PATH --output json --use-rpc"
            ;;
        2)
            echo -e "${BLUE}▶ Tentando deploy com buffer...${NC}"
            DEPLOY_CMD="solana program deploy $PROGRAM_PATH --output json --buffer"
            ;;
        3)
            echo -e "${BLUE}▶ Tentando deploy direto...${NC}"
            DEPLOY_CMD="solana program deploy $PROGRAM_PATH"
            ;;
        *)
            echo -e "${BLUE}▶ Tentando deploy básico final...${NC}"
            DEPLOY_CMD="solana program deploy $PROGRAM_PATH --output json --commitment confirmed"
            ;;
    esac
    
    if DEPLOY_OUTPUT=$($DEPLOY_CMD 2>&1); then
        echo -e "${GREEN}✅ Deploy bem-sucedido!${NC}"
        echo "$DEPLOY_OUTPUT"
        
        # Tentar extrair Program ID do output
        if [[ "$DEPLOY_OUTPUT" =~ \"programId\":\"([^\"]+)\" ]]; then
            PROGRAM_ID="${BASH_REMATCH[1]}"
            echo -e "${GREEN}🎯 Program ID: $PROGRAM_ID${NC}"
        elif [[ "$DEPLOY_OUTPUT" =~ Program\ Id:\ ([A-Za-z0-9]+) ]]; then
            PROGRAM_ID="${BASH_REMATCH[1]}"
            echo -e "${GREEN}🎯 Program ID: $PROGRAM_ID${NC}"
        else
            echo -e "${YELLOW}⚠️ Não foi possível extrair Program ID do output${NC}"
            PROGRAM_ID="UNKNOWN"
        fi
        
        # Sucesso!
        break
    else
        echo -e "${YELLOW}⚠️ Falha: $DEPLOY_OUTPUT${NC}"
        
        # Se o erro é de SBPF, não vale a pena tentar mais
        if [[ "$DEPLOY_OUTPUT" =~ "sbpf_version" || "$DEPLOY_OUTPUT" =~ "ELF error" ]]; then
            echo -e "${RED}❌ Erro de compatibilidade SBPF detectado${NC}"
            echo -e "${YELLOW}💡 Sugestão: O artefato foi compilado com SBPF v2, mas a rede suporta apenas v1${NC}"
            echo -e "${YELLOW}💡 Necessário recompilação com toolchain compatível${NC}"
            exit 1
        fi
    fi
    
    RETRY_COUNT=$(($RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo -e "${YELLOW}Aguardando 3 segundos...${NC}"
        sleep 3
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Deploy falhou após $MAX_RETRIES tentativas${NC}"
    exit 1
fi

# 4. Verificar deploy
if [ "$PROGRAM_ID" != "UNKNOWN" ]; then
    echo -e "${YELLOW}🔍 Verificando deploy...${NC}"
    if solana program show "$PROGRAM_ID" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Programa verificado na blockchain${NC}"
    else
        echo -e "${YELLOW}⚠️ Programa não encontrado na verificação${NC}"
    fi
fi

# 5. Resumo final
echo
echo -e "${GREEN}🎉 DEPLOY CONCLUÍDO! 🎉${NC}"
echo "================================"
echo -e "${BLUE}📋 INFORMAÇÕES:${NC}"
echo -e "${BLUE}   • Program ID: ${GREEN}${PROGRAM_ID}${NC}"
echo -e "${BLUE}   • Network: ${GREEN}$(echo $RPC_URL | grep -o 'devnet\|testnet\|mainnet' || echo 'Unknown')${NC}"
echo -e "${BLUE}   • Deployer: ${GREEN}$WALLET_ADDRESS${NC}"
echo -e "${BLUE}   • Artifact: ${GREEN}$PROGRAM_PATH ($ARTIFACT_SIZE)${NC}"

if [[ "$RPC_URL" =~ "devnet" ]]; then
    echo -e "${BLUE}   • Explorer: ${GREEN}https://explorer.solana.com/address/$PROGRAM_ID?cluster=devnet${NC}"
elif [[ "$RPC_URL" =~ "testnet" ]]; then
    echo -e "${BLUE}   • Explorer: ${GREEN}https://explorer.solana.com/address/$PROGRAM_ID?cluster=testnet${NC}"
fi

echo
echo -e "${GREEN}Deploy finalizado! 🚀${NC}" 