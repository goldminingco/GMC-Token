#!/bin/bash
# ============================================================================
# 🚀 PREPARAÇÃO DO REPOSITÓRIO PARA O PÚBLICO - GMC TOKEN
# ============================================================================
# Este script remove todos os arquivos sensíveis e desnecessários para 
# garantir que o repositório esteja limpo e seguro para ser público.
# ============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}🚀 Iniciando a preparação do repositório GMC Token...${NC}"
echo -e "${YELLOW}=======================================================${NC}"

# --- FUNÇÃO DE REMOÇÃO SEGURA ---
remove_item() {
    local item=$1
    local item_type=$2
    if [ -e "$item" ]; then
        echo -e "   🗑️ Removendo ${item_type}: ${item}"
        rm -rf "$item"
        echo -e "   ${GREEN}✅ Removido com sucesso.${NC}"
    else
        echo -e "   👍 ${item_type} não encontrado: ${item}"
    fi
}

# --- FASE 1: REMOVER DIRETÓRIOS SENSÍVEIS E DESNECESSÁRIOS ---
echo -e "\n${YELLOW}--- FASE 1: Removendo diretórios sensíveis... ---${NC}"
remove_item "_archive" "Diretório de arquivo morto"
remove_item "backups" "Diretório de backups"
remove_item "reports" "Diretório de relatórios"
remove_item "config" "Diretório de configuração"
remove_item "cleanup_backup_20250725_145155" "Diretório de backup de limpeza"
# A linha abaixo foi comentada para não remover o diretório Docs localmente
# remove_item "Docs" "Diretório de documentação"

# --- FASE 2: REMOVER ARQUIVOS DE CARTEIRA COM CHAVES PRIVADAS ---
echo -e "\n${YELLOW}--- FASE 2: Removendo arquivos de carteira... ---${NC}"
remove_item "wallets/test-wallet-1753882096092.json" "Carteira de teste"
# Deixar os diretórios, mas remover os arquivos .json de chaves
find wallets/mainnet -name "*.json" -print0 | while IFS= read -r -d '' file; do
    remove_item "$file" "Arquivo de chave privada"
done

# --- FASE 3: REMOVER SCRIPTS DE ANÁLISE INTERNA ---
echo -e "\n${YELLOW}--- FASE 3: Removendo scripts de análise... ---${NC}"
remove_item "scripts/analyze_distribution_flow.js" "Script de análise"
remove_item "scripts/check_address_type.js" "Script de análise"
remove_item "scripts/check_balances.js" "Script de análise"
remove_item "scripts/check_current_distribution.js" "Script de análise"
remove_item "scripts/check_metadata.js" "Script de análise"
remove_item "scripts/complete_audit.js" "Script de análise"
remove_item "scripts/distribute_sol_for_test.js" "Script de teste"
remove_item "scripts/find_consolidator_wallet.js" "Script de análise"
remove_item "scripts/get_token_account_owner.js" "Script de análise"
remove_item "scripts/get_tx_destination.js" "Script de análise"
remove_item "scripts/implement_metadata_native.js" "Script de metadados"
remove_item "scripts/implement_metaplex_metadata.js" "Script de metadados"
remove_item "scripts/implement_metaplex_metadata_simple.js" "Script de metadados"
remove_item "scripts/implement_token_metadata.js" "Script de metadados"
remove_item "scripts/restore_architecture.js" "Script de restauração"
remove_item "scripts/test_business_rules_comprehensive.js" "Script de teste"
remove_item "scripts/test_smart_contracts_comprehensive.js" "Script de teste"
remove_item "scripts/test_with_deployer_wallet.js" "Script de teste"
remove_item "scripts/test_with_real_tokens.js" "Script de teste"

# --- FASE 4: REMOVER ARQUIVOS DIVERSOS SENSÍVEIS ---
echo -e "\n${YELLOW}--- FASE 4: Removendo arquivos diversos... ---${NC}"
remove_item "gmc-metadata-official.json" "Arquivo de metadados gerado"
remove_item "gmc-metaplex-final.json" "Arquivo de metadados gerado"
remove_item "PROXIMOS_PASSOS_COMPLETOS.md" "Arquivo de planejamento"

# --- ALERTA FINAL ---
echo -e "\n${RED}=======================================================${NC}"
echo -e "${RED}🚨 ALERTA DE SEGURANÇA 🚨${NC}"
echo -e "${RED}Verifique se você removeu manualmente o arquivo:${NC}"
echo -e "${RED}>> BACKUP_SEGURANCA_MAINNET_COMPLETO.md <<${NC}"
echo -e "${RED}Este arquivo contém chaves privadas e NÃO DEVE ser commitado!${NC}"
echo -e "${RED}=======================================================${NC}"

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN}✅ Limpeza concluída! O repositório está pronto.${NC}"
echo -e "${GREEN}=======================================================${NC}" 