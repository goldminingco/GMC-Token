#!/bin/bash

# 🎯 GMC Ecosystem - DevSecOps Orchestrator
# Orquestrador principal para automação DevSecOps completa
# Integra segurança, deployment, monitoramento e observabilidade

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
LOG_DIR="$PROJECT_ROOT/logs/orchestrator"
REPORT_DIR="$PROJECT_ROOT/reports/orchestrator"
CONFIG_DIR="$PROJECT_ROOT/devsecops/config"
SCRIPTS_DIR="$PROJECT_ROOT/devsecops/scripts"

# Criar diretórios necessários
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Timestamp para logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/orchestrator_$TIMESTAMP.log"

# Configurações padrão
ENVIRONMENT="${ENVIRONMENT:-devnet}"
OPERATION="${OPERATION:-full-pipeline}"
SKIP_SECURITY="${SKIP_SECURITY:-false}"
SKIP_DEPLOYMENT="${SKIP_DEPLOYMENT:-false}"
SKIP_MONITORING="${SKIP_MONITORING:-false}"
CONTINUOUS_MONITORING="${CONTINUOUS_MONITORING:-false}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
PARALLEL="${PARALLEL:-false}"

# Configurações de segurança
SECURITY_THRESHOLD="${SECURITY_THRESHOLD:-80}"
REQUIRE_APPROVAL="${REQUIRE_APPROVAL:-true}"
AUTO_ROLLBACK="${AUTO_ROLLBACK:-true}"

# Configurações de notificação
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
EMAIL_ALERTS="${EMAIL_ALERTS:-}"
TEAMS_WEBHOOK="${TEAMS_WEBHOOK:-}"

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
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${PURPLE}[$timestamp] [DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            fi
            ;;
        "ORCHESTRATOR")
            echo -e "${CYAN}[$timestamp] [🎯 ORCHESTRATOR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SECURITY")
            echo -e "${RED}[$timestamp] [🔒 SECURITY]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "DEPLOY")
            echo -e "${GREEN}[$timestamp] [🚀 DEPLOY]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "MONITOR")
            echo -e "${PURPLE}[$timestamp] [📊 MONITOR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Função para verificar dependências
check_dependencies() {
    log "INFO" "Verificando dependências..."
    
    local deps=("curl" "jq" "yq" "bc" "solana" "anchor")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Dependências faltando: ${missing_deps[*]}"
        log "INFO" "Instale as dependências e tente novamente."
        return 1
    fi
    
    log "SUCCESS" "Todas as dependências estão disponíveis"
    return 0
}

# Função para verificar scripts DevSecOps
check_devsecops_scripts() {
    log "INFO" "Verificando scripts DevSecOps..."
    
    local required_scripts=(
        "security-automation.sh"
        "deployment-automation.sh"
        "monitoring-automation.sh"
        "sol-management.sh"
        "cleanup-and-consolidate.sh"
    )
    
    local missing_scripts=()
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
            missing_scripts+=("$script")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log "ERROR" "Scripts DevSecOps faltando: ${missing_scripts[*]}"
        return 1
    fi
    
    # Verificar se scripts são executáveis
    for script in "${required_scripts[@]}"; do
        if [[ ! -x "$SCRIPTS_DIR/$script" ]]; then
            log "WARN" "Tornando $script executável..."
            chmod +x "$SCRIPTS_DIR/$script"
        fi
    done
    
    log "SUCCESS" "Todos os scripts DevSecOps estão disponíveis"
    return 0
}

