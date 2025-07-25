#!/bin/bash

# 📊 GMC Ecosystem - Monitoring and Observability Automation
# Sistema completo de monitoramento DevSecOps para Solana
# Monitoramento 24/7, alertas, métricas e observabilidade

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
LOG_DIR="$PROJECT_ROOT/logs/monitoring"
REPORT_DIR="$PROJECT_ROOT/reports/monitoring"
CONFIG_DIR="$PROJECT_ROOT/devsecops/config"
METRICS_DIR="$PROJECT_ROOT/metrics"
ALERTS_DIR="$PROJECT_ROOT/alerts"

# Criar diretórios necessários
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$METRICS_DIR" "$ALERTS_DIR"

# Timestamp para logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/monitoring_$TIMESTAMP.log"

# Configurações de monitoramento
ENVIRONMENT="${ENVIRONMENT:-devnet}"
MONITORING_INTERVAL="${MONITORING_INTERVAL:-60}"
ALERT_THRESHOLD_RESPONSE_TIME="${ALERT_THRESHOLD_RESPONSE_TIME:-5000}"
ALERT_THRESHOLD_ERROR_RATE="${ALERT_THRESHOLD_ERROR_RATE:-5}"
ALERT_THRESHOLD_AVAILABILITY="${ALERT_THRESHOLD_AVAILABILITY:-99.0}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
EMAIL_ALERTS="${EMAIL_ALERTS:-}"
CONTINUOUS_MODE="${CONTINUOUS_MODE:-false}"
VERBOSE="${VERBOSE:-false}"

# Configurações de endpoints por ambiente
declare -A DEVNET_ENDPOINTS=(
    ["official"]="https://api.devnet.solana.com"
    ["alchemy"]="https://solana-devnet.g.alchemy.com/v2/demo"
    ["helius"]="https://devnet.helius-rpc.com/?api-key=demo"
)

declare -A TESTNET_ENDPOINTS=(
    ["official"]="https://api.testnet.solana.com"
    ["alchemy"]="https://solana-testnet.g.alchemy.com/v2/demo"
)

declare -A MAINNET_ENDPOINTS=(
    ["official"]="https://api.mainnet-beta.solana.com"
    ["alchemy"]="https://solana-mainnet.g.alchemy.com/v2/demo"
    ["helius"]="https://mainnet.helius-rpc.com/?api-key=demo"
)

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
        "MONITOR")
            echo -e "${CYAN}[$timestamp] [MONITOR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ALERT")
            echo -e "${RED}[$timestamp] [🚨 ALERT]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Função para obter endpoints por ambiente
get_endpoints_for_environment() {
    local env=$1
    local -n endpoints_ref=$2
    
    case $env in
        "devnet")
            for key in "${!DEVNET_ENDPOINTS[@]}"; do
                endpoints_ref["$key"]="${DEVNET_ENDPOINTS[$key]}"
            done
            ;;
        "testnet")
            for key in "${!TESTNET_ENDPOINTS[@]}"; do
                endpoints_ref["$key"]="${TESTNET_ENDPOINTS[$key]}"
            done
            ;;
        "mainnet")
            for key in "${!MAINNET_ENDPOINTS[@]}"; do
                endpoints_ref["$key"]="${MAINNET_ENDPOINTS[$key]}"
            done
            ;;
        *)
            log "ERROR" "Ambiente não suportado: $env"
            return 1
            ;;
    esac
    
    return 0
}

# =============================================================================
# FUNÇÕES DE MONITORAMENTO
# =============================================================================

# Função para medir tempo de resposta
measure_response_time() {
    local endpoint=$1
    local endpoint_name=$2
    
    log "DEBUG" "Medindo tempo de resposta: $endpoint_name"
    
    local start_time
    start_time=$(date +%s%3N)
    
    local response
    local http_code
    
    response=$(curl -s -w "%{http_code}" --max-time 10 \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
        "$endpoint" 2>/dev/null || echo "000")
    
    local end_time
    end_time=$(date +%s%3N)
    
    local response_time
    response_time=$((end_time - start_time))
    
    # Extrair código HTTP
    http_code="${response: -3}"
    
    # Verificar se resposta é válida
    local is_healthy=false
    if [[ "$http_code" == "200" ]] && echo "${response%???}" | jq -e '.result' > /dev/null 2>&1; then
        is_healthy=true
    fi
    
    # Retornar métricas
    echo "{\"endpoint\":\"$endpoint_name\",\"response_time\":$response_time,\"http_code\":\"$http_code\",\"healthy\":$is_healthy,\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
}

