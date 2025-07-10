#!/bin/bash

# Manage Coder FaaS Functions
# This script helps list, inspect, and clean up coder-faas functions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="default"
PROJECT_LABEL="project=coder-faas"

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

log_header() {
    echo -e "${CYAN}==== $1 ====${NC}"
}

# Function to show usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list              List all coder-faas functions"
    echo "  list-all          List all functions (including non-coder-faas)"
    echo "  status            Show detailed status of coder-faas functions"
    echo "  logs <name>       Show logs for a specific function"
    echo "  test <name>       Test a specific function"
    echo "  delete <name>     Delete a specific function"
    echo "  cleanup           Delete ALL coder-faas functions (interactive)"
    echo "  cleanup-force     Delete ALL coder-faas functions (no confirmation)"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 logs hello"
    echo "  $0 test hello"
    echo "  $0 delete hello"
    echo "  $0 cleanup"
    exit 1
}

# List coder-faas functions only
list_functions() {
    log_header "Coder FaaS Functions"
    
    # Get all functions and filter for coder-faas
    local all_functions
    all_functions=$(kubectl exec -n fission deployment/coder-server -- fission function list -n "$NAMESPACE" 2>/dev/null || true)
    
    if [ -z "$all_functions" ]; then
        log_warning "No functions found in namespace $NAMESPACE"
        echo "Create one with: ./scripts/create-function.sh <name> <code-file>"
        return
    fi
    
    # Filter for coder-faas functions
    local functions
    functions=$(echo "$all_functions" | grep "coder-faas-" || true)
    
    if [ -z "$functions" ]; then
        log_warning "No coder-faas functions found"
        echo "Create one with: ./scripts/create-function.sh <name> <code-file>"
        echo ""
        log_info "All functions in $NAMESPACE:"
        echo "$all_functions"
    else
        # Show header from original output
        echo "$all_functions" | head -1
        echo "$functions"
        echo
        log_info "Total coder-faas functions: $(echo "$functions" | wc -l | tr -d ' ')"
    fi
}

# List all functions
list_all_functions() {
    log_header "All Functions in $NAMESPACE Namespace"
    kubectl exec -n fission deployment/coder-server -- fission function list -n "$NAMESPACE"
}

# Show detailed status
show_status() {
    log_header "Coder FaaS Function Status"
    
    # Get function names
    local function_names
    function_names=$(kubectl exec -n fission deployment/coder-server -- fission function list -n "$NAMESPACE" --output name 2>/dev/null | grep "coder-faas-" || true)
    
    if [ -z "$function_names" ]; then
        log_warning "No coder-faas functions found"
        return
    fi
    
    for func_name in $function_names; do
        echo
        log_info "Function: $func_name"
        
        # Get function details
        kubectl exec -n fission deployment/coder-server -- fission function get --name "$func_name" -n "$NAMESPACE" 2>/dev/null || log_error "Failed to get details for $func_name"
        
        # Check if there are any pods running
        local pods
        pods=$(kubectl get pods -n "$NAMESPACE" -l "functionName=$func_name" --no-headers 2>/dev/null || true)
        if [ -n "$pods" ]; then
            echo "  Pods:"
            echo "$pods" | sed 's/^/    /'
        else
            echo "  Pods: None running"
        fi
    done
}

# Show logs for a function
show_logs() {
    local func_name="$1"
    local full_name="coder-faas-${func_name}"
    
    log_info "Showing logs for function: $full_name"
    kubectl exec -n fission deployment/coder-server -- fission function logs --name "$full_name" -n "$NAMESPACE"
}

# Test a function
test_function() {
    local func_name="$1"
    local full_name="coder-faas-${func_name}"
    
    log_info "Testing function: $full_name"
    kubectl exec -n fission deployment/coder-server -- fission function test --name "$full_name" -n "$NAMESPACE"
}

# Delete a specific function
delete_function() {
    local func_name="$1"
    local full_name="coder-faas-${func_name}"
    
    log_warning "Deleting function: $full_name"
    
    # Delete HTTP trigger if exists
    local trigger_name="${full_name}-trigger"
    if kubectl exec -n fission deployment/coder-server -- fission httptrigger get --name "$trigger_name" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Deleting HTTP trigger: $trigger_name"
        kubectl exec -n fission deployment/coder-server -- fission httptrigger delete --name "$trigger_name" -n "$NAMESPACE"
    fi
    
    # Delete function
    kubectl exec -n fission deployment/coder-server -- fission function delete --name "$full_name" -n "$NAMESPACE"
    log_success "Function $full_name deleted"
}

# Cleanup all coder-faas functions
cleanup_functions() {
    local force="$1"
    
    # Get function names
    local function_names
    function_names=$(kubectl exec -n fission deployment/coder-server -- fission function list -n "$NAMESPACE" --output name 2>/dev/null | grep "coder-faas-" || true)
    
    if [ -z "$function_names" ]; then
        log_info "No coder-faas functions to cleanup"
        return
    fi
    
    log_warning "Found coder-faas functions to delete:"
    for func_name in $function_names; do
        echo "  - $func_name"
    done
    
    if [ "$force" != "force" ]; then
        echo
        read -p "Are you sure you want to delete ALL coder-faas functions? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            return
        fi
    fi
    
    echo
    for func_name in $function_names; do
        log_info "Deleting: $func_name"
        
        # Delete HTTP trigger if exists
        local trigger_name="${func_name}-trigger"
        if kubectl exec -n fission deployment/coder-server -- fission httptrigger get --name "$trigger_name" -n "$NAMESPACE" >/dev/null 2>&1; then
            kubectl exec -n fission deployment/coder-server -- fission httptrigger delete --name "$trigger_name" -n "$NAMESPACE" >/dev/null 2>&1 || true
        fi
        
        # Delete function
        kubectl exec -n fission deployment/coder-server -- fission function delete --name "$func_name" -n "$NAMESPACE" >/dev/null 2>&1 || true
    done
    
    # Also cleanup environment if no functions left
    local remaining_functions
    remaining_functions=$(kubectl exec -n fission deployment/coder-server -- fission function list -n "$NAMESPACE" --output name 2>/dev/null | grep "coder-faas-" || true)
    
    if [ -z "$remaining_functions" ]; then
        log_info "Cleaning up environment..."
        kubectl exec -n fission deployment/coder-server -- fission env delete --name "coder-faas-nodejs" -n "$NAMESPACE" >/dev/null 2>&1 || true
    fi
    
    log_success "Cleanup completed"
}

# Main execution
main() {
    local command="$1"
    local arg="$2"
    
    case "$command" in
        "list")
            list_functions
            ;;
        "list-all")
            list_all_functions
            ;;
        "status")
            show_status
            ;;
        "logs")
            if [ -z "$arg" ]; then
                log_error "Function name required for logs command"
                echo "Usage: $0 logs <function-name>"
                exit 1
            fi
            show_logs "$arg"
            ;;
        "test")
            if [ -z "$arg" ]; then
                log_error "Function name required for test command"
                echo "Usage: $0 test <function-name>"
                exit 1
            fi
            test_function "$arg"
            ;;
        "delete")
            if [ -z "$arg" ]; then
                log_error "Function name required for delete command"
                echo "Usage: $0 delete <function-name>"
                exit 1
            fi
            delete_function "$arg"
            ;;
        "cleanup")
            cleanup_functions
            ;;
        "cleanup-force")
            cleanup_functions "force"
            ;;
        *)
            if [ -z "$command" ]; then
                list_functions
            else
                log_error "Unknown command: $command"
                usage
            fi
            ;;
    esac
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@" 