# Função para solicitar aprovação
request_approval() {
    local operation=$1
    local environment=$2
    
    if [[ "$REQUIRE_APPROVAL" == "false" || "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo
    log "WARN" "🚨 APROVAÇÃO NECESSÁRIA 🚨"
    log "INFO" "Operação: $operation"
    log "INFO" "Ambiente: $environment"
    echo
    
    if [[ "$environment" == "mainnet" ]]; then
        log "ERROR" "⚠️  ATENÇÃO: OPERAÇÃO EM MAINNET ⚠️"
        log "WARN" "Esta operação afetará o ambiente de produção!"
        echo
    fi
    
    read -p "Deseja continuar? (digite 'CONFIRMO' para prosseguir): " confirmation
    
    if [[ "$confirmation" != "CONFIRMO" ]]; then
        log "WARN" "Operação cancelada pelo usuário"
        exit 1
    fi
    
    log "SUCCESS" "Aprovação concedida"
    return 0
}

# Função para enviar notificações
send_notification() {
    local title=$1
    local message=$2
    local status=$3  # success, warning, error
    
    local color
    local emoji
    
    case $status in
        "success")
            color="#28a745"
            emoji="✅"
            ;;
        "warning")
            color="#ffc107"
            emoji="⚠️"
            ;;
        "error")
            color="#dc3545"
            emoji="❌"
            ;;
        *)
            color="#007bff"
            emoji="ℹ️"
            ;;
    esac
    
    # Slack
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local slack_payload
        slack_payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "$emoji $title",
            "text": "$message",
            "fields": [
                {
                    "title": "Environment",
                    "value": "$ENVIRONMENT",
                    "short": true
                },
                {
                    "title": "Operation",
                    "value": "$OPERATION",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date)",
                    "short": false
                }
            ]
        }
    ]
}
EOF
        )
        
        curl -s -X POST \
            -H 'Content-type: application/json' \
            --data "$slack_payload" \
            "$SLACK_WEBHOOK" > /dev/null 2>&1 || log "WARN" "Falha ao enviar notificação Slack"
    fi
    
    # Teams
    if [[ -n "$TEAMS_WEBHOOK" ]]; then
        local teams_payload
        teams_payload=$(cat << EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "$color",
    "summary": "$title",
    "sections": [
        {
            "activityTitle": "$emoji $title",
            "activitySubtitle": "GMC DevSecOps Orchestrator",
            "text": "$message",
            "facts": [
                {
                    "name": "Environment",
                    "value": "$ENVIRONMENT"
                },
                {
                    "name": "Operation",
                    "value": "$OPERATION"
                },
                {
                    "name": "Timestamp",
                    "value": "$(date)"
                }
            ]
        }
    ]
}
EOF
        )
        
        curl -s -X POST \
            -H 'Content-type: application/json' \
            --data "$teams_payload" \
            "$TEAMS_WEBHOOK" > /dev/null 2>&1 || log "WARN" "Falha ao enviar notificação Teams"
    fi
    
    # Email
    if [[ -n "$EMAIL_ALERTS" ]]; then
        local subject="GMC DevSecOps: $title"
        echo -e "$message\n\nEnvironment: $ENVIRONMENT\nOperation: $OPERATION\nTimestamp: $(date)" | \
            mail -s "$subject" "$EMAIL_ALERTS" 2>/dev/null || log "WARN" "Falha ao enviar email"
    fi
}

# =============================================================================
# OPERAÇÕES PRINCIPAIS
# =============================================================================

# Função para executar verificações de segurança
run_security_checks() {
    if [[ "$SKIP_SECURITY" == "true" ]]; then
        log "WARN" "Verificações de segurança foram puladas"
        return 0
    fi
    
    log "SECURITY" "Executando verificações de segurança..."
    
    local security_script="$SCRIPTS_DIR/security-automation.sh"
    
    if [[ ! -f "$security_script" ]]; then
        log "ERROR" "Script de segurança não encontrado: $security_script"
        return 1
    fi
    
    # Executar verificações de segurança
    local security_output
    if ! security_output=$("$security_script" --environment "$ENVIRONMENT" --format json 2>&1); then
        log "ERROR" "Falha nas verificações de segurança"
        log "ERROR" "Output: $security_output"
        
        send_notification "Security Check Failed" "Verificações de segurança falharam para $ENVIRONMENT" "error"
        return 1
    fi
    
    # Verificar score de segurança
    local security_score
    security_score=$(echo "$security_output" | jq -r '.security_summary.overall_score' 2>/dev/null || echo "0")
    
    log "SECURITY" "Score de segurança: $security_score%"
    
    if [[ $(echo "$security_score < $SECURITY_THRESHOLD" | bc -l) -eq 1 ]]; then
        log "ERROR" "Score de segurança abaixo do threshold ($SECURITY_THRESHOLD%)"
        
        if [[ "$FORCE" != "true" ]]; then
            send_notification "Security Threshold Not Met" "Score: $security_score% (required: $SECURITY_THRESHOLD%)" "error"
            return 1
        else
            log "WARN" "Continuando devido ao flag --force"
        fi
    fi
    
    log "SUCCESS" "Verificações de segurança aprovadas"
    send_notification "Security Checks Passed" "Score: $security_score% ✅" "success"
    return 0
}

