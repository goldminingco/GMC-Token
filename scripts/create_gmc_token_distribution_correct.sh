#!/bin/bash

# 🪙 GMC Token - Distribuição Inicial Correta
# ==========================================
# 
# Script para criar e distribuir o GMC Token conforme especificação oficial:
# Total Supply: 100.000.000 GMC (sem inflação futura)
# 
# DISTRIBUIÇÃO CORRETA:
# - Pool de Staking: 70.000.000 GMC (70%)
# - Reserva Estratégica: 10.000.000 GMC (10%) - 5 anos
# - Pré-venda (ICO): 8.000.000 GMC (8%)
# - Marketing & Expansão: 6.000.000 GMC (6%)
# - Airdrop: 2.000.000 GMC (2%)
# - Equipe (Vesting): 2.000.000 GMC (2%) - 24 meses
# - Tesouraria: 2.000.000 GMC (2%)

set -e

echo "🪙 GMC Token - Distribuição Inicial Correta"
echo "==========================================="
echo ""

# Configurações do Token
TOKEN_NAME="GMC Token"
TOKEN_SYMBOL="GMC"
TOKEN_DESCRIPTION="Gold Mining Company Token - Revolutionary DeFi ecosystem with staking, affiliate system, and treasury management"
TOTAL_SUPPLY=100000000   # 100 milhões
DECIMALS=9

# Distribuição Correta (em GMC)
STAKING_POOL=70000000    # 70M GMC (70%)
STRATEGIC_RESERVE=10000000 # 10M GMC (10%)
PRESALE=8000000          # 8M GMC (8%)
MARKETING=6000000        # 6M GMC (6%)
AIRDROP=2000000          # 2M GMC (2%)
TEAM_VESTING=2000000     # 2M GMC (2%)
TREASURY=2000000         # 2M GMC (2%)

# Carteiras TestNet (conforme memória)
DEPLOYER_WALLET="1CfuyFT7yxu73uwYWyetjvPEhfqJX8QVEgxH2KvjR4L"
TREASURY_WALLET="E3aRtiDuSE976Kgw4e9iakNWrXbz8HWd9hNHmiVAPZ6r"
TEAM_WALLET="5W8VPYTBvND31LN7pFtErZ6UpyVqHCec5tcCJg32Tqie"
PRESALE_WALLET="5hKqwf3aVxMF9Hm8ZqoKowVk8sL9i9xEcF3XzbciR3LL"
MARKETING_WALLET="2i5d4pUknPYmYN6GFnkjGbZLcnchJuYB5vfXhtzYRvCE"
AIRDROP_WALLET="DEgymkGwkgNbVzt9siN2tEV8ne61mYdg8cTdjmnsFfBU"

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}📋 DISTRIBUIÇÃO OFICIAL GMC TOKEN:${NC}"
echo -e "   • ${BLUE}Total Supply:${NC} $(printf "%'d" $TOTAL_SUPPLY) GMC"
echo -e "   • ${BLUE}Pool de Staking:${NC} $(printf "%'d" $STAKING_POOL) GMC (70%)"
echo -e "   • ${BLUE}Reserva Estratégica:${NC} $(printf "%'d" $STRATEGIC_RESERVE) GMC (10%)"
echo -e "   • ${BLUE}Pré-venda (ICO):${NC} $(printf "%'d" $PRESALE) GMC (8%)"
echo -e "   • ${BLUE}Marketing & Expansão:${NC} $(printf "%'d" $MARKETING) GMC (6%)"
echo -e "   • ${BLUE}Airdrop:${NC} $(printf "%'d" $AIRDROP) GMC (2%)"
echo -e "   • ${BLUE}Equipe (Vesting):${NC} $(printf "%'d" $TEAM_VESTING) GMC (2%)"
echo -e "   • ${BLUE}Tesouraria:${NC} $(printf "%'d" $TREASURY) GMC (2%)"
echo ""

