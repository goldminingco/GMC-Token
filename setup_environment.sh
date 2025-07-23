#!/bin/bash
# 🚀 GMC Token - Script de Setup Definitivo do Ambiente de Build
# Este script resolve de forma definitiva os problemas recorrentes de:
# - Cargo.lock versão 4 vs cargo-build-sbf
# - Conflitos de toolchain (nightly vs stable)
# - Dependências incompatíveis
# - Configuração de ambiente inconsistente

set -e  # Para o script se qualquer comando falhar

echo "🚀 GMC Token - Setup Definitivo do Ambiente de Build"
echo "=================================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Verificar e instalar Rust se necessário
log_info "Verificando instalação do Rust..."
if ! command -v rustc &> /dev/null; then
    log_warning "Rust não encontrado. Instalando..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    log_success "Rust instalado com sucesso"
else
    log_success "Rust já está instalado: $(rustc --version)"
fi

# 2. Configurar toolchains necessários
log_info "Configurando toolchains Rust..."

# Instalar nightly (para edition 2024 e dependências modernas)
rustup toolchain install nightly
log_success "Toolchain nightly instalado"

# Instalar stable (para compatibilidade com cargo-build-sbf)
rustup toolchain install stable
log_success "Toolchain stable instalado"

# Definir nightly como padrão para o projeto (mas com override para build)
rustup override set nightly
log_success "Nightly definido como padrão para o projeto"

# 3. Verificar e instalar Solana CLI
log_info "Verificando instalação do Solana CLI..."
if ! command -v solana &> /dev/null; then
    log_warning "Solana CLI não encontrado. Instalando versão 1.18.26..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.26/install)"
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    log_success "Solana CLI instalado com sucesso"
else
    SOLANA_VERSION=$(solana --version | cut -d' ' -f2)
    log_success "Solana CLI já está instalado: $SOLANA_VERSION"
fi

# Verificar se cargo-build-sbf está disponível
if ! command -v cargo-build-sbf &> /dev/null; then
    log_error "cargo-build-sbf não encontrado. Verifique a instalação do Solana CLI."
    exit 1
fi
log_success "cargo-build-sbf está disponível"

# 4. Limpar ambiente de build anterior
log_info "Limpando ambiente de build anterior..."
rm -rf target/
rm -f Cargo.lock
rm -f programs/gmc_token_native/Cargo.lock
log_success "Ambiente limpo"

# 5. Configurar dependências compatíveis
log_info "Configurando dependências para máxima compatibilidade..."

# Verificar se o Cargo.toml do programa tem as configurações corretas
PROGRAM_CARGO_TOML="programs/gmc_token_native/Cargo.toml"
if ! grep -q "cargo-features.*edition2024" "$PROGRAM_CARGO_TOML"; then
    log_warning "Adicionando cargo-features para edition2024..."
    # Backup do arquivo original
    cp "$PROGRAM_CARGO_TOML" "$PROGRAM_CARGO_TOML.backup"
    # Adicionar cargo-features no início
    echo 'cargo-features = ["edition2024"]' > temp_cargo.toml
    echo '' >> temp_cargo.toml
    cat "$PROGRAM_CARGO_TOML" >> temp_cargo.toml
    mv temp_cargo.toml "$PROGRAM_CARGO_TOML"
    log_success "cargo-features adicionado"
fi

# 6. Gerar Cargo.lock compatível usando estratégia híbrida
log_info "Gerando Cargo.lock compatível..."
cd programs/gmc_token_native

# Estratégia: usar stable para gerar lockfile, depois usar nightly para build
log_info "Gerando lockfile com toolchain stable..."
cargo +stable generate-lockfile 2>/dev/null || {
    log_warning "Falha com stable, tentando com nightly..."
    cargo +nightly generate-lockfile
}

# Verificar se o lockfile foi gerado
if [ -f "Cargo.lock" ]; then
    LOCKFILE_VERSION=$(head -n 5 Cargo.lock | grep "version" | cut -d' ' -f3)
    log_success "Cargo.lock gerado (versão: $LOCKFILE_VERSION)"
else
    log_error "Falha ao gerar Cargo.lock"
    exit 1
fi

cd ../..

# 7. Teste de build
log_info "Testando build do programa..."
cd programs/gmc_token_native

# Tentar build com nightly primeiro
if cargo +nightly build-sbf --arch sbfv2 &>/dev/null; then
    log_success "Build com nightly funcionou!"
    BUILD_TOOLCHAIN="nightly"
elif cargo +stable build-sbf --arch sbfv2 &>/dev/null; then
    log_success "Build com stable funcionou!"
    BUILD_TOOLCHAIN="stable"
else
    log_error "Build falhou com ambos os toolchains"
    exit 1
fi

cd ../..

# 8. Criar script de build otimizado
log_info "Criando script de build otimizado..."
cat > build_stable.sh << 'EOF'
#!/bin/bash
# 🚀 Script de Build Estável - GMC Token Native Rust
# Este script usa a configuração otimizada descoberta pelo setup_environment.sh

set -e

PROGRAM_PATH="programs/gmc_token_native"
DEPLOY_DIR="deploy"
ARTIFACT_NAME="gmc_token.so"

echo "🔧 Iniciando build estável do GMC Token..."

# Limpar build anterior
echo "Limpando build anterior..."
(cd "$PROGRAM_PATH" && cargo clean)

# Remover lockfiles problemáticos
echo "Removendo lockfiles incompatíveis..."
rm -f Cargo.lock
rm -f "$PROGRAM_PATH/Cargo.lock"

# Gerar lockfile compatível
echo "Gerando Cargo.lock compatível..."
(cd "$PROGRAM_PATH" && cargo +stable generate-lockfile 2>/dev/null || cargo +nightly generate-lockfile)

