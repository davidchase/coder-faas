#!/bin/bash

# Fission + Coder Development Environment Setup Script
# This script sets up a complete serverless development environment with faas namespace

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="kind-coder-faaas"
NAMESPACE="fission"
FAAS_NAMESPACE="faas"
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
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
        log_info "Please install the missing tools and run the script again."
        log_info "Installation guides:"
        log_info "  Docker: https://docs.docker.com/get-docker/"
        log_info "  kubectl: https://kubernetes.io/docs/tasks/tools/"
        log_info "  Helm: https://helm.sh/docs/intro/install/"
        log_info "  Kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites are met!"
}

# Create Kind cluster
create_cluster() {
    log_info "Creating Kind cluster '$CLUSTER_NAME'..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log_warning "Cluster '$CLUSTER_NAME' already exists."
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kind delete cluster --name "$CLUSTER_NAME"
        else
            log_info "Using existing cluster."
            return
        fi
    fi
    
    # Create cluster with configuration
    kind create cluster --name "$CLUSTER_NAME" --config config/kind-cluster.yaml
    
    # Wait for cluster to be ready
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "Kind cluster '$CLUSTER_NAME' created successfully!"
}

# Install Fission
install_fission() {
    log_info "Installing Fission..."
    
    # Add Fission Helm repository
    helm repo add fission-charts https://fission.github.io/fission-charts/
    helm repo update
    
    # Create namespaces
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$FAAS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if Fission is already installed
    if helm list -n "$NAMESPACE" | grep -q fission; then
        log_warning "Fission is already installed."
        read -p "Do you want to upgrade it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            helm upgrade fission fission-charts/fission-all -n "$NAMESPACE"
        else
            log_info "Skipping Fission installation."
        fi
    else
        # Install Fission with default values
        helm install fission fission-charts/fission-all -n "$NAMESPACE"
    fi
    
    # Wait for Fission components to be ready
    log_info "Waiting for Fission components to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/router -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/executor -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/webhook -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/buildermgr -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/storagesvc -n "$NAMESPACE"
    
    log_success "Fission installed successfully!"
}

# Configure faas namespace
configure_faas_namespace() {
    log_info "Configuring faas namespace for multi-namespace support..."
    
    # Apply RBAC configuration for faas namespace
    kubectl apply -f manifests/faas-namespace-rbac.yaml
    
    # Patch router, executor, and buildermgr to watch faas namespace
    kubectl patch deployment router -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"router","env":[{"name":"FISSION_RESOURCE_NAMESPACES","value":"default,faas"}]}]}}}}'
    kubectl patch deployment executor -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"executor","env":[{"name":"FISSION_RESOURCE_NAMESPACES","value":"default,faas"}]}]}}}}'
    kubectl patch deployment buildermgr -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"buildermgr","env":[{"name":"FISSION_RESOURCE_NAMESPACES","value":"default,faas"}]}]}}}}'
    
    # Wait for deployments to restart
    kubectl rollout status deployment/router -n "$NAMESPACE" --timeout=120s
    kubectl rollout status deployment/executor -n "$NAMESPACE" --timeout=120s
    kubectl rollout status deployment/buildermgr -n "$NAMESPACE" --timeout=120s
    
    log_success "faas namespace configured successfully!"
}

# Deploy Coder server
deploy_coder() {
    log_info "Deploying Coder code-server..."
    
    # Apply Coder manifests
    kubectl apply -f manifests/coder-server.yaml
    
    # Wait for Coder to be ready
    log_info "Waiting for Coder code-server to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/coder-server -n "$NAMESPACE"
    
    log_success "Coder code-server deployed successfully!"
}

# Create sample functions in faas namespace
create_sample_functions() {
    log_info "Setting up sample functions in faas namespace..."
    
    # Wait a bit for everything to be ready
    sleep 10
    
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

# Display access information
show_access_info() {
    log_success "Setup completed successfully!"
    echo
    log_info "🎯 Access Information:"
    echo "  🌐 Coder Code-Server: http://localhost:$CODER_PORT"
    echo "  🔑 Password: coder123"
    echo
    log_info "🚀 Function Management (Professional CLI):"
    echo "  📋 List functions: fission function list --namespace $FAAS_NAMESPACE"
    echo "  ➕ Create function: fission function create --name <name> --env nodejs --code <file> --namespace $FAAS_NAMESPACE"
    echo "  🧪 Test function: fission function test --name <name> --namespace $FAAS_NAMESPACE"
    echo "  📦 List environments: fission env list --namespace $FAAS_NAMESPACE"
    echo
    log_info "🔍 Monitoring Commands:"
    echo "  📊 Fission pods: kubectl get pods -n $NAMESPACE"
    echo "  🏃 Function pods: kubectl get pods -n $FAAS_NAMESPACE"
    echo "  📝 Router logs: kubectl logs -n $NAMESPACE deployment/router"
    echo
    log_info "🧪 Test Your Setup:"
    echo "  🚀 Run: ./scripts/test-faas-functions.sh"
    echo
    log_success "✅ Your portable faas namespace environment is ready!"
    echo
    log_warning "💡 Remember: Always use '--namespace $FAAS_NAMESPACE' with fission commands"
    log_info "   This keeps your functions isolated and portable across environments."
}

# Main execution
main() {
    log_info "🚀 Starting Portable Fission + Coder Development Environment Setup"
    log_info "   Using faas namespace for professional isolation"
    echo
    
    check_prerequisites
    create_cluster
    install_fission
    configure_faas_namespace
    deploy_coder
    create_sample_functions
    show_access_info
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@" 