#!/bin/bash
# 🏦 GMC Token - Distribuição de Saldos Testnet
# Transfer saldos de carteiras existentes para nova organização

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
OLD_KEYS_DIR="$KEYS_DIR/old"
NEW_KEYS_DIR="$KEYS_DIR/new"

echo -e "${BLUE}🏦 GMC Token - Distribuição de Saldos Testnet${NC}"
echo "=============================================="
echo

# 1. Configurar ambiente testnet
echo -e "${YELLOW}1. Configurando ambiente testnet...${NC}"
solana config set --url testnet
echo -e "${GREEN}✅ Conectado à testnet${NC}"

# 2. Criar estrutura de diretórios
echo -e "${YELLOW}2. Preparando estrutura de carteiras...${NC}"
mkdir -p "$OLD_KEYS_DIR" "$NEW_KEYS_DIR"

# 3. Restaurar carteiras existentes com saldo
echo -e "${YELLOW}3. Restaurando carteiras existentes...${NC}"

# Carteira Deployer Original
echo -e "${CYAN}Restaurando Deployer (1CfuyFT7yxu73uwYWyetjvPEhfqJX8QVEgxH2KvjR4L)...${NC}"
solana-keygen recover -o "$OLD_KEYS_DIR/deployer_old.json" --force <<EOF
high tribe initial auto tired hundred evil verify hover whale ozone initial
EOF

# Carteira Treasury Original  
echo -e "${CYAN}Restaurando Treasury (E3aRtiDuSE976Kgw4e9iakNWrXbz8HWd9hNHmiVAPZ6r)...${NC}"
solana-keygen recover -o "$OLD_KEYS_DIR/treasury_old.json" --force <<EOF
scissors strike flame chair material pencil swing praise polar remember have carpet
EOF

# Carteira Admin Original
echo -e "${CYAN}Restaurando Admin (2SQcM81LF4FkWCJ3ComCVuiuNxqSENT9R7PJZ7iBdjQR)...${NC}"
solana-keygen recover -o "$OLD_KEYS_DIR/admin_old.json" --force <<EOF
because cushion stand museum poem pig remind transfer scrap word style faint
EOF

echo -e "${GREEN}✅ Carteiras antigas restauradas${NC}"

# 4. Verificar saldos das carteiras antigas
echo -e "${YELLOW}4. Verificando saldos existentes...${NC}"

check_balance() {
    local keypair_file=$1
    local name=$2
    local address=$(solana-keygen pubkey "$keypair_file")
    local balance=$(solana balance "$keypair_file" --lamports 2>/dev/null || echo "0")
    local balance_sol=$(echo "scale=4; $balance / 1000000000" | bc -l 2>/dev/null || echo "0")
    
    echo -e "${BLUE}$name:${NC}"
    echo -e "  Address: ${GREEN}$address${NC}"
    echo -e "  Balance: ${GREEN}$balance_sol SOL${NC} ($balance lamports)"
    echo
    
    echo "$balance"
}

DEPLOYER_BALANCE=$(check_balance "$OLD_KEYS_DIR/deployer_old.json" "Deployer Old")
TREASURY_BALANCE=$(check_balance "$OLD_KEYS_DIR/treasury_old.json" "Treasury Old")
ADMIN_BALANCE=$(check_balance "$OLD_KEYS_DIR/admin_old.json" "Admin Old")

# Calcular total
TOTAL_BALANCE=$(echo "$DEPLOYER_BALANCE + $TREASURY_BALANCE + $ADMIN_BALANCE" | bc)
TOTAL_SOL=$(echo "scale=4; $TOTAL_BALANCE / 1000000000" | bc -l)

echo -e "${CYAN}💰 Total disponível: ${GREEN}$TOTAL_SOL SOL${NC} ($TOTAL_BALANCE lamports)"
echo

# 5. Gerar novas carteiras organizadas
echo -e "${YELLOW}5. Gerando novas carteiras organizadas...${NC}"

generate_new_wallet() {
    local name=$1
    local file_path=$2
    
    echo -e "${CYAN}Gerando carteira $name...${NC}"
    solana-keygen new -o "$file_path" --no-bip39-passphrase --silent
    local address=$(solana-keygen pubkey "$file_path")
    local seed=$(solana-keygen pubkey "$file_path" --with-seed 2>/dev/null || echo "N/A")
    
    echo -e "${GREEN}✅ $name criada:${NC}"
    echo -e "   Address: $address"
    echo -e "   File: $file_path"
    echo
    
    echo "$address"
}

# Gerar novas carteiras
NEW_DEPLOYER_ADDR=$(generate_new_wallet "Deployer" "$NEW_KEYS_DIR/deployer.json")
NEW_TREASURY_ADDR=$(generate_new_wallet "Treasury" "$NEW_KEYS_DIR/treasury.json")
NEW_ADMIN_ADDR=$(generate_new_wallet "Admin" "$NEW_KEYS_DIR/admin.json")
NEW_USER1_ADDR=$(generate_new_wallet "User1 (Testing)" "$NEW_KEYS_DIR/user1.json")
NEW_USER2_ADDR=$(generate_new_wallet "User2 (Testing)" "$NEW_KEYS_DIR/user2.json")

# 6. Calcular distribuição
echo -e "${YELLOW}6. Calculando distribuição de saldos...${NC}"

# Reservar para taxas de transação (0.1 SOL por carteira antiga)
TRANSACTION_FEES=300000000  # 0.3 SOL total para fees
DISTRIBUTABLE_BALANCE=$(echo "$TOTAL_BALANCE - $TRANSACTION_FEES" | bc)
DISTRIBUTABLE_SOL=$(echo "scale=4; $DISTRIBUTABLE_BALANCE / 1000000000" | bc -l)

# Distribuição proposta:
# - Deployer: 40% (para deploy e upgrades)
# - Treasury: 30% (para operações treasury)  
# - Admin: 15% (para operações admin)
# - User1: 8% (para testes)
# - User2: 7% (para testes)

DEPLOYER_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 40 / 100" | bc)
TREASURY_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 30 / 100" | bc)
ADMIN_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 15 / 100" | bc)
USER1_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 8 / 100" | bc)
USER2_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 7 / 100" | bc)

echo -e "${CYAN}📊 Distribuição planejada:${NC}"
echo -e "   Deployer (40%): $(echo "scale=4; $DEPLOYER_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   Treasury (30%): $(echo "scale=4; $TREASURY_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   Admin (15%):    $(echo "scale=4; $ADMIN_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   User1 (8%):     $(echo "scale=4; $USER1_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   User2 (7%):     $(echo "scale=4; $USER2_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   Total dist.:    $DISTRIBUTABLE_SOL SOL"
echo

# 7. Confirmar antes de transferir
echo -e "${YELLOW}7. Confirmação de transferência...${NC}"
echo -e "${RED}⚠️  Esta operação irá transferir todos os saldos!${NC}"
echo -e "${CYAN}Carteiras origem:${NC}"
echo -e "   Deployer Old: $DEPLOYER_BALANCE lamports"
echo -e "   Treasury Old: $TREASURY_BALANCE lamports" 
echo -e "   Admin Old:    $ADMIN_BALANCE lamports"
echo
echo -e "${CYAN}Carteiras destino:${NC}"
echo -e "   Deployer: $NEW_DEPLOYER_ADDR"
echo -e "   Treasury: $NEW_TREASURY_ADDR"
echo -e "   Admin:    $NEW_ADMIN_ADDR"
echo -e "   User1:    $NEW_USER1_ADDR"
echo -e "   User2:    $NEW_USER2_ADDR"
echo

read -p "Confirma a transferência? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Operação cancelada pelo usuário${NC}"
    exit 0
fi

# 8. Executar transferências
echo -e "${YELLOW}8. Executando transferências...${NC}"

transfer_from_wallet() {
    local from_keypair=$1
    local to_address=$2
    local amount=$3
    local description=$4
    
    echo -e "${CYAN}Transferindo para $description...${NC}"
    
    if [ "$amount" -gt 0 ]; then
        if solana transfer --from "$from_keypair" "$to_address" "$amount" --allow-unfunded-recipient --lamports; then
            local amount_sol=$(echo "scale=4; $amount / 1000000000" | bc -l)
            echo -e "${GREEN}✅ Transferido: $amount_sol SOL${NC}"
        else
            echo -e "${RED}❌ Falha na transferência para $description${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️ Valor zero, pulando transferência${NC}"
    fi
    echo
}

# Transferir de cada carteira antiga
if [ "$DEPLOYER_BALANCE" -gt 100000000 ]; then # Se > 0.1 SOL
    DEPLOYER_TRANSFER=$(echo "$DEPLOYER_BALANCE - 100000000" | bc) # Deixar 0.1 SOL para fees
    transfer_from_wallet "$OLD_KEYS_DIR/deployer_old.json" "$NEW_DEPLOYER_ADDR" "$DEPLOYER_TRANSFER" "Deployer"
fi

if [ "$TREASURY_BALANCE" -gt 100000000 ]; then
    TREASURY_TRANSFER=$(echo "$TREASURY_BALANCE - 100000000" | bc)
    transfer_from_wallet "$OLD_KEYS_DIR/treasury_old.json" "$NEW_TREASURY_ADDR" "$TREASURY_TRANSFER" "Treasury"
fi

if [ "$ADMIN_BALANCE" -gt 100000000 ]; then
    ADMIN_TRANSFER=$(echo "$ADMIN_BALANCE - 100000000" | bc)
    transfer_from_wallet "$OLD_KEYS_DIR/admin_old.json" "$NEW_USER1_ADDR" "$ADMIN_TRANSFER" "User1"
fi

# 9. Redistribuir do deployer para outras carteiras
echo -e "${YELLOW}9. Redistribuindo saldos...${NC}"
solana config set --keypair "$NEW_KEYS_DIR/deployer.json"

if [ "$TREASURY_AMOUNT" -gt 0 ]; then
    transfer_from_wallet "$NEW_KEYS_DIR/deployer.json" "$NEW_TREASURY_ADDR" "$TREASURY_AMOUNT" "Treasury (redistribuição)"
fi

if [ "$ADMIN_AMOUNT" -gt 0 ]; then
    transfer_from_wallet "$NEW_KEYS_DIR/deployer.json" "$NEW_ADMIN_ADDR" "$ADMIN_AMOUNT" "Admin (redistribuição)"
fi

if [ "$USER2_AMOUNT" -gt 0 ]; then
    transfer_from_wallet "$NEW_KEYS_DIR/deployer.json" "$NEW_USER2_ADDR" "$USER2_AMOUNT" "User2 (redistribuição)"
fi

# 10. Verificar saldos finais
echo -e "${YELLOW}10. Verificando saldos finais...${NC}"

echo -e "${CYAN}💰 Saldos finais das novas carteiras:${NC}"
check_balance "$NEW_KEYS_DIR/deployer.json" "Deployer" > /dev/null
check_balance "$NEW_KEYS_DIR/treasury.json" "Treasury" > /dev/null  
check_balance "$NEW_KEYS_DIR/admin.json" "Admin" > /dev/null
check_balance "$NEW_KEYS_DIR/user1.json" "User1" > /dev/null
check_balance "$NEW_KEYS_DIR/user2.json" "User2" > /dev/null

# 11. Gerar relatório de distribuição
echo -e "${YELLOW}11. Gerando relatório...${NC}"

REPORT_FILE="$KEYS_DIR/distribution_report_$(date +%Y%m%d_%H%M%S).json"
cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "testnet",
  "operation": "balance_distribution",
  "old_wallets": {
    "deployer": {
      "address": "1CfuyFT7yxu73uwYWyetjvPEhfqJX8QVEgxH2KvjR4L",
      "balance_lamports": $DEPLOYER_BALANCE
    },
    "treasury": {
      "address": "E3aRtiDuSE976Kgw4e9iakNWrXbz8HWd9hNHmiVAPZ6r",
      "balance_lamports": $TREASURY_BALANCE
    },
    "admin": {
      "address": "2SQcM81LF4FkWCJ3ComCVuiuNxqSENT9R7PJZ7iBdjQR",
      "balance_lamports": $ADMIN_BALANCE
    }
  },
  "new_wallets": {
    "deployer": {
      "address": "$NEW_DEPLOYER_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/deployer.json"
    },
    "treasury": {
      "address": "$NEW_TREASURY_ADDR", 
      "keypair_file": "$NEW_KEYS_DIR/treasury.json"
    },
    "admin": {
      "address": "$NEW_ADMIN_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/admin.json"
    },
    "user1": {
      "address": "$NEW_USER1_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/user1.json"
    },
    "user2": {
      "address": "$NEW_USER2_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/user2.json"
    }
  },
  "total_distributed_lamports": $DISTRIBUTABLE_BALANCE,
  "total_distributed_sol": "$DISTRIBUTABLE_SOL"
}
EOF

echo -e "${GREEN}✅ Relatório salvo em: $REPORT_FILE${NC}"

# 12. Configurar deployer como padrão
solana config set --keypair "$NEW_KEYS_DIR/deployer.json"

echo
echo -e "${GREEN}🎉 DISTRIBUIÇÃO CONCLUÍDA COM SUCESSO! 🎉${NC}"
echo "============================================="
echo -e "${BLUE}📋 Nova organização de carteiras:${NC}"
echo -e "${BLUE}   • Deployer: ${GREEN}$NEW_DEPLOYER_ADDR${NC}"
echo -e "${BLUE}   • Treasury: ${GREEN}$NEW_TREASURY_ADDR${NC}"
echo -e "${BLUE}   • Admin:    ${GREEN}$NEW_ADMIN_ADDR${NC}"
echo -e "${BLUE}   • User1:    ${GREEN}$NEW_USER1_ADDR${NC}"
echo -e "${BLUE}   • User2:    ${GREEN}$NEW_USER2_ADDR${NC}"
echo
echo -e "${YELLOW}🔍 Próximos passos:${NC}"
echo -e "${BLUE}   1. Execute: ./scripts/deploy_testnet.sh${NC}"
echo -e "${BLUE}   2. Teste as funcionalidades com User1/User2${NC}"
echo -e "${BLUE}   3. Configure frontend para testnet${NC}"
echo

echo -e "${GREEN}Distribuição finalizada! 🚀${NC}" 