#!/bin/bash

# 🪙 GMC Ecosystem - Master SOL Management Script
# Script consolidado para gerenciamento de SOL em todos os ambientes
# Substitui múltiplos scripts de airdrop e coleta redundantes

set -euo pipefail

# Importar script de SOL management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVSECOPS_DIR="$(dirname "$SCRIPT_DIR")/devsecops"

if [[ -f "$DEVSECOPS_DIR/scripts/sol-management.sh" ]]; then
    source "$DEVSECOPS_DIR/scripts/sol-management.sh"
else
    echo "❌ Script de SOL management não encontrado!"
    echo "Execute primeiro: ./devsecops/scripts/sol-management.sh"
    exit 1
fi

# Executar SOL management com os argumentos passados
main "$@"
