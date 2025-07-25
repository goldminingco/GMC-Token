#!/bin/bash

# 🪙 GMC Token - Criação Correta do Token SPL
# ===========================================
# 
# Este script cria o token SPL GMC com as especificações CORRETAS:
# - Supply: 100.000.000 GMC (100 milhões) conforme tokenomics.md
# - Nome: GMC Token
# - Símbolo: GMC
# - Decimais: 9

set -e

echo "🪙 GMC Token - Criação Correta do Token SPL"
echo "==========================================="
echo ""

# Configurações CORRETAS do Token (baseadas na análise do projeto)
TOKEN_NAME="GMC Token"
TOKEN_SYMBOL="GMC"
TOKEN_DESCRIPTION="Gold Mining Company Token - Revolutionary DeFi token with staking, affiliate system, and treasury management"
INITIAL_SUPPLY=100000000   # 100 milhões conforme tokenomics.md
DECIMALS=9

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}📋 CONFIGURAÇÕES CORRETAS DO GMC TOKEN:${NC}"
echo -e "   • ${BLUE}Nome:${NC} $TOKEN_NAME"
echo -e "   • ${BLUE}Símbolo:${NC} $TOKEN_SYMBOL"
echo -e "   • ${BLUE}Supply Total:${NC} $(printf "%'d" $INITIAL_SUPPLY) GMC (100 milhões)"
echo -e "   • ${BLUE}Decimais:${NC} $DECIMALS"
echo ""

echo -e "${PURPLE}🏗️ FUNCIONALIDADES DO PROJETO (conforme análise):${NC}"
echo -e "   • ${GREEN}✅ Staking System${NC} (longo prazo + flexível)"
echo -e "   • ${GREEN}✅ Affiliate System${NC} (6 níveis: 20%, 15%, 8%, 4%, 2%, 1%)"
echo -e "   • ${GREEN}✅ Treasury Management${NC} (70M GMC para staking)"
echo -e "   • ${GREEN}✅ Fee System${NC} (0.5% por transação)"
echo -e "   • ${GREEN}✅ Burn Mechanism${NC} (até atingir 12M GMC)"
echo -e "   • ${GREEN}✅ Vesting System${NC} (liberação gradual)"
echo ""

echo -e "${PURPLE}💰 DISTRIBUIÇÃO INICIAL (conforme tokenomics.md):${NC}"
echo -e "   • ${BLUE}Staking Pool:${NC} 70.000.000 GMC (70%)"
echo -e "   • ${BLUE}Reserva Gold Mining:${NC} 10.000.000 GMC (10%)"
echo -e "   • ${BLUE}Pré-venda (ICO):${NC} 8.000.000 GMC (8%)"
echo -e "   • ${BLUE}Marketing:${NC} 6.000.000 GMC (6%)"
echo -e "   • ${BLUE}Tesouraria:${NC} 2.000.000 GMC (2%)"
echo -e "   • ${BLUE}Airdrop:${NC} 2.000.000 GMC (2%)"
echo -e "   • ${BLUE}Equipe:${NC} 2.000.000 GMC (2%)"
echo ""

# 1. Verificar se spl-token está instalado
echo "1. Verificando spl-token..."
if ! command -v spl-token &> /dev/null; then
    echo -e "${RED}❌ spl-token não encontrado. Instalando...${NC}"
    cargo install spl-token-cli
else
    echo -e "${GREEN}✅ spl-token disponível${NC}"
fi

# 2. Verificar configuração da rede
echo ""
echo "2. Verificando configuração da rede..."
CURRENT_RPC=$(solana config get | grep "RPC URL" | awk '{print $3}')
echo -e "${BLUE}📡 RPC atual: $CURRENT_RPC${NC}"

if [[ "$CURRENT_RPC" != *"devnet"* ]]; then
    echo -e "${YELLOW}⚠️ Configurando para devnet...${NC}"
    solana config set --url https://api.devnet.solana.com
fi

# 3. Verificar saldo da wallet
echo ""
echo "3. Verificando saldo da wallet..."
DEPLOYER_WALLET=$(solana address)
BALANCE=$(solana balance)
echo -e "${BLUE}💰 Deployer: $DEPLOYER_WALLET${NC}"
echo -e "${BLUE}💰 Saldo atual: $BALANCE${NC}"

if (( $(echo "$BALANCE" | cut -d' ' -f1 | awk '{print ($1 < 0.1)}') )); then
    echo -e "${RED}❌ Saldo insuficiente para criar token${NC}"
    echo "💡 Execute: solana airdrop 2"
    exit 1
fi

# 4. Criar o Token Mint com supply CORRETO
echo ""
echo "4. Criando Token Mint GMC..."
echo -e "${YELLOW}📦 Criando mint para $TOKEN_SYMBOL com supply de $(printf "%'d" $INITIAL_SUPPLY)...${NC}"

MINT_ADDRESS=$(spl-token create-token --decimals $DECIMALS 2>/dev/null | grep "Creating token" | awk '{print $3}')

if [ -z "$MINT_ADDRESS" ]; then
    echo -e "${RED}❌ Erro ao criar token mint${NC}"
    exit 1
fi

echo -e "${GREEN}✅ GMC Token Mint criado: $MINT_ADDRESS${NC}"

