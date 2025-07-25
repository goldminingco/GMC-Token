#!/bin/bash
# 🔧 Build Legacy - Versão simplificada para compatibilidade
set -e

echo "🔧 Build Legacy GMC Token para máxima compatibilidade..."

# 1. Limpar builds anteriores
echo "1. Limpando builds anteriores..."
cargo clean 2>/dev/null || true

# 2. Remover Cargo.lock que pode ter dependências problemáticas
echo "2. Removendo Cargo.lock..."
rm -f Cargo.lock

# 3. Build básico sem otimizações agressivas
echo "3. Compilando com configurações básicas..."
cd programs/gmc_token_native

# Backup do Cargo.toml atual
cp Cargo.toml Cargo.toml.backup

# Criar versão simplificada do Cargo.toml
cat > Cargo.toml << 'EOF'
[package]
name = "gmc_token_native"
version = "1.0.0"
edition = "2021"
license = "MIT"

[lib]
crate-type = ["cdylib", "lib"]

[features]
default = []

[dependencies]
solana-program = "1.18.0"
spl-token = { version = "4.0.0", features = ["no-entrypoint"] }
thiserror = "1.0"
borsh = "0.10"
bytemuck = { version = "1.14", features = ["derive"] }
EOF

# Build simples
echo "🚀 Executando build legado..."
cargo build-sbf --arch sbfv1

# Verificar se foi criado
if [ -f "target/sbf-solana-solana/release/gmc_token_native.so" ]; then
    echo "✅ Build legado realizado com sucesso!"
    
    # Copiar para pasta deploy
    cd ../..
    mkdir -p deploy
    cp programs/gmc_token_native/target/sbf-solana-solana/release/gmc_token_native.so deploy/gmc_token_legacy.so
    
    echo "📦 Artefato legado criado: deploy/gmc_token_legacy.so"
    ls -lh deploy/gmc_token_legacy.so
else
    echo "❌ Build legado falhou"
    
    # Restaurar backup
    cd programs/gmc_token_native
    cp Cargo.toml.backup Cargo.toml
    cd ../..
    exit 1
fi

# Restaurar Cargo.toml original
cd programs/gmc_token_native
cp Cargo.toml.backup Cargo.toml
cd ../..

echo "🎉 Build legado concluído!" 