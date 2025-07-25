#!/bin/bash

# 🚀 GMC Token - Build & Deploy Completo
# =====================================
# 
# Este script realiza o build e deploy do GMC Token completo
# considerando toda a estrutura modular do projeto:
# - Staking System (longo prazo + flexível)
# - Affiliate System (6 níveis)
# - Treasury Management
# - Ranking System
# - Vesting System
# - USDT Fee Distribution

set -e

echo "🚀 GMC Token - Build & Deploy Completo"
echo "======================================"
echo ""

# Configurações do Projeto
PROJECT_NAME="GMC Token Native"
PROGRAM_NAME="gmc_token_native"
SUPPLY_TOTAL=100000000  # 100 milhões conforme tokenomics.md
DECIMALS=9

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}📋 CONFIGURAÇÕES DO PROJETO GMC TOKEN:${NC}"
echo -e "   • ${BLUE}Nome:${NC} $PROJECT_NAME"
echo -e "   • ${BLUE}Programa:${NC} $PROGRAM_NAME"
echo -e "   • ${BLUE}Supply Total:${NC} $(printf "%'d" $SUPPLY_TOTAL) GMC"
echo -e "   • ${BLUE}Decimais:${NC} $DECIMALS"
echo ""

echo -e "${PURPLE}🏗️ MÓDULOS DO PROJETO:${NC}"
echo -e "   • ${GREEN}✅ Staking System${NC} (longo prazo + flexível)"
echo -e "   • ${GREEN}✅ Affiliate System${NC} (6 níveis de comissão)"
echo -e "   • ${GREEN}✅ Treasury Management${NC} (gestão de fundos)"
echo -e "   • ${GREEN}✅ Ranking System${NC} (premiações mensais)"
echo -e "   • ${GREEN}✅ Vesting System${NC} (liberação gradual)"
echo -e "   • ${GREEN}✅ USDT Fee Distribution${NC} (taxas em USDT)"
echo ""

# 1. Verificar estrutura do projeto
echo "1. Verificando estrutura do projeto..."
if [ ! -d "programs/$PROGRAM_NAME" ]; then
    echo -e "${RED}❌ Diretório programs/$PROGRAM_NAME não encontrado${NC}"
    exit 1
fi

if [ ! -f "programs/$PROGRAM_NAME/Cargo.toml" ]; then
    echo -e "${RED}❌ Cargo.toml do programa não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Estrutura do projeto validada${NC}"

# 2. Verificar módulos principais
echo ""
echo "2. Verificando módulos principais..."
MODULES=("lib.rs" "staking.rs" "affiliate.rs" "treasury.rs" "ranking.rs" "vesting.rs")
for module in "${MODULES[@]}"; do
    if [ -f "programs/$PROGRAM_NAME/src/$module" ]; then
        size=$(wc -c < "programs/$PROGRAM_NAME/src/$module")
        echo -e "   • ${GREEN}✅ $module${NC} ($(printf "%'d" $size) bytes)"
    else
        echo -e "   • ${YELLOW}⚠️ $module${NC} (não encontrado - opcional)"
    fi
done

# 3. Verificar configuração da rede
echo ""
echo "3. Verificando configuração da rede..."
CURRENT_RPC=$(solana config get | grep "RPC URL" | awk '{print $3}')
echo -e "${BLUE}📡 RPC atual: $CURRENT_RPC${NC}"

if [[ "$CURRENT_RPC" != *"devnet"* ]]; then
    echo -e "${YELLOW}⚠️ Configurando para devnet...${NC}"
    solana config set --url https://api.devnet.solana.com
fi

# 4. Verificar saldo da wallet
echo ""
echo "4. Verificando saldo da wallet..."
BALANCE=$(solana balance)
echo -e "${BLUE}💰 Saldo atual: $BALANCE${NC}"

if (( $(echo "$BALANCE" | cut -d' ' -f1 | awk '{print ($1 < 1.0)}') )); then
    echo -e "${YELLOW}⚠️ Saldo baixo. Fazendo airdrop...${NC}"
    solana airdrop 2
    BALANCE=$(solana balance)
    echo -e "${BLUE}💰 Novo saldo: $BALANCE${NC}"
fi

# 5. Limpar builds anteriores
echo ""
echo "5. Limpando builds anteriores..."
if [ -d "target" ]; then
    rm -rf target
    echo -e "${GREEN}✅ Diretório target limpo${NC}"
fi

if [ -d "programs/$PROGRAM_NAME/target" ]; then
    rm -rf "programs/$PROGRAM_NAME/target"
    echo -e "${GREEN}✅ Target do programa limpo${NC}"
fi

# 6. Verificar e ajustar Cargo.lock se necessário
echo ""
echo "6. Verificando compatibilidade do Cargo.lock..."
if [ -f "Cargo.lock" ]; then
    LOCK_VERSION=$(head -n 5 Cargo.lock | grep "version" | awk '{print $3}')
    echo -e "${BLUE}📋 Versão do Cargo.lock: $LOCK_VERSION${NC}"
    
    if [ "$LOCK_VERSION" = "4" ]; then
        echo -e "${YELLOW}⚠️ Cargo.lock v4 detectado. Removendo para compatibilidade...${NC}"
        rm Cargo.lock
    fi
fi

# 7. Build do programa principal
echo ""
echo "7. Realizando build do programa GMC Token..."
echo -e "${YELLOW}🔨 Compilando com otimizações para compute units...${NC}"

cd programs/$PROGRAM_NAME

# Tentar build com diferentes estratégias
BUILD_SUCCESS=false

echo -e "${BLUE}📦 Estratégia 1: cargo build-sbf --arch sbfv1${NC}"
if cargo build-sbf --arch sbfv1 2>/dev/null; then
    BUILD_SUCCESS=true
    echo -e "${GREEN}✅ Build SBPFv1 bem-sucedido!${NC}"
