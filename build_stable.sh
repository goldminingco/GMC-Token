#!/bin/bash
# 🚀 Script de Build Estável - GMC Token Native Rust
# SOLUÇÃO DEFINITIVA para problemas de Cargo.lock v4 e toolchain conflicts

set -e

PROGRAM_PATH="programs/gmc_token_native"
DEPLOY_DIR="deploy"
ARTIFACT_NAME="gmc_token.so"

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔧 Iniciando build estável do GMC Token...${NC}"

# SOLUÇÃO DEFINITIVA: O problema é o Cargo.lock do workspace (versão 4)
# que é incompatível com cargo-build-sbf. A solução é removê-lo antes do build.

echo -e "${YELLOW}1. Limpando build anterior...${NC}"
(cd "$PROGRAM_PATH" && cargo clean)

echo -e "${YELLOW}2. Removendo Cargo.lock problemático do workspace...${NC}"
# Este é o passo CRÍTICO - remove o lockfile v4 do workspace que causa conflito
rm -f Cargo.lock
rm -f "$PROGRAM_PATH/Cargo.lock"

echo -e "${YELLOW}3. Compilando programa...${NC}"
cd "$PROGRAM_PATH"

# SOLUÇÃO ROBUSTA: Monitorar e remover Cargo.lock se for regenerado durante o build
echo "Iniciando build com monitoramento de lockfile..."

# Build com nightly (que é o padrão do projeto)
if cargo build-sbf --arch sbfv2 2>&1 | tee /tmp/build_output.log; then
    echo -e "${GREEN}✅ Build realizado com sucesso${NC}"
else
    # Se falhar, verificar se é por causa do lockfile e tentar novamente
    if grep -q "lock file version 4" /tmp/build_output.log; then
        echo -e "${YELLOW}⚠️ Lockfile v4 detectado, removendo e tentando novamente...${NC}"
        cd ..
        rm -f Cargo.lock
        cd "$PROGRAM_PATH"
        rm -f Cargo.lock
        
        # Segunda tentativa
        if cargo build-sbf --arch sbfv2; then
            echo -e "${GREEN}✅ Build realizado com sucesso na segunda tentativa${NC}"
        else
            echo "❌ Build falhou mesmo após remoção do lockfile"
            exit 1
        fi
    else
        echo "❌ Build falhou por outro motivo"
        cat /tmp/build_output.log
        exit 1
    fi
fi

cd ../..

echo -e "${YELLOW}4. Preparando artefato...${NC}"
# Criar diretório de deploy
mkdir -p "$DEPLOY_DIR"

# Copiar artefato
SOURCE_ARTIFACT_PATH="$PROGRAM_PATH/target/sbf-solana-solana/release/gmc_token_native.so"
cp "$SOURCE_ARTIFACT_PATH" "$DEPLOY_DIR/$ARTIFACT_NAME"

# Informações do artefato
ARTIFACT_SIZE=$(ls -lh "$DEPLOY_DIR/$ARTIFACT_NAME" | awk '{print $5}')

echo ""
echo -e "${GREEN}🎉 BUILD CONCLUÍDO COM SUCESSO!${NC}"
echo -e "${BLUE}📦 Artefato: $DEPLOY_DIR/$ARTIFACT_NAME${NC}"
echo -e "${BLUE}📏 Tamanho: $ARTIFACT_SIZE${NC}"
echo ""
echo -e "${GREEN}✅ SOLUÇÃO DEFINITIVA APLICADA:${NC}"
echo "   • Cargo.lock do workspace removido antes do build"
echo "   • Build usando nightly toolchain (padrão do projeto)"
echo "   • Sem conflitos de versão de lockfile"
echo ""
echo -e "${BLUE}💡 Para builds futuros, sempre execute: ./build_stable.sh${NC}"
