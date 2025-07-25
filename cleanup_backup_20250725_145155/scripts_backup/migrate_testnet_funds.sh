#!/bin/bash
# 💰 GMC Token - Migração de Fundos Testnet
# Recupera carteiras antigas e migra fundos para carteiras novas virgens

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verificar se as seed phrases foram fornecidas
if [ $# -ne 3 ]; then
    echo -e "${RED}❌ Uso incorreto!${NC}"
    echo -e "${YELLOW}Uso: $0 \"<deployer_seed>\" \"<treasury_seed>\" \"<admin_seed>\"${NC}"
    echo
    echo -e "${CYAN}Exemplo:${NC}"
    echo -e "$0 \"palavra1 palavra2 ... palavra12\" \"palavra1 palavra2 ... palavra12\" \"palavra1 palavra2 ... palavra12\""
    exit 1
fi

DEPLOYER_SEED="$1"
TREASURY_SEED="$2"
ADMIN_SEED="$3"

# Diretórios
KEYS_DIR=".testnet-keys"
OLD_KEYS_DIR="$KEYS_DIR/old"
NEW_KEYS_DIR="$KEYS_DIR/new"

echo -e "${BLUE}💰 GMC Token - Migração de Fundos Testnet${NC}"
echo "=========================================="
echo

# 1. Configurar ambiente
echo -e "${YELLOW}1. Configurando ambiente testnet...${NC}"
solana config set --url testnet
mkdir -p "$OLD_KEYS_DIR" "$NEW_KEYS_DIR"
echo -e "${GREEN}✅ Ambiente configurado${NC}"

# 2. Recuperar carteiras antigas usando as seeds fornecidas
echo -e "${YELLOW}2. Recuperando carteiras antigas...${NC}"

recover_wallet() {
    local seed_phrase="$1"
    local output_file="$2"
    local name="$3"
    
    echo -e "${CYAN}Recuperando $name...${NC}"
    
    # Usar printf para enviar automaticamente as respostas
    # Seed phrase + Enter (sem passphrase) + y (confirmar)
    printf "%s\n\ny\n" "$seed_phrase" | solana-keygen recover -o "$output_file" --force >/dev/null 2>&1
    
    if [ -f "$output_file" ]; then
        local address=$(solana-keygen pubkey "$output_file")
        echo -e "${GREEN}✅ $name: $address${NC}"
        echo "$address"
    else
        echo -e "${RED}❌ Falha ao recuperar $name${NC}"
        exit 1
    fi
}

# Recuperar as 3 carteiras antigas
OLD_DEPLOYER_ADDR=$(recover_wallet "$DEPLOYER_SEED" "$OLD_KEYS_DIR/deployer_old.json" "Deployer")
OLD_TREASURY_ADDR=$(recover_wallet "$TREASURY_SEED" "$OLD_KEYS_DIR/treasury_old.json" "Treasury") 
OLD_ADMIN_ADDR=$(recover_wallet "$ADMIN_SEED" "$OLD_KEYS_DIR/admin_old.json" "Admin")

echo

# 3. Verificar saldos das carteiras antigas
echo -e "${YELLOW}3. Verificando saldos existentes...${NC}"

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

OLD_DEPLOYER_BALANCE=$(check_balance "$OLD_KEYS_DIR/deployer_old.json" "Deployer Old")
OLD_TREASURY_BALANCE=$(check_balance "$OLD_KEYS_DIR/treasury_old.json" "Treasury Old")
OLD_ADMIN_BALANCE=$(check_balance "$OLD_KEYS_DIR/admin_old.json" "Admin Old")

# Calcular total disponível
TOTAL_OLD_BALANCE=$(echo "$OLD_DEPLOYER_BALANCE + $OLD_TREASURY_BALANCE + $OLD_ADMIN_BALANCE" | bc)
TOTAL_OLD_SOL=$(echo "scale=4; $TOTAL_OLD_BALANCE / 1000000000" | bc -l)

echo -e "${CYAN}💰 Total disponível: ${GREEN}$TOTAL_OLD_SOL SOL${NC} ($TOTAL_OLD_BALANCE lamports)"
echo

# Verificar se há saldo suficiente
if [ "$TOTAL_OLD_BALANCE" -lt 500000000 ]; then  # < 0.5 SOL
    echo -e "${RED}❌ Saldo insuficiente para migração (mínimo: 0.5 SOL)${NC}"
    exit 1
fi

# 4. Gerar carteiras novas virgens
echo -e "${YELLOW}4. Gerando carteiras novas virgens...${NC}"

generate_new_wallet() {
    local name=$1
    local file_path=$2
    
    echo -e "${CYAN}Gerando carteira $name...${NC}"
    solana-keygen new -o "$file_path" --no-bip39-passphrase --silent
    local address=$(solana-keygen pubkey "$file_path")
    
    echo -e "${GREEN}✅ $name criada: $address${NC}"
    echo -e "   File: $file_path"
    echo
    
    echo "$address"
}

# Gerar novas carteiras
NEW_DEPLOYER_ADDR=$(generate_new_wallet "Deployer Novo" "$NEW_KEYS_DIR/deployer.json")
NEW_TREASURY_ADDR=$(generate_new_wallet "Treasury Novo" "$NEW_KEYS_DIR/treasury.json")
NEW_ADMIN_ADDR=$(generate_new_wallet "Admin Novo" "$NEW_KEYS_DIR/admin.json")
NEW_USER1_ADDR=$(generate_new_wallet "User1 (Testes)" "$NEW_KEYS_DIR/user1.json")
NEW_USER2_ADDR=$(generate_new_wallet "User2 (Testes)" "$NEW_KEYS_DIR/user2.json")

# 5. Calcular distribuição
echo -e "${YELLOW}5. Calculando distribuição...${NC}"

# Reservar 0.5 SOL para taxas de transação
TRANSACTION_FEES=500000000  # 0.5 SOL
DISTRIBUTABLE_BALANCE=$(echo "$TOTAL_OLD_BALANCE - $TRANSACTION_FEES" | bc)
DISTRIBUTABLE_SOL=$(echo "scale=4; $DISTRIBUTABLE_BALANCE / 1000000000" | bc -l)

# Distribuição proposta:
# - Deployer: 50% (para deploy e operações críticas)
# - Treasury: 20% (operações treasury)
# - Admin: 15% (operações admin)  
# - User1: 10% (testes principais)
# - User2: 5% (testes secundários)

NEW_DEPLOYER_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 50 / 100" | bc)
NEW_TREASURY_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 20 / 100" | bc)
NEW_ADMIN_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 15 / 100" | bc)
NEW_USER1_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 10 / 100" | bc)
NEW_USER2_AMOUNT=$(echo "$DISTRIBUTABLE_BALANCE * 5 / 100" | bc)

echo -e "${CYAN}📊 Distribuição planejada (total: $DISTRIBUTABLE_SOL SOL):${NC}"
echo -e "   Deployer (50%): $(echo "scale=4; $NEW_DEPLOYER_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   Treasury (20%): $(echo "scale=4; $NEW_TREASURY_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   Admin (15%):    $(echo "scale=4; $NEW_ADMIN_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   User1 (10%):    $(echo "scale=4; $NEW_USER1_AMOUNT / 1000000000" | bc -l) SOL"
echo -e "   User2 (5%):     $(echo "scale=4; $NEW_USER2_AMOUNT / 1000000000" | bc -l) SOL"
echo

# 6. Confirmar migração
echo -e "${YELLOW}6. Confirmação de migração...${NC}"
echo -e "${RED}⚠️  Esta operação irá transferir TODOS os saldos!${NC}"
echo -e "${CYAN}De (antigas):${NC}"
echo -e "   $OLD_DEPLOYER_ADDR: $(echo "scale=4; $OLD_DEPLOYER_BALANCE / 1000000000" | bc -l) SOL"
echo -e "   $OLD_TREASURY_ADDR: $(echo "scale=4; $OLD_TREASURY_BALANCE / 1000000000" | bc -l) SOL"
echo -e "   $OLD_ADMIN_ADDR: $(echo "scale=4; $OLD_ADMIN_BALANCE / 1000000000" | bc -l) SOL"
echo
echo -e "${CYAN}Para (novas):${NC}"
echo -e "   Deployer: $NEW_DEPLOYER_ADDR"
echo -e "   Treasury: $NEW_TREASURY_ADDR"
echo -e "   Admin:    $NEW_ADMIN_ADDR"
echo -e "   User1:    $NEW_USER1_ADDR"
echo -e "   User2:    $NEW_USER2_ADDR"
echo

read -p "Confirma a migração? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Operação cancelada pelo usuário${NC}"
    exit 0
fi

# 7. Executar transferências
echo -e "${YELLOW}7. Executando migração...${NC}"

transfer_sol() {
    local from_keypair=$1
    local to_address=$2
    local amount_lamports=$3
    local description=$4
    
    if [ "$amount_lamports" -le 0 ]; then
        echo -e "${YELLOW}⚠️ Valor zero para $description, pulando...${NC}"
        return 0
    fi
    
    local amount_sol=$(echo "scale=4; $amount_lamports / 1000000000" | bc -l)
    echo -e "${CYAN}Transferindo $amount_sol SOL para $description...${NC}"
    
    if solana transfer --from "$from_keypair" "$to_address" "$amount_lamports" --allow-unfunded-recipient --lamports; then
        echo -e "${GREEN}✅ Transferido: $amount_sol SOL${NC}"
        return 0
    else
        echo -e "${RED}❌ Falha na transferência para $description${NC}"
        return 1
    fi
}

# Fase 1: Consolidar tudo no novo deployer
echo -e "${CYAN}Fase 1: Consolidando fundos...${NC}"

# Transferir quase tudo das carteiras antigas para o novo deployer
if [ "$OLD_DEPLOYER_BALANCE" -gt 50000000 ]; then  # Se > 0.05 SOL
    TRANSFER_AMOUNT=$(echo "$OLD_DEPLOYER_BALANCE - 50000000" | bc)  # Deixar 0.05 SOL para fee
    transfer_sol "$OLD_KEYS_DIR/deployer_old.json" "$NEW_DEPLOYER_ADDR" "$TRANSFER_AMOUNT" "Novo Deployer (de old deployer)"
fi

if [ "$OLD_TREASURY_BALANCE" -gt 50000000 ]; then
    TRANSFER_AMOUNT=$(echo "$OLD_TREASURY_BALANCE - 50000000" | bc)
    transfer_sol "$OLD_KEYS_DIR/treasury_old.json" "$NEW_DEPLOYER_ADDR" "$TRANSFER_AMOUNT" "Novo Deployer (de old treasury)"
fi

if [ "$OLD_ADMIN_BALANCE" -gt 50000000 ]; then
    TRANSFER_AMOUNT=$(echo "$OLD_ADMIN_BALANCE - 50000000" | bc)
    transfer_sol "$OLD_KEYS_DIR/admin_old.json" "$NEW_DEPLOYER_ADDR" "$TRANSFER_AMOUNT" "Novo Deployer (de old admin)"
fi

echo

# Fase 2: Redistribuir do novo deployer para as outras carteiras
echo -e "${CYAN}Fase 2: Redistribuindo fundos...${NC}"
solana config set --keypair "$NEW_KEYS_DIR/deployer.json"

transfer_sol "$NEW_KEYS_DIR/deployer.json" "$NEW_TREASURY_ADDR" "$NEW_TREASURY_AMOUNT" "Novo Treasury"
transfer_sol "$NEW_KEYS_DIR/deployer.json" "$NEW_ADMIN_ADDR" "$NEW_ADMIN_AMOUNT" "Novo Admin"
transfer_sol "$NEW_KEYS_DIR/deployer.json" "$NEW_USER1_ADDR" "$NEW_USER1_AMOUNT" "User1"
transfer_sol "$NEW_KEYS_DIR/deployer.json" "$NEW_USER2_ADDR" "$NEW_USER2_AMOUNT" "User2"

echo

# 8. Verificar saldos finais
echo -e "${YELLOW}8. Verificando saldos finais...${NC}"

echo -e "${CYAN}💰 Saldos finais das carteiras novas:${NC}"
check_balance "$NEW_KEYS_DIR/deployer.json" "Deployer Novo" > /dev/null
check_balance "$NEW_KEYS_DIR/treasury.json" "Treasury Novo" > /dev/null
check_balance "$NEW_KEYS_DIR/admin.json" "Admin Novo" > /dev/null
check_balance "$NEW_KEYS_DIR/user1.json" "User1" > /dev/null
check_balance "$NEW_KEYS_DIR/user2.json" "User2" > /dev/null

# 9. Gerar relatório completo
echo -e "${YELLOW}9. Gerando relatório...${NC}"

REPORT_FILE="$KEYS_DIR/migration_report_$(date +%Y%m%d_%H%M%S).json"
cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "testnet",
  "operation": "fund_migration",
  "old_wallets": {
    "deployer": {
      "address": "$OLD_DEPLOYER_ADDR",
      "initial_balance_lamports": $OLD_DEPLOYER_BALANCE
    },
    "treasury": {
      "address": "$OLD_TREASURY_ADDR",
      "initial_balance_lamports": $OLD_TREASURY_BALANCE
    },
    "admin": {
      "address": "$OLD_ADMIN_ADDR",
      "initial_balance_lamports": $OLD_ADMIN_BALANCE
    }
  },
  "new_wallets": {
    "deployer": {
      "address": "$NEW_DEPLOYER_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/deployer.json",
      "allocated_lamports": $NEW_DEPLOYER_AMOUNT
    },
    "treasury": {
      "address": "$NEW_TREASURY_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/treasury.json",
      "allocated_lamports": $NEW_TREASURY_AMOUNT
    },
    "admin": {
      "address": "$NEW_ADMIN_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/admin.json",
      "allocated_lamports": $NEW_ADMIN_AMOUNT
    },
    "user1": {
      "address": "$NEW_USER1_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/user1.json",
      "allocated_lamports": $NEW_USER1_AMOUNT
    },
    "user2": {
      "address": "$NEW_USER2_ADDR",
      "keypair_file": "$NEW_KEYS_DIR/user2.json",
      "allocated_lamports": $NEW_USER2_AMOUNT
    }
  },
  "total_migrated_lamports": $DISTRIBUTABLE_BALANCE,
  "total_migrated_sol": "$DISTRIBUTABLE_SOL"
}
EOF

echo -e "${GREEN}✅ Relatório salvo em: $REPORT_FILE${NC}"

# 10. Configurar deployer como padrão
solana config set --keypair "$NEW_KEYS_DIR/deployer.json"

# 11. Salvar seed phrases das novas carteiras (para backup)
echo -e "${YELLOW}10. Salvando informações de backup...${NC}"

BACKUP_FILE="$KEYS_DIR/new_wallets_info_$(date +%Y%m%d_%H%M%S).txt"
cat > "$BACKUP_FILE" << EOF
=== GMC Token - Novas Carteiras Testnet ===
Data: $(date)

DEPLOYER:
Address: $NEW_DEPLOYER_ADDR
File: $NEW_KEYS_DIR/deployer.json

TREASURY:
Address: $NEW_TREASURY_ADDR
File: $NEW_KEYS_DIR/treasury.json

ADMIN:
Address: $NEW_ADMIN_ADDR
File: $NEW_KEYS_DIR/admin.json

USER1:
Address: $NEW_USER1_ADDR
File: $NEW_KEYS_DIR/user1.json

USER2:
Address: $NEW_USER2_ADDR
File: $NEW_KEYS_DIR/user2.json

IMPORTANTE: Guarde este arquivo em local seguro!
EOF

echo -e "${GREEN}✅ Backup salvo em: $BACKUP_FILE${NC}"

echo
echo -e "${GREEN}🎉 MIGRAÇÃO CONCLUÍDA COM SUCESSO! 🎉${NC}"
echo "=============================================="
echo -e "${BLUE}📋 Novas carteiras configuradas:${NC}"
echo -e "${BLUE}   • Deployer: ${GREEN}$NEW_DEPLOYER_ADDR${NC}"
echo -e "${BLUE}   • Treasury: ${GREEN}$NEW_TREASURY_ADDR${NC}"
echo -e "${BLUE}   • Admin:    ${GREEN}$NEW_ADMIN_ADDR${NC}"
echo -e "${BLUE}   • User1:    ${GREEN}$NEW_USER1_ADDR${NC}"
echo -e "${BLUE}   • User2:    ${GREEN}$NEW_USER2_ADDR${NC}"
echo
echo -e "${BLUE}💰 Total migrado: ${GREEN}$DISTRIBUTABLE_SOL SOL${NC}"
echo -e "${BLUE}🎯 Carteira ativa: ${GREEN}$NEW_DEPLOYER_ADDR${NC}"
echo
echo -e "${YELLOW}🔍 Próximos passos:${NC}"
echo -e "${BLUE}   1. Execute: ./scripts/deploy_testnet.sh${NC}"
echo -e "${BLUE}   2. Verificar deploy no explorer${NC}"
echo -e "${BLUE}   3. Testar funcionalidades com User1/User2${NC}"
echo -e "${BLUE}   4. Guardar $BACKUP_FILE em local seguro${NC}"
echo

echo -e "${GREEN}Migração finalizada! 🚀${NC}" 