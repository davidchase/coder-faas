#!/bin/bash

# Port Forward Script for Coder Access
# This script sets up port forwarding to access Coder code-server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="fission"
LOCAL_PORT="31315"
SERVICE_PORT="8080"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Coder service exists
check_service() {
    if ! kubectl get service coder-server -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Coder service not found. Please deploy Coder first:"
        log_info "  ./scripts/deploy-to-existing.sh"
        exit 1
    fi
}

# Kill existing port forwards
cleanup_existing() {
    log_info "Cleaning up existing port forwards..."
    pkill -f "port-forward.*coder-server" 2>/dev/null || true
    pkill -f "port-forward.*$LOCAL_PORT" 2>/dev/null || true
    sleep 2
}

# Start port forwarding
start_portforward() {
    log_info "Starting port forward: localhost:$LOCAL_PORT -> coder-server:$SERVICE_PORT"
    
    # Start port forward in background
    kubectl port-forward -n "$NAMESPACE" service/coder-server "$LOCAL_PORT:$SERVICE_PORT" &
    
    # Get the PID
    PORT_FORWARD_PID=$!
    
    # Wait a moment for it to start
    sleep 3
    
    # Test if it's working
    if curl -s -I http://localhost:$LOCAL_PORT >/dev/null 2>&1; then
        log_success "Port forwarding established successfully!"
        log_info "🌐 Coder Code-Server: http://localhost:$LOCAL_PORT"
        log_info "🔑 Password: coder"
        log_info "📋 PID: $PORT_FORWARD_PID"
        
        # Save PID for later cleanup
        echo $PORT_FORWARD_PID > /tmp/coder-portforward.pid
        
        log_warning "Port forwarding is running in background."
        log_info "To stop: ./scripts/stop-portforward.sh"
        log_info "Or kill manually: kill $PORT_FORWARD_PID"
        
    else
        log_error "Port forwarding failed to start properly"
        kill $PORT_FORWARD_PID 2>/dev/null || true
        exit 1
    fi
}

# Main execution
main() {
    log_info "Setting up Coder Code-Server access..."
    
    check_service
    cleanup_existing
    start_portforward
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@" 