# Função para verificar saúde dos contratos
check_contract_health() {
    local environment=$1
    local program_id=$2
    local endpoint=$3
    
    log "DEBUG" "Verificando saúde do contrato: $program_id"
    
    local response
    response=$(curl -s --max-time 10 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getAccountInfo\",\"params\":[\"$program_id\"]}" \
        "$endpoint" 2>/dev/null || echo "")
    
    local is_deployed=false
    if [[ -n "$response" ]] && echo "$response" | jq -e '.result.value' > /dev/null 2>&1; then
        is_deployed=true
    fi
    
    echo "{\"program_id\":\"$program_id\",\"deployed\":$is_deployed,\"environment\":\"$environment\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
}

# Função para coletar métricas de rede
collect_network_metrics() {
    local environment=$1
    
    declare -A endpoints
    get_endpoints_for_environment "$environment" endpoints
    
    local metrics_file="$METRICS_DIR/network_metrics_${environment}_$TIMESTAMP.json"
    
    log "MONITOR" "Coletando métricas de rede para $environment..."
    
    # Inicializar arquivo de métricas
    echo '{"network_metrics":{"environment":"'$environment'","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' > "$metrics_file"
    echo '"endpoints":[' >> "$metrics_file"
    
    local first=true
    local total_response_time=0
    local healthy_endpoints=0
    local total_endpoints=0
    
    for endpoint_name in "${!endpoints[@]}"; do
        local endpoint="${endpoints[$endpoint_name]}"
        
        if [[ "$first" == "false" ]]; then
            echo ',' >> "$metrics_file"
        fi
        first=false
        
        local metrics
        metrics=$(measure_response_time "$endpoint" "$endpoint_name")
        echo "$metrics" >> "$metrics_file"
        
        # Extrair dados para cálculos
        local response_time
        response_time=$(echo "$metrics" | jq -r '.response_time')
        local is_healthy
        is_healthy=$(echo "$metrics" | jq -r '.healthy')
        
        total_response_time=$((total_response_time + response_time))
        total_endpoints=$((total_endpoints + 1))
        
        if [[ "$is_healthy" == "true" ]]; then
            healthy_endpoints=$((healthy_endpoints + 1))
        fi
        
        log "DEBUG" "$endpoint_name: ${response_time}ms, healthy: $is_healthy"
    done
    
    # Calcular métricas agregadas
    local avg_response_time=0
    local availability=0
    
    if [[ $total_endpoints -gt 0 ]]; then
        avg_response_time=$((total_response_time / total_endpoints))
        availability=$(echo "scale=2; $healthy_endpoints * 100 / $total_endpoints" | bc -l)
    fi
    
    # Finalizar arquivo de métricas
    echo '],' >> "$metrics_file"
    echo '"summary":{' >> "$metrics_file"
    echo '"total_endpoints":'$total_endpoints',' >> "$metrics_file"
    echo '"healthy_endpoints":'$healthy_endpoints',' >> "$metrics_file"
    echo '"avg_response_time":'$avg_response_time',' >> "$metrics_file"
    echo '"availability":'$availability >> "$metrics_file"
    echo '}}}' >> "$metrics_file"
    
    log "MONITOR" "Métricas coletadas: $healthy_endpoints/$total_endpoints endpoints saudáveis, ${avg_response_time}ms avg, ${availability}% disponibilidade"
    
    # Verificar thresholds e gerar alertas
    check_alert_thresholds "$avg_response_time" "$availability" "$environment"
    
    echo "$metrics_file"
}