# Validar soma = 100%
TOTAL_ALLOCATED=$((STAKING_POOL + STRATEGIC_RESERVE + PRESALE + MARKETING + AIRDROP + TEAM_VESTING + TREASURY))
if [ $TOTAL_ALLOCATED -ne $TOTAL_SUPPLY ]; then
    echo -e "${RED}❌ ERRO: Distribuição não soma 100M GMC!${NC}"
    echo -e "   Total alocado: $(printf "%'d" $TOTAL_ALLOCATED) GMC"
    echo -e "   Esperado: $(printf "%'d" $TOTAL_SUPPLY) GMC"
    exit 1
fi

echo -e "${GREEN}✅ Distribuição validada: $(printf "%'d" $TOTAL_ALLOCATED) GMC = 100%${NC}"
echo ""

echo -e "${PURPLE}🚀 INICIANDO CRIAÇÃO DO TOKEN...${NC}"

# 1. Criar o token mint
echo -e "${YELLOW}1. Criando token mint...${NC}"
MINT_KEYPAIR=$(mktemp)
solana-keygen new --no-bip39-passphrase --silent --outfile $MINT_KEYPAIR

MINT_ADDRESS=$(solana-keygen pubkey $MINT_KEYPAIR)
echo -e "${GREEN}   Mint Address: $MINT_ADDRESS${NC}"

# 2. Criar o token
spl-token create-token --decimals $DECIMALS $MINT_KEYPAIR
echo -e "${GREEN}   Token criado com $DECIMALS decimais${NC}"

# 3. Criar conta de token para o deployer
echo -e "${YELLOW}2. Criando conta de token...${NC}"
TOKEN_ACCOUNT=$(spl-token create-account $MINT_ADDRESS --output json | jq -r '.account')
echo -e "${GREEN}   Token Account: $TOKEN_ACCOUNT${NC}"

# 4. Mintar o supply total
echo -e "${YELLOW}3. Mintando supply total...${NC}"
spl-token mint $MINT_ADDRESS $TOTAL_SUPPLY $TOKEN_ACCOUNT
echo -e "${GREEN}   Supply mintado: $(printf "%'d" $TOTAL_SUPPLY) GMC${NC}"

# 5. Distribuir para carteiras específicas
echo -e "${YELLOW}4. Distribuindo tokens...${NC}"

# Pré-venda (8M GMC)
echo -e "   • Pré-venda: $(printf "%'d" $PRESALE) GMC → $PRESALE_WALLET"
PRESALE_ACCOUNT=$(spl-token create-account $MINT_ADDRESS --owner $PRESALE_WALLET --output json | jq -r '.account')
spl-token transfer $MINT_ADDRESS $PRESALE $PRESALE_ACCOUNT --fund-recipient

# Marketing (6M GMC)
echo -e "   • Marketing: $(printf "%'d" $MARKETING) GMC → $MARKETING_WALLET"
MARKETING_ACCOUNT=$(spl-token create-account $MINT_ADDRESS --owner $MARKETING_WALLET --output json | jq -r '.account')
spl-token transfer $MINT_ADDRESS $MARKETING $MARKETING_ACCOUNT --fund-recipient

# Airdrop (2M GMC)
echo -e "   • Airdrop: $(printf "%'d" $AIRDROP) GMC → $AIRDROP_WALLET"
AIRDROP_ACCOUNT=$(spl-token create-account $MINT_ADDRESS --owner $AIRDROP_WALLET --output json | jq -r '.account')
spl-token transfer $MINT_ADDRESS $AIRDROP $AIRDROP_ACCOUNT --fund-recipient

# Tesouraria (2M GMC)
echo -e "   • Tesouraria: $(printf "%'d" $TREASURY) GMC → $TREASURY_WALLET"
TREASURY_ACCOUNT=$(spl-token create-account $MINT_ADDRESS --owner $TREASURY_WALLET --output json | jq -r '.account')
spl-token transfer $MINT_ADDRESS $TREASURY $TREASURY_ACCOUNT --fund-recipient

echo -e "${GREEN}✅ Distribuição para carteiras específicas concluída${NC}"

# 6. Tokens restantes (Staking Pool + Reserva + Team Vesting)
REMAINING_TOKENS=$((STAKING_POOL + STRATEGIC_RESERVE + TEAM_VESTING))
echo -e "${YELLOW}5. Tokens restantes no deployer:${NC}"
echo -e "   • Pool de Staking: $(printf "%'d" $STAKING_POOL) GMC (gerenciado pelo smart contract)"
echo -e "   • Reserva Estratégica: $(printf "%'d" $STRATEGIC_RESERVE) GMC (5 anos)"
echo -e "   • Team Vesting: $(printf "%'d" $TEAM_VESTING) GMC (24 meses + 6 meses cliff)"
echo -e "   • Total restante: $(printf "%'d" $REMAINING_TOKENS) GMC"

# 7. Verificar saldos finais
echo -e "${PURPLE}📊 VERIFICAÇÃO FINAL:${NC}"
DEPLOYER_BALANCE=$(spl-token balance --address $TOKEN_ACCOUNT)
echo -e "${GREEN}   Saldo Deployer: $(printf "%'d" $DEPLOYER_BALANCE) GMC${NC}"

TOTAL_SUPPLY_CHECK=$(spl-token supply $MINT_ADDRESS)
echo -e "${GREEN}   Supply Total: $(printf "%'d" $TOTAL_SUPPLY_CHECK) GMC${NC}"

# 8. Salvar informações importantes
echo -e "${YELLOW}6. Salvando informações...${NC}"
cat > gmc_token_info.json << EOF
{
  "token_name": "$TOKEN_NAME",
  "token_symbol": "$TOKEN_SYMBOL",
  "mint_address": "$MINT_ADDRESS",
  "total_supply": $TOTAL_SUPPLY,
  "decimals": $DECIMALS,
  "distribution": {
    "staking_pool": $STAKING_POOL,
    "strategic_reserve": $STRATEGIC_RESERVE,
    "presale": $PRESALE,
    "marketing": $MARKETING,
    "airdrop": $AIRDROP,
    "team_vesting": $TEAM_VESTING,
    "treasury": $TREASURY
  },
  "wallets": {
    "deployer": "$DEPLOYER_WALLET",
    "treasury": "$TREASURY_WALLET",
    "team": "$TEAM_WALLET",
    "presale": "$PRESALE_WALLET",
    "marketing": "$MARKETING_WALLET",
    "airdrop": "$AIRDROP_WALLET"
  },
  "accounts": {
    "deployer_token_account": "$TOKEN_ACCOUNT",
    "presale_account": "$PRESALE_ACCOUNT",
    "marketing_account": "$MARKETING_ACCOUNT",
    "airdrop_account": "$AIRDROP_ACCOUNT",
    "treasury_account": "$TREASURY_ACCOUNT"
  }
}
EOF

echo -e "${GREEN}✅ Informações salvas em: gmc_token_info.json${NC}"

# 9. Limpar arquivos temporários
rm -f $MINT_KEYPAIR

echo ""
echo -e "${PURPLE}🎉 GMC TOKEN CRIADO E DISTRIBUÍDO COM SUCESSO!${NC}"
echo ""
echo -e "${BLUE}📋 RESUMO FINAL:${NC}"
echo -e "   • ${GREEN}Mint Address:${NC} $MINT_ADDRESS"
echo -e "   • ${GREEN}Total Supply:${NC} $(printf "%'d" $TOTAL_SUPPLY_CHECK) GMC"
echo -e "   • ${GREEN}Distribuição:${NC} Conforme especificação oficial"
echo -e "   • ${GREEN}Status:${NC} Pronto para integração com smart contracts"
echo ""
echo -e "${YELLOW}📝 PRÓXIMOS PASSOS:${NC}"
echo -e "   1. Integrar Mint Address no smart contract GMC"
echo -e "   2. Configurar vesting da equipe (2M GMC)"
echo -e "   3. Configurar pool de staking (70M GMC)"
echo -e "   4. Ativar sistema de treasury multisig"
echo ""
echo -e "${GREEN}🔗 Explorer: https://explorer.solana.com/address/$MINT_ADDRESS?cluster=devnet${NC}"
