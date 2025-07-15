#!/bin/bash

# 🔒 GMC Ecosystem - Security Automation Scripts
# Scripts automatizados para validações de segurança DevSecOps
# Baseado em OWASP Top 10 Smart Contracts e melhores práticas

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
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOG_DIR="$PROJECT_ROOT/logs/security"
REPORT_DIR="$PROJECT_ROOT/reports/security"
CONFIG_DIR="$PROJECT_ROOT/devsecops/config"

# Criar diretórios necessários
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Timestamp para logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/security_scan_$TIMESTAMP.log"

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
    esac
}

# Função para verificar dependências
check_dependencies() {
    log "INFO" "Verificando dependências..."
    
    local deps=("cargo" "anchor" "jq" "curl" "git" "rustc")
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

# Função para verificar se estamos no diretório correto
check_project_structure() {
    log "INFO" "Verificando estrutura do projeto..."
    
    local required_files=("Cargo.toml" "Anchor.toml" "programs")
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "$PROJECT_ROOT/$file" ]]; then
            log "ERROR" "Arquivo/diretório obrigatório não encontrado: $file"
            log "ERROR" "Execute este script a partir do diretório raiz do projeto GMC."
            exit 1
        fi
    done
    
    log "SUCCESS" "Estrutura do projeto verificada."
}

# Função para gerar relatório JSON
generate_json_report() {
    local report_type=$1
    local results=$2
    local output_file="$REPORT_DIR/${report_type}_report_$TIMESTAMP.json"
    
    cat > "$output_file" << EOF
{
  "report_type": "$report_type",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project": "GMC Ecosystem",
  "version": "1.0",
  "results": $results
}
EOF
    
    log "INFO" "Relatório JSON gerado: $output_file"
    echo "$output_file"
}

# =============================================================================
# OWASP TOP 10 SMART CONTRACTS - VERIFICAÇÕES
# =============================================================================

# SC01 - Reentrancy Protection
check_reentrancy() {
    log "INFO" "🔍 SC01 - Verificando proteção contra reentrância..."
    
    local findings=()
    local severity="medium"
    
    # Verificar uso de ReentrancyGuard ou padrões similares
    if grep -r "ReentrancyGuard\|nonReentrant\|reentrancy_guard" "$PROJECT_ROOT/programs" --include="*.rs" > /dev/null; then
        log "SUCCESS" "Proteção contra reentrância encontrada."
        findings+=('{"type": "protection_found", "message": "ReentrancyGuard ou similar implementado"}')
    else
        log "WARN" "Nenhuma proteção explícita contra reentrância encontrada."
        findings+=('{"type": "missing_protection", "message": "Considere implementar proteção contra reentrância"}')
        severity="high"
    fi
    
    # Verificar padrão Checks-Effects-Interactions
    local cei_violations=$(grep -r "transfer\|send" "$PROJECT_ROOT/programs" --include="*.rs" -A 5 -B 5 | grep -c "state_change_after_external_call" || true)
    
    if [[ $cei_violations -gt 0 ]]; then
        log "WARN" "Possíveis violações do padrão Checks-Effects-Interactions encontradas: $cei_violations"
        findings+=('{"type": "cei_violation", "count": '$cei_violations', "message": "Verificar ordem de operações"}')
        severity="high"
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "reentrancy", "severity": "'$severity'", "findings": '$result'}'
}

# SC02 - Integer Overflow/Underflow
check_integer_overflow() {
    log "INFO" "🔍 SC02 - Verificando proteção contra overflow/underflow..."
    
    local findings=()
    local severity="low"
    
    # Verificar uso de operações seguras
    local safe_math_usage=$(grep -r "checked_add\|checked_sub\|checked_mul\|checked_div" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    local unsafe_math_usage=$(grep -r "\+\|\-\|\*\|/" "$PROJECT_ROOT/programs" --include="*.rs" | grep -v "checked_" | wc -l)
    
    if [[ $safe_math_usage -gt 0 ]]; then
        log "SUCCESS" "Operações matemáticas seguras encontradas: $safe_math_usage"
        findings+=('{"type": "safe_math_found", "count": '$safe_math_usage'}')
    fi
    
    if [[ $unsafe_math_usage -gt 10 ]]; then  # Threshold arbitrário
        log "WARN" "Muitas operações matemáticas potencialmente inseguras: $unsafe_math_usage"
        findings+=('{"type": "unsafe_math_warning", "count": '$unsafe_math_usage'}')
        severity="medium"
    fi
    
    # Verificar validação de entrada
    local input_validation=$(grep -r "require\|assert\|ensure" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $input_validation -gt 0 ]]; then
        log "SUCCESS" "Validações de entrada encontradas: $input_validation"
        findings+=('{"type": "input_validation_found", "count": '$input_validation'}')
    else
        log "WARN" "Poucas validações de entrada encontradas."
        findings+=('{"type": "insufficient_validation", "message": "Considere adicionar mais validações"}')
        severity="medium"
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "integer_overflow", "severity": "'$severity'", "findings": '$result'}'
}