# Função para verificar thresholds de alerta
check_alert_thresholds() {
    local avg_response_time=$1
    local availability=$2
    local environment=$3
    
    local alerts_triggered=false
    local alert_file="$ALERTS_DIR/alert_${environment}_$TIMESTAMP.json"
    
    # Inicializar arquivo de alertas
    echo '{"alerts":{"environment":"'$environment'","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' > "$alert_file"
    echo '"triggered":[' >> "$alert_file"
    
    local first=true
    
    # Verificar tempo de resposta
    if [[ $avg_response_time -gt $ALERT_THRESHOLD_RESPONSE_TIME ]]; then
        if [[ "$first" == "false" ]]; then
            echo ',' >> "$alert_file"
        fi
        first=false
        
        local alert_msg="Tempo de resposta alto: ${avg_response_time}ms (threshold: ${ALERT_THRESHOLD_RESPONSE_TIME}ms)"
        log "ALERT" "$alert_msg"
        
        echo '{"type":"response_time","severity":"warning","message":"'$alert_msg'","value":'$avg_response_time',"threshold":'$ALERT_THRESHOLD_RESPONSE_TIME'}' >> "$alert_file"
        alerts_triggered=true
    fi
    
    # Verificar disponibilidade
    if (( $(echo "$availability < $ALERT_THRESHOLD_AVAILABILITY" | bc -l) )); then
        if [[ "$first" == "false" ]]; then
            echo ',' >> "$alert_file"
        fi
        first=false
        
        local alert_msg="Disponibilidade baixa: ${availability}% (threshold: ${ALERT_THRESHOLD_AVAILABILITY}%)"
        log "ALERT" "$alert_msg"
        
        echo '{"type":"availability","severity":"critical","message":"'$alert_msg'","value":'$availability',"threshold":'$ALERT_THRESHOLD_AVAILABILITY'}' >> "$alert_file"
        alerts_triggered=true
    fi
    
    # Finalizar arquivo de alertas
    echo ']}}' >> "$alert_file"
    
    # Enviar notificações se alertas foram disparados
    if [[ "$alerts_triggered" == "true" ]]; then
        send_alert_notifications "$alert_file" "$environment"
    else
        # Remover arquivo de alerta vazio
        rm "$alert_file"
    fi
    
    return 0
}

# Função para enviar notificações de alerta
send_alert_notifications() {
    local alert_file=$1
    local environment=$2
    
    log "ALERT" "Enviando notificações de alerta..."
    
    # Slack webhook
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local slack_message
        slack_message="🚨 *GMC $environment Alert* 🚨\n$(jq -r '.alerts.triggered[].message' "$alert_file" | head -3 | sed 's/^/• /')"
        
        curl -s -X POST \
            -H 'Content-type: application/json' \
            --data "{\"text\":\"$slack_message\"}" \
            "$SLACK_WEBHOOK" > /dev/null 2>&1 || log "WARN" "Falha ao enviar alerta para Slack"
        
        log "INFO" "Alerta enviado para Slack"
    fi
    
    # Email (se configurado)
    if [[ -n "$EMAIL_ALERTS" ]]; then
        local subject="GMC $environment Alert - $(date)"
        local body
        body=$(jq -r '.alerts.triggered[].message' "$alert_file" | sed 's/^/• /')
        
        echo "$body" | mail -s "$subject" "$EMAIL_ALERTS" 2>/dev/null || log "WARN" "Falha ao enviar email de alerta"
        
        log "INFO" "Alerta enviado por email para $EMAIL_ALERTS"
    fi
    
    return 0
}

# =============================================================================
# MONITORAMENTO DE CONTRATOS
# =============================================================================

