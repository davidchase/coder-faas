#!/bin/bash

# WSL2-Optimized Fission + Coder Development Environment Setup Script
# This script addresses WSL2/VDI specific issues like timeout and resource constraints

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - WSL2 optimized
CLUSTER_NAME="kind-coder-faaas"
NAMESPACE="fission"
FAAS_NAMESPACE="faas"
CODER_PORT="31315"

# WSL2 specific timeouts (longer for resource-constrained environments)
HELM_TIMEOUT="600s"
KUBECTL_TIMEOUT="600s"
ROLLOUT_TIMEOUT="300s"

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for WSL2..."
    
    local missing_tools=()
    
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists helm; then
        missing_tools+=("helm")
    fi
    
    if ! command_exists kind; then
        missing_tools+=("kind")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "WSL2 Installation commands:"
        log_info "  Docker: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
        log_info "  kubectl: curl -LO 'https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl'"
        log_info "  Helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        log_info "  Kind: curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. In WSL2, try: sudo service docker start"
        exit 1
    fi
    
    # WSL2 specific checks
    if grep -q WSL /proc/version; then
        log_info "✅ WSL2 environment detected"
        log_warning "💡 If you encounter issues, ensure adequate WSL2 memory allocation in .wslconfig"
    fi
    
    log_success "All prerequisites are met for WSL2!"
}

# Create Kind cluster with WSL2 optimizations
create_cluster() {
    log_info "Creating Kind cluster '$CLUSTER_NAME' with WSL2 optimizations..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log_warning "Cluster '$CLUSTER_NAME' already exists."
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "$CLUSTER_NAME"
            sleep 5  # Give time for cleanup
        else
            log_info "Using existing cluster."
            return
        fi
    fi
    
    # Create cluster with configuration and extra wait time
    log_info "Creating cluster (this may take longer in WSL2)..."
    kind create cluster --name "$CLUSTER_NAME" --config config/kind-cluster.yaml --wait 300s
    
    # Additional wait for WSL2
    log_info "Waiting for cluster nodes to be fully ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout="$KUBECTL_TIMEOUT"
    
    # Verify cluster is healthy
    kubectl cluster-info --context "kind-$CLUSTER_NAME"
    
    log_success "Kind cluster '$CLUSTER_NAME' created successfully!"
}

# Install Fission with WSL2 optimizations
install_fission() {
    log_info "Installing Fission with WSL2 optimizations..."
    
    # Add Fission Helm repository
    log_info "Adding Fission Helm repository..."
    helm repo add fission-charts https://fission.github.io/fission-charts/
    helm repo update
    
    # Create namespaces
    log_info "Creating namespaces..."
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$FAAS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if Fission is already installed
    if helm list -n "$NAMESPACE" | grep -q fission; then
        log_warning "Fission is already installed."
        read -p "Do you want to upgrade it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Upgrading Fission with extended timeout..."
            helm upgrade fission fission-charts/fission-all -n "$NAMESPACE" --timeout="$HELM_TIMEOUT" --wait
        else
            log_info "Skipping Fission installation."
        fi
    else
        # Install Fission with WSL2-friendly settings
        log_info "Installing Fission (this may take several minutes in WSL2)..."
        helm install fission fission-charts/fission-all \
            -n "$NAMESPACE" \
            --timeout="$HELM_TIMEOUT" \
            --wait \
            --set prometheus.enabled=false \
            --set canaryDeployment.enabled=false \
            --set pruner.enabled=false
    fi
    
    # Wait for Fission components to be ready with extended timeouts
    log_info "Waiting for Fission components to be ready (extended timeout for WSL2)..."
    
    # Check each component individually with better error handling
    components=("router" "executor" "webhook" "buildermgr" "storagesvc")
    for component in "${components[@]}"; do
        log_info "Waiting for $component to be ready..."
        if ! kubectl wait --for=condition=available --timeout="$KUBECTL_TIMEOUT" "deployment/$component" -n "$NAMESPACE"; then
            log_error "Component $component failed to become ready. Checking status..."
            kubectl get pods -n "$NAMESPACE" | grep "$component"
            kubectl describe deployment "$component" -n "$NAMESPACE"
            # Continue with other components instead of failing entirely
        else
            log_success "$component is ready!"
        fi
    done
    
    log_success "Fission installation completed!"
}

# Configure faas namespace with extended timeouts
configure_faas_namespace() {
    log_info "Configuring faas namespace for multi-namespace support..."
    
    # Apply RBAC configuration for faas namespace
    log_info "Applying RBAC configuration..."
    kubectl apply -f manifests/faas-namespace-rbac.yaml
    
    # Patch router, executor, and buildermgr to watch faas namespace
    log_info "Configuring components to watch faas namespace..."
    kubectl patch deployment router -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"router","env":[{"name":"FISSION_RESOURCE_NAMESPACES","value":"default,faas"}]}]}}}}'
    kubectl patch deployment executor -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"executor","env":[{"name":"FISSION_RESOURCE_NAMESPACES","value":"default,faas"}]}]}}}}'
    kubectl patch deployment buildermgr -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"buildermgr","env":[{"name":"FISSION_RESOURCE_NAMESPACES","value":"default,faas"}]}]}}}}'
    
    # Wait for deployments to restart with extended timeouts
    log_info "Waiting for component restarts (extended timeout for WSL2)..."
    kubectl rollout status deployment/router -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" || log_warning "Router rollout may still be in progress"
    kubectl rollout status deployment/executor -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" || log_warning "Executor rollout may still be in progress"  
    kubectl rollout status deployment/buildermgr -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" || log_warning "Buildermgr rollout may still be in progress"
    
    log_success "faas namespace configured successfully!"
}

