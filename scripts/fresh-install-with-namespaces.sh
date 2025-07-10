#!/bin/bash

# Fresh Fission Installation with Multi-Namespace Support
# This creates a setup like your client has: fission -n clientname

set -e

echo "🚀 Fresh Fission installation with multi-namespace support"
echo "This will create a setup like your client's environment"

# 1. Create the function namespace first
echo "Creating faas namespace..."
kubectl create namespace faas --dry-run=client -o yaml | kubectl apply -f -

# 2. Install Fission with multi-namespace configuration
echo "Installing/upgrading Fission with namespace support..."
helm upgrade --install fission fission-charts/fission-all \
    --namespace fission \
    --create-namespace \
    --values config/fission-values-with-namespaces.yaml \
    --wait

# 3. Wait for Fission to be ready
echo "Waiting for Fission to be ready..."
kubectl wait --for=condition=ready pod -l app=fission-router -n fission --timeout=300s
kubectl wait --for=condition=ready pod -l svc=executor -n fission --timeout=300s

# 4. Set up RBAC for faas namespace
echo "Setting up RBAC for faas namespace..."
./scripts/setup-namespace.sh faas

echo ""
echo "✅ Fresh installation complete!"
echo ""
echo "🎯 You can now use pure Fission CLI like your client:"
echo "  kubectl exec -n fission deployment/coder-server -- fission env create --name nodejs --image ghcr.io/fission/node-env-22:latest -n faas"
echo "  kubectl exec -n fission deployment/coder-server -- fission function create --name hello --env nodejs --code functions/hello.js -n faas"
echo "  kubectl exec -n fission deployment/coder-server -- fission function test --name hello -n faas"
echo ""
echo "🏷️ Benefits:"
echo "  ✅ Pure Fission CLI (no scripts needed)"
echo "  ✅ Custom namespace isolation (like your client)"
echo "  ✅ No interference with your local macOS k8s"
echo "  ✅ Professional deployment pattern" 