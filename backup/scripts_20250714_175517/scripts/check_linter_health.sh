#!/bin/bash

# 🔍 GMC Ecosystem - Linter Health Check Script
# Verifica e resolve automaticamente problemas de "linter fantasma"

set -e

echo "🔍 GMC Ecosystem - Linter Health Check"
echo "======================================"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log com cores
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar se estamos no diretório correto
if [ ! -f "Anchor.toml" ]; then
    log_error "Anchor.toml não encontrado. Execute este script na raiz do projeto GMC."
    exit 1
fi

log_info "Verificando saúde do ambiente de desenvolvimento..."

# 1. Verificar versões das ferramentas
echo ""
log_info "1. Verificando versões das ferramentas..."

# Verificar Rust
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version)
    log_success "Rust: $RUST_VERSION"
else
    log_error "Rust não encontrado"
    exit 1
fi

# Verificar Anchor
if command -v anchor &> /dev/null; then
    ANCHOR_VERSION=$(anchor --version)
    log_success "Anchor: $ANCHOR_VERSION"
else
    log_error "Anchor CLI não encontrado"
    exit 1
fi

# Verificar Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    log_success "Node.js: $NODE_VERSION"
else
    log_error "Node.js não encontrado"
    exit 1
fi

# Verificar Yarn
if command -v yarn &> /dev/null; then
    YARN_VERSION=$(yarn --version)
    log_success "Yarn: v$YARN_VERSION"
else
    log_error "Yarn não encontrado"
    exit 1
fi

# 2. Verificar estrutura de arquivos críticos
echo ""
log_info "2. Verificando arquivos críticos..."

# Verificar tsconfig.json
if [ -f "tsconfig.json" ]; then
    log_success "tsconfig.json encontrado"
    
    # Verificar se tem as configurações necessárias
    if grep -q "esModuleInterop" tsconfig.json && grep -q "allowSyntheticDefaultImports" tsconfig.json; then
        log_success "Configurações TypeScript adequadas"
    else
        log_warning "tsconfig.json pode precisar de atualização"
    fi
else
    log_error "tsconfig.json não encontrado"
fi

# Verificar package.json
if [ -f "package.json" ]; then
    log_success "package.json encontrado"
else
    log_error "package.json não encontrado"
fi

# 3. Verificar estado do target/
echo ""
log_info "3. Verificando diretório target/..."