# SC03 - Timestamp Dependence
check_timestamp_dependence() {
    log "INFO" "🔍 SC03 - Verificando dependência de timestamp..."
    
    local findings=()
    local severity="low"
    
    # Verificar uso de Clock::get()
    local clock_usage=$(grep -r "Clock::get\|clock.unix_timestamp" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $clock_usage -gt 0 ]]; then
        log "INFO" "Uso de timestamp encontrado: $clock_usage ocorrências"
        findings+=('{"type": "timestamp_usage", "count": '$clock_usage'}')
        
        # Verificar se há validação de tolerância
        local tolerance_checks=$(grep -r "tolerance\|window\|range" "$PROJECT_ROOT/programs" --include="*.rs" -A 3 -B 3 | grep -c "timestamp" || true)
        
        if [[ $tolerance_checks -gt 0 ]]; then
            log "SUCCESS" "Verificações de tolerância de tempo encontradas."
            findings+=('{"type": "tolerance_found", "count": '$tolerance_checks'}')
        else
            log "WARN" "Uso de timestamp sem verificação de tolerância."
            findings+=('{"type": "no_tolerance", "message": "Considere implementar janelas de tolerância"}')
            severity="medium"
        fi
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "timestamp_dependence", "severity": "'$severity'", "findings": '$result'}'
}

# SC04 - Authorization
check_authorization() {
    log "INFO" "🔍 SC04 - Verificando controles de autorização..."
    
    local findings=()
    local severity="low"
    
    # Verificar uso de Signer
    local signer_usage=$(grep -r "Signer\|has_one\|constraint" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $signer_usage -gt 0 ]]; then
        log "SUCCESS" "Verificações de assinatura encontradas: $signer_usage"
        findings+=('{"type": "signer_checks_found", "count": '$signer_usage'}')
    else
        log "ERROR" "Nenhuma verificação de assinatura encontrada!"
        findings+=('{"type": "no_signer_checks", "message": "Implementar verificações de autorização"}')
        severity="critical"
    fi
    
    # Verificar controles de acesso baseados em papel
    local rbac_usage=$(grep -r "admin\|owner\|authority\|role" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $rbac_usage -gt 0 ]]; then
        log "SUCCESS" "Controles de acesso baseados em papel encontrados: $rbac_usage"
        findings+=('{"type": "rbac_found", "count": '$rbac_usage'}')
    fi
    
    # Verificar funções públicas sem proteção
    local public_functions=$(grep -r "pub fn" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    local protected_functions=$(grep -r "pub fn" "$PROJECT_ROOT/programs" --include="*.rs" -A 10 | grep -c "Signer\|constraint" || true)
    
    local unprotected_ratio=$((public_functions - protected_functions))
    
    if [[ $unprotected_ratio -gt 5 ]]; then  # Threshold arbitrário
        log "WARN" "Muitas funções públicas potencialmente desprotegidas: $unprotected_ratio"
        findings+=('{"type": "unprotected_functions", "count": '$unprotected_ratio'}')
        severity="high"
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "authorization", "severity": "'$severity'", "findings": '$result'}'
}

