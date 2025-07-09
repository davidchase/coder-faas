#!/bin/bash

# Deploy Coder to Existing Fission Cluster
# This script safely deploys Coder code-server to an existing Fission installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="fission"
CODER_PORT="31315"

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

# Check if kubectl is available and cluster is accessible
check_cluster() {
    log_info "Checking cluster connectivity..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Cluster connectivity confirmed"
}

# Verify Fission installation
verify_fission() {
    log_info "Verifying existing Fission installation..."
    
    # Check if Fission namespace exists
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Fission namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    # Check if Fission core components are running
    local required_deployments=("router" "executor" "webhook" "buildermgr" "storagesvc")
    local missing_deployments=()
    
    for deployment in "${required_deployments[@]}"; do
        if ! kubectl get deployment "$deployment" -n "$NAMESPACE" >/dev/null 2>&1; then
            missing_deployments+=("$deployment")
        fi
    done
    
    if [ ${#missing_deployments[@]} -ne 0 ]; then
        log_error "Missing Fission deployments: ${missing_deployments[*]}"
        log_error "Please ensure Fission is properly installed"
        exit 1
    fi
    
    # Check if deployments are ready
    for deployment in "${required_deployments[@]}"; do
        if ! kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout=30s >/dev/null 2>&1; then
            log_warning "Deployment '$deployment' may not be fully ready"
        fi
    done
    
    log_success "Fission installation verified"
}

# Check if Coder is already deployed
check_existing_coder() {
    if kubectl get deployment coder-server -n "$NAMESPACE" >/dev/null 2>&1; then
        log_warning "Coder code-server is already deployed"
        read -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping Coder deployment"
            show_access_info
            exit 0
        fi
        return 1
    fi
    return 0
}

# Deploy Coder server
deploy_coder() {
    log_info "Deploying Coder code-server to existing Fission cluster..."
    
    # Check if manifests directory exists
    if [ ! -f "manifests/coder-server.yaml" ]; then
        log_error "Coder manifests not found. Please ensure you're in the correct directory."
        exit 1
    fi
    
    # Apply Coder manifests
    kubectl apply -f manifests/coder-server.yaml
    
    # Wait for Coder to be ready
    log_info "Waiting for Coder code-server to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/coder-server -n "$NAMESPACE"
    
    # Wait for pod to be running
    kubectl wait --for=condition=ready pod -l app=coder-server -n "$NAMESPACE" --timeout=300s
    
    log_success "Coder code-server deployed successfully!"
}

# Create sample functions if they don't exist
create_samples() {
    log_info "Creating sample functions..."
    
    # Create functions directory
    mkdir -p functions/examples
    
    # Only create samples if they don't exist
    if [ ! -f "functions/examples/hello-node.js" ]; then
        cat > functions/examples/hello-node.js << 'EOF'
module.exports = async function(context) {
    return {
        status: 200,
        body: {
            message: "Hello from Node.js in Fission!",
            timestamp: new Date().toISOString(),
            headers: context.request.headers
        }
    };
}
EOF
        log_info "Created Node.js sample function"
    fi
    
    if [ ! -f "functions/examples/hello-python.py" ]; then
        cat > functions/examples/hello-python.py << 'EOF'
def main():
    return {
        "message": "Hello from Python in Fission!",
        "timestamp": "2024-01-01T00:00:00Z",
        "runtime": "python"
    }
EOF
        log_info "Created Python sample function"
    fi
    
    log_success "Sample functions ready in functions/examples/"
}

# Test Fission CLI access
test_fission_cli() {
    log_info "Testing Fission CLI access..."
    
    # Wait a bit for the container to fully initialize
    sleep 10
    
    # Test Fission CLI
    if kubectl exec -n "$NAMESPACE" deployment/coder-server -- fission --version >/dev/null 2>&1; then
        log_success "Fission CLI is accessible from Coder"
    else
        log_warning "Fission CLI may still be initializing. You can test it manually later."
    fi
    
    # List current environments
    log_info "Current Fission environments:"
    kubectl exec -n "$NAMESPACE" deployment/coder-server -- fission env list 2>/dev/null || log_warning "Could not list environments yet"
}

# Setup port forwarding for access
setup_access() {
    log_info "Setting up access to Coder Code-Server..."
    
    # Kill any existing port forwards
    pkill -f "port-forward.*coder-server" 2>/dev/null || true
    pkill -f "port-forward.*$CODER_PORT" 2>/dev/null || true
    
    # Start port forwarding
    kubectl port-forward -n "$NAMESPACE" service/coder-server "$CODER_PORT:8080" &
    PORT_FORWARD_PID=$!
    
    # Save PID for cleanup
    echo $PORT_FORWARD_PID > /tmp/coder-portforward.pid
    
    # Wait and test
    sleep 3
    if curl -s -I http://localhost:$CODER_PORT >/dev/null 2>&1; then
        log_success "Port forwarding established!"
    else
        log_warning "Port forwarding may need a moment to initialize"
    fi
}

# Display access information
show_access_info() {
    log_success "Deployment completed successfully!"
    echo
    log_info "Access Information:"
    echo "  🌐 Coder Code-Server: http://localhost:$CODER_PORT"
    echo "  🔑 Password: coder"
    echo "  📋 Port Forward PID: $(cat /tmp/coder-portforward.pid 2>/dev/null || echo 'Not saved')"
    echo
    log_info "Useful Commands:"
    echo "  📦 List functions: kubectl exec -it -n $NAMESPACE deployment/coder-server -- fission function list"
    echo "  🚀 Create environment: kubectl exec -it -n $NAMESPACE deployment/coder-server -- fission env create --name nodejs --image fission/node-env"
    echo "  📊 Get pods: kubectl get pods -n $NAMESPACE"
    echo "  📝 View logs: kubectl logs -n $NAMESPACE deployment/coder-server"
    echo
    log_info "Example Functions:"
    echo "  📁 Located in: functions/examples/"
    echo "  🔧 Edit in Coder: http://localhost:$CODER_PORT"
    echo
    log_info "Port Forwarding Commands:"
    echo "  🚀 Start access: ./scripts/start-portforward.sh"
    echo "  🛑 Stop access: ./scripts/stop-portforward.sh"
    echo
    log_info "Next Steps:"
    echo "  1. Open Coder in your browser: http://localhost:$CODER_PORT"
    echo "  2. Open a terminal in Coder"
    echo "  3. Create your first function:"
    echo "     fission env create --name nodejs --image fission/node-env"
    echo "     fission function create --name hello --env nodejs --code functions/examples/hello-node.js"
    echo "     fission function test --name hello"
    echo
    log_warning "Note: Your existing Fission setup has been preserved!"
    log_warning "Port forwarding is running in background. Use stop script to clean up."
}

# Main execution
main() {
    log_info "Deploying Coder to Existing Fission Cluster"
    echo
    
    check_cluster
    verify_fission
    
    # Check if Coder already exists and handle accordingly
    if check_existing_coder; then
        deploy_coder
    fi
    
    create_samples
    test_fission_cli
    setup_access
    show_access_info
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@" 