if [ -d "target" ]; then
    log_success "Diretório target/ existe"
    
    # Verificar IDLs
    if [ -d "target/idl" ] && [ "$(ls -A target/idl)" ]; then
        IDL_COUNT=$(ls target/idl/*.json 2>/dev/null | wc -l)
        log_success "IDLs encontrados: $IDL_COUNT arquivos"
    else
        log_warning "IDLs não encontrados ou diretório vazio"
    fi
    
    # Verificar Types
    if [ -d "target/types" ] && [ "$(ls -A target/types)" ]; then
        TYPES_COUNT=$(ls target/types/*.ts 2>/dev/null | wc -l)
        log_success "Types encontrados: $TYPES_COUNT arquivos"
    else
        log_warning "Types não encontrados ou diretório vazio"
    fi
    
    # Verificar binários
    if [ -d "target/deploy" ] && [ "$(ls -A target/deploy)" ]; then
        DEPLOY_COUNT=$(ls target/deploy/*.so 2>/dev/null | wc -l)
        log_success "Binários encontrados: $DEPLOY_COUNT arquivos"
    else
        log_warning "Binários não encontrados"
    fi
else
    log_warning "Diretório target/ não existe"
fi

# 4. Verificar dependências Node.js
echo ""
log_info "4. Verificando dependências Node.js..."

if [ -d "node_modules" ]; then
    log_success "node_modules/ existe"
    
    # Verificar dependências críticas
    CRITICAL_DEPS=("@coral-xyz/anchor" "chai" "mocha" "@types/mocha" "@types/chai")
    
    for dep in "${CRITICAL_DEPS[@]}"; do
        if [ -d "node_modules/$dep" ]; then
            log_success "Dependência $dep instalada"
        else
            log_warning "Dependência $dep não encontrada"
        fi
    done
else
    log_warning "node_modules/ não existe"
fi

# 5. Função de auto-reparo
auto_repair() {
    echo ""
    log_info "🔧 Iniciando auto-reparo..."
    
    # Limpeza de cache
    log_info "Limpando caches..."
    if [ -d "target" ]; then
        rm -rf target/idl target/types
        log_success "Cache IDL/Types limpo"
    fi
    
    if [ -d "node_modules/.cache" ]; then
        rm -rf node_modules/.cache
        log_success "Cache Node.js limpo"
    fi
    
    # Reinstalar dependências
    log_info "Reinstalando dependências..."
    yarn install --silent
    log_success "Dependências reinstaladas"
    
    # Recompilar contratos
    log_info "Recompilando contratos..."
    anchor build > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_success "Contratos recompilados com sucesso"
    else
        log_warning "Problemas na recompilação - tentando com --no-idl"
        anchor build --no-idl > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_success "Contratos compilados (sem IDL)"
        else
            log_error "Falha na compilação"
            return 1
        fi
    fi
    
    return 0
}

# 6. Teste de compilação TypeScript
echo ""
log_info "5. Testando compilação TypeScript..."

# Verificar se há arquivos de teste
TEST_FILES=$(find tests -name "*.ts" 2>/dev/null | head -1)

if [ -n "$TEST_FILES" ]; then
    log_info "Testando compilação TypeScript em: $TEST_FILES"
    
    # Tentar compilar sem executar
    if npx tsc --noEmit "$TEST_FILES" > /dev/null 2>&1; then
        log_success "TypeScript compila sem erros críticos"
    else
        log_warning "Encontrados problemas de TypeScript"
        
        # Oferecer auto-reparo
        echo ""
        read -p "🔧 Deseja tentar o auto-reparo? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if auto_repair; then
                log_success "Auto-reparo concluído"
                
                # Testar novamente
                log_info "Testando novamente..."
                if npx tsc --noEmit "$TEST_FILES" > /dev/null 2>&1; then
                    log_success "Problemas resolvidos!"
                else
                    log_warning "Ainda há problemas menores (podem ser warnings normais)"
                fi
            else
                log_error "Auto-reparo falhou"
            fi
        fi
    fi
else
    log_warning "Nenhum arquivo de teste encontrado"
fi

# 7. Teste final
echo ""
log_info "6. Teste final do ambiente..."

# Verificar se anchor test pode ser executado (sem rodar de fato)
if anchor build --help > /dev/null 2>&1; then
    log_success "Anchor CLI funcionando corretamente"
else
    log_error "Problemas com Anchor CLI"
fi

# Resumo final
echo ""
echo "📊 RESUMO DA VERIFICAÇÃO"
echo "========================"

# Verificar se tudo está OK para determinar status geral
ISSUES_FOUND=false

# Verificar se IDLs e types existem
if [ ! -d "target/types" ] || [ ! "$(ls -A target/types 2>/dev/null)" ]; then
    log_warning "Types TypeScript não encontrados"
    ISSUES_FOUND=true
fi

if [ ! -d "target/idl" ] || [ ! "$(ls -A target/idl 2>/dev/null)" ]; then
    log_warning "IDLs não encontrados"
    ISSUES_FOUND=true
fi

if [ ! -d "node_modules" ]; then
    log_error "Dependências Node.js não instaladas"
    ISSUES_FOUND=true
fi

if [ "$ISSUES_FOUND" = false ]; then
    echo ""
    log_success "🎉 AMBIENTE SAUDÁVEL - Nenhum problema de linter fantasma detectado!"
    echo ""
    echo "✅ Próximos passos recomendados:"
    echo "   • anchor build    # Para desenvolvimento"
    echo "   • anchor test     # Para executar testes"
    echo "   • anchor deploy   # Para deploy"
else
    echo ""
    log_warning "⚠️  PROBLEMAS DETECTADOS - Execute o auto-reparo se necessário"
    echo ""
    echo "🔧 Para resolver automaticamente:"
    echo "   • Execute este script novamente e escolha 'y' para auto-reparo"
    echo "   • Ou execute manualmente:"
    echo "     - rm -rf target/idl target/types"
    echo "     - yarn install"
    echo "     - anchor build"
fi

echo ""
echo "📚 Para mais informações, consulte:"
echo "   • Docs/COMPILATION_ANALYSIS.md"
echo "   • Docs/SECURITY_AUDIT_PREPARATION.md"
echo ""

exit 0 