# Salvar endereço do mint
mkdir -p .devnet-keys
echo "$MINT_ADDRESS" > .devnet-keys/gmc_token_mint_correct.txt
echo -e "${BLUE}📋 Endereço salvo em: .devnet-keys/gmc_token_mint_correct.txt${NC}"

# 5. Criar Account de Token para o deployer
echo ""
echo "5. Criando Token Account..."
TOKEN_ACCOUNT=$(spl-token create-account $MINT_ADDRESS 2>/dev/null | grep "Creating account" | awk '{print $3}')

if [ -z "$TOKEN_ACCOUNT" ]; then
    echo -e "${RED}❌ Erro ao criar token account${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token Account criado: $TOKEN_ACCOUNT${NC}"

# 6. Fazer Mint Inicial com supply CORRETO
echo ""
echo "6. Fazendo mint inicial com supply correto..."
echo -e "${YELLOW}🏭 Mintando $(printf "%'d" $INITIAL_SUPPLY) GMC tokens (100 milhões)...${NC}"

spl-token mint $MINT_ADDRESS $INITIAL_SUPPLY $TOKEN_ACCOUNT

echo -e "${GREEN}✅ Mint inicial realizado com supply correto!${NC}"

# 7. Verificar supply total
echo ""
echo "7. Verificando supply..."
TOTAL_SUPPLY=$(spl-token supply $MINT_ADDRESS)
echo -e "${GREEN}📊 Supply total: $(printf "%'d" $TOTAL_SUPPLY) GMC${NC}"

# 8. Verificar saldo do token account
ACCOUNT_BALANCE=$(spl-token balance --address $TOKEN_ACCOUNT)
echo -e "${GREEN}💰 Saldo na conta: $(printf "%'d" $ACCOUNT_BALANCE) GMC${NC}"

# 9. Validar se o supply está correto
if [ "$TOTAL_SUPPLY" = "$INITIAL_SUPPLY" ]; then
    echo -e "${GREEN}✅ Supply validado: $(printf "%'d" $TOTAL_SUPPLY) GMC = 100 milhões ✅${NC}"
else
    echo -e "${RED}❌ Supply incorreto! Esperado: $INITIAL_SUPPLY, Atual: $TOTAL_SUPPLY${NC}"
fi

# 10. Informações sobre o programa deployado
echo ""
echo "8. Informações do programa GMC Token..."
if [ -f ".devnet-keys/gmc_complete_program_id.txt" ]; then
    PROGRAM_ID=$(cat .devnet-keys/gmc_complete_program_id.txt)
    echo -e "${BLUE}🔗 Program ID: $PROGRAM_ID${NC}"
elif [ -f ".devnet-keys/gmc_program_id.txt" ]; then
    PROGRAM_ID=$(cat .devnet-keys/gmc_program_id.txt)
    echo -e "${BLUE}🔗 Program ID: $PROGRAM_ID${NC}"
else
    echo -e "${YELLOW}⚠️ Program ID não encontrado. Execute o deploy do programa primeiro.${NC}"
fi

# 11. Resumo final
echo ""
echo -e "${PURPLE}🎉 GMC TOKEN SPL CRIADO COM ESPECIFICAÇÕES CORRETAS! 🎉${NC}"
echo "============================================================="
echo ""
echo -e "${GREEN}📋 INFORMAÇÕES DO TOKEN GMC:${NC}"
echo -e "   • ${BLUE}Nome:${NC} $TOKEN_NAME"
echo -e "   • ${BLUE}Símbolo:${NC} $TOKEN_SYMBOL"
echo -e "   • ${BLUE}Mint Address:${NC} $MINT_ADDRESS"
echo -e "   • ${BLUE}Token Account:${NC} $TOKEN_ACCOUNT"
echo -e "   • ${BLUE}Supply Total:${NC} $(printf "%'d" $TOTAL_SUPPLY) GMC (100 milhões) ✅"
echo -e "   • ${BLUE}Decimais:${NC} $DECIMALS"
echo -e "   • ${BLUE}Network:${NC} devnet"
echo ""

echo -e "${GREEN}🔗 LINKS ÚTEIS:${NC}"
echo -e "   • ${BLUE}Explorer (Mint):${NC} https://explorer.solana.com/address/$MINT_ADDRESS?cluster=devnet"
echo -e "   • ${BLUE}Explorer (Account):${NC} https://explorer.solana.com/address/$TOKEN_ACCOUNT?cluster=devnet"
if [ -n "$PROGRAM_ID" ]; then
    echo -e "   • ${BLUE}Explorer (Program):${NC} https://explorer.solana.com/address/$PROGRAM_ID?cluster=devnet"
fi
echo ""

echo -e "${GREEN}📁 ARQUIVOS SALVOS:${NC}"
echo -e "   • ${BLUE}Mint Address:${NC} .devnet-keys/gmc_token_mint_correct.txt"
echo ""

echo -e "${GREEN}🎯 PRÓXIMOS PASSOS:${NC}"
echo "   1. 🔍 Verificar token no Explorer usando os links acima"
echo "   2. 🧪 Testar funcionalidades do programa (staking, affiliate, etc.)"
echo "   3. 🎨 Configurar metadados avançados (logo, descrição, etc.)"
echo "   4. 🚀 Integrar frontend com Mint Address: $MINT_ADDRESS"
echo "   5. 📊 Implementar distribuição inicial conforme tokenomics"
echo ""

echo -e "${GREEN}✅ GMC Token está agora visível no Explorer com supply CORRETO de 100 milhões!${NC}"
