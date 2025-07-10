#!/bin/bash

# Setup Namespace for Pure Fission CLI Usage
# This script configures a namespace for your client-like workflow: fission -n faas

set -e

NAMESPACE="${1:-faas}"

echo "🚀 Setting up namespace '$NAMESPACE' for pure Fission CLI usage"

# 1. Create namespace
echo "Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 2. Copy all necessary roles from default namespace
echo "Setting up RBAC permissions..."

# Get the roles from default namespace and apply to target namespace
for role in fission-executor fission-buildermgr fission-executor-fission-cr fission-buildermgr-fission-cr; do
    if kubectl get role "$role" -n default >/dev/null 2>&1; then
        echo "  Copying role: $role"
        kubectl get role "$role" -n default -o yaml | \
        sed "s/namespace: default/namespace: $NAMESPACE/" | \
        kubectl apply -f -
    fi
done

# 3. Create role bindings
echo "Creating role bindings..."
kubectl create rolebinding fission-executor \
    --role=fission-executor \
    --serviceaccount=fission:fission-executor \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create rolebinding fission-executor-fission-cr \
    --role=fission-executor-fission-cr \
    --serviceaccount=fission:fission-executor \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create rolebinding fission-buildermgr \
    --role=fission-buildermgr \
    --serviceaccount=fission:fission-buildermgr \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create rolebinding fission-buildermgr-fission-cr \
    --role=fission-buildermgr-fission-cr \
    --serviceaccount=fission:fission-buildermgr \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Namespace '$NAMESPACE' is ready for pure Fission CLI usage!"
echo ""
echo "🎯 Now you can use:"
echo "  fission env create --name nodejs --image ghcr.io/fission/node-env-22:latest -n $NAMESPACE"
echo "  fission function create --name hello --env nodejs --code hello.js -n $NAMESPACE"
echo "  fission function test --name hello -n $NAMESPACE"
echo ""
echo "📝 Note: Your executor/router may need restart to pick up the new namespace:"
echo "  kubectl rollout restart deployment/executor deployment/router -n fission" 