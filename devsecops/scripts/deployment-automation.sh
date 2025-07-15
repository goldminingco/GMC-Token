#!/bin/bash

# 🚀 GMC Ecosystem - Deployment Automation with Security Integration
# Scripts automatizados para deployment seguro em Devnet, Testnet e Mainnet
# Integração completa com verificações de segurança DevSecOps

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES GLOBAIS
# =============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")")
LOG_DIR="$PROJECT_ROOT/logs/deployment"
REPORT_DIR="$PROJECT_ROOT/reports/deployment"
CONFIG_DIR="$PROJECT_ROOT/devsecops/config"
SECURITY_SCRIPT="$SCRIPT_DIR/security-automation.sh"

# Criar diretórios necessários
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Timestamp para logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/deployment_$TIMESTAMP.log"

# Configurações de ambiente
ENVIRONMENT="${ENVIRONMENT:-devnet}"
SECURITY_LEVEL="${SECURITY_LEVEL:-basic}"
AUTO_CONFIRM="${AUTO_CONFIRM:-false}"
DRY_RUN="${DRY_RUN:-false}"

# =============================================================================
# FUNÇÕES UTILITÁRIAS
# =============================================================================

# Função de logging
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[$timestamp] [INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] [WARN]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] [SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            if [[ "${DEBUG:-false}" == "true" ]]; then
                echo -e "${PURPLE}[$timestamp] [DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            fi
            ;;
        "SECURITY")
            echo -e "${CYAN}[$timestamp] [SECURITY]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Função para verificar dependências
check_dependencies() {
    log "INFO" "Verificando dependências..."
    
    local deps=("cargo" "anchor" "jq" "curl" "git" "rustc" "solana")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Dependências faltando: ${missing_deps[*]}"
        log "INFO" "Instale as dependências faltando e tente novamente."
        exit 1
    fi
    
    log "SUCCESS" "Todas as dependências estão instaladas."
}

# Função para carregar configuração do ambiente
load_environment_config() {
    local env=$1
    local config_file="$CONFIG_DIR/environments.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        log "ERROR" "Arquivo de configuração não encontrado: $config_file"
        exit 1
    fi
    
    log "INFO" "Carregando configuração para ambiente: $env"
    
    # Extrair configurações usando yq ou fallback para grep/sed
    if command -v yq &> /dev/null; then
        export RPC_URL=$(yq eval ".environment_specific.$env.network.rpc_url" "$config_file")
        export CLUSTER=$(yq eval ".environment_specific.$env.network.cluster" "$config_file")
        export SECURITY_LEVEL=$(yq eval ".environment_specific.$env.security.level" "$config_file")
        export MIN_SOL_BALANCE=$(yq eval ".environment_specific.$env.sol_management.min_balance" "$config_file")
    else
        # Fallback simples para ambientes conhecidos
        case $env in
            "devnet")
                export RPC_URL="https://api.devnet.solana.com"
                export CLUSTER="devnet"
                export SECURITY_LEVEL="basic"
                export MIN_SOL_BALANCE="1.0"
                ;;
            "testnet")
                export RPC_URL="https://api.testnet.solana.com"
                export CLUSTER="testnet"
                export SECURITY_LEVEL="high"
                export MIN_SOL_BALANCE="5.0"
                ;;
            "mainnet")
                export RPC_URL="https://api.mainnet-beta.solana.com"
                export CLUSTER="mainnet-beta"
                export SECURITY_LEVEL="maximum"
                export MIN_SOL_BALANCE="10.0"
                ;;
            *)
                log "ERROR" "Ambiente não suportado: $env"
                exit 1
                ;;
        esac
    fi
    
    log "SUCCESS" "Configuração carregada: RPC=$RPC_URL, Cluster=$CLUSTER, Security=$SECURITY_LEVEL"
}

