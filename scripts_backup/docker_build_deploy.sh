#!/bin/bash
# 🐳 Docker Build & Deploy - Solução Definitiva SBPF
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🐳 GMC Token - Docker Build & Deploy${NC}"
echo "====================================="
echo

# Verificar se Docker está disponível
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker não encontrado!${NC}"
    echo -e "${YELLOW}📋 Por favor, instale Docker:${NC}"
    echo -e "${BLUE}   https://docs.docker.com/get-docker/${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker encontrado!${NC}"

# 1. Preparar ambiente para Docker
echo -e "${YELLOW}1. Preparando código para Docker...${NC}"

# Criar Dockerfile personalizado se não existir
if [ ! -f "Dockerfile.solana" ]; then
    cat > Dockerfile.solana << 'EOF'
FROM solanalabs/rust:1.68.0

# Instalar dependências necessárias
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Configurar ambiente Solana
ENV PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

# Instalar versão específica do Solana CLI compatível
RUN sh -c "$(curl -sSfL https://release.solana.com/v1.17.31/install)"

WORKDIR /workspace

# Comando padrão
CMD ["bash"]
EOF
    echo -e "${GREEN}✅ Dockerfile.solana criado${NC}"
fi

# Criar versão limpa do projeto para Docker
echo -e "${YELLOW}2. Criando código limpo...${NC}"
rm -rf .docker-build
mkdir -p .docker-build

# Copiar apenas arquivos essenciais
cp -r programs .docker-build/
cp Cargo.toml .docker-build/
cp -r .cargo .docker-build/ 2>/dev/null || true

# Criar Cargo.toml simplificado para compatibilidade
cat > .docker-build/programs/gmc_token_native/Cargo.toml << 'EOF'
[package]
name = "gmc_token_native"
version = "1.0.0"
edition = "2021"
license = "MIT"

[lib]
crate-type = ["cdylib", "lib"]

[dependencies]
solana-program = "1.17.31"
borsh = "0.9.3"

[dev-dependencies]
solana-program-test = "1.17.31"
EOF

# Usar apenas código básico funcional
cp programs/gmc_token_native/src/lib_minimal.rs .docker-build/programs/gmc_token_native/src/lib.rs

echo -e "${GREEN}✅ Código preparado para Docker${NC}"

# 3. Build no Docker
echo -e "${YELLOW}3. Executando build no Docker...${NC}"
echo -e "${BLUE}📦 Comando: docker run --rm -v \$(pwd)/.docker-build:/workspace solanalabs/rust:1.68.0 cargo build-sbf --arch sbfv1${NC}"

if docker run --rm -v "$(pwd)/.docker-build:/workspace" solanalabs/rust:1.68.0 bash -c "
    cd /workspace && 
    cargo clean && 
    cargo build-sbf --arch sbfv1
