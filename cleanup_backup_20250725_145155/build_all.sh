#!/bin/bash
# Script para compilar o programa GMC Token (Native Rust) de forma robusta.

set -e # Encerra o script se qualquer comando falhar

PROGRAM_PATH="programs/gmc_token_native"
DEPLOY_DIR="deploy"
ARTIFACT_NAME="gmc_token.so"

# Limpa o ambiente de compilação anterior de forma segura
echo "Cleaning up previous build artifacts for $PROGRAM_PATH..."
(cd "$PROGRAM_PATH" && cargo clean)

# Remove Cargo.lock se existir (incompatível com cargo build-sbf)
echo "Removing incompatible Cargo.lock files..."
rm -f Cargo.lock
rm -f "$PROGRAM_PATH/Cargo.lock"

# Gerar Cargo.lock compatível usando toolchain solana
echo "Generating compatible Cargo.lock..."
(cd "$PROGRAM_PATH" && cargo +stable generate-lockfile 2>/dev/null || cargo generate-lockfile)

# Compilar o programa gmc_token_native
echo "Compiling the gmc_token_native program..."
# Trabalhar diretamente no diretório do programa para evitar workspace lockfile issues
cd "$PROGRAM_PATH"
# Remover qualquer Cargo.lock que possa existir
rm -f Cargo.lock
# Compilar usando cargo build-sbf
cargo build-sbf --arch sbfv2
# Voltar ao diretório raiz
cd ../..

# Criar diretório de deploy se não existir
echo "Creating deploy directory..."
mkdir -p "$DEPLOY_DIR"

# Define o caminho de origem do artefato
SOURCE_ARTIFACT_PATH="$PROGRAM_PATH/target/sbf-solana-solana/release/gmc_token_native.so"

# Copiar o artefato de build para o diretório de deploy
echo "Copying artifact from $SOURCE_ARTIFACT_PATH..."
cp "$SOURCE_ARTIFACT_PATH" "$DEPLOY_DIR/$ARTIFACT_NAME"

echo "✅ Build complete. Artifact copied to $DEPLOY_DIR/$ARTIFACT_NAME"