# SC05 - Unprotected Token Withdrawal
check_unprotected_withdrawal() {
    log "INFO" "🔍 SC05 - Verificando proteção de retiradas..."
    
    local findings=()
    local severity="low"
    
    # Verificar funções de transferência/retirada
    local transfer_functions=$(grep -r "transfer\|withdraw\|claim" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $transfer_functions -gt 0 ]]; then
        log "INFO" "Funções de transferência encontradas: $transfer_functions"
        findings+=('{"type": "transfer_functions_found", "count": '$transfer_functions'}')
        
        # Verificar validações de saldo
        local balance_checks=$(grep -r "balance\|amount" "$PROJECT_ROOT/programs" --include="*.rs" -A 5 -B 5 | grep -c "require\|assert\|ensure" || true)
        
        if [[ $balance_checks -gt 0 ]]; then
            log "SUCCESS" "Verificações de saldo encontradas: $balance_checks"
            findings+=('{"type": "balance_checks_found", "count": '$balance_checks'}')
        else
            log "WARN" "Poucas verificações de saldo encontradas."
            findings+=('{"type": "insufficient_balance_checks", "message": "Implementar verificações de saldo"}')
            severity="high"
        fi
        
        # Verificar limites de retirada
        local withdrawal_limits=$(grep -r "limit\|max_amount\|daily_limit" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
        
        if [[ $withdrawal_limits -gt 0 ]]; then
            log "SUCCESS" "Limites de retirada encontrados: $withdrawal_limits"
            findings+=('{"type": "withdrawal_limits_found", "count": '$withdrawal_limits'}')
        else
            log "WARN" "Nenhum limite de retirada encontrado."
            findings+=('{"type": "no_withdrawal_limits", "message": "Considere implementar limites"}')
            severity="medium"
        fi
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "unprotected_withdrawal", "severity": "'$severity'", "findings": '$result'}'
}

# SC06 - Selfdestruct
check_selfdestruct() {
    log "INFO" "🔍 SC06 - Verificando proteção contra destruição..."
    
    local findings=()
    local severity="low"
    
    # Verificar funções de fechamento de conta
    local close_functions=$(grep -r "close\|destroy\|selfdestruct" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $close_functions -gt 0 ]]; then
        log "INFO" "Funções de fechamento encontradas: $close_functions"
        findings+=('{"type": "close_functions_found", "count": '$close_functions'}')
        
        # Verificar proteções de admin
        local admin_protection=$(grep -r "close\|destroy" "$PROJECT_ROOT/programs" --include="*.rs" -A 5 -B 5 | grep -c "admin\|owner\|authority" || true)
        
        if [[ $admin_protection -gt 0 ]]; then
            log "SUCCESS" "Proteções de administrador encontradas: $admin_protection"
            findings+=('{"type": "admin_protection_found", "count": '$admin_protection'}')
        else
            log "WARN" "Funções de fechamento sem proteção de administrador."
            findings+=('{"type": "no_admin_protection", "message": "Proteger funções de fechamento"}')
            severity="high"
        fi
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "selfdestruct", "severity": "'$severity'", "findings": '$result'}'
}

# SC07 - Floating Pragma
check_floating_pragma() {
    log "INFO" "🔍 SC07 - Verificando versões fixas de dependências..."
    
    local findings=()
    local severity="low"
    
    # Verificar Cargo.toml para versões fixas
    if [[ -f "$PROJECT_ROOT/Cargo.toml" ]]; then
        local floating_versions=$(grep -E '"\^|"~|">=|">' "$PROJECT_ROOT/Cargo.toml" | wc -l)
        local fixed_versions=$(grep -E '"[0-9]+\.[0-9]+\.[0-9]+"' "$PROJECT_ROOT/Cargo.toml" | wc -l)
        
        if [[ $floating_versions -gt 0 ]]; then
            log "WARN" "Versões flutuantes encontradas: $floating_versions"
            findings+=('{"type": "floating_versions_found", "count": '$floating_versions'}')
            severity="medium"
        fi
        
        if [[ $fixed_versions -gt 0 ]]; then
            log "SUCCESS" "Versões fixas encontradas: $fixed_versions"
            findings+=('{"type": "fixed_versions_found", "count": '$fixed_versions'}')
        fi
    fi
    
    # Verificar Cargo.lock
    if [[ -f "$PROJECT_ROOT/Cargo.lock" ]]; then
        log "SUCCESS" "Cargo.lock encontrado - dependências travadas."
        findings+=('{"type": "cargo_lock_found", "message": "Dependências travadas"}')
    else
        log "WARN" "Cargo.lock não encontrado."
        findings+=('{"type": "no_cargo_lock", "message": "Gerar Cargo.lock"}')
        severity="medium"
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "floating_pragma", "severity": "'$severity'", "findings": '$result'}'
}

