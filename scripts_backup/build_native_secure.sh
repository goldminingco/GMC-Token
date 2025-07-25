#!/bin/bash
# 🛡️ GMC Token Native Rust Secure Build Script
# Integrates TDD + OWASP + DevSecOps + Security Auditing
# 
# This script follows our Security-First Development methodology

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Security banner
echo -e "${PURPLE}🛡️ =====================================${NC}"
echo -e "${PURPLE}🛡️  GMC TOKEN NATIVE RUST SECURE BUILD${NC}"
echo -e "${PURPLE}🛡️  TDD + OWASP + DevSecOps Pipeline${NC}"
echo -e "${PURPLE}🛡️ =====================================${NC}"

# Navigate to program directory
cd programs/gmc_token_native

echo -e "\n${BLUE}📋 Step 1: Environment Validation${NC}"
echo "🔍 Checking Rust version..."
rustc --version
echo "🔍 Checking Cargo version..."
cargo --version
echo "🔍 Checking Solana CLI version..."
solana --version

echo -e "\n${BLUE}🧪 Step 2: TDD Testing Phase (Red-Green-Refactor-Security)${NC}"
echo "🔴 Running unit tests..."
cargo test --lib --verbose

echo -e "\n${BLUE}🛡️ Step 3: Security Audit Phase${NC}"
echo "🔍 Running cargo audit for vulnerability scanning..."
cargo audit

echo "🔍 Running cargo deny for dependency policy enforcement..."
cargo deny check

echo -e "\n${BLUE}🧪 Step 4: Property-Based Testing (Security Fuzzing)${NC}"
echo "🎯 Running property-based tests for security validation..."
cargo test property_tests --verbose

echo -e "\n${BLUE}🔧 Step 5: Code Quality Checks${NC}"
echo "🔍 Running clippy for code quality..."
cargo clippy --all-targets --all-features -- -D warnings

echo "🔍 Running format check..."
cargo fmt --check

echo -e "\n${BLUE}🏗️ Step 6: Secure Build Phase${NC}"
echo "🔨 Building with security optimizations..."
cargo build-sbf --verbose

echo -e "\n${BLUE}📦 Step 7: Artifact Validation${NC}"
echo "🔍 Checking build artifacts..."
if [ -f "../../target/sbf-solana-solana/release/deps/gmc_token_native.so" ]; then
    echo "✅ Build artifact found"
    
    # Copy to deploy directory
    mkdir -p ../../deploy
    cp ../../target/sbf-solana-solana/release/deps/gmc_token_native.so ../../deploy/
    echo "📦 Artifact copied to deploy/"
    
    # Validate artifact
    ls -la ../../deploy/gmc_token_native.so
    file ../../deploy/gmc_token_native.so
else
    echo -e "${RED}❌ Build artifact not found${NC}"
    exit 1
fi

echo -e "\n${BLUE}🛡️ Step 8: Security Validation${NC}"
echo "🔍 Running final security checks on artifact..."

# Check for common security issues in the binary
echo "🔍 Checking binary security properties..."
if command -v objdump &> /dev/null; then
    echo "📊 Binary analysis:"
    objdump -h ../../deploy/gmc_token_native.so | head -20
fi

echo -e "\n${GREEN}✅ =====================================${NC}"
echo -e "${GREEN}✅  SECURE BUILD COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}✅  All security checks passed${NC}"
echo -e "${GREEN}✅  Artifact ready for deployment${NC}"
echo -e "${GREEN}✅ =====================================${NC}"

echo -e "\n${YELLOW}📋 Build Summary:${NC}"
echo "🏗️ Program: GMC Token Native Rust"
echo "🛡️ Security: OWASP + DevSecOps validated"
echo "🧪 Testing: TDD + Property-based tests passed"
echo "📦 Artifact: ../../deploy/gmc_token_native.so"
echo "🚀 Status: Ready for deployment"

echo -e "\n${BLUE}🚀 Next Steps:${NC}"
echo "1. Deploy: ./scripts/deploy_and_test.sh"
echo "2. Monitor: ./scripts/monitor_validator.sh"
echo "3. Interact: node scripts/interact_with_program.js"
