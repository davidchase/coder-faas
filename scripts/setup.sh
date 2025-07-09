#!/bin/bash

# Fission + Coder Development Environment Setup Script
# This script sets up a complete serverless development environment

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
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if Fission is already installed
    if helm list -n "$NAMESPACE" | grep -q fission; then
        log_warning "Fission is already installed."
        read -p "Do you want to upgrade it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            helm upgrade fission fission-charts/fission-all -n "$NAMESPACE" -f config/fission-values.yaml
        else
            log_info "Skipping Fission installation."
            return
        fi
    else
        # Install Fission
        helm install fission fission-charts/fission-all -n "$NAMESPACE" -f config/fission-values.yaml
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

# Create sample functions
create_samples() {
    log_info "Creating sample functions..."
    
    # Create functions directory
    mkdir -p functions/examples
    
    # Node.js function
    cat > functions/examples/hello-node.js << 'EOF'
module.exports = async function(context) {
    return {
        status: 200,
        body: {
            message: "Hello from Node.js!",
            timestamp: new Date().toISOString(),
            headers: context.request.headers
        }
    };
}
EOF
    
    # Python function
    cat > functions/examples/hello-python.py << 'EOF'
def main():
    return {
        "message": "Hello from Python!",
        "timestamp": "2024-01-01T00:00:00Z"
    }
EOF
    
    log_success "Sample functions created in functions/examples/"
}

# Display access information
show_access_info() {
    log_success "Setup completed successfully!"
    echo
    log_info "Access Information:"
    echo "  🌐 Coder Code-Server: http://localhost:$CODER_PORT"
    echo "  🔑 Password: coder"
    echo
    log_info "Useful Commands:"
    echo "  📦 List functions: kubectl exec -it -n $NAMESPACE deployment/coder-server -- fission function list"
    echo "  🚀 Create function: kubectl exec -it -n $NAMESPACE deployment/coder-server -- fission function create ..."
    echo "  📊 Get pods: kubectl get pods -n $NAMESPACE"
    echo "  📝 View logs: kubectl logs -n $NAMESPACE deployment/coder-server"
    echo
    log_info "Example Functions:"
    echo "  📁 Located in: functions/examples/"
    echo "  🔧 Edit in Coder: http://localhost:$CODER_PORT"
    echo
    log_info "Next Steps:"
    echo "  1. Open Coder in your browser"
    echo "  2. Navigate to /home/coder/functions"
    echo "  3. Create and deploy your functions!"
}

# Main execution
main() {
    log_info "Starting Fission + Coder Development Environment Setup"
    echo
    
    check_prerequisites
    create_cluster
    install_fission
    deploy_coder
    create_samples
    show_access_info
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@" 