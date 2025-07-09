#!/bin/bash

# Stop Port Forward Script for Coder Access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Stop port forwarding
stop_portforward() {
    log_info "Stopping Coder port forwarding..."
    
    local stopped=false
    
    # Try to kill using saved PID
    if [ -f "/tmp/coder-portforward.pid" ]; then
        local pid=$(cat /tmp/coder-portforward.pid)
        if kill "$pid" 2>/dev/null; then
            log_success "Stopped port forward (PID: $pid)"
            stopped=true
        fi
        rm -f /tmp/coder-portforward.pid
    fi
    
    # Kill any remaining port forwards for coder-server
    if pkill -f "port-forward.*coder-server" 2>/dev/null; then
        log_success "Stopped additional port forwards"
        stopped=true
    fi
    
    # Kill any port forwards on port 31315
    if pkill -f "port-forward.*31315" 2>/dev/null; then
        log_success "Stopped port forwards on port 31315"
        stopped=true
    fi
    
    if [ "$stopped" = true ]; then
        log_success "All Coder port forwards stopped"
    else
        log_warning "No active port forwards found"
    fi
}

# Main execution
main() {
    log_info "Stopping Coder Code-Server port forwarding..."
    stop_portforward
}

# Run main function
main "$@" 