# SC08 - Function Visibility
check_function_visibility() {
    log "INFO" "🔍 SC08 - Verificando visibilidade de funções..."
    
    local findings=()
    local severity="low"
    
    # Verificar funções públicas
    local public_functions=$(grep -r "pub fn" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    local private_functions=$(grep -r "fn " "$PROJECT_ROOT/programs" --include="*.rs" | grep -v "pub fn" | wc -l)
    
    log "INFO" "Funções públicas: $public_functions, Funções privadas: $private_functions"
    findings+=('{"type": "function_visibility", "public": '$public_functions', "private": '$private_functions'}')
    
    # Verificar se há muitas funções públicas
    if [[ $public_functions -gt $((private_functions * 2)) ]]; then
        log "WARN" "Muitas funções públicas em relação às privadas."
        findings+=('{"type": "too_many_public", "message": "Revisar necessidade de funções públicas"}')
        severity="medium"
    fi
    
    # Verificar funções sem documentação
    local undocumented_functions=$(grep -r "pub fn" "$PROJECT_ROOT/programs" --include="*.rs" -B 3 | grep -c "///" || true)
    local documented_ratio=$((undocumented_functions * 100 / public_functions))
    
    if [[ $documented_ratio -lt 80 ]]; then
        log "WARN" "Muitas funções públicas sem documentação: $documented_ratio%"
        findings+=('{"type": "undocumented_functions", "ratio": '$documented_ratio'}')
        severity="medium"
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "function_visibility", "severity": "'$severity'", "findings": '$result'}'
}

# SC09 - Gas Limit DoS
check_gas_limit_dos() {
    log "INFO" "🔍 SC09 - Verificando proteção contra DoS por gas..."
    
    local findings=()
    local severity="low"
    
    # Verificar loops sem limite
    local unbounded_loops=$(grep -r "for \|while " "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    local bounded_loops=$(grep -r "for \|while " "$PROJECT_ROOT/programs" --include="*.rs" -A 5 | grep -c "break\|return\|limit" || true)
    
    if [[ $unbounded_loops -gt 0 ]]; then
        log "INFO" "Loops encontrados: $unbounded_loops"
        findings+=('{"type": "loops_found", "count": '$unbounded_loops'}')
        
        local unbounded_ratio=$((unbounded_loops - bounded_loops))
        
        if [[ $unbounded_ratio -gt 2 ]]; then
            log "WARN" "Loops potencialmente sem limite: $unbounded_ratio"
            findings+=('{"type": "unbounded_loops", "count": '$unbounded_ratio'}')
            severity="medium"
        fi
    fi
    
    # Verificar operações custosas
    local expensive_ops=$(grep -r "sort\|search\|iterate" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $expensive_ops -gt 0 ]]; then
        log "INFO" "Operações potencialmente custosas: $expensive_ops"
        findings+=('{"type": "expensive_operations", "count": '$expensive_ops'}')
        
        if [[ $expensive_ops -gt 5 ]]; then
            severity="medium"
        fi
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "gas_limit_dos", "severity": "'$severity'", "findings": '$result'}'
}

# SC10 - Unhandled Exception
check_unhandled_exception() {
    log "INFO" "🔍 SC10 - Verificando tratamento de exceções..."
    
    local findings=()
    local severity="low"
    
    # Verificar uso de Result e Option
    local result_usage=$(grep -r "Result<\|Option<" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    local error_handling=$(grep -r "match\|if let\|unwrap_or\|map_err" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $result_usage -gt 0 ]]; then
        log "SUCCESS" "Uso de Result/Option encontrado: $result_usage"
        findings+=('{"type": "result_option_usage", "count": '$result_usage'}')
    fi
    
    if [[ $error_handling -gt 0 ]]; then
        log "SUCCESS" "Tratamento de erro encontrado: $error_handling"
        findings+=('{"type": "error_handling_found", "count": '$error_handling'}')
    fi
    
    # Verificar uso perigoso de unwrap
    local unwrap_usage=$(grep -r "\.unwrap()" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $unwrap_usage -gt 0 ]]; then
        log "WARN" "Uso de unwrap() encontrado: $unwrap_usage"
        findings+=('{"type": "unwrap_usage", "count": '$unwrap_usage', "message": "Considere usar expect() ou tratamento adequado"}')
        severity="medium"
    fi
    
    # Verificar definição de erros customizados
    local custom_errors=$(grep -r "#\[error\]\|Error\|ErrorCode" "$PROJECT_ROOT/programs" --include="*.rs" | wc -l)
    
    if [[ $custom_errors -gt 0 ]]; then
        log "SUCCESS" "Erros customizados encontrados: $custom_errors"
        findings+=('{"type": "custom_errors_found", "count": '$custom_errors'}')
    else
        log "WARN" "Poucos erros customizados encontrados."
        findings+=('{"type": "insufficient_custom_errors", "message": "Implementar erros customizados"}')
        severity="medium"
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "unhandled_exception", "severity": "'$severity'", "findings": '$result'}'
}

