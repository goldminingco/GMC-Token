#!/bin/bash

# Script de build Docker otimizado para GMC Token
# Resolve problemas de compatibilidade Rust/Anchor/Solana

set -e

echo "🚀 Iniciando build do ambiente Docker GMC Token..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se Docker está instalado e rodando
if ! command -v docker &> /dev/null; then
    log_error "Docker não está instalado. Instale o Docker primeiro."
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker não está rodando. Inicie o Docker primeiro."
    exit 1
fi

log_info "Docker verificado com sucesso"

# Limpar imagens antigas se existirem
log_info "Limpando imagens antigas..."
docker rmi gmc-token-dev:latest 2>/dev/null || true
docker system prune -f

# Build da nova imagem
log_info "Construindo imagem Docker otimizada..."
docker build -t gmc-token-dev:latest .

if [ $? -eq 0 ]; then
    log_info "✅ Imagem Docker construída com sucesso!"
else
    log_error "❌ Falha na construção da imagem Docker"
    exit 1
fi

# Verificar se a imagem foi criada
if docker images | grep -q "gmc-token-dev"; then
    log_info "Imagem 'gmc-token-dev:latest' criada com sucesso"
else
    log_error "Falha ao criar a imagem"
    exit 1
fi

echo ""
log_info "🎉 Build concluído com sucesso!"
echo ""
echo "Para usar o ambiente Docker:"
echo "  docker run -it -v \$(pwd):/workspace gmc-token-dev:latest"
echo ""
echo "Ou use o script de desenvolvimento:"
echo "  ./docker-dev.sh"
echo ""