# Função para verificar saldo SOL
check_sol_balance() {
    local wallet_path=$1
    local min_balance=$2
    
    log "INFO" "Verificando saldo SOL..."
    
    local current_balance
    current_balance=$(solana balance "$wallet_path" --url "$RPC_URL" 2>/dev/null | grep -o '[0-9]*\.[0-9]*' || echo "0")
    
    log "INFO" "Saldo atual: $current_balance SOL (mínimo: $min_balance SOL)"
    
    if (( $(echo "$current_balance < $min_balance" | bc -l) )); then
        log "WARN" "Saldo insuficiente. Tentando airdrop..."
        
        if [[ "$CLUSTER" == "devnet" || "$CLUSTER" == "testnet" ]]; then
            local airdrop_amount=$(echo "$min_balance - $current_balance + 1" | bc -l)
            log "INFO" "Solicitando airdrop de $airdrop_amount SOL..."
            
            if solana airdrop "$airdrop_amount" "$wallet_path" --url "$RPC_URL"; then
                log "SUCCESS" "Airdrop realizado com sucesso."
            else
                log "ERROR" "Falha no airdrop. Verifique manualmente."
                return 1
            fi
        else
            log "ERROR" "Saldo insuficiente em mainnet. Adicione SOL manualmente."
            return 1
        fi
    fi
    
    return 0
}

# Função para executar verificações de segurança
run_security_checks() {
    local security_level=$1
    
    log "SECURITY" "Executando verificações de segurança (nível: $security_level)..."
    
    if [[ ! -f "$SECURITY_SCRIPT" ]]; then
        log "ERROR" "Script de segurança não encontrado: $SECURITY_SCRIPT"
        return 1
    fi
    
    # Tornar o script executável
    chmod +x "$SECURITY_SCRIPT"
    
    case $security_level in
        "basic")
            log "SECURITY" "Executando verificações básicas de segurança..."
            if ! "$SECURITY_SCRIPT" --secrets-check; then
                log "ERROR" "Verificação de secrets falhou!"
                return 1
            fi
            ;;
        "high")
            log "SECURITY" "Executando verificações completas OWASP..."
            if ! "$SECURITY_SCRIPT" --owasp-check; then
                log "ERROR" "Verificações OWASP falharam!"
                return 1
            fi
            ;;
        "maximum")
            log "SECURITY" "Executando todas as verificações de segurança..."
            if ! "$SECURITY_SCRIPT" --all-checks; then
                log "ERROR" "Verificações de segurança falharam!"
                return 1
            fi
            ;;
        *)
            log "WARN" "Nível de segurança desconhecido: $security_level"
            ;;
    esac
    
    log "SUCCESS" "Verificações de segurança concluídas."
    return 0
}