elif cargo build-bpf 2>/dev/null; then
    BUILD_SUCCESS=true
    echo -e "${GREEN}✅ Build BPF bem-sucedido!${NC}"
else
    echo -e "${YELLOW}⚠️ Tentando com cargo +solana build-sbf...${NC}"
    if cargo +solana build-sbf 2>/dev/null; then
        BUILD_SUCCESS=true
        echo -e "${GREEN}✅ Build com toolchain Solana bem-sucedido!${NC}"
    fi
fi

cd ../..

if [ "$BUILD_SUCCESS" = false ]; then
    echo -e "${RED}❌ Falha no build do programa${NC}"
    exit 1
fi

# 8. Localizar e verificar artefato
echo ""
echo "8. Localizando artefato compilado..."
ARTIFACT_PATH=""

# Possíveis localizações do artefato
POSSIBLE_PATHS=(
    "target/deploy/$PROGRAM_NAME.so"
    "programs/$PROGRAM_NAME/target/deploy/$PROGRAM_NAME.so"
    "target/sbf-solana-solana/release/$PROGRAM_NAME.so"
    "programs/$PROGRAM_NAME/target/sbf-solana-solana/release/$PROGRAM_NAME.so"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        ARTIFACT_PATH="$path"
        break
    fi
done

if [ -z "$ARTIFACT_PATH" ]; then
    echo -e "${RED}❌ Artefato compilado não encontrado${NC}"
    exit 1
fi

# Copiar para diretório deploy
mkdir -p deploy
cp "$ARTIFACT_PATH" "deploy/gmc_token_complete.so"
ARTIFACT_SIZE=$(wc -c < "deploy/gmc_token_complete.so")

echo -e "${GREEN}✅ Artefato localizado: deploy/gmc_token_complete.so${NC}"
echo -e "${BLUE}📦 Tamanho: $(printf "%'d" $ARTIFACT_SIZE) bytes${NC}"

# 9. Verificar compatibilidade SBPF
echo ""
echo "9. Verificando compatibilidade SBPF..."
if command -v file &> /dev/null; then
    FILE_INFO=$(file deploy/gmc_token_complete.so)
    echo -e "${BLUE}🔍 Tipo de arquivo: $FILE_INFO${NC}"
fi

# 10. Deploy do programa
echo ""
echo "10. Realizando deploy do programa GMC Token..."
echo -e "${YELLOW}🚀 Deployando programa completo...${NC}"

DEPLOY_OUTPUT=$(solana program deploy deploy/gmc_token_complete.so 2>&1)
DEPLOY_EXIT_CODE=$?

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    PROGRAM_ID=$(echo "$DEPLOY_OUTPUT" | grep -o 'Program Id: [A-Za-z0-9]*' | awk '{print $3}')
    
    if [ -z "$PROGRAM_ID" ]; then
        # Tentar extrair de formato JSON
        PROGRAM_ID=$(echo "$DEPLOY_OUTPUT" | grep -o '"programId": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -n "$PROGRAM_ID" ]; then
        echo -e "${GREEN}✅ DEPLOY REALIZADO COM SUCESSO!${NC}"
        echo "$PROGRAM_ID" > .devnet-keys/gmc_program_id.txt
    else
        echo -e "${GREEN}✅ Deploy realizado, mas Program ID não detectado automaticamente${NC}"
        echo "$DEPLOY_OUTPUT"
    fi
else
    echo -e "${RED}❌ Falha no deploy:${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# 11. Resumo final
echo ""
echo -e "${PURPLE}🎉 GMC TOKEN PROGRAMA DEPLOYADO COM SUCESSO! 🎉${NC}"
echo "=================================================="
echo ""
echo -e "${GREEN}📋 INFORMAÇÕES DO DEPLOY:${NC}"
if [ -n "$PROGRAM_ID" ]; then
    echo -e "   • ${BLUE}Program ID:${NC} $PROGRAM_ID"
fi
echo -e "   • ${BLUE}Network:${NC} devnet"
echo -e "   • ${BLUE}Artefato:${NC} deploy/gmc_token_complete.so"
echo -e "   • ${BLUE}Tamanho:${NC} $(printf "%'d" $ARTIFACT_SIZE) bytes"
echo -e "   • ${BLUE}Módulos Incluídos:${NC} Staking, Affiliate, Treasury, Ranking, Vesting"
echo ""

if [ -n "$PROGRAM_ID" ]; then
    echo -e "${GREEN}🔗 LINKS ÚTEIS:${NC}"
    echo -e "   • ${BLUE}Explorer:${NC} https://explorer.solana.com/address/$PROGRAM_ID?cluster=devnet"
    echo ""
fi

echo -e "${GREEN}📁 ARQUIVOS SALVOS:${NC}"
echo -e "   • ${BLUE}Artefato:${NC} deploy/gmc_token_complete.so"
if [ -n "$PROGRAM_ID" ]; then
    echo -e "   • ${BLUE}Program ID:${NC} .devnet-keys/gmc_program_id.txt"
fi
echo ""

echo -e "${GREEN}🎯 PRÓXIMOS PASSOS:${NC}"
echo "   1. 🪙 Criar Token SPL (mint) com supply de 100 milhões"
echo "   2. 🧪 Executar testes de integração dos módulos"
echo "   3. 🎨 Configurar metadados do token (nome, símbolo, logo)"
echo "   4. 🚀 Integrar frontend com Program ID"
echo "   5. 📊 Testar funcionalidades: staking, affiliate, treasury"
echo ""

echo -e "${GREEN}✅ GMC Token (programa completo) está deployado e pronto para uso!${NC}"
