#!/bin/bash

# 🚀 GMC Ecosystem - Master Deployment Script
# Script consolidado para deployment em todos os ambientes
# Substitui múltiplos scripts de deployment redundantes

set -euo pipefail

# Importar script de deployment automation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVSECOPS_DIR="$(dirname "$SCRIPT_DIR")/devsecops"

if [[ -f "$DEVSECOPS_DIR/scripts/deployment-automation.sh" ]]; then
    source "$DEVSECOPS_DIR/scripts/deployment-automation.sh"
else
    echo "❌ Script de deployment automation não encontrado!"
    echo "Execute primeiro: ./devsecops/scripts/deployment-automation.sh"
    exit 1
fi

# Executar deployment com os argumentos passados
main "$@"