"; then
    echo -e "${GREEN}✅ Build Docker realizado com sucesso!${NC}"
    
    # 4. Copiar artefato
    if [ -f ".docker-build/programs/gmc_token_native/target/sbf-solana-solana/release/gmc_token_native.so" ]; then
        mkdir -p deploy
        cp .docker-build/programs/gmc_token_native/target/sbf-solana-solana/release/gmc_token_native.so deploy/gmc_token_docker.so
        
        ARTIFACT_SIZE=$(ls -lh deploy/gmc_token_docker.so | awk '{print $5}')
        echo -e "${GREEN}📦 Artefato Docker SBPF v1: deploy/gmc_token_docker.so ($ARTIFACT_SIZE)${NC}"
        
        # Verificar compatibilidade
        echo -e "${YELLOW}4. Verificando compatibilidade...${NC}"
        file deploy/gmc_token_docker.so
        
        # 5. Deploy automático
        echo -e "${YELLOW}5. Iniciando deploy...${NC}"
        
        # Verificar configuração
        WALLET_ADDRESS=$(solana address)
        BALANCE=$(solana balance)
        RPC_URL=$(solana config get | grep "RPC URL" | awk '{print $3}')
        
        echo -e "${CYAN}📋 CONFIG DEPLOY:${NC}"
        echo -e "${GREEN}✅ Wallet: $WALLET_ADDRESS${NC}"
        echo -e "${GREEN}✅ Saldo: $BALANCE${NC}"
        echo -e "${GREEN}✅ RPC: $RPC_URL${NC}"
        
        # Verificar saldo
        if [[ "$BALANCE" == "0 SOL" ]]; then
            echo -e "${YELLOW}⚠️ Solicitando airdrop...${NC}"
            solana airdrop 2
            sleep 3
            BALANCE=$(solana balance)
        fi
        
        # Deploy
        echo -e "${BLUE}🚀 Fazendo deploy do artefato compatível...${NC}"
        if DEPLOY_OUTPUT=$(solana program deploy deploy/gmc_token_docker.so --output json 2>&1); then
            echo -e "${GREEN}✅ Deploy realizado com sucesso!${NC}"
            echo "$DEPLOY_OUTPUT"
            
            # Extrair Program ID
            if [[ "$DEPLOY_OUTPUT" =~ \"programId\":\"([^\"]+)\" ]]; then
                PROGRAM_ID="${BASH_REMATCH[1]}"
            elif [[ "$DEPLOY_OUTPUT" =~ Program\ Id:\ ([A-Za-z0-9]+) ]]; then
                PROGRAM_ID="${BASH_REMATCH[1]}"
            else
                PROGRAM_ID="Ver output acima"
            fi
            
            echo
            echo -e "${GREEN}🎉 DEPLOY DOCKER CONCLUÍDO COM SUCESSO! 🎉${NC}"
            echo "=============================================="
            echo -e "${BLUE}📋 INFORMAÇÕES DO DEPLOY:${NC}"
            echo -e "${BLUE}   • Program ID: ${GREEN}$PROGRAM_ID${NC}"
            echo -e "${BLUE}   • Network: ${GREEN}$(echo $RPC_URL | grep -o 'devnet\|testnet\|mainnet' || echo 'Unknown')${NC}"
            echo -e "${BLUE}   • Deployer: ${GREEN}$WALLET_ADDRESS${NC}"
            echo -e "${BLUE}   • Artefato: ${GREEN}deploy/gmc_token_docker.so ($ARTIFACT_SIZE)${NC}"
            
            if [[ "$RPC_URL" =~ "devnet" ]]; then
                echo -e "${BLUE}   • Explorer: ${GREEN}https://explorer.solana.com/address/$PROGRAM_ID?cluster=devnet${NC}"
            elif [[ "$RPC_URL" =~ "testnet" ]]; then
                echo -e "${BLUE}   • Explorer: ${GREEN}https://explorer.solana.com/address/$PROGRAM_ID?cluster=testnet${NC}"
            fi
            
            # Salvar informações
            cat > deploy/deploy_info_docker.json << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "$(echo $RPC_URL | grep -o 'devnet\|testnet\|mainnet' || echo 'unknown')",
  "programId": "$PROGRAM_ID",
  "deployerAddress": "$WALLET_ADDRESS",
  "artifactPath": "deploy/gmc_token_docker.so",
  "artifactSize": "$ARTIFACT_SIZE",
  "buildMethod": "Docker + SBPF v1"
}
EOF
            
            echo
            echo -e "${YELLOW}🔍 PRÓXIMOS PASSOS - TESTES DE INTEGRAÇÃO:${NC}"
            echo -e "${BLUE}   1. Verificar programa no explorer${NC}"
            echo -e "${BLUE}   2. Testar funcionalidades básicas${NC}"
            echo -e "${BLUE}   3. Executar: ./scripts/integration_tests.sh${NC}"
            echo -e "${BLUE}   4. Preparar para mainnet${NC}"
            
        else
            echo -e "${RED}❌ Deploy falhou: $DEPLOY_OUTPUT${NC}"
            if [[ "$DEPLOY_OUTPUT" =~ "sbpf_version" ]]; then
                echo -e "${YELLOW}💡 Ainda há incompatibilidade SBPF. Tentando versão ainda mais antiga...${NC}"
            fi
        fi
        
    else
        echo -e "${RED}❌ Artefato não encontrado após build Docker${NC}"
        echo -e "${YELLOW}💡 Listando arquivos gerados:${NC}"
        find .docker-build -name "*.so" -type f 2>/dev/null || echo "Nenhum .so encontrado"
    fi
    
else
    echo -e "${RED}❌ Build Docker falhou${NC}"
    echo -e "${YELLOW}💡 Tentando estratégia alternativa...${NC}"
    
    # Estratégia alternativa: usar imagem mais antiga
    echo -e "${BLUE}📦 Tentando com imagem Rust mais antiga...${NC}"
    docker run --rm -v "$(pwd)/.docker-build:/workspace" rust:1.68.0 bash -c "
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
        curl -sSfL https://release.solana.com/v1.17.31/install | sh
        export PATH=\"/root/.local/share/solana/install/active_release/bin:\$PATH\"
        cd /workspace
        cargo build-sbf --arch sbfv1
    " || echo -e "${RED}❌ Estratégia alternativa também falhou${NC}"
fi

# Limpeza
echo -e "${YELLOW}6. Limpando arquivos temporários...${NC}"
rm -rf .docker-build

echo -e "${GREEN}Script Docker finalizado! 🐳${NC}" 