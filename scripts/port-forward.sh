#!/bin/bash

# Port forwarding script for coder-server on macOS
# Kind doesn't expose NodePorts directly on macOS, so we need port forwarding

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
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

# Check if coder-server is running
if ! kubectl get service coder-server -n fission &>/dev/null; then
    print_error "Coder-server service not found. Please run ./scripts/setup.sh first."
    exit 1
fi

# Check if port forwarding is already running
if lsof -i :31315 &>/dev/null; then
    print_warning "Port 31315 is already in use. Checking if it's our port forwarding..."
    
    # Kill existing port forwarding if it's kubectl
    pkill -f "kubectl port-forward.*coder-server" 2>/dev/null || true
    sleep 2
fi

print_info "Starting port forwarding for coder-server..."
print_info "This will make coder-server accessible at http://localhost:31315"

# Start port forwarding
kubectl port-forward -n fission service/coder-server 31315:8080 &
PORT_FORWARD_PID=$!

# Wait a moment for it to establish
sleep 3

# Check if port forwarding is working
if lsof -i :31315 &>/dev/null; then
    print_success "✅ Port forwarding active!"
    echo ""
    print_info "🌐 Access Information:"
    echo "  URL: http://localhost:31315"
    echo "  Password: coder123"
    echo ""
    print_warning "⚠️  Keep this terminal open to maintain the connection"
    print_info "   Press Ctrl+C to stop port forwarding"
    echo ""
    
    # Wait for user to stop
    wait $PORT_FORWARD_PID
else
    print_error "Failed to establish port forwarding"
    exit 1
fi 