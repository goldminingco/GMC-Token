#!/bin/bash

# Script para compilar todos os programas do workspace individualmente,
# contornando problemas de ambiente do 'anchor build'.

set -e # Encerra o script se qualquer comando falhar

# Caminho absoluto para a versão correta do cargo
CARGO_PATH="/Users/cliente/.cargo/bin/cargo"

# Limpa o ambiente de compilação anterior
echo "Limpando ambiente de compilação..."
rm -f Cargo.lock
rm -rf target

# Lista de programas no workspace
PROGRAMS=(
    "programs/gmc_staking"
    "programs/gmc_ranking"
    "programs/gmc_vesting"
    "programs/gmc_treasury"
)

# Compila cada programa
for program in "${PROGRAMS[@]}"
do
    echo "Limpando Cargo.lock para a compilação de $program..."
    rm -f Cargo.lock # Garante que não há lock file antes de cada compilação
    echo "Compilando $program..."
    (cd "$program" && $CARGO_PATH build-sbf)
done

echo "Compilação de todos os programas concluída com sucesso!"