# Função para executar deployment
run_deployment() {
    if [[ "$SKIP_DEPLOYMENT" == "true" ]]; then
        log "WARN" "Deployment foi pulado"
        return 0
    fi
    
    log "DEPLOY" "Executando deployment para $ENVIRONMENT..."
    
    local deployment_script="$SCRIPTS_DIR/deployment-automation.sh"
    
    if [[ ! -f "$deployment_script" ]]; then
        log "ERROR" "Script de deployment não encontrado: $deployment_script"
        return 1
    fi
    
    # Preparar argumentos
    local deploy_args=("--environment" "$ENVIRONMENT")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        deploy_args+=("--dry-run")
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        deploy_args+=("--verbose")
    fi
    
    if [[ "$AUTO_ROLLBACK" == "true" ]]; then
        deploy_args+=("--auto-rollback")
    fi
    
    # Executar deployment
    local deployment_output
    if ! deployment_output=$("$deployment_script" "${deploy_args[@]}" 2>&1); then
        log "ERROR" "Falha no deployment"
        log "ERROR" "Output: $deployment_output"
        
        send_notification "Deployment Failed" "Deployment falhou para $ENVIRONMENT" "error"
        return 1
    fi
    
    log "SUCCESS" "Deployment concluído com sucesso"
    send_notification "Deployment Successful" "Deployment concluído para $ENVIRONMENT ✅" "success"
    return 0
}

# Função para executar monitoramento
run_monitoring() {
    if [[ "$SKIP_MONITORING" == "true" ]]; then
        log "WARN" "Monitoramento foi pulado"
        return 0
    fi
    
    log "MONITOR" "Executando monitoramento para $ENVIRONMENT..."
    
    local monitoring_script="$SCRIPTS_DIR/monitoring-automation.sh"
    
    if [[ ! -f "$monitoring_script" ]]; then
        log "ERROR" "Script de monitoramento não encontrado: $monitoring_script"
        return 1
    fi
    
    # Preparar argumentos
    local monitor_args=()
    
    if [[ "$CONTINUOUS_MONITORING" == "true" ]]; then
        monitor_args+=("continuous")
    else
        monitor_args+=("monitor")
    fi
    
    monitor_args+=("--environment" "$ENVIRONMENT")
    
    if [[ "$VERBOSE" == "true" ]]; then
        monitor_args+=("--verbose")
    fi
    
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        monitor_args+=("--slack-webhook" "$SLACK_WEBHOOK")
    fi
    
    if [[ -n "$EMAIL_ALERTS" ]]; then
        monitor_args+=("--email-alerts" "$EMAIL_ALERTS")
    fi
    
    # Executar monitoramento
    if [[ "$CONTINUOUS_MONITORING" == "true" ]]; then
        log "MONITOR" "Iniciando monitoramento contínuo..."
        log "INFO" "Pressione Ctrl+C para parar"
        
        # Executar em background se não for modo contínuo interativo
        if [[ "$PARALLEL" == "true" ]]; then
            "$monitoring_script" "${monitor_args[@]}" &
            local monitor_pid=$!
            log "MONITOR" "Monitoramento iniciado em background (PID: $monitor_pid)"
            echo "$monitor_pid" > "$LOG_DIR/monitoring.pid"
        else
            "$monitoring_script" "${monitor_args[@]}"
        fi
    else
        local monitoring_output
        if ! monitoring_output=$("$monitoring_script" "${monitor_args[@]}" 2>&1); then
            log "ERROR" "Falha no monitoramento"
            log "ERROR" "Output: $monitoring_output"
            
            send_notification "Monitoring Failed" "Monitoramento falhou para $ENVIRONMENT" "error"
            return 1
        fi
        
        log "SUCCESS" "Monitoramento concluído"
        send_notification "Monitoring Completed" "Monitoramento concluído para $ENVIRONMENT ✅" "success"
    fi
    
    return 0
}

