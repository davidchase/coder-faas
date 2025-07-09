#!/bin/bash

# Cleanup script for Fission + Coder Development Environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="fission-dev"
NAMESPACE="fission"

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

# Cleanup function
cleanup_environment() {
    log_info "Starting cleanup of Fission + Coder Development Environment"
    
    # Check if Kind cluster exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log_warning "This will delete the entire '$CLUSTER_NAME' cluster and all data."
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting Kind cluster '$CLUSTER_NAME'..."
            kind delete cluster --name "$CLUSTER_NAME"
            log_success "Cluster '$CLUSTER_NAME' deleted successfully!"
        else
            log_info "Cleanup cancelled."
            exit 0
        fi
    else
        log_info "Cluster '$CLUSTER_NAME' not found. Nothing to clean up."
    fi
    
    # Clean up any local files if needed
    log_info "Cleaning up local temporary files..."
    
    # Remove any temporary files created during setup
    if [ -d "/tmp/fission-setup" ]; then
        rm -rf /tmp/fission-setup
        log_info "Removed temporary setup files"
    fi
    
    log_success "Cleanup completed successfully!"
}

# Partial cleanup function (keep cluster, remove only applications)
partial_cleanup() {
    log_info "Starting partial cleanup (removing applications only)..."
    
    # Check if cluster exists and we have context
    if ! kubectl cluster-info &>/dev/null; then
        log_error "No active Kubernetes context found."
        exit 1
    fi
    
    # Remove Coder deployment
    if kubectl get deployment coder-server -n "$NAMESPACE" &>/dev/null; then
        log_info "Removing Coder code-server..."
        kubectl delete -f manifests/coder-server.yaml || true
        log_success "Coder code-server removed"
    fi
    
    # Remove Fission (if installed via Helm)
    if helm list -n "$NAMESPACE" | grep -q fission; then
        log_info "Removing Fission..."
        helm uninstall fission -n "$NAMESPACE"
        log_success "Fission removed"
    fi
    
    # Optionally remove namespace
    read -p "Do you want to remove the '$NAMESPACE' namespace? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        log_success "Namespace '$NAMESPACE' removed"
    fi
    
    log_success "Partial cleanup completed!"
}

# Main menu
main() {
    echo "Fission + Coder Development Environment Cleanup"
    echo "================================================"
    echo
    echo "Choose cleanup option:"
    echo "1) Full cleanup (delete entire Kind cluster)"
    echo "2) Partial cleanup (remove applications, keep cluster)"
    echo "3) Cancel"
    echo
    
    read -p "Enter your choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            cleanup_environment
            ;;
        2)
            partial_cleanup
            ;;
        3)
            log_info "Cleanup cancelled."
            exit 0
            ;;
        *)
            log_error "Invalid choice. Please run the script again."
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_error "Cleanup interrupted"; exit 1' INT TERM

# Run main function
main "$@" 