# Função para monitorar contratos específicos
monitor_contracts() {
    local environment=$1
    
    log "MONITOR" "Monitorando contratos para $environment..."
    
    declare -A endpoints
    get_endpoints_for_environment "$environment" endpoints
    
    # Usar primeiro endpoint ativo
    local endpoint="${endpoints[official]}"
    
    # IDs dos programas (exemplo - ajustar conforme necessário)
    local program_ids=()
    
    # Tentar carregar IDs dos programas de arquivos IDL
    if [[ -f "$PROJECT_ROOT/target/idl/gmc_token.json" ]]; then
        local token_program_id
        token_program_id=$(jq -r '.metadata.address' "$PROJECT_ROOT/target/idl/gmc_token.json" 2>/dev/null || echo "")
        if [[ -n "$token_program_id" && "$token_program_id" != "null" ]]; then
            program_ids+=("$token_program_id")
        fi
    fi
    
    if [[ -f "$PROJECT_ROOT/target/idl/gmc_staking.json" ]]; then
        local staking_program_id
        staking_program_id=$(jq -r '.metadata.address' "$PROJECT_ROOT/target/idl/gmc_staking.json" 2>/dev/null || echo "")
        if [[ -n "$staking_program_id" && "$staking_program_id" != "null" ]]; then
            program_ids+=("$staking_program_id")
        fi
    fi
    
    if [[ ${#program_ids[@]} -eq 0 ]]; then
        log "WARN" "Nenhum programa deployado encontrado para monitoramento"
        return 0
    fi
    
    local contracts_file="$METRICS_DIR/contracts_${environment}_$TIMESTAMP.json"
    
    echo '{"contract_monitoring":{"environment":"'$environment'","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' > "$contracts_file"
    echo '"contracts":[' >> "$contracts_file"
    
    local first=true
    local deployed_count=0
    
    for program_id in "${program_ids[@]}"; do
        if [[ "$first" == "false" ]]; then
            echo ',' >> "$contracts_file"
        fi
        first=false
        
        local contract_health
        contract_health=$(check_contract_health "$environment" "$program_id" "$endpoint")
        echo "$contract_health" >> "$contracts_file"
        
        local is_deployed
        is_deployed=$(echo "$contract_health" | jq -r '.deployed')
        
        if [[ "$is_deployed" == "true" ]]; then
            ((deployed_count++))
            log "SUCCESS" "Contrato ativo: $program_id"
        else
            log "ERROR" "Contrato inativo: $program_id"
        fi
    done
    
    echo '],' >> "$contracts_file"
    echo '"summary":{' >> "$contracts_file"
    echo '"total_contracts":'${#program_ids[@]}',' >> "$contracts_file"
    echo '"deployed_contracts":'$deployed_count >> "$contracts_file"
    echo '}}}' >> "$contracts_file"
    
    log "MONITOR" "Contratos monitorados: $deployed_count/${#program_ids[@]} ativos"
    
    echo "$contracts_file"
}

# =============================================================================
# DASHBOARD E RELATÓRIOS
# =============================================================================

# Função para gerar dashboard HTML
generate_dashboard() {
    local environment=$1
    
    log "INFO" "Gerando dashboard para $environment..."
    
    local dashboard_file="$REPORT_DIR/dashboard_${environment}_$TIMESTAMP.html"
    
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GMC Ecosystem - Monitoring Dashboard</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.8;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 30px;
        }
        .metric-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            border-left: 4px solid #007bff;
        }
        .metric-card.warning {
            border-left-color: #ffc107;
        }
        .metric-card.danger {
            border-left-color: #dc3545;
        }
        .metric-card.success {
            border-left-color: #28a745;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
        }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-healthy {
            background-color: #28a745;
        }
        .status-warning {
            background-color: #ffc107;
        }
        .status-critical {
            background-color: #dc3545;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #dee2e6;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 GMC Ecosystem</h1>
            <p>Monitoring Dashboard - ENVIRONMENT_PLACEHOLDER</p>
            <p>Last Update: TIMESTAMP_PLACEHOLDER</p>
        </div>
        
        <div class="metrics">
            <div class="metric-card success">
                <div class="metric-value">AVAILABILITY_PLACEHOLDER%</div>
                <div class="metric-label">
                    <span class="status-indicator status-healthy"></span>
                    Network Availability
                </div>
            </div>
            
            <div class="metric-card">
                <div class="metric-value">RESPONSE_TIME_PLACEHOLDERms</div>
                <div class="metric-label">
                    <span class="status-indicator status-healthy"></span>
                    Avg Response Time
                </div>
            </div>
            
            <div class="metric-card success">
                <div class="metric-value">HEALTHY_ENDPOINTS_PLACEHOLDER/TOTAL_ENDPOINTS_PLACEHOLDER</div>
                <div class="metric-label">
                    <span class="status-indicator status-healthy"></span>
                    Healthy Endpoints
                </div>
            </div>
            
            <div class="metric-card success">
                <div class="metric-value">DEPLOYED_CONTRACTS_PLACEHOLDER/TOTAL_CONTRACTS_PLACEHOLDER</div>
                <div class="metric-label">
                    <span class="status-indicator status-healthy"></span>
                    Active Contracts
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>🔒 GMC DevSecOps Monitoring System</p>
            <p>Automated monitoring with real-time alerts and observability</p>
        </div>
    </div>
</body>
</html>
EOF
    
    # Substituir placeholders com dados reais
    sed -i.bak "s/ENVIRONMENT_PLACEHOLDER/$environment/g" "$dashboard_file"
    sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$(date)/g" "$dashboard_file"
    
    # Tentar obter métricas mais recentes
    local latest_metrics
    latest_metrics=$(find "$METRICS_DIR" -name "network_metrics_${environment}_*.json" -type f | sort | tail -1)
    
    if [[ -f "$latest_metrics" ]]; then
        local availability
        availability=$(jq -r '.network_metrics.summary.availability' "$latest_metrics" 2>/dev/null || echo "0")
        local response_time
        response_time=$(jq -r '.network_metrics.summary.avg_response_time' "$latest_metrics" 2>/dev/null || echo "0")
        local healthy_endpoints
        healthy_endpoints=$(jq -r '.network_metrics.summary.healthy_endpoints' "$latest_metrics" 2>/dev/null || echo "0")
        local total_endpoints
        total_endpoints=$(jq -r '.network_metrics.summary.total_endpoints' "$latest_metrics" 2>/dev/null || echo "0")
        
        sed -i.bak "s/AVAILABILITY_PLACEHOLDER/$availability/g" "$dashboard_file"
        sed -i.bak "s/RESPONSE_TIME_PLACEHOLDER/$response_time/g" "$dashboard_file"
        sed -i.bak "s/HEALTHY_ENDPOINTS_PLACEHOLDER/$healthy_endpoints/g" "$dashboard_file"
        sed -i.bak "s/TOTAL_ENDPOINTS_PLACEHOLDER/$total_endpoints/g" "$dashboard_file"
    fi
    
    # Tentar obter métricas de contratos
    local latest_contracts
    latest_contracts=$(find "$METRICS_DIR" -name "contracts_${environment}_*.json" -type f | sort | tail -1)
    
    if [[ -f "$latest_contracts" ]]; then
        local deployed_contracts
        deployed_contracts=$(jq -r '.contract_monitoring.summary.deployed_contracts' "$latest_contracts" 2>/dev/null || echo "0")
        local total_contracts
        total_contracts=$(jq -r '.contract_monitoring.summary.total_contracts' "$latest_contracts" 2>/dev/null || echo "0")
        
        sed -i.bak "s/DEPLOYED_CONTRACTS_PLACEHOLDER/$deployed_contracts/g" "$dashboard_file"
        sed -i.bak "s/TOTAL_CONTRACTS_PLACEHOLDER/$total_contracts/g" "$dashboard_file"
    fi
    
    # Limpar arquivos de backup
    rm -f "${dashboard_file}.bak"
    
    log "SUCCESS" "Dashboard gerado: $dashboard_file"
    echo "$dashboard_file"
}

# Função para gerar relatório de monitoramento
generate_monitoring_report() {
    local environment=$1
    
    local report_file="$REPORT_DIR/monitoring_report_${environment}_$TIMESTAMP.json"
    
    # Coletar métricas mais recentes
    local latest_metrics
    latest_metrics=$(find "$METRICS_DIR" -name "network_metrics_${environment}_*.json" -type f | sort | tail -1)
    
    local latest_contracts
    latest_contracts=$(find "$METRICS_DIR" -name "contracts_${environment}_*.json" -type f | sort | tail -1)
    
    local latest_alerts
    latest_alerts=$(find "$ALERTS_DIR" -name "alert_${environment}_*.json" -type f | sort | tail -1)
    
    cat > "$report_file" << EOF
{
  "monitoring_report": {
    "environment": "$environment",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "monitoring_interval": "$MONITORING_INTERVAL",
    "continuous_mode": "$CONTINUOUS_MODE"
  },
  "network_metrics": $(cat "$latest_metrics" 2>/dev/null || echo 'null'),
  "contract_monitoring": $(cat "$latest_contracts" 2>/dev/null || echo 'null'),
  "alerts": $(cat "$latest_alerts" 2>/dev/null || echo 'null'),
  "thresholds": {
    "response_time": "$ALERT_THRESHOLD_RESPONSE_TIME",
    "error_rate": "$ALERT_THRESHOLD_ERROR_RATE",
    "availability": "$ALERT_THRESHOLD_AVAILABILITY"
  },
  "artifacts": {
    "log_file": "$LOG_FILE",
    "report_file": "$report_file",
    "metrics_directory": "$METRICS_DIR",
    "alerts_directory": "$ALERTS_DIR"
  }
}
EOF
    
    log "SUCCESS" "Relatório de monitoramento gerado: $report_file"
    echo "$report_file"
}

# =============================================================================
# MODO CONTÍNUO
# =============================================================================

# Função para monitoramento contínuo
continuous_monitoring() {
    local environment=$1
    
    log "INFO" "🔄 Iniciando monitoramento contínuo para $environment..."
    log "INFO" "Intervalo: ${MONITORING_INTERVAL}s"
    log "INFO" "Pressione Ctrl+C para parar"
    
    # Trap para limpeza
    trap 'log "INFO" "Parando monitoramento contínuo..."; exit 0' INT TERM
    
    local iteration=0
    
    while true; do
        ((iteration++))
        
        log "MONITOR" "Iteração #$iteration - $(date)"
        
        # Coletar métricas de rede
        collect_network_metrics "$environment"
        
        # Monitorar contratos
        monitor_contracts "$environment"
        
        # Gerar dashboard a cada 10 iterações
        if (( iteration % 10 == 0 )); then
            generate_dashboard "$environment"
        fi
        
        # Aguardar próxima iteração
        sleep "$MONITORING_INTERVAL"
    done
}

# =============================================================================
# FUNÇÃO DE AJUDA
# =============================================================================

show_help() {
    cat << EOF
📊 GMC Monitoring and Observability Script

Uso: $0 [COMANDO] [OPÇÕES]

Comandos:
  monitor     Executar monitoramento único
  continuous  Monitoramento contínuo
  dashboard   Gerar dashboard HTML
  report      Gerar relatório de monitoramento
  help        Mostrar esta ajuda

Opções:
  --environment ENV           Ambiente (devnet|testnet|mainnet)
  --interval SECONDS          Intervalo de monitoramento (padrão: 60s)
  --response-time-threshold MS Threshold de tempo de resposta (padrão: 5000ms)
  --availability-threshold %   Threshold de disponibilidade (padrão: 99.0%)
  --slack-webhook URL         Webhook do Slack para alertas
  --email-alerts EMAIL        Email para alertas
  --verbose                   Logs detalhados

Exemplos:
  $0 monitor --environment devnet
  $0 continuous --environment mainnet --interval 30
  $0 dashboard --environment testnet
  $0 monitor --slack-webhook https://hooks.slack.com/...

Variáveis de ambiente:
  ENVIRONMENT                 Ambiente alvo
  MONITORING_INTERVAL         Intervalo de monitoramento
  ALERT_THRESHOLD_RESPONSE_TIME Threshold de tempo de resposta
  ALERT_THRESHOLD_AVAILABILITY  Threshold de disponibilidade
  SLACK_WEBHOOK              Webhook do Slack
  EMAIL_ALERTS               Email para alertas
  CONTINUOUS_MODE            Modo contínuo
  VERBOSE                    Logs detalhados

Métricas monitoradas:
  - Tempo de resposta dos endpoints
  - Disponibilidade da rede
  - Saúde dos contratos
  - Status dos programas deployados
  - Alertas automáticos

Saídas:
  - Métricas em JSON
  - Dashboard HTML
  - Alertas automáticos
  - Relatórios de monitoramento
  - Logs detalhados

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Banner
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "📊 GMC ECOSYSTEM - MONITORING AND OBSERVABILITY AUTOMATION 📊"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    # Verificar dependências
    local deps=("curl" "jq" "bc")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "ERROR" "Dependência faltando: $dep"
            exit 1
        fi
    done
    
    # Processar argumentos
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            "monitor"|"continuous"|"dashboard"|"report"|"help")
                command="$1"
                shift
                ;;
            "--environment")
                export ENVIRONMENT="$2"
                shift 2
                ;;
            "--interval")
                export MONITORING_INTERVAL="$2"
                shift 2
                ;;
            "--response-time-threshold")
                export ALERT_THRESHOLD_RESPONSE_TIME="$2"
                shift 2
                ;;
            "--availability-threshold")
                export ALERT_THRESHOLD_AVAILABILITY="$2"
                shift 2
                ;;
            "--slack-webhook")
                export SLACK_WEBHOOK="$2"
                shift 2
                ;;
            "--email-alerts")
                export EMAIL_ALERTS="$2"
                shift 2
                ;;
            "--verbose")
                export VERBOSE="true"
                shift
                ;;
            *)
                log "ERROR" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar se comando foi especificado
    if [[ -z "$command" ]]; then
        log "ERROR" "Comando não especificado."
        show_help
        exit 1
    fi
    
    # Executar comando
    case $command in
        "monitor")
            log "INFO" "🔍 Executando monitoramento único para $ENVIRONMENT..."
            
            collect_network_metrics "$ENVIRONMENT"
            monitor_contracts "$ENVIRONMENT"
            generate_dashboard "$ENVIRONMENT"
            generate_monitoring_report "$ENVIRONMENT"
            
            log "SUCCESS" "✅ Monitoramento concluído!"
            ;;
        "continuous")
            export CONTINUOUS_MODE="true"
            continuous_monitoring "$ENVIRONMENT"
            ;;
        "dashboard")
            generate_dashboard "$ENVIRONMENT"
            ;;
        "report")
            generate_monitoring_report "$ENVIRONMENT"
            ;;
        "help")
            show_help
            exit 0
            ;;
        *)
            log "ERROR" "Comando inválido: $command"
            show_help
            exit 1
            ;;
    esac
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi