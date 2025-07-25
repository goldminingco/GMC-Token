#!/bin/bash
# 🔐 GMC Token - Setup Carteiras Testnet
# Configuração simples e rápida das carteiras para testnet

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Diretórios
KEYS_DIR=".testnet-keys"

echo -e "${BLUE}🔐 GMC Token - Setup Carteiras Testnet${NC}"
echo "======================================="
echo

# 1. Configurar ambiente testnet
echo -e "${YELLOW}1. Configurando ambiente testnet...${NC}"
solana config set --url testnet
mkdir -p "$KEYS_DIR"
echo -e "${GREEN}✅ Ambiente configurado${NC}"

# 2. Instruções para recuperação manual
echo -e "${YELLOW}2. Vamos recuperar as carteiras manualmente...${NC}"
echo

echo -e "${CYAN}📋 Recuperando Deployer...${NC}"
echo -e "${BLUE}Seed phrase: high tribe initial auto tired hundred evil verify hover whale ozone initial${NC}"
echo -e "${YELLOW}Execute:${NC} solana-keygen recover -o $KEYS_DIR/deployer.json --force"
echo -e "${YELLOW}Cole a seed phrase quando solicitado${NC}"
echo
read -p "Pressione Enter quando terminar..."

# Verificar se a carteira foi criada
if [ -f "$KEYS_DIR/deployer.json" ]; then
    DEPLOYER_ADDR=$(solana-keygen pubkey "$KEYS_DIR/deployer.json")
    echo -e "${GREEN}✅ Deployer: $DEPLOYER_ADDR${NC}"
else
    echo -e "${RED}❌ Deployer não foi criada${NC}"
    exit 1
fi

echo
echo -e "${CYAN}📋 Recuperando Treasury...${NC}"
echo -e "${BLUE}Seed phrase: scissors strike flame chair material pencil swing praise polar remember have carpet${NC}"
echo -e "${YELLOW}Execute:${NC} solana-keygen recover -o $KEYS_DIR/treasury.json --force"
echo -e "${YELLOW}Cole a seed phrase quando solicitado${NC}"
echo
read -p "Pressione Enter quando terminar..."

# Verificar se a carteira foi criada
if [ -f "$KEYS_DIR/treasury.json" ]; then
    TREASURY_ADDR=$(solana-keygen pubkey "$KEYS_DIR/treasury.json")
    echo -e "${GREEN}✅ Treasury: $TREASURY_ADDR${NC}"
else
    echo -e "${RED}❌ Treasury não foi criada${NC}"
    exit 1
fi

echo
echo -e "${CYAN}📋 Recuperando Admin...${NC}"
echo -e "${BLUE}Seed phrase: because cushion stand museum poem pig remind transfer scrap word style faint${NC}"
echo -e "${YELLOW}Execute:${NC} solana-keygen recover -o $KEYS_DIR/admin.json --force"
echo -e "${YELLOW}Cole a seed phrase quando solicitado${NC}"
echo
read -p "Pressione Enter quando terminar..."

# Verificar se a carteira foi criada
if [ -f "$KEYS_DIR/admin.json" ]; then
    ADMIN_ADDR=$(solana-keygen pubkey "$KEYS_DIR/admin.json")
    echo -e "${GREEN}✅ Admin: $ADMIN_ADDR${NC}"
else
    echo -e "${RED}❌ Admin não foi criada${NC}"
    exit 1
fi

# 3. Verificar saldos
echo
echo -e "${YELLOW}3. Verificando saldos...${NC}"

check_balance() {
    local keypair_file=$1
    local name=$2
    local address=$(solana-keygen pubkey "$keypair_file")
    local balance=$(solana balance "$keypair_file" --lamports 2>/dev/null || echo "0")
    local balance_sol=$(echo "scale=4; $balance / 1000000000" | bc -l 2>/dev/null || echo "0")
    
    echo -e "${BLUE}$name:${NC}"
    echo -e "  Address: ${GREEN}$address${NC}"
    echo -e "  Balance: ${GREEN}$balance_sol SOL${NC}"
    echo
    
    echo "$balance"
}

DEPLOYER_BALANCE=$(check_balance "$KEYS_DIR/deployer.json" "Deployer")
TREASURY_BALANCE=$(check_balance "$KEYS_DIR/treasury.json" "Treasury")
ADMIN_BALANCE=$(check_balance "$KEYS_DIR/admin.json" "Admin")

# Calcular total
TOTAL_BALANCE=$(echo "$DEPLOYER_BALANCE + $TREASURY_BALANCE + $ADMIN_BALANCE" | bc)
TOTAL_SOL=$(echo "scale=4; $TOTAL_BALANCE / 1000000000" | bc -l)

echo -e "${CYAN}💰 Total disponível: ${GREEN}$TOTAL_SOL SOL${NC}"

# 4. Configurar deployer como padrão
echo -e "${YELLOW}4. Configurando deployer como padrão...${NC}"
solana config set --keypair "$KEYS_DIR/deployer.json"

# Verificar configuração
CURRENT_KEYPAIR=$(solana config get | grep "Keypair Path" | awk '{print $3}')
WALLET_ADDRESS=$(solana address)

echo -e "${GREEN}✅ Keypair ativa: $CURRENT_KEYPAIR${NC}"
echo -e "${GREEN}✅ Endereço ativo: $WALLET_ADDRESS${NC}"

# 5. Gerar relatório
echo -e "${YELLOW}5. Gerando relatório...${NC}"

REPORT_FILE="$KEYS_DIR/wallet_setup_$(date +%Y%m%d_%H%M%S).json"
cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "testnet",
  "wallets": {
    "deployer": {
      "address": "$DEPLOYER_ADDR",
      "balance_lamports": $DEPLOYER_BALANCE,
      "keypair_file": "$KEYS_DIR/deployer.json"
    },
    "treasury": {
      "address": "$TREASURY_ADDR",
      "balance_lamports": $TREASURY_BALANCE,
      "keypair_file": "$KEYS_DIR/treasury.json"
    },
    "admin": {
      "address": "$ADMIN_ADDR",
      "balance_lamports": $ADMIN_BALANCE,
      "keypair_file": "$KEYS_DIR/admin.json"
    }
  },
  "total_balance_lamports": $TOTAL_BALANCE,
  "total_balance_sol": "$TOTAL_SOL",
  "active_wallet": "$WALLET_ADDRESS"
}
EOF

echo -e "${GREEN}✅ Relatório salvo em: $REPORT_FILE${NC}"

echo
echo -e "${GREEN}🎉 SETUP DE CARTEIRAS CONCLUÍDO! 🎉${NC}"
echo "======================================="
echo -e "${BLUE}📋 Carteiras configuradas:${NC}"
echo -e "${BLUE}   • Deployer: ${GREEN}$DEPLOYER_ADDR${NC} (${GREEN}$(echo "scale=4; $DEPLOYER_BALANCE / 1000000000" | bc -l) SOL${NC})"
echo -e "${BLUE}   • Treasury: ${GREEN}$TREASURY_ADDR${NC} (${GREEN}$(echo "scale=4; $TREASURY_BALANCE / 1000000000" | bc -l) SOL${NC})"
echo -e "${BLUE}   • Admin:    ${GREEN}$ADMIN_ADDR${NC} (${GREEN}$(echo "scale=4; $ADMIN_BALANCE / 1000000000" | bc -l) SOL${NC})"
echo
echo -e "${BLUE}💰 Total: ${GREEN}$TOTAL_SOL SOL${NC}"
echo -e "${BLUE}🎯 Carteira ativa: ${GREEN}$WALLET_ADDRESS${NC}"
echo
echo -e "${YELLOW}🔍 Próximos passos:${NC}"
echo -e "${BLUE}   1. Execute: ./scripts/deploy_testnet.sh${NC}"
echo -e "${BLUE}   2. Verificar deploy no explorer${NC}"
echo -e "${BLUE}   3. Testar funcionalidades${NC}"
echo

echo -e "${GREEN}Setup finalizado! 🚀${NC}" 