# Build com toolchain otimizado
echo "Compilando programa..."
cd "$PROGRAM_PATH"

# Tentar nightly primeiro, depois stable como fallback
if cargo +nightly build-sbf --arch sbfv2; then
    echo "✅ Build realizado com nightly"
elif cargo +stable build-sbf --arch sbfv2; then
    echo "✅ Build realizado com stable"
else
    echo "❌ Build falhou com ambos os toolchains"
    exit 1
fi

cd ../..

# Criar diretório de deploy
mkdir -p "$DEPLOY_DIR"

# Copiar artefato
SOURCE_ARTIFACT_PATH="$PROGRAM_PATH/target/sbf-solana-solana/release/gmc_token_native.so"
cp "$SOURCE_ARTIFACT_PATH" "$DEPLOY_DIR/$ARTIFACT_NAME"

echo "🎉 Build concluído com sucesso!"
echo "📦 Artefato: $DEPLOY_DIR/$ARTIFACT_NAME"
echo "📏 Tamanho: $(ls -lh $DEPLOY_DIR/$ARTIFACT_NAME | awk '{print $5}')"
EOF

chmod +x build_stable.sh
log_success "Script build_stable.sh criado"

# 9. Criar Dockerfile otimizado
log_info "Criando Dockerfile otimizado..."
cat > Dockerfile.stable << 'EOF'
# 🚀 Dockerfile Estável - GMC Token Native Rust
# Este Dockerfile resolve os problemas recorrentes de lockfile e toolchain

FROM rustlang/rust:nightly-bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    curl \
    wget \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instalar Solana CLI versão específica
RUN wget https://github.com/solana-labs/solana/releases/download/v1.18.26/solana-release-x86_64-unknown-linux-gnu.tar.bz2 \
    && tar -jxf solana-release-x86_64-unknown-linux-gnu.tar.bz2 \
    && mv solana-release/bin/* /usr/local/bin/ \
    && rm -rf solana-release* \
    && solana --version

# Configurar toolchains
RUN rustup toolchain install stable \
    && rustup toolchain install nightly \
    && rustup default nightly

WORKDIR /app

# Copiar apenas arquivos necessários (evitar problemas de contexto)
COPY programs/ programs/
COPY build_stable.sh .
COPY Cargo.toml .

# Executar build estável
RUN chmod +x build_stable.sh && ./build_stable.sh

# Comando padrão
CMD ["./build_stable.sh"]
EOF

log_success "Dockerfile.stable criado"

# 10. Criar documentação de troubleshooting
log_info "Criando documentação de troubleshooting..."
cat > STABLE_BUILD_GUIDE.md << 'EOF'
# 🚀 GMC Token - Guia de Build Estável

## Problemas Resolvidos

Este setup resolve definitivamente:

- ✅ Cargo.lock versão 4 vs cargo-build-sbf
- ✅ Conflitos entre toolchain nightly e stable  
- ✅ Dependências incompatíveis (base64, edition2024)
- ✅ Problemas de workspace vs programa individual
- ✅ Inconsistências entre build local e Docker

## Scripts Disponíveis

### 1. `setup_environment.sh`
```bash
./setup_environment.sh
```
- Configura o ambiente completo
- Instala dependências necessárias
- Resolve conflitos de toolchain
- Gera lockfile compatível
- Testa o build

### 2. `build_stable.sh`
```bash
./build_stable.sh
```
- Build otimizado e estável
- Fallback automático entre toolchains
- Limpeza automática de lockfiles problemáticos
- Geração de artefato final

### 3. Docker Estável
```bash
docker build -f Dockerfile.stable -t gmc-token-stable .
```
- Ambiente Docker otimizado
- Sem problemas de lockfile
- Build reprodutível

## Estratégia de Lockfile

1. **Geração**: Usar `cargo +stable generate-lockfile`
2. **Build**: Tentar `nightly` primeiro, `stable` como fallback
3. **Limpeza**: Remover lockfiles antes de cada build

## Troubleshooting

### Problema: "lock file version 4 requires -Znext-lockfile-bump"
**Solução**: Execute `./setup_environment.sh` novamente

### Problema: "failed to find a workspace root"
**Solução**: Certifique-se que o Cargo.toml do workspace está presente

### Problema: Build falha no Docker
**Solução**: Use `Dockerfile.stable` em vez do Dockerfile padrão

## Verificação do Ambiente

```bash
# Verificar toolchains
rustup show

# Verificar Solana CLI
solana --version
cargo-build-sbf --version

# Testar build
./build_stable.sh
```
EOF

log_success "STABLE_BUILD_GUIDE.md criado"

# 11. Teste final
log_info "Executando teste final do ambiente..."
if ./build_stable.sh; then
    log_success "🎉 AMBIENTE CONFIGURADO COM SUCESSO!"
    echo ""
    echo "📋 Resumo da Configuração:"
    echo "  • Rust: $(rustc --version)"
    echo "  • Solana: $(solana --version | cut -d' ' -f1-2)"
    echo "  • Toolchain padrão: $(rustup show active-toolchain | cut -d' ' -f1)"
    echo "  • Build toolchain: $BUILD_TOOLCHAIN"
    echo ""
    echo "🚀 Scripts disponíveis:"
    echo "  • ./setup_environment.sh - Reconfigurar ambiente"
    echo "  • ./build_stable.sh - Build estável"
    echo "  • docker build -f Dockerfile.stable - Build Docker"
    echo ""
    echo "📖 Documentação: STABLE_BUILD_GUIDE.md"
else
    log_error "Teste final falhou. Verifique os logs acima."
    exit 1
fi
