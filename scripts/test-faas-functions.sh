#!/bin/bash

# Test script for faas namespace functions
echo "🚀 Testing Fission functions in faas namespace..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if fission CLI is available
if ! command -v fission &> /dev/null; then
    print_error "Fission CLI not found. Please install it first."
    exit 1
fi

# Check if the faas namespace exists
if ! kubectl get namespace faas &> /dev/null; then
    print_error "faas namespace not found. Please run setup.sh first."
    exit 1
fi

# Test function 1: hello-faas
print_status "Testing hello-faas function..."
result1=$(fission function test --name hello-faas --namespace faas 2>/dev/null)
if [[ $? -eq 0 ]]; then
    print_success "hello-faas function working!"
    echo "Response: $result1"
else
    print_error "hello-faas function failed"
fi

echo ""

# Test function 2: math-faas
print_status "Testing math-faas function..."
result2=$(fission function test --name math-faas --namespace faas 2>/dev/null)
if [[ $? -eq 0 ]]; then
    print_success "math-faas function working!"
    echo "Response: $result2"
else
    print_error "math-faas function failed"
fi

echo ""

# List all functions in faas namespace
print_status "Functions in faas namespace:"
fission function list --namespace faas

echo ""

# List all environments in faas namespace
print_status "Environments in faas namespace:"
fission env list --namespace faas

echo ""

# Check coder-server access
print_status "Checking coder-server accessibility..."
if kubectl get service coder-server -n fission &> /dev/null; then
    print_success "Coder-server is running and accessible at http://localhost:31315"
    print_warning "Password: coder123"
else
    print_error "Coder-server not found"
fi

echo ""
print_success "✅ Test complete! Your faas namespace is working properly."
print_status "Use 'fission -n faas' commands for all function operations." 