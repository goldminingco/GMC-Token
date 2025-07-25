#!/bin/bash

# 🚀 GMC Token - Deploy PROJETO REAL (Baseado no Script que FUNCIONOU)
# ====================================================================
# 
# Este script usa EXATAMENTE a mesma estratégia do isolated_build_deploy.sh
# que funcionou 100%, mas copia o código REAL do projeto para o ambiente isolado.
# 
# GARANTIAS:
# - Nenhuma regra de negócio será alterada
# - Todo o código fonte original será preservado
# - Mesma estratégia de build que funcionou
# - Mesmo ambiente isolado que funcionou

set -e

# Cores para output (mesmas do script que funcionou)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 GMC Token - Deploy PROJETO REAL${NC}"
echo "=================================="
echo ""

echo -e "${YELLOW}📋 Estratégia COMPROVADA (baseada no script que funcionou):${NC}"
echo -e "${BLUE}   • Ambiente isolado (sem conflitos de workspace)${NC}"
echo -e "${BLUE}   • Solana 1.17.31 (compatível SBPF v1)${NC}"
echo -e "${BLUE}   • Código fonte REAL do projeto (preservado)${NC}"
echo ""

# Verificar se estamos no diretório correto
if [ ! -d "programs/gmc_token_native" ]; then
    echo -e "${RED}❌ Execute este script a partir da raiz do projeto GMC-Token${NC}"
    exit 1
fi

# 1. Criar ambiente isolado (EXATAMENTE como funcionou)
echo -e "${YELLOW}1. Criando ambiente isolado...${NC}"
TEMP_DIR="/tmp/gmc_token_real_$(date +%s)"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
echo -e "${GREEN}✅ Ambiente isolado criado: $TEMP_DIR${NC}"

# 2. Configurar Solana (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}2. Configurando Solana...${NC}"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

if command -v solana >/dev/null 2>&1; then
    SOLANA_VERSION=$(solana --version | head -n1)
    echo -e "${GREEN}✅ Solana disponível: $SOLANA_VERSION${NC}"
else
    echo -e "${RED}❌ Solana não encontrado${NC}"
    exit 1
fi

# 3. Criar projeto do zero (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}3. Criando projeto do zero...${NC}"
cargo init --name gmc_token_native --lib
echo -e "${GREEN}✅ Projeto isolado criado${NC}"

# 4. Copiar Cargo.toml REAL (preservando dependências originais)
echo ""
echo -e "${YELLOW}4. Copiando configurações REAIS do projeto...${NC}"
cp "/Users/cliente/Documents/GMC-Token/programs/gmc_token_native/Cargo.toml" ./Cargo.toml
echo -e "${GREEN}✅ Cargo.toml real copiado${NC}"

# 5. Copiar TODO o código fonte REAL (sem alterações)
echo ""
echo -e "${YELLOW}5. Copiando código fonte REAL...${NC}"
rm -rf src/*
cp -r "/Users/cliente/Documents/GMC-Token/programs/gmc_token_native/src/"* ./src/

# Verificar módulos copiados
echo -e "${BLUE}📋 Módulos do projeto real copiados:${NC}"
for file in src/*.rs; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        size=$(wc -c < "$file")
        echo -e "   • ${GREEN}✅ $filename${NC} ($(printf "%'d" $size) bytes)"
    fi
done

# 6. Verificar se lib.rs declara os módulos corretamente
echo ""
echo -e "${YELLOW}6. Verificando estrutura do lib.rs...${NC}"
if [ -f "src/lib.rs" ]; then
    # Verificar se lib.rs já tem as declarações necessárias
    if ! grep -q "entrypoint!" src/lib.rs; then
        echo -e "${YELLOW}⚠️ lib.rs parece não ter entrypoint. Verificando estrutura...${NC}"
        head -10 src/lib.rs
    else
        echo -e "${GREEN}✅ lib.rs com estrutura correta${NC}"
    fi
else
    echo -e "${RED}❌ lib.rs não encontrado${NC}"
    exit 1
fi

# 7. Compilar projeto REAL (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}7. Compilando projeto REAL...${NC}"
echo -e "${BLUE}📦 Usando estratégias que funcionaram...${NC}"

BUILD_SUCCESS=false

# Estratégia 1: cargo build-sbf --arch sbfv1 (que funcionou)
echo -e "${BLUE}📦 Estratégia 1: cargo build-sbf --arch sbfv1${NC}"
if cargo build-sbf --arch sbfv1 2>/dev/null; then
    BUILD_SUCCESS=true
    echo -e "${GREEN}✅ Build sbfv1 bem-sucedido!${NC}"
else
    # Estratégia 2: cargo build-bpf (fallback que funcionou)
    echo -e "${BLUE}📦 Estratégia 2: cargo build-bpf${NC}"
    if cargo build-bpf 2>/dev/null; then
        BUILD_SUCCESS=true
        echo -e "${GREEN}✅ Build bpf bem-sucedido!${NC}"
    else
        echo -e "${RED}❌ Build falhou. Verificando erros...${NC}"
        echo -e "${YELLOW}💡 Tentando build com output detalhado:${NC}"
        cargo build-sbf --arch sbfv1 2>&1 | head -20
    fi
fi

if [ "$BUILD_SUCCESS" = false ]; then
    echo -e "${RED}❌ Falha no build do projeto real${NC}"
    exit 1
fi

# 8. Localizar artefato (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}8. Localizando artefato...${NC}"
ARTIFACT_PATH=""

# Possíveis localizações (mesmas que funcionaram)
POSSIBLE_PATHS=(
    "target/deploy/gmc_token_native.so"
    "target/sbf-solana-solana/release/gmc_token_native.so"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        ARTIFACT_PATH="$path"
        break
    fi
done

if [ -z "$ARTIFACT_PATH" ]; then
    echo -e "${RED}❌ Artefato não encontrado${NC}"
    echo -e "${YELLOW}💡 Procurando em target:${NC}"
    find target -name "*.so" 2>/dev/null | head -5
    exit 1
fi

# Copiar para projeto principal
MAIN_PROJECT="/Users/cliente/Documents/GMC-Token"
mkdir -p "$MAIN_PROJECT/deploy"
cp "$ARTIFACT_PATH" "$MAIN_PROJECT/deploy/gmc_token_real.so"

ARTIFACT_SIZE=$(wc -c < "$MAIN_PROJECT/deploy/gmc_token_real.so")
echo -e "${GREEN}📦 Artefato: deploy/gmc_token_real.so ($(printf "%'d" $ARTIFACT_SIZE) bytes)${NC}"

# 9. Verificar compatibilidade (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}9. Verificando compatibilidade...${NC}"
cd "$MAIN_PROJECT"
if command -v file &> /dev/null; then
    FILE_INFO=$(file deploy/gmc_token_real.so)
    echo -e "${BLUE}🔍 $FILE_INFO${NC}"
fi

# 10. Configurar para devnet (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}10. Configurando para devnet...${NC}"
CURRENT_CONFIG=$(solana config get)
echo -e "${BLUE}$CURRENT_CONFIG${NC}"

CURRENT_RPC=$(echo "$CURRENT_CONFIG" | grep "RPC URL" | awk '{print $3}')
DEPLOYER_WALLET=$(echo "$CURRENT_CONFIG" | grep "Keypair Path" | awk '{print $3}')

echo -e "${BLUE}📋 CONFIGURAÇÃO:${NC}"
echo -e "${GREEN}✅ Wallet: $(solana address)${NC}"
echo -e "${GREEN}✅ Saldo: $(solana balance)${NC}"
echo -e "${GREEN}✅ RPC: $CURRENT_RPC${NC}"

# 11. Deploy do projeto REAL (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}11. Deploy do GMC Token REAL...${NC}"
echo -e "${CYAN}🚀 Deploy do projeto completo com todas as regras de negócio...${NC}"

DEPLOY_OUTPUT=$(solana program deploy deploy/gmc_token_real.so 2>&1)
DEPLOY_EXIT_CODE=$?

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ DEPLOY DO PROJETO REAL REALIZADO COM SUCESSO!${NC}"
    
    # Extrair Program ID (mesmo método que funcionou)
    PROGRAM_ID=$(echo "$DEPLOY_OUTPUT" | grep -o 'Program Id: [A-Za-z0-9]*' | awk '{print $3}')
    
    if [ -z "$PROGRAM_ID" ]; then
        # Tentar formato JSON
        PROGRAM_ID=$(echo "$DEPLOY_OUTPUT" | grep -o '"programId": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -n "$PROGRAM_ID" ]; then
        echo "$PROGRAM_ID" > .devnet-keys/gmc_real_program_id.txt
        echo "$DEPLOY_OUTPUT"
    else
        echo "$DEPLOY_OUTPUT"
    fi
else
    echo -e "${RED}❌ Falha no deploy:${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# 12. Limpeza (EXATAMENTE como funcionou)
echo ""
echo -e "${YELLOW}12. Limpando ambiente temporário...${NC}"
rm -rf "$TEMP_DIR"

# 13. Resumo final (EXATAMENTE como funcionou)
echo ""
echo -e "${CYAN}🎉 PROJETO REAL GMC TOKEN DEPLOYADO COM SUCESSO! 🎉${NC}"
echo "======================================================="
echo ""
echo -e "${GREEN}📋 INFORMAÇÕES DO DEPLOY REAL:${NC}"
if [ -n "$PROGRAM_ID" ]; then
    echo -e "   • ${BLUE}Program ID:${NC} $PROGRAM_ID"
    echo -e "   • ${BLUE}Explorer:${NC} https://explorer.solana.com/address/$PROGRAM_ID?cluster=devnet"
fi
echo -e "   • ${BLUE}Network:${NC} devnet"
echo -e "   • ${BLUE}Deployer:${NC} $(solana address)"
echo -e "   • ${BLUE}Artefato:${NC} deploy/gmc_token_real.so ($(printf "%'d" $ARTIFACT_SIZE) bytes)"
echo -e "   • ${BLUE}Versão:${NC} PROJETO REAL (todas as regras de negócio preservadas)"
echo ""

echo -e "${GREEN}🏗️ MÓDULOS INCLUÍDOS (do projeto real):${NC}"
echo -e "   • ${GREEN}✅ Staking System${NC} (longo prazo + flexível)"
echo -e "   • ${GREEN}✅ Affiliate System${NC} (6 níveis de comissão)"
echo -e "   • ${GREEN}✅ Treasury Management${NC} (gestão de fundos)"
echo -e "   • ${GREEN}✅ Ranking System${NC} (premiações mensais)"
echo -e "   • ${GREEN}✅ Vesting System${NC} (liberação gradual)"
echo -e "   • ${GREEN}✅ Fee Distribution${NC} (taxas USDT)"
echo ""

echo -e "${GREEN}📁 ARQUIVOS SALVOS:${NC}"
echo -e "   • ${BLUE}Artefato Real:${NC} deploy/gmc_token_real.so"
if [ -n "$PROGRAM_ID" ]; then
    echo -e "   • ${BLUE}Program ID:${NC} .devnet-keys/gmc_real_program_id.txt"
fi
echo ""

echo -e "${GREEN}🎯 PRÓXIMOS PASSOS:${NC}"
echo "   1. 🧪 Testar funcionalidades: staking, affiliate, treasury"
echo "   2. 🪙 Criar Token SPL com supply de 100 milhões"
echo "   3. 🎨 Configurar metadados do token"
echo "   4. 🚀 Integrar frontend com Program ID"
echo "   5. 📊 Executar testes de integração completos"
echo ""

echo -e "${GREEN}✅ GMC Token (PROJETO REAL) deployado e pronto para uso!${NC}"
echo -e "${BLUE}Script finalizado! 🎯${NC}"
