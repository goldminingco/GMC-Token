#!/bin/bash

# 🔧 Script de Gerenciamento de Dependências - Projetos Solana
# Implementa as melhores práticas para evitar conflitos

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🔧 Gerenciador de Dependências - Projetos Solana"
echo "=============================================="

# 1. Verificar duplicatas
echo ""
log_info "1. Analisando dependências duplicadas..."
DUPLICATES=$(cargo tree --duplicates 2>/dev/null | wc -l)
if [ "$DUPLICATES" -gt 0 ]; then
    log_warning "Encontradas $DUPLICATES dependências duplicadas"
    echo "Executando análise detalhada:"
    cargo tree --duplicates | head -20
else
    log_success "Nenhuma dependência duplicada encontrada"
fi

# 2. Verificar dependências não utilizadas
echo ""
log_info "2. Verificando dependências não utilizadas..."
if command -v cargo-machete &> /dev/null; then
    cargo machete
else
    log_warning "cargo-machete não instalado. Para instalar:"
    echo "cargo install cargo-machete"
fi

# 3. Verificar vulnerabilidades
echo ""
log_info "3. Verificando vulnerabilidades conhecidas..."
if cargo audit --version &> /dev/null; then
    cargo audit
else
    log_warning "cargo-audit não instalado. Para instalar:"
    echo "cargo install cargo-audit"
fi

# 4. Verificar atualizações disponíveis
echo ""
log_info "4. Verificando atualizações disponíveis..."
if command -v cargo-outdated &> /dev/null; then
    cargo outdated
else
    log_warning "cargo-outdated não instalado. Para instalar:"
    echo "cargo install cargo-outdated"
fi

# 5. Análise específica para Anchor/Solana
echo ""
log_info "5. Verificação específica Anchor/Solana..."

# Verificar versões críticas
ANCHOR_VERSION=$(cargo tree | grep "anchor-lang" | head -1 | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
PROC_MACRO_VERSION=$(cargo tree | grep "proc-macro2" | head -1 | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)

log_info "Anchor Lang: $ANCHOR_VERSION"
log_info "Proc-macro2: $PROC_MACRO_VERSION"

# Verificar compatibilidade conhecida
if [[ "$PROC_MACRO_VERSION" == "v1.0.95" ]] && [[ "$ANCHOR_VERSION" == "v0.30.1" ]]; then
    log_warning "Incompatibilidade conhecida detectada!"
    echo "Solução: Use 'anchor build --no-idl' ou atualize Anchor"
fi

# 6. Gerar relatório
echo ""
log_info "6. Gerando relatório de dependências..."
REPORT_FILE="dependency_report_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "# Relatório de Dependências - $(date)"
    echo "=================================="
    echo ""
    echo "## Árvore de Dependências"
    cargo tree
    echo ""
    echo "## Dependências Duplicadas"
    cargo tree --duplicates
    echo ""
    echo "## Versões Instaladas"
    echo "Rust: $(rustc --version)"
    echo "Cargo: $(cargo --version)"
    if command -v anchor &> /dev/null; then
        echo "Anchor: $(anchor --version)"
    fi
} > "$REPORT_FILE"

log_success "Relatório salvo em: $REPORT_FILE"

# 7. Sugestões de otimização
echo ""
log_info "7. Sugestões de otimização:"
echo "   • Usar versões exatas (=x.y.z) para deps críticas"
echo "   • Implementar CI/CD com verificação de deps"
echo "   • Monitorar releases do Anchor Framework"
echo "   • Executar este script semanalmente"

# 8. Ações automáticas (opcional)
echo ""
read -p "🔧 Deseja executar limpeza automática? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Executando limpeza..."
    cargo clean
    log_success "Limpeza concluída"
fi

echo ""
log_success "Análise de dependências concluída!"
echo "📊 Para mais detalhes, consulte: $REPORT_FILE" 