# Função para limpeza e consolidação
run_cleanup() {
    log "INFO" "Executando limpeza e consolidação..."
    
    local cleanup_script="$SCRIPTS_DIR/cleanup-and-consolidate.sh"
    
    if [[ ! -f "$cleanup_script" ]]; then
        log "WARN" "Script de limpeza não encontrado: $cleanup_script"
        return 0
    fi
    
    # Executar limpeza
    local cleanup_output
    if ! cleanup_output=$("$cleanup_script" --environment "$ENVIRONMENT" 2>&1); then
        log "WARN" "Falha na limpeza (não crítico)"
        log "DEBUG" "Output: $cleanup_output"
        return 0
    fi
    
    log "SUCCESS" "Limpeza e consolidação concluídas"
    return 0
}

# =============================================================================
# PIPELINES PRINCIPAIS
# =============================================================================

# Pipeline completo
run_full_pipeline() {
    log "ORCHESTRATOR" "🚀 Iniciando pipeline DevSecOps completo..."
    
    local start_time
    start_time=$(date +%s)
    
    # Solicitar aprovação
    request_approval "Full DevSecOps Pipeline" "$ENVIRONMENT"
    
    # Notificar início
    send_notification "Pipeline Started" "Pipeline DevSecOps iniciado para $ENVIRONMENT" "info"
    
    # Executar etapas
    local failed_steps=()
    
    # 1. Verificações de segurança
    if ! run_security_checks; then
        failed_steps+=("security")
        if [[ "$FORCE" != "true" ]]; then
            log "ERROR" "Pipeline interrompido devido a falhas de segurança"
            send_notification "Pipeline Failed" "Falha nas verificações de segurança" "error"
            return 1
        fi
    fi
    
    # 2. Deployment
    if ! run_deployment; then
        failed_steps+=("deployment")
        if [[ "$FORCE" != "true" ]]; then
            log "ERROR" "Pipeline interrompido devido a falhas no deployment"
            send_notification "Pipeline Failed" "Falha no deployment" "error"
            return 1
        fi
    fi
    
    # 3. Monitoramento
    if ! run_monitoring; then
        failed_steps+=("monitoring")
        log "WARN" "Falha no monitoramento (não crítico)"
    fi
    
    # 4. Limpeza
    run_cleanup
    
    # Calcular tempo total
    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - start_time))
    
    # Relatório final
    if [[ ${#failed_steps[@]} -eq 0 ]]; then
        log "SUCCESS" "✅ Pipeline DevSecOps concluído com sucesso!"
        log "INFO" "Tempo total: ${duration}s"
        
        send_notification "Pipeline Completed" "Pipeline concluído com sucesso em ${duration}s" "success"
    else
        log "WARN" "⚠️ Pipeline concluído com falhas: ${failed_steps[*]}"
        log "INFO" "Tempo total: ${duration}s"
        
        send_notification "Pipeline Completed with Issues" "Falhas em: ${failed_steps[*]}" "warning"
    fi
    
    return 0
}

# Pipeline de segurança apenas
run_security_pipeline() {
    log "ORCHESTRATOR" "🔒 Executando pipeline de segurança..."
    
    request_approval "Security Pipeline" "$ENVIRONMENT"
    
    if run_security_checks; then
        log "SUCCESS" "✅ Pipeline de segurança concluído"
        return 0
    else
        log "ERROR" "❌ Pipeline de segurança falhou"
        return 1
    fi
}

# Pipeline de deployment apenas
run_deployment_pipeline() {
    log "ORCHESTRATOR" "🚀 Executando pipeline de deployment..."
    
    request_approval "Deployment Pipeline" "$ENVIRONMENT"
    
    if run_deployment; then
        log "SUCCESS" "✅ Pipeline de deployment concluído"
        return 0
    else
        log "ERROR" "❌ Pipeline de deployment falhou"
        return 1
    fi
}

# Pipeline de monitoramento apenas
run_monitoring_pipeline() {
    log "ORCHESTRATOR" "📊 Executando pipeline de monitoramento..."
    
    if run_monitoring; then
        log "SUCCESS" "✅ Pipeline de monitoramento concluído"
        return 0
    else
        log "ERROR" "❌ Pipeline de monitoramento falhou"
        return 1
    fi
}

# =============================================================================
# FUNÇÃO DE AJUDA
# =============================================================================

show_help() {
    cat << EOF
🎯 GMC DevSecOps Orchestrator

Uso: $0 [OPERAÇÃO] [OPÇÕES]

Operações:
  full-pipeline       Pipeline DevSecOps completo (padrão)
  security-only       Apenas verificações de segurança
  deployment-only     Apenas deployment
  monitoring-only     Apenas monitoramento
  cleanup             Limpeza e consolidação
  help                Mostrar esta ajuda

Opções:
  --environment ENV           Ambiente (devnet|testnet|mainnet)
  --skip-security            Pular verificações de segurança
  --skip-deployment          Pular deployment
  --skip-monitoring          Pular monitoramento
  --continuous-monitoring    Monitoramento contínuo
  --security-threshold NUM   Threshold de segurança (padrão: 80)
  --no-approval              Não solicitar aprovação
  --auto-rollback            Rollback automático em falhas
  --dry-run                  Simular operações
  --force                    Forçar execução mesmo com falhas
  --parallel                 Executar monitoramento em paralelo
  --verbose                  Logs detalhados
  --slack-webhook URL        Webhook do Slack
  --email-alerts EMAIL       Email para alertas
  --teams-webhook URL        Webhook do Teams

Exemplos:
  # Pipeline completo para Devnet
  $0 full-pipeline --environment devnet
  
  # Deployment para Testnet com aprovação
  $0 deployment-only --environment testnet
  
  # Verificações de segurança apenas
  $0 security-only --environment mainnet --verbose
  
  # Monitoramento contínuo
  $0 monitoring-only --environment devnet --continuous-monitoring
  
  # Pipeline com notificações
  $0 full-pipeline --environment testnet \
    --slack-webhook https://hooks.slack.com/... \
    --email-alerts admin@gmc.com
  
  # Deployment forçado (pular falhas)
  $0 deployment-only --environment devnet --force --no-approval

Variáveis de ambiente:
  ENVIRONMENT                 Ambiente alvo
  OPERATION                   Operação a executar
  SKIP_SECURITY              Pular verificações de segurança
  SKIP_DEPLOYMENT            Pular deployment
  SKIP_MONITORING            Pular monitoramento
  CONTINUOUS_MONITORING      Monitoramento contínuo
  SECURITY_THRESHOLD         Threshold de segurança
  REQUIRE_APPROVAL           Solicitar aprovação
  AUTO_ROLLBACK              Rollback automático
  DRY_RUN                    Modo simulação
  FORCE                      Forçar execução
  PARALLEL                   Execução paralela
  VERBOSE                    Logs detalhados
  SLACK_WEBHOOK              Webhook do Slack
  EMAIL_ALERTS               Email para alertas
  TEAMS_WEBHOOK              Webhook do Teams

Fluxo do Pipeline:
  1. 🔍 Verificações de dependências
  2. 🔒 Verificações de segurança (OWASP)
  3. 🚀 Deployment automatizado
  4. 📊 Monitoramento e observabilidade
  5. 🧹 Limpeza e consolidação
  6. 📧 Notificações e relatórios

Segurança:
  - Verificações OWASP Top 10 Smart Contracts
  - Análise estática de código
  - Verificação de dependências
  - Validação de configurações
  - Aprovações obrigatórias para Mainnet
  - Rollback automático em falhas

Monitoramento:
  - Métricas de rede em tempo real
  - Saúde dos contratos
  - Alertas automáticos
  - Dashboard HTML
  - Integração Slack/Teams/Email

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Banner
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "🎯 GMC ECOSYSTEM - DEVSECOPS ORCHESTRATOR 🎯"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    # Verificar dependências
    if ! check_dependencies; then
        exit 1
    fi
    
    # Verificar scripts DevSecOps
    if ! check_devsecops_scripts; then
        exit 1
    fi
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            "full-pipeline"|"security-only"|"deployment-only"|"monitoring-only"|"cleanup"|"help")
                export OPERATION="$1"
                shift
                ;;
            "--environment")
                export ENVIRONMENT="$2"
                shift 2
                ;;
            "--skip-security")
                export SKIP_SECURITY="true"
                shift
                ;;
            "--skip-deployment")
                export SKIP_DEPLOYMENT="true"
                shift
                ;;
            "--skip-monitoring")
                export SKIP_MONITORING="true"
                shift
                ;;
            "--continuous-monitoring")
                export CONTINUOUS_MONITORING="true"
                shift
                ;;
            "--security-threshold")
                export SECURITY_THRESHOLD="$2"
                shift 2
                ;;
            "--no-approval")
                export REQUIRE_APPROVAL="false"
                shift
                ;;
            "--auto-rollback")
                export AUTO_ROLLBACK="true"
                shift
                ;;
            "--dry-run")
                export DRY_RUN="true"
                shift
                ;;
            "--force")
                export FORCE="true"
                shift
                ;;
            "--parallel")
                export PARALLEL="true"
                shift
                ;;
            "--verbose")
                export VERBOSE="true"
                shift
                ;;
            "--slack-webhook")
                export SLACK_WEBHOOK="$2"
                shift 2
                ;;
            "--email-alerts")
                export EMAIL_ALERTS="$2"
                shift 2
                ;;
            "--teams-webhook")
                export TEAMS_WEBHOOK="$2"
                shift 2
                ;;
            *)
                log "ERROR" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validar ambiente
    case $ENVIRONMENT in
        "devnet"|"testnet"|"mainnet")
            ;;
        *)
            log "ERROR" "Ambiente inválido: $ENVIRONMENT"
            log "INFO" "Ambientes válidos: devnet, testnet, mainnet"
            exit 1
            ;;
    esac
    
    # Log de configuração
    log "ORCHESTRATOR" "Configuração:"
    log "INFO" "  Ambiente: $ENVIRONMENT"
    log "INFO" "  Operação: $OPERATION"
    log "INFO" "  Threshold de segurança: $SECURITY_THRESHOLD%"
    log "INFO" "  Aprovação necessária: $REQUIRE_APPROVAL"
    log "INFO" "  Rollback automático: $AUTO_ROLLBACK"
    log "INFO" "  Modo dry-run: $DRY_RUN"
    log "INFO" "  Modo verbose: $VERBOSE"
    
    # Executar operação
    case $OPERATION in
        "full-pipeline")
            run_full_pipeline
            ;;
        "security-only")
            run_security_pipeline
            ;;
        "deployment-only")
            run_deployment_pipeline
            ;;
        "monitoring-only")
            run_monitoring_pipeline
            ;;
        "cleanup")
            run_cleanup
            ;;
        "help")
            show_help
            exit 0
            ;;
        *)
            log "ERROR" "Operação inválida: $OPERATION"
            show_help
            exit 1
            ;;
    esac
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "ORCHESTRATOR" "🎉 Operação concluída com sucesso!"
    else
        log "ORCHESTRATOR" "💥 Operação falhou!"
    fi
    
    exit $exit_code
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi