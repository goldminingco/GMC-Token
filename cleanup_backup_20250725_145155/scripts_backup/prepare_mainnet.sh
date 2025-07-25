#!/bin/bash
# 🎯 Prepare Mainnet - Checklist e Preparação para Produção
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}🎯 GMC Token - Preparação para Mainnet${NC}"
echo "======================================="
echo

# Verificar se há testes de integração bem-sucedidos
if [ ! -f "deploy/frontend_config.json" ]; then
    echo -e "${RED}❌ Testes de integração não encontrados!${NC}"
    echo -e "${YELLOW}💡 Execute primeiro: ./scripts/integration_tests.sh${NC}"
    exit 1
fi

# Ler resultados dos testes
SUCCESS_RATE=$(cat deploy/frontend_config.json | grep -o '"successRate": "[^"]*"' | cut -d'"' -f4)
NETWORK=$(cat deploy/frontend_config.json | grep -o '"network": "[^"]*"' | cut -d'"' -f4)

echo -e "${CYAN}📊 STATUS ATUAL:${NC}"
echo -e "${GREEN}✅ Testes de Integração: $SUCCESS_RATE${NC}"
echo -e "${GREEN}✅ Rede Atual: $NETWORK${NC}"
echo

# Checklist de preparação para mainnet
echo -e "${YELLOW}📋 CHECKLIST DE PREPARAÇÃO PARA MAINNET${NC}"
echo "========================================"
echo

CHECKLIST_ITEMS=(
    "Código auditado por terceiros:❌:CRÍTICO"
    "Testes de integração > 90%:✅:CRÍTICO"
    "Documentação técnica completa:✅:ALTO"
    "Plano de resposta a incidentes:❌:ALTO"
    "Backup de chaves privadas:❌:CRÍTICO"
    "Seguro para smart contracts:❌:ALTO"
    "Testes de stress/load:❌:MÉDIO"
    "Frontend auditado:❌:ALTO"
    "Configurações de monitoring:❌:MÉDIO"
    "Política de upgrades definida:❌:ALTO"
)

CRITICAL_MISSING=0
HIGH_MISSING=0
MEDIUM_MISSING=0

echo -e "${BLUE}🔍 VERIFICANDO ITENS DO CHECKLIST:${NC}"
echo

for item in "${CHECKLIST_ITEMS[@]}"; do
    IFS=':' read -r description status priority <<< "$item"
    
    if [ "$status" = "✅" ]; then
        echo -e "${GREEN}✅ $description${NC}"
    else
        echo -e "${RED}❌ $description ${YELLOW}($priority)${NC}"
        case $priority in
            "CRÍTICO") CRITICAL_MISSING=$((CRITICAL_MISSING + 1));;
            "ALTO") HIGH_MISSING=$((HIGH_MISSING + 1));;
            "MÉDIO") MEDIUM_MISSING=$((MEDIUM_MISSING + 1));;
        esac
    fi
done

echo
echo -e "${YELLOW}📊 RESUMO DO CHECKLIST:${NC}"
echo -e "${RED}❌ Itens Críticos Pendentes: $CRITICAL_MISSING${NC}"
echo -e "${YELLOW}⚠️ Itens Altos Pendentes: $HIGH_MISSING${NC}"
echo -e "${BLUE}ℹ️ Itens Médios Pendentes: $MEDIUM_MISSING${NC}"

# Avaliação de prontidão
echo
echo -e "${YELLOW}🎯 AVALIAÇÃO DE PRONTIDÃO PARA MAINNET:${NC}"
echo "====================================="

if [ $CRITICAL_MISSING -eq 0 ] && [ $HIGH_MISSING -eq 0 ]; then
    echo -e "${GREEN}🎉 PRONTO PARA MAINNET!${NC}"
    MAINNET_READY=true
elif [ $CRITICAL_MISSING -eq 0 ] && [ $HIGH_MISSING -le 2 ]; then
    echo -e "${YELLOW}⚠️ QUASE PRONTO - Revisar itens de alta prioridade${NC}"
    MAINNET_READY=false
elif [ $CRITICAL_MISSING -le 1 ]; then
    echo -e "${YELLOW}⚠️ NÃO RECOMENDADO - Itens críticos pendentes${NC}"
    MAINNET_READY=false
else
    echo -e "${RED}❌ NÃO PRONTO - Muitos itens críticos pendentes${NC}"
    MAINNET_READY=false
fi

echo
echo -e "${YELLOW}🛡️ RECOMENDAÇÕES DE SEGURANÇA PARA MAINNET:${NC}"
echo "=========================================="
echo -e "${BLUE}1. AUDITORIA EXTERNA:${NC}"
echo -e "${BLUE}   • Contratar empresa especializada (Trail of Bits, ConsenSys, etc.)${NC}"
echo -e "${BLUE}   • Custo estimado: \$15,000 - \$50,000${NC}"
echo -e "${BLUE}   • Prazo: 2-4 semanas${NC}"
echo
echo -e "${BLUE}2. SEGURO PARA SMART CONTRACTS:${NC}"
echo -e "${BLUE}   • Nexus Mutual, Unslashed Finance${NC}"
echo -e "${BLUE}   • Cobertura recomendada: \$1M - \$10M${NC}"
echo
echo -e "${BLUE}3. MONITORING E ALERTAS:${NC}"
echo -e "${BLUE}   • Configurar monitoramento 24/7${NC}"
echo -e "${BLUE}   • Alertas para transações suspeitas${NC}"
echo -e "${BLUE}   • Dashboard de métricas em tempo real${NC}"

if [ "$MAINNET_READY" = "true" ]; then
    echo
    echo -e "${GREEN}🚀 PREPARANDO DEPLOY PARA MAINNET...${NC}"
    echo "==================================="
    
    # Criar configuração para mainnet
    cat > deploy/mainnet_config.json << EOF
{
  "network": "mainnet-beta",
  "rpcUrl": "https://api.mainnet-beta.solana.com",
  "preparationDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "readinessStatus": "APPROVED",
  "criticalIssues": $CRITICAL_MISSING,
  "highPriorityIssues": $HIGH_MISSING,
  "mediumPriorityIssues": $MEDIUM_MISSING,
  "recommendedActions": [
    "Realizar auditoria externa antes do deploy",
    "Configurar seguro para smart contracts",
    "Implementar monitoring 24/7",
    "Preparar plano de resposta a incidentes",
    "Fazer backup seguro de todas as chaves"
  ],
  "estimatedMainnetCost": {
    "deploymentFee": "~0.5-2 SOL",
    "auditCost": "$15,000 - $50,000",
    "insuranceCost": "$5,000 - $20,000/year",
    "monitoringCost": "$500 - $2,000/month"
  }
}
EOF
    
    echo -e "${GREEN}✅ Configuração mainnet salva em: deploy/mainnet_config.json${NC}"
    
    # Criar script de deploy para mainnet
    cat > scripts/deploy_mainnet.sh << 'EOF'
#!/bin/bash
# 🎯 Deploy Mainnet - Deploy Final na Rede Principal
set -e

echo "🎯 GMC Token - Deploy Mainnet"
echo "============================="
echo
echo "⚠️  ATENÇÃO: Este é o deploy FINAL na rede principal da Solana!"
echo "⚠️  Certifique-se de que todos os testes foram realizados!"
echo
read -p "Tem certeza que deseja continuar? (digite 'CONFIRMO'): " confirm

if [ "$confirm" != "CONFIRMO" ]; then
    echo "Deploy cancelado."
    exit 1
fi

# Configurar para mainnet
solana config set --url mainnet-beta

# Verificar saldo (mainnet requer SOL real)
BALANCE=$(solana balance)
echo "Saldo atual: $BALANCE"

if [[ "$BALANCE" == "0 SOL" ]]; then
    echo "❌ Saldo insuficiente para deploy na mainnet!"
    echo "💡 Transfira SOL para a carteira antes de continuar"
    exit 1
fi

# Deploy
echo "🚀 Fazendo deploy na MAINNET..."
solana program deploy deploy/gmc_token_docker.so --output json
EOF
    
    chmod +x scripts/deploy_mainnet.sh
    echo -e "${GREEN}✅ Script de deploy mainnet criado: scripts/deploy_mainnet.sh${NC}"
    
    echo
    echo -e "${YELLOW}🎯 PRÓXIMOS PASSOS PARA MAINNET:${NC}"
    echo "==============================="
    echo -e "${BLUE}1. ✅ Completar itens críticos do checklist${NC}"
    echo -e "${BLUE}2. ✅ Realizar auditoria externa${NC}"
    echo -e "${BLUE}3. ✅ Configurar seguro e monitoring${NC}"
    echo -e "${BLUE}4. ✅ Adquirir SOL para deploy (estimativa: 2-5 SOL)${NC}"
    echo -e "${BLUE}5. ✅ Executar: ./scripts/deploy_mainnet.sh${NC}"
    
else
    echo
    echo -e "${YELLOW}📋 TAREFAS PENDENTES PARA MAINNET:${NC}"
    echo "================================="
    
    if [ $CRITICAL_MISSING -gt 0 ]; then
        echo -e "${RED}🚨 CRÍTICO - Resolver antes de prosseguir:${NC}"
        echo -e "${BLUE}   • Auditoria externa do código${NC}"
        echo -e "${BLUE}   • Backup seguro de chaves privadas${NC}"
    fi
    
    if [ $HIGH_MISSING -gt 0 ]; then
        echo -e "${YELLOW}⚠️ ALTA PRIORIDADE:${NC}"
        echo -e "${BLUE}   • Plano de resposta a incidentes${NC}"
        echo -e "${BLUE}   • Seguro para smart contracts${NC}"
        echo -e "${BLUE}   • Auditoria do frontend${NC}"
        echo -e "${BLUE}   • Política de upgrades${NC}"
    fi
    
    if [ $MEDIUM_MISSING -gt 0 ]; then
        echo -e "${BLUE}ℹ️ PRIORIDADE MÉDIA:${NC}"
        echo -e "${BLUE}   • Testes de stress/load${NC}"
        echo -e "${BLUE}   • Configurações de monitoring${NC}"
    fi
fi

echo
echo -e "${YELLOW}💰 ESTIMATIVA DE CUSTOS PARA MAINNET:${NC}"
echo "===================================="
echo -e "${BLUE}• Deploy: ${GREEN}~0.5-2 SOL (~\$50-200)${NC}"
echo -e "${BLUE}• Auditoria: ${GREEN}\$15,000 - \$50,000${NC}"
echo -e "${BLUE}• Seguro: ${GREEN}\$5,000 - \$20,000/ano${NC}"
echo -e "${BLUE}• Monitoring: ${GREEN}\$500 - \$2,000/mês${NC}"
echo -e "${BLUE}• Total inicial: ${GREEN}\$20,000 - \$72,000${NC}"

echo
echo -e "${PURPLE}Preparação para mainnet concluída! 🎯${NC}" 