# Deploy Coder server
deploy_coder() {
    log_info "Deploying Coder code-server..."
    
    # Apply Coder manifests
    kubectl apply -f manifests/coder-server.yaml
    
    # Wait for Coder to be ready with extended timeout
    log_info "Waiting for Coder code-server to be ready (extended timeout for WSL2)..."
    kubectl wait --for=condition=available --timeout="$KUBECTL_TIMEOUT" deployment/coder-server -n "$NAMESPACE" || {
        log_warning "Coder may still be starting. Checking status..."
        kubectl get pods -n "$NAMESPACE" | grep coder
    }
    
    log_success "Coder code-server deployed successfully!"
}

# Create sample functions in faas namespace
create_sample_functions() {
    log_info "Setting up sample functions in faas namespace..."
    
    # Wait a bit longer for everything to be ready in WSL2
    log_info "Waiting for system stabilization..."
    sleep 15
    
    # Create Node.js environment in faas namespace
    if ! kubectl get environment nodejs -n "$FAAS_NAMESPACE" &>/dev/null; then
        log_info "Creating Node.js environment in faas namespace..."
        kubectl apply -f - <<EOF
apiVersion: fission.io/v1
kind: Environment
metadata:
  name: nodejs
  namespace: $FAAS_NAMESPACE
spec:
  image: ghcr.io/fission/node-env
  poolsize: 3
EOF
    fi
    
    # Create sample functions if they exist
    if [ -f "functions/hello-faas.js" ]; then
        log_info "Creating hello-faas function..."
        if ! kubectl get function hello-faas -n "$FAAS_NAMESPACE" &>/dev/null; then
            fission function create --name hello-faas --env nodejs --code functions/hello-faas.js --namespace "$FAAS_NAMESPACE" || true
        fi
    fi
    
    if [ -f "functions/math-faas.js" ]; then
        log_info "Creating math-faas function..."
        if ! kubectl get function math-faas -n "$FAAS_NAMESPACE" &>/dev/null; then
            fission function create --name math-faas --env nodejs --code functions/math-faas.js --namespace "$FAAS_NAMESPACE" || true
        fi
    fi
    
    log_success "Sample functions setup complete!"
}

# Display access information for WSL2
show_access_info() {
    log_success "WSL2 setup completed successfully!"
    echo
    log_info "🎯 WSL2 Access Information:"
    echo "  🌐 Coder Code-Server: http://localhost:$CODER_PORT"
    echo "  🔑 Password: coder123"
    echo "  📝 Note: On WSL2, you may need to access via Windows host IP"
    echo
    log_info "🚀 Function Management (Professional CLI):"
    echo "  📋 List functions: fission function list --namespace $FAAS_NAMESPACE"
    echo "  ➕ Create function: fission function create --name <n> --env nodejs --code <file> --namespace $FAAS_NAMESPACE"
    echo "  🧪 Test function: fission function test --name <n> --namespace $FAAS_NAMESPACE"
    echo "  📦 List environments: fission env list --namespace $FAAS_NAMESPACE"
    echo
    log_info "🔍 WSL2 Monitoring Commands:"
    echo "  📊 Fission pods: kubectl get pods -n $NAMESPACE"
    echo "  🏃 Function pods: kubectl get pods -n $FAAS_NAMESPACE"
    echo "  📝 Router logs: kubectl logs -n $NAMESPACE deployment/router"
    echo "  💾 WSL2 memory: free -h"
    echo
    log_info "🧪 Test Your Setup:"
    echo "  🚀 Run: ./scripts/test-faas-functions.sh"
    echo
    log_success "✅ Your WSL2 faas namespace environment is ready!"
    echo
    log_warning "💡 WSL2 Tips:"
    log_info "   - Use 'kubectl port-forward' for service access"
    log_info "   - Monitor resources with 'kubectl top nodes' and 'free -h'"
    log_info "   - Increase WSL2 memory in .wslconfig if needed"
}

# Cleanup function for failed installations
cleanup_on_failure() {
    log_error "Setup failed. Cleaning up..."
    helm uninstall fission -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete namespace "$NAMESPACE" 2>/dev/null || true
    kubectl delete namespace "$FAAS_NAMESPACE" 2>/dev/null || true
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
}

# Main execution
main() {
    log_info "🚀 Starting WSL2-Optimized Fission + Coder Development Environment Setup"
    log_info "   Designed for resource-constrained environments like WSL2/VDI"
    echo
    
    # Set up cleanup trap
    trap cleanup_on_failure ERR
    
    check_prerequisites
    create_cluster
    install_fission
    configure_faas_namespace
    deploy_coder
    create_sample_functions
    show_access_info
    
    # Remove cleanup trap on success
    trap - ERR
}

# Handle script interruption
trap 'log_error "Setup interrupted"; cleanup_on_failure; exit 1' INT TERM

# Run main function
main "$@" 