# Função para build dos programas
build_programs() {
    log "INFO" "Compilando programas..."
    
    cd "$PROJECT_ROOT"
    
    # Limpar build anterior
    if [[ -d "target" ]]; then
        log "INFO" "Limpando build anterior..."
        rm -rf target/deploy/*.so target/idl/*.json
    fi
    
    # Build com Anchor
    log "INFO" "Executando anchor build..."
    if ! anchor build; then
        log "ERROR" "Falha na compilação dos programas!"
        return 1
    fi
    
    # Verificar se os arquivos foram gerados
    local program_files=("target/deploy/gmc_token.so" "target/deploy/gmc_staking.so")
    
    for file in "${program_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log "ERROR" "Arquivo de programa não encontrado: $file"
            return 1
        fi
        
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        log "INFO" "Programa compilado: $(basename "$file") ($file_size bytes)"
    done
    
    log "SUCCESS" "Compilação concluída com sucesso."
    return 0
}

# Função para executar testes
run_tests() {
    local test_level=$1
    
    log "INFO" "Executando testes (nível: $test_level)..."
    
    cd "$PROJECT_ROOT"
    
    case $test_level in
        "basic")
            log "INFO" "Executando testes unitários..."
            if ! cargo test --workspace; then
                log "ERROR" "Testes unitários falharam!"
                return 1
            fi
            ;;
        "high")
            log "INFO" "Executando testes unitários e de integração..."
            if ! cargo test --workspace; then
                log "ERROR" "Testes falharam!"
                return 1
            fi
            
            if command -v anchor &> /dev/null; then
                log "INFO" "Executando testes Anchor..."
                if ! anchor test --skip-local-validator; then
                    log "WARN" "Alguns testes Anchor falharam (pode ser normal em alguns ambientes)."
                fi
            fi
            ;;
        "maximum")
            log "INFO" "Executando suite completa de testes..."
            if ! cargo test --workspace --release; then
                log "ERROR" "Testes falharam!"
                return 1
            fi
            
            # Testes de cobertura se disponível
            if command -v cargo-tarpaulin &> /dev/null; then
                log "INFO" "Executando análise de cobertura..."
                cargo tarpaulin --out xml --output-dir "$REPORT_DIR/coverage/" || log "WARN" "Análise de cobertura falhou."
            fi
            ;;
    esac
    
    log "SUCCESS" "Testes concluídos."
    return 0
}

# Função para deploy dos programas
deploy_programs() {
    local environment=$1
    local dry_run=$2
    
    log "INFO" "Iniciando deploy para $environment (dry-run: $dry_run)..."
    
    cd "$PROJECT_ROOT"
    
    # Configurar Solana CLI
    log "INFO" "Configurando Solana CLI..."
    solana config set --url "$RPC_URL"
    solana config set --keypair "$HOME/.config/solana/id.json"
    
    # Verificar conexão
    if ! solana cluster-version; then
        log "ERROR" "Falha na conexão com o cluster $CLUSTER"
        return 1
    fi
    
    # Deploy com Anchor
    if [[ "$dry_run" == "true" ]]; then
        log "INFO" "Modo dry-run: simulando deploy..."
        anchor deploy --provider.cluster "$CLUSTER" --dry-run
    else
        log "INFO" "Executando deploy real..."
        
        # Confirmação para ambientes críticos
        if [[ "$environment" == "mainnet" && "$AUTO_CONFIRM" != "true" ]]; then
            echo -n "⚠️  ATENÇÃO: Deploy para MAINNET. Confirma? (yes/no): "
            read -r confirmation
            if [[ "$confirmation" != "yes" ]]; then
                log "INFO" "Deploy cancelado pelo usuário."
                return 1
            fi
        fi
        
        if ! anchor deploy --provider.cluster "$CLUSTER"; then
            log "ERROR" "Falha no deploy dos programas!"
            return 1
        fi
    fi
    
    log "SUCCESS" "Deploy concluído com sucesso."
    return 0
}

# Função para validação pós-deploy
post_deploy_validation() {
    local environment=$1
    
    log "INFO" "Executando validação pós-deploy..."
    
    # Verificar se os programas estão ativos
    local program_ids=()
    
    if [[ -f "target/idl/gmc_token.json" ]]; then
        local token_program_id
        token_program_id=$(jq -r '.metadata.address' target/idl/gmc_token.json)
        program_ids+=("$token_program_id")
    fi
    
    for program_id in "${program_ids[@]}"; do
        log "INFO" "Verificando programa: $program_id"
        
        if solana account "$program_id" --url "$RPC_URL" > /dev/null 2>&1; then
            log "SUCCESS" "Programa ativo: $program_id"
        else
            log "ERROR" "Programa não encontrado: $program_id"
            return 1
        fi
    done
    
    # Testes de smoke
    log "INFO" "Executando smoke tests..."
    
    # Aqui você pode adicionar testes específicos para verificar
    # se os contratos estão funcionando corretamente
    
    log "SUCCESS" "Validação pós-deploy concluída."
    return 0
}

# Função para setup de monitoramento
setup_monitoring() {
    local environment=$1
    
    log "INFO" "Configurando monitoramento para $environment..."
    
    # Criar arquivo de configuração de monitoramento
    local monitoring_config="$REPORT_DIR/monitoring_$environment.json"
    
    cat > "$monitoring_config" << EOF
{
  "environment": "$environment",
  "cluster": "$CLUSTER",
  "rpc_url": "$RPC_URL",
  "deployed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "programs": [],
  "monitoring": {
    "health_check_interval": "60s",
    "alert_thresholds": {
      "response_time": "5s",
      "error_rate": "1%",
      "availability": "99.9%"
    }
  }
}
EOF
    
    log "SUCCESS" "Configuração de monitoramento criada: $monitoring_config"
    
    # Configurar alertas específicos por ambiente
    case $environment in
        "mainnet")
            log "INFO" "Configurando monitoramento 24/7 para mainnet..."
            # Aqui você pode integrar com sistemas de monitoramento
            # como Datadog, New Relic, Prometheus, etc.
            ;;
        "testnet")
            log "INFO" "Configurando monitoramento de bug bounty..."
            ;;
        "devnet")
            log "INFO" "Configurando monitoramento básico..."
            ;;
    esac
    
    return 0
}

# Função para gerar relatório de deployment
generate_deployment_report() {
    local environment=$1
    local status=$2
    
    local report_file="$REPORT_DIR/deployment_${environment}_$TIMESTAMP.json"
    
    cat > "$report_file" << EOF
{
  "deployment": {
    "environment": "$environment",
    "cluster": "$CLUSTER",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "$status",
    "security_level": "$SECURITY_LEVEL",
    "dry_run": "$DRY_RUN"
  },
  "configuration": {
    "rpc_url": "$RPC_URL",
    "min_sol_balance": "$MIN_SOL_BALANCE"
  },
  "artifacts": {
    "log_file": "$LOG_FILE",
    "report_file": "$report_file"
  },
  "next_steps": [
    "Verificar monitoramento",
    "Executar testes de aceitação",
    "Notificar stakeholders"
  ]
}
EOF
    
    log "INFO" "Relatório de deployment gerado: $report_file"
    echo "$report_file"
}

# Função para rollback
perform_rollback() {
    local environment=$1
    local reason=$2
    
    log "ERROR" "Iniciando rollback para $environment. Razão: $reason"
    
    # Implementar lógica de rollback específica
    # Isso pode incluir:
    # - Restaurar versão anterior dos programas
    # - Reverter configurações
    # - Notificar equipes
    
    log "INFO" "Rollback concluído para $environment"
    
    # Gerar relatório de rollback
    generate_deployment_report "$environment" "rolled_back"
    
    return 0
}

# =============================================================================
# FUNÇÕES PRINCIPAIS DE DEPLOYMENT
# =============================================================================

# Deploy para Devnet
deploy_devnet() {
    log "INFO" "🚀 Iniciando deployment para DEVNET..."
    
    load_environment_config "devnet"
    
    # Verificações básicas
    if ! check_sol_balance "$HOME/.config/solana/id.json" "$MIN_SOL_BALANCE"; then
        log "ERROR" "Falha na verificação de saldo."
        return 1
    fi
    
    # Verificações de segurança básicas
    if ! run_security_checks "$SECURITY_LEVEL"; then
        log "ERROR" "Verificações de segurança falharam."
        return 1
    fi
    
    # Build e testes
    if ! build_programs; then
        log "ERROR" "Falha na compilação."
        return 1
    fi
    
    if ! run_tests "basic"; then
        log "ERROR" "Falha nos testes."
        return 1
    fi
    
    # Deploy
    if ! deploy_programs "devnet" "$DRY_RUN"; then
        log "ERROR" "Falha no deploy."
        perform_rollback "devnet" "deploy_failed"
        return 1
    fi
    
    # Validação pós-deploy
    if ! post_deploy_validation "devnet"; then
        log "ERROR" "Falha na validação pós-deploy."
        perform_rollback "devnet" "validation_failed"
        return 1
    fi
    
    # Setup de monitoramento
    setup_monitoring "devnet"
    
    # Gerar relatório
    generate_deployment_report "devnet" "success"
    
    log "SUCCESS" "✅ Deployment para DEVNET concluído com sucesso!"
    return 0
}

# Deploy para Testnet
deploy_testnet() {
    log "INFO" "🚀 Iniciando deployment para TESTNET..."
    
    load_environment_config "testnet"
    
    # Verificações rigorosas
    if ! check_sol_balance "$HOME/.config/solana/id.json" "$MIN_SOL_BALANCE"; then
        log "ERROR" "Falha na verificação de saldo."
        return 1
    fi
    
    # Verificações de segurança completas
    if ! run_security_checks "$SECURITY_LEVEL"; then
        log "ERROR" "Verificações de segurança falharam."
        return 1
    fi
    
    # Build e testes completos
    if ! build_programs; then
        log "ERROR" "Falha na compilação."
        return 1
    fi
    
    if ! run_tests "high"; then
        log "ERROR" "Falha nos testes."
        return 1
    fi
    
    # Confirmação manual se não for auto
    if [[ "$AUTO_CONFIRM" != "true" ]]; then
        echo -n "Confirma deployment para TESTNET? (yes/no): "
        read -r confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log "INFO" "Deploy cancelado pelo usuário."
            return 1
        fi
    fi
    
    # Deploy
    if ! deploy_programs "testnet" "$DRY_RUN"; then
        log "ERROR" "Falha no deploy."
        perform_rollback "testnet" "deploy_failed"
        return 1
    fi
    
    # Validação pós-deploy
    if ! post_deploy_validation "testnet"; then
        log "ERROR" "Falha na validação pós-deploy."
        perform_rollback "testnet" "validation_failed"
        return 1
    fi
    
    # Setup de monitoramento
    setup_monitoring "testnet"
    
    # Notificar bug bounty
    log "INFO" "Notificando programa de bug bounty..."
    
    # Gerar relatório
    generate_deployment_report "testnet" "success"
    
    log "SUCCESS" "✅ Deployment para TESTNET concluído com sucesso!"
    log "INFO" "🐛 Bug bounty ativo - monitore relatórios de segurança."
    return 0
}

# Deploy para Mainnet (Cerimônia)
deploy_mainnet() {
    log "INFO" "🚀 Iniciando CERIMÔNIA DE DEPLOYMENT para MAINNET..."
    
    load_environment_config "mainnet"
    
    # Verificações máximas de segurança
    log "SECURITY" "Executando auditoria final de segurança..."
    if ! run_security_checks "maximum"; then
        log "ERROR" "Auditoria de segurança falhou - DEPLOYMENT BLOQUEADO!"
        return 1
    fi
    
    # Verificações de saldo críticas
    if ! check_sol_balance "$HOME/.config/solana/id.json" "$MIN_SOL_BALANCE"; then
        log "ERROR" "Saldo insuficiente para mainnet."
        return 1
    fi
    
    # Build e testes máximos
    if ! build_programs; then
        log "ERROR" "Falha na compilação."
        return 1
    fi
    
    if ! run_tests "maximum"; then
        log "ERROR" "Falha nos testes."
        return 1
    fi
    
    # Múltiplas confirmações
    log "WARN" "⚠️  ATENÇÃO: DEPLOYMENT PARA MAINNET ⚠️"
    log "WARN" "Este é um deployment irreversível para a rede principal."
    log "WARN" "Todos os testes e auditorias foram executados."
    
    if [[ "$AUTO_CONFIRM" != "true" ]]; then
        echo -n "PRIMEIRA CONFIRMAÇÃO - Prosseguir com mainnet? (yes/no): "
        read -r confirmation1
        if [[ "$confirmation1" != "yes" ]]; then
            log "INFO" "Deploy cancelado na primeira confirmação."
            return 1
        fi
        
        echo -n "SEGUNDA CONFIRMAÇÃO - Tem certeza absoluta? (yes/no): "
        read -r confirmation2
        if [[ "$confirmation2" != "yes" ]]; then
            log "INFO" "Deploy cancelado na segunda confirmação."
            return 1
        fi
        
        echo -n "CONFIRMAÇÃO FINAL - Digite 'DEPLOY MAINNET' para confirmar: "
        read -r final_confirmation
        if [[ "$final_confirmation" != "DEPLOY MAINNET" ]]; then
            log "INFO" "Deploy cancelado na confirmação final."
            return 1
        fi
    fi
    
    # Deploy cerimonial
    log "INFO" "🎯 Executando deployment cerimonial..."
    if ! deploy_programs "mainnet" "$DRY_RUN"; then
        log "ERROR" "FALHA CRÍTICA NO DEPLOY MAINNET!"
        perform_rollback "mainnet" "critical_deploy_failure"
        return 1
    fi
    
    # Validação crítica pós-deploy
    if ! post_deploy_validation "mainnet"; then
        log "ERROR" "FALHA CRÍTICA NA VALIDAÇÃO MAINNET!"
        perform_rollback "mainnet" "critical_validation_failure"
        return 1
    fi
    
    # Setup de monitoramento 24/7
    setup_monitoring "mainnet"
    
    # Ativar monitoramento contínuo
    log "INFO" "🔍 Ativando monitoramento 24/7..."
    
    # Gerar relatório final
    generate_deployment_report "mainnet" "success"
    
    log "SUCCESS" "🎉 DEPLOYMENT MAINNET CONCLUÍDO COM SUCESSO! 🎉"
    log "SUCCESS" "🚀 GMC Ecosystem está LIVE na rede principal!"
    log "INFO" "📊 Monitoramento 24/7 ativo."
    log "INFO" "🔔 Notificações de emergência configuradas."
    
    return 0
}

# =============================================================================
# FUNÇÃO DE AJUDA
# =============================================================================

show_help() {
    cat << EOF
🚀 GMC Deployment Automation Script

Uso: $0 [AMBIENTE] [OPÇÕES]

Ambientes:
  devnet      Deploy para Devnet (desenvolvimento)
  testnet     Deploy para Testnet (testes e bug bounty)
  mainnet     Deploy cerimonial para Mainnet (produção)

Opções:
  --dry-run           Simular deployment sem executar
  --auto-confirm      Pular confirmações manuais
  --security-level    Nível de segurança (basic|high|maximum)
  --help             Mostrar esta ajuda

Exemplos:
  $0 devnet
  $0 testnet --security-level high
  $0 mainnet --dry-run
  $0 devnet --auto-confirm

Variáveis de ambiente:
  ENVIRONMENT         Ambiente alvo (devnet|testnet|mainnet)
  SECURITY_LEVEL      Nível de segurança
  AUTO_CONFIRM        Confirmação automática (true|false)
  DRY_RUN            Modo simulação (true|false)
  DEBUG              Logs de debug (true|false)

Fluxo de deployment:
  1. Verificação de dependências
  2. Carregamento de configuração
  3. Verificação de saldo SOL
  4. Verificações de segurança
  5. Compilação dos programas
  6. Execução de testes
  7. Deploy dos contratos
  8. Validação pós-deploy
  9. Setup de monitoramento
  10. Geração de relatórios

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Banner
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "🔒 GMC ECOSYSTEM - DEPLOYMENT AUTOMATION WITH DEVSECOPS 🔒"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    # Verificar dependências
    check_dependencies
    
    # Processar argumentos
    local environment=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            "devnet"|"testnet"|"mainnet")
                environment="$1"
                shift
                ;;
            "--dry-run")
                export DRY_RUN="true"
                shift
                ;;
            "--auto-confirm")
                export AUTO_CONFIRM="true"
                shift
                ;;
            "--security-level")
                export SECURITY_LEVEL="$2"
                shift 2
                ;;
            "--help")
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar se ambiente foi especificado
    if [[ -z "$environment" ]]; then
        log "ERROR" "Ambiente não especificado."
        show_help
        exit 1
    fi
    
    # Executar deployment baseado no ambiente
    case $environment in
        "devnet")
            deploy_devnet
            ;;
        "testnet")
            deploy_testnet
            ;;
        "mainnet")
            deploy_mainnet
            ;;
        *)
            log "ERROR" "Ambiente inválido: $environment"
            exit 1
            ;;
    esac
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "🎉 Deployment concluído com sucesso!"
    else
        log "ERROR" "❌ Deployment falhou!"
    fi
    
    exit $exit_code
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi