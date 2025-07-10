#!/bin/bash

# Create Function Script with Proper Labeling
# This script creates functions with consistent labeling for easy management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="default"
PROJECT_LABEL="project=coder-faas"
MANAGED_BY_LABEL="managed-by=coder"
ENV_NAME="coder-faas-nodejs"

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

# Function to show usage
usage() {
    echo "Usage: $0 <function-name> <code-file> [executor-type]"
    echo ""
    echo "Examples:"
    echo "  $0 my-hello functions/hello.js"
    echo "  $0 my-api functions/api.js newdeploy"
    echo ""
    echo "Arguments:"
    echo "  function-name   Name for the function (will be prefixed with 'coder-faas-')"
    echo "  code-file       Path to the function code file"
    echo "  executor-type   Optional: 'poolmgr' (default) or 'newdeploy'"
    exit 1
}

# Check arguments
if [ $# -lt 2 ]; then
    usage
fi

FUNCTION_BASE_NAME="$1"
CODE_FILE="$2"
EXECUTOR_TYPE="${3:-poolmgr}"
FUNCTION_NAME="coder-faas-${FUNCTION_BASE_NAME}"

# Validate inputs
if [ ! -f "$CODE_FILE" ]; then
    log_error "Code file not found: $CODE_FILE"
    exit 1
fi

if [[ "$EXECUTOR_TYPE" != "poolmgr" && "$EXECUTOR_TYPE" != "newdeploy" ]]; then
    log_error "Invalid executor type. Use 'poolmgr' or 'newdeploy'"
    exit 1
fi

# Check if environment exists
check_environment() {
    log_info "Checking if environment '$ENV_NAME' exists..."
    
    if ! kubectl exec -n fission deployment/coder-server -- fission env get --name "$ENV_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_warning "Environment '$ENV_NAME' not found. Creating it..."
        kubectl exec -n fission deployment/coder-server -- fission env create \
            --name "$ENV_NAME" \
            --image "ghcr.io/fission/node-env-22:latest" \
            -n "$NAMESPACE" \
            --labels="$PROJECT_LABEL,$MANAGED_BY_LABEL"
        log_success "Environment '$ENV_NAME' created"
    else
        log_success "Environment '$ENV_NAME' exists"
    fi
}

# Create function
create_function() {
    log_info "Creating function '$FUNCTION_NAME'..."
    
    # Copy local code file to coder workspace
    log_info "Copying code file to coder workspace..."
    local pod_name
    pod_name=$(kubectl get pod -n fission -l app=coder-server -o jsonpath="{.items[0].metadata.name}")
    kubectl cp "$CODE_FILE" "fission/$pod_name:/home/coder/workspace/$CODE_FILE"
    
    # Check if function already exists
    if kubectl exec -n fission deployment/coder-server -- fission function get --name "$FUNCTION_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_warning "Function '$FUNCTION_NAME' already exists. Updating..."
        kubectl exec -n fission deployment/coder-server -- bash -c "cd /home/coder/workspace && fission function update \
            --name '$FUNCTION_NAME' \
            --code '$CODE_FILE' \
            -n '$NAMESPACE'"
    else
        kubectl exec -n fission deployment/coder-server -- bash -c "cd /home/coder/workspace && fission function create \
            --name '$FUNCTION_NAME' \
            --env '$ENV_NAME' \
            --code '$CODE_FILE' \
            -n '$NAMESPACE' \
            --labels='$PROJECT_LABEL,$MANAGED_BY_LABEL'"
    fi
    
    # Configure executor type if newdeploy
    if [ "$EXECUTOR_TYPE" = "newdeploy" ]; then
        log_info "Configuring function for newdeploy executor..."
        kubectl exec -n fission deployment/coder-server -- fission function update \
            --name "$FUNCTION_NAME" \
            --executortype newdeploy \
            --minscale 1 \
            --maxscale 3 \
            -n "$NAMESPACE"
    fi
    
    log_success "Function '$FUNCTION_NAME' created/updated successfully!"
}

# Test function
test_function() {
    log_info "Testing function '$FUNCTION_NAME'..."
    
    sleep 2  # Give it a moment to be ready
    
    if kubectl exec -n fission deployment/coder-server -- fission function test --name "$FUNCTION_NAME" -n "$NAMESPACE"; then
        log_success "Function test successful!"
    else
        log_warning "Function test failed. The function may still be initializing."
        log_info "You can test it manually with:"
        log_info "  kubectl exec -n fission deployment/coder-server -- fission function test --name $FUNCTION_NAME -n $NAMESPACE"
    fi
}

# Create HTTP trigger
create_trigger() {
    local trigger_name="${FUNCTION_NAME}-trigger"
    local url="/${FUNCTION_BASE_NAME}"
    
    log_info "Creating HTTP trigger at '$url'..."
    
    if kubectl exec -n fission deployment/coder-server -- fission httptrigger get --name "$trigger_name" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_warning "HTTP trigger '$trigger_name' already exists"
    else
        kubectl exec -n fission deployment/coder-server -- fission httptrigger create \
            --name "$trigger_name" \
            --function "$FUNCTION_NAME" \
            --url "$url" \
            -n "$NAMESPACE"
        log_success "HTTP trigger created: $url"
    fi
}

# Main execution
main() {
    log_info "Creating Coder FaaS function: $FUNCTION_NAME"
    log_info "Code file: $CODE_FILE"
    log_info "Executor: $EXECUTOR_TYPE"
    log_info "Namespace: $NAMESPACE"
    echo
    
    check_environment
    create_function
    create_trigger
    test_function
    
    echo
    log_success "Function setup complete!"
    log_info "Commands to manage your function:"
    echo "  📋 List: kubectl exec -n fission deployment/coder-server -- fission function list -n $NAMESPACE"
    echo "  🧪 Test: kubectl exec -n fission deployment/coder-server -- fission function test --name $FUNCTION_NAME -n $NAMESPACE"
    echo "  📝 Logs: kubectl exec -n fission deployment/coder-server -- fission function logs --name $FUNCTION_NAME -n $NAMESPACE"
    echo "  🌐 HTTP: Create route or use trigger at /${FUNCTION_BASE_NAME}"
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@" 