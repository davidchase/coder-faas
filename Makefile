# Fission + Coder Development Environment Makefile

.PHONY: help setup deploy-existing cleanup status test-setup clean logs start-access stop-access

# Default target
help:
	@echo "🚀 Fission + Coder Development Environment"
	@echo "==========================================="
	@echo ""
	@echo "Available commands:"
	@echo "  setup           - Complete environment setup (new installation)"
	@echo "  deploy-existing - Deploy Coder to existing Fission cluster"
	@echo "  start-access    - Start port forwarding to access Coder"
	@echo "  stop-access     - Stop port forwarding"
	@echo "  status          - Check environment status"
	@echo "  logs            - View Coder server logs"
	@echo "  cleanup         - Clean up environment"
	@echo "  test-setup      - Test if setup is working"
	@echo "  clean           - Full cleanup (delete cluster)"
	@echo ""

# Complete setup for new environment
setup:
	@echo "🔧 Setting up complete environment..."
	./scripts/setup.sh

# Deploy to existing Fission cluster  
deploy-existing:
	@echo "📦 Deploying Coder to existing Fission cluster..."
	./scripts/deploy-to-existing.sh

# Check environment status
status:
	@echo "📊 Checking environment status..."
	@echo ""
	@echo "🔍 Cluster Info:"
	kubectl cluster-info 2>/dev/null || echo "❌ No cluster found"
	@echo ""
	@echo "🏗️ Fission Pods:"
	kubectl get pods -n fission 2>/dev/null || echo "❌ Fission namespace not found"
	@echo ""
	@echo "🌐 Services:"
	kubectl get services -n fission 2>/dev/null || echo "❌ No services found"
	@echo ""
	@echo "🔗 Access URLs:"
	@echo "  Coder: http://localhost:31315 (password: coder)"

# View Coder server logs
logs:
	@echo "📝 Coder server logs:"
	kubectl logs -n fission deployment/coder-server --tail=50 -f

# Test if setup is working
test-setup:
	@echo "🧪 Testing setup..."
	@echo ""
	@echo "1. Checking cluster connectivity..."
	kubectl cluster-info >/dev/null 2>&1 && echo "✅ Cluster accessible" || echo "❌ Cluster not accessible"
	@echo ""
	@echo "2. Checking Fission namespace..."
	kubectl get namespace fission >/dev/null 2>&1 && echo "✅ Fission namespace exists" || echo "❌ Fission namespace missing"
	@echo ""
	@echo "3. Checking Coder deployment..."
	kubectl get deployment coder-server -n fission >/dev/null 2>&1 && echo "✅ Coder deployed" || echo "❌ Coder not deployed"
	@echo ""
	@echo "4. Checking Fission CLI in Coder..."
	kubectl exec -n fission deployment/coder-server -- fission --version >/dev/null 2>&1 && echo "✅ Fission CLI working" || echo "❌ Fission CLI not accessible"
	@echo ""
	@echo "5. Testing port accessibility..."
	curl -s http://localhost:31315 >/dev/null 2>&1 && echo "✅ Coder accessible on port 31315" || echo "❌ Coder not accessible"

# Cleanup with options
cleanup:
	@echo "🧹 Running cleanup..."
	./scripts/cleanup.sh

# Full cleanup (delete everything)
clean:
	@echo "💥 Full cleanup - this will delete everything!"
	@echo "Are you sure? Press Ctrl+C to cancel, or Enter to continue..."
	@read
	kind delete cluster --name fission-dev 2>/dev/null || echo "Cluster already deleted"
	@echo "✅ Complete cleanup done"

# Quick commands for development
dev-create-nodejs:
	@echo "🔧 Creating Node.js environment..."
	kubectl exec -n fission deployment/coder-server -- fission env create --name nodejs --image fission/node-env || echo "Environment may already exist"

dev-create-python:
	@echo "🐍 Creating Python environment..."
	kubectl exec -n fission deployment/coder-server -- fission env create --name python --image fission/python-env || echo "Environment may already exist"

dev-list-functions:
	@echo "📋 Listing functions..."
	kubectl exec -n fission deployment/coder-server -- fission function list

dev-list-envs:
	@echo "🏗️ Listing environments..."
	kubectl exec -n fission deployment/coder-server -- fission env list

# Port forwarding management
start-access:
	@echo "🚀 Starting Coder access..."
	./scripts/start-portforward.sh

stop-access:
	@echo "🛑 Stopping Coder access..."
	./scripts/stop-portforward.sh 