# =============================================================================
# VERIFICAÇÕES ADICIONAIS DE SEGURANÇA
# =============================================================================

# Verificação de secrets no código
check_secrets_in_code() {
    log "INFO" "🔍 Verificando secrets no código..."
    
    local findings=()
    local severity="low"
    
    # Padrões de secrets comuns
    local secret_patterns=(
        "private.*key"
        "secret.*key"
        "api.*key"
        "password"
        "token"
        "[0-9a-fA-F]{32,}"
        "[A-Za-z0-9+/]{40,}={0,2}"
    )
    
    for pattern in "${secret_patterns[@]}"; do
        local matches=$(grep -ri "$pattern" "$PROJECT_ROOT" --exclude-dir=.git --exclude-dir=target --exclude-dir=node_modules --exclude="*.log" | wc -l)
        
        if [[ $matches -gt 0 ]]; then
            log "WARN" "Possíveis secrets encontrados para padrão '$pattern': $matches"
            findings+=('{"type": "potential_secret", "pattern": "'$pattern'", "count": '$matches'}')
            severity="high"
        fi
    done
    
    if [[ ${#findings[@]} -eq 0 ]]; then
        log "SUCCESS" "Nenhum secret óbvio encontrado no código."
        findings+=('{"type": "no_secrets_found", "message": "Verificação passou"}')
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "secrets_in_code", "severity": "'$severity'", "findings": '$result'}'
}

# Verificação de dependências vulneráveis
check_vulnerable_dependencies() {
    log "INFO" "🔍 Verificando dependências vulneráveis..."
    
    local findings=()
    local severity="low"
    
    # Executar cargo audit se disponível
    if command -v cargo-audit &> /dev/null; then
        local audit_output
        if audit_output=$(cargo audit --json 2>/dev/null); then
            local vulnerabilities=$(echo "$audit_output" | jq '.vulnerabilities.found | length' 2>/dev/null || echo "0")
            
            if [[ $vulnerabilities -gt 0 ]]; then
                log "WARN" "Vulnerabilidades encontradas: $vulnerabilities"
                findings+=('{"type": "vulnerabilities_found", "count": '$vulnerabilities'}')
                severity="high"
            else
                log "SUCCESS" "Nenhuma vulnerabilidade conhecida encontrada."
                findings+=('{"type": "no_vulnerabilities", "message": "Audit passou"}')
            fi
        else
            log "WARN" "Falha ao executar cargo audit."
            findings+=('{"type": "audit_failed", "message": "Não foi possível executar audit"}')
            severity="medium"
        fi
    else
        log "WARN" "cargo-audit não instalado."
        findings+=('{"type": "audit_not_available", "message": "Instalar cargo-audit"}')
        severity="medium"
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "vulnerable_dependencies", "severity": "'$severity'", "findings": '$result'}'
}

# Verificação de configuração de segurança
check_security_configuration() {
    log "INFO" "🔍 Verificando configuração de segurança..."
    
    local findings=()
    local severity="low"
    
    # Verificar arquivos de configuração de segurança
    local security_configs=(
        "$CONFIG_DIR/security-policies.yaml"
        "$PROJECT_ROOT/.cargo-deny.toml"
        "$PROJECT_ROOT/.gitignore"
    )
    
    for config in "${security_configs[@]}"; do
        if [[ -f "$config" ]]; then
            log "SUCCESS" "Configuração de segurança encontrada: $(basename "$config")"
            findings+=('{"type": "config_found", "file": "'$(basename "$config")'"}')  
        else
            log "WARN" "Configuração de segurança faltando: $(basename "$config")"
            findings+=('{"type": "config_missing", "file": "'$(basename "$config")'"}')  
            severity="medium"
        fi
    done
    
    # Verificar .gitignore para secrets
    if [[ -f "$PROJECT_ROOT/.gitignore" ]]; then
        local gitignore_patterns=("*.key" "*.pem" ".env" "secrets/")
        local protected_patterns=0
        
        for pattern in "${gitignore_patterns[@]}"; do
            if grep -q "$pattern" "$PROJECT_ROOT/.gitignore"; then
                ((protected_patterns++))
            fi
        done
        
        if [[ $protected_patterns -ge 3 ]]; then
            log "SUCCESS" "Padrões de proteção adequados no .gitignore: $protected_patterns"
            findings+=('{"type": "gitignore_protection", "count": '$protected_patterns'}')
        else
            log "WARN" "Poucos padrões de proteção no .gitignore: $protected_patterns"
            findings+=('{"type": "insufficient_gitignore", "count": '$protected_patterns'}')
            severity="medium"
        fi
    fi
    
    local result=$(printf '%s\n' "${findings[@]}" | jq -s '.')
    echo '{"check": "security_configuration", "severity": "'$severity'", "findings": '$result'}'
}

# =============================================================================
# FUNÇÃO PRINCIPAL DE EXECUÇÃO
# =============================================================================

# Executar todas as verificações OWASP
run_owasp_checks() {
    log "INFO" "🚀 Iniciando verificações OWASP Top 10 Smart Contracts..."
    
    local all_results=()
    
    # Executar todas as verificações
    all_results+=("$(check_reentrancy)")
    all_results+=("$(check_integer_overflow)")
    all_results+=("$(check_timestamp_dependence)")
    all_results+=("$(check_authorization)")
    all_results+=("$(check_unprotected_withdrawal)")
    all_results+=("$(check_selfdestruct)")
    all_results+=("$(check_floating_pragma)")
    all_results+=("$(check_function_visibility)")
    all_results+=("$(check_gas_limit_dos)")
    all_results+=("$(check_unhandled_exception)")
    
    # Verificações adicionais
    all_results+=("$(check_secrets_in_code)")
    all_results+=("$(check_vulnerable_dependencies)")
    all_results+=("$(check_security_configuration)")
    
    # Gerar relatório consolidado
    local consolidated_results=$(printf '%s\n' "${all_results[@]}" | jq -s '.')
    local report_file=$(generate_json_report "owasp_security_scan" "$consolidated_results")
    
    # Calcular score de segurança
    local critical_count=$(echo "$consolidated_results" | jq '[.[] | select(.severity == "critical")] | length')
    local high_count=$(echo "$consolidated_results" | jq '[.[] | select(.severity == "high")] | length')
    local medium_count=$(echo "$consolidated_results" | jq '[.[] | select(.severity == "medium")] | length')
    local low_count=$(echo "$consolidated_results" | jq '[.[] | select(.severity == "low")] | length')
    
    local security_score=$((100 - (critical_count * 25) - (high_count * 10) - (medium_count * 5) - (low_count * 1)))
    
    log "INFO" "📊 Resumo da Verificação de Segurança:"
    log "INFO" "   Crítico: $critical_count"
    log "INFO" "   Alto: $high_count"
    log "INFO" "   Médio: $medium_count"
    log "INFO" "   Baixo: $low_count"
    log "INFO" "   Score de Segurança: $security_score/100"
    
    if [[ $security_score -ge 85 ]]; then
        log "SUCCESS" "✅ Score de segurança excelente!"
    elif [[ $security_score -ge 70 ]]; then
        log "WARN" "⚠️  Score de segurança bom, mas pode melhorar."
    else
        log "ERROR" "❌ Score de segurança baixo - ação necessária!"
    fi
    
    log "INFO" "📄 Relatório completo: $report_file"
    
    return $((critical_count + high_count))
}

# Função de ajuda
show_help() {
    cat << EOF
🔒 GMC Security Automation Script

Uso: $0 [OPÇÃO]

Opções:
  --owasp-check     Executar verificações OWASP Top 10 Smart Contracts
  --secrets-check   Verificar secrets no código
  --deps-check      Verificar dependências vulneráveis
  --config-check    Verificar configuração de segurança
  --all-checks      Executar todas as verificações
  --help           Mostrar esta ajuda

Exemplos:
  $0 --owasp-check
  $0 --all-checks
  $0 --secrets-check

Variáveis de ambiente:
  DEBUG=true        Habilitar logs de debug
  LOG_LEVEL=info    Nível de log (debug, info, warn, error)

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Verificar dependências e estrutura
    check_dependencies
    check_project_structure
    
    # Processar argumentos
    case "${1:-}" in
        "--owasp-check")
            run_owasp_checks
            ;;
        "--secrets-check")
            check_secrets_in_code
            ;;
        "--deps-check")
            check_vulnerable_dependencies
            ;;
        "--config-check")
            check_security_configuration
            ;;
        "--all-checks")
            run_owasp_checks
            ;;
        "--help")
            show_help
            ;;
        "")
            log "INFO" "Executando verificações padrão..."
            run_owasp_checks
            ;;
        *)
            log "ERROR" "Opção inválida: $1"
            show_help
            exit 1
            ;;
    esac
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi