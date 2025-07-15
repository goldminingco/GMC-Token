#!/bin/bash

# GMC Ecosystem - Local TDD Environment Setup
# This script sets up the local development environment for TDD implementation

set -e

echo "🚀 GMC Ecosystem - Local TDD Environment Setup"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if solana-test-validator is available
check_solana_validator() {
    if ! command -v solana-test-validator &> /dev/null; then
        print_error "solana-test-validator not found. Please install Solana CLI tools."
        exit 1
    fi
    print_success "Solana test validator found"
}

# Check if local validator is running
check_validator_running() {
    if pgrep -f "solana-test-validator" > /dev/null; then
        print_warning "Local validator is already running"
        return 0
    else
        return 1
    fi
}

# Start local validator
start_validator() {
    print_status "Starting Solana local validator..."
    
    # Kill any existing validator
    pkill -f "solana-test-validator" 2>/dev/null || true
    sleep 2
    
    # Create anchor directory if it doesn't exist
    mkdir -p .anchor
    
    # Start validator with optimized settings for development
    print_status "Launching validator with enhanced configuration..."
    solana-test-validator \
        --reset \
        --quiet \
        --ledger .anchor/test-ledger \
        --bind-address 127.0.0.1 \
        --rpc-port 8899 \
        --faucet-port 9900 \
        --faucet-sol 1000000 \
        --slots-per-epoch 32 \
        --limit-ledger-size 10000000 \
        --log \
        > .anchor/validator.log 2>&1 &
    
    VALIDATOR_PID=$!
    
    # Wait for validator to start
    print_status "Waiting for validator to initialize..."
    sleep 10
    
    # Check if validator is running
    if check_validator_running; then
        print_success "Local validator started successfully (PID: $VALIDATOR_PID)"
    else
        print_error "Failed to start local validator"
        print_warning "Trying alternative startup method..."
        
        # Try without reset flag
        solana-test-validator \
            --quiet \
            --ledger .anchor/test-ledger \
            --bind-address 127.0.0.1 \
            --rpc-port 8899 \
            --faucet-port 9900 \
            --faucet-sol 1000000 \
            --log \
            > .anchor/validator.log 2>&1 &
        
        sleep 10
        
        if ! check_validator_running; then
            print_error "Unable to start validator. Please check if Solana is properly installed."
            exit 1
        else
            print_success "Local validator started with alternative method"
        fi
    fi
}

# Check and optimize dependencies
check_dependencies() {
    print_status "Checking and optimizing dependencies..."
    if [ -f "scripts/manage_dependencies.sh" ]; then
        print_status "Running dependency analysis (non-interactive)..."
        # Execute dependency script with automatic 'no' to cleanup question
        echo "n" | bash scripts/manage_dependencies.sh
    else
        print_warning "Dependency management script not found"
    fi
}

# Configure Solana CLI for local development
configure_solana_cli() {
    print_status "Configuring Solana CLI for local development..."
    
    # Set config to localnet
    solana config set --url http://127.0.0.1:8899
    
    # Generate or use existing keypair
    if [ ! -f ~/.config/solana/id.json ]; then
        print_status "Generating new Solana keypair..."
        solana-keygen new --no-bip39-passphrase --silent --outfile ~/.config/solana/id.json
    fi
    
    # Airdrop SOL for development
    print_status "Requesting SOL airdrop..."
    solana airdrop 1000 --url http://127.0.0.1:8899 || true
    
    # Show wallet info
    echo ""
    print_success "Solana CLI configured:"
    solana config get
    echo ""
    print_success "Wallet balance:"
    solana balance
    echo ""
}

# Build and deploy programs
build_and_deploy() {
    print_status "Building Anchor programs..."
    
    # Clean previous builds
    anchor clean
    
    # Build programs
    if anchor build; then
        print_success "Programs built successfully"
    else
        print_error "Failed to build programs"
        exit 1
    fi
    
    print_status "Deploying programs to local validator..."
    
    # Deploy programs
    if anchor deploy; then
        print_success "Programs deployed successfully"
    else
        print_error "Failed to deploy programs"
        exit 1
    fi
}

# Run TDD tests
run_tdd_tests() {
    print_status "Running TDD tests..."
    echo ""
    
    print_status "🔴 Running RED Phase Tests (should FAIL)..."
    echo "==========================================="
    
    # Test 1: Real Fee Collection (CRITICAL-001)
    print_status "Testing CRITICAL-001: Real SPL Token-2022 Fee Collection"
    if npx mocha tests/10_real_fee_collection_tdd.test.ts --timeout 60000 --reporter spec; then
        print_warning "CRITICAL-001 tests passed - implementation may already exist"
    else
        print_success "CRITICAL-001 tests failed as expected (RED phase)"
    fi
    echo ""
    
    # Test 2: Multilevel Affiliate System (CRITICAL-003)
    print_status "Testing CRITICAL-003: Multilevel Affiliate System"
    if npx mocha tests/11_multilevel_affiliate_system_tdd.test.ts --timeout 60000 --reporter spec; then
        print_warning "CRITICAL-003 tests passed - implementation may already exist"
    else
        print_success "CRITICAL-003 tests failed as expected (RED phase)"
    fi
    echo ""
    
    # Test 3: Emergency Unstake Penalty (CRITICAL-002)
    print_status "Testing CRITICAL-002: Emergency Unstake Penalty Correction"
    if npx mocha tests/12_emergency_unstake_penalty_tdd.test.ts --timeout 60000 --reporter spec; then
        print_warning "CRITICAL-002 tests passed - implementation may already exist"
    else
        print_success "CRITICAL-002 tests failed as expected (RED phase)"
    fi
    echo ""
    
    print_status "🟢 TDD RED Phase Complete!"
    echo "Next steps:"
    echo "1. Implement the failing functionality (GREEN phase)"
    echo "2. Make tests pass with minimal code"
    echo "3. Refactor for optimization (REFACTOR phase)"
    echo ""
}

# Generate development report
generate_report() {
    print_status "Generating TDD development report..."
    
    REPORT_FILE="reports/tdd_setup_report_$(date +%Y%m%d_%H%M%S).md"
    mkdir -p reports
    
    cat > "$REPORT_FILE" << EOF
# GMC Ecosystem - TDD Setup Report

Generated: $(date)
Environment: Local Development (Localnet)

## Setup Summary

### Environment Configuration
- Solana Cluster: Localnet (http://127.0.0.1:8899)
- Anchor Version: $(anchor --version)
- Solana CLI Version: $(solana --version)
- Wallet: $(solana address)
- Balance: $(solana balance)

### Programs Deployed
$(anchor show)

### TDD Tests Created

#### CRITICAL-001: Real SPL Token-2022 Fee Collection
- File: tests/10_real_fee_collection_tdd.test.ts
- Status: RED phase (tests should fail)
- Implementation needed: collect_and_distribute_fees with real CPI

#### CRITICAL-003: Multilevel Affiliate System
- File: tests/11_multilevel_affiliate_system_tdd.test.ts
- Status: RED phase (tests should fail)
- Implementation needed: 6-level affiliate tree traversal

#### CRITICAL-002: Emergency Unstake Penalty Correction
- File: tests/12_emergency_unstake_penalty_tdd.test.ts
- Status: RED phase (tests should fail)
- Implementation needed: 5 USDT + 50% capital + 80% interest penalty

## Next Steps

1. **GREEN Phase**: Implement minimal code to make tests pass
2. **REFACTOR Phase**: Optimize for gas efficiency and security
3. **Integration**: Test with existing ecosystem components
4. **Security Audit**: Review implementations for vulnerabilities

## Development Commands

\`\`\`bash
# Run specific TDD test
npx mocha tests/10_real_fee_collection_tdd.test.ts --timeout 60000

# Build and redeploy after changes
anchor build && anchor deploy

# Check validator logs
tail -f .anchor/validator.log

# Stop validator
pkill -f "solana-test-validator"
\`\`\`

## Performance Targets

- Fee collection: <50,000 compute units
- Affiliate calculation: <30,000 compute units
- Emergency penalty: <25,000 compute units
- Total gas cost per operation: <0.001 SOL

EOF

    print_success "Report generated: $REPORT_FILE"
}

# Main execution
main() {
    echo ""
    print_status "Starting GMC Ecosystem Local TDD Setup..."
    echo ""
    
    # Step 1: Check prerequisites
    check_solana_validator
    
    # Step 2: Check and optimize dependencies
    check_dependencies
    
    # Step 3: Start local validator if not running
    if ! check_validator_running; then
        start_validator
    fi
    
    # Step 4: Configure Solana CLI
    configure_solana_cli
    
    # Step 5: Build and deploy programs
    build_and_deploy
    
    # Step 6: Run TDD tests
    run_tdd_tests
    
    # Step 7: Generate report
    generate_report
    
    echo ""
    print_success "🎉 GMC Ecosystem Local TDD Environment Ready!"
    print_status "You can now start implementing the failing tests."
    print_status "Use 'npx mocha tests/<test_file>' to run specific tests."
    echo ""
}

# Handle script interruption
trap 'print_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"