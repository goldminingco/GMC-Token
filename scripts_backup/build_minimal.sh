#!/bin/bash
# 🔧 Build Minimal - Versão absolutamente mínima para deploy
set -e

echo "🔧 Build Minimal GMC Token - Versão básica..."

# 1. Limpar builds anteriores
echo "1. Limpando builds anteriores..."
cargo clean 2>/dev/null || true
rm -f Cargo.lock

# 2. Backup e substituir arquivos
echo "2. Criando versão mínima..."
cd programs/gmc_token_native

# Backup do lib.rs original
cp src/lib.rs src/lib.rs.backup

# Usar a versão mínima
cp src/lib_minimal.rs src/lib.rs

# Criar Cargo.toml mínimo
cp Cargo.toml Cargo.toml.backup

cat > Cargo.toml << 'EOF'
[package]
name = "gmc_token_native"
version = "1.0.0"
edition = "2021"
license = "MIT"

[lib]
crate-type = ["cdylib", "lib"]

[dependencies]
solana-program = "1.18.0"
borsh = "0.10"

[dev-dependencies]
solana-program-test = "1.18.0"
EOF

# 3. Build mínimo
echo "3. Compilando versão mínima..."
cargo build-sbf --arch sbfv1

# 4. Verificar e copiar
if [ -f "target/sbf-solana-solana/release/gmc_token_native.so" ]; then
    echo "✅ Build mínimo realizado com sucesso!"
    
    # Copiar para pasta deploy
    cd ../..
    mkdir -p deploy
    cp programs/gmc_token_native/target/sbf-solana-solana/release/gmc_token_native.so deploy/gmc_token_minimal.so
    
    echo "📦 Artefato mínimo criado: deploy/gmc_token_minimal.so"
    ls -lh deploy/gmc_token_minimal.so
    
    echo "🎉 Build mínimo pronto para deploy!"
else
    echo "❌ Build mínimo falhou"
    
    # Restaurar backups
    cd programs/gmc_token_native
    cp src/lib.rs.backup src/lib.rs
    cp Cargo.toml.backup Cargo.toml
    cd ../..
    exit 1
fi

# 5. Restaurar arquivos originais
echo "4. Restaurando arquivos originais..."
cd programs/gmc_token_native
cp src/lib.rs.backup src/lib.rs
cp Cargo.toml.backup Cargo.toml
cd ../..

echo "🎉 Deploy mínimo concluído! Use: deploy/gmc_token_minimal.so" 