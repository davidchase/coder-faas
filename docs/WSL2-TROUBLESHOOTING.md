# WSL2/VDI Troubleshooting Guide

This guide helps resolve common issues when running the Fission + Coder setup in WSL2 or VDI environments.

## 🔧 Quick Fixes

### 1. Use WSL2-Optimized Script
Instead of `./scripts/setup.sh`, use:
```bash
./scripts/setup-wsl2.sh
```

### 2. Helm Installation Timeout
**Error:** `Error: INSTALLATION FAILED: failed post-install: 1 error occurred: * timed out waiting for the condition`

**Solutions:**
```bash
# Option 1: Increase WSL2 memory allocation
# Create/edit ~/.wslconfig
[wsl2]
memory=8GB
processors=4

# Restart WSL2
wsl --shutdown

# Option 2: Manual Fission installation with longer timeout
helm install fission fission-charts/fission-all \
  -n fission \
  --timeout=600s \
  --wait \
  --set prometheus.enabled=false \
  --set canaryDeployment.enabled=false
```

### 3. Docker Not Running
**Error:** `Docker is not running`

**Solution:**
```bash
# Start Docker service in WSL2
sudo service docker start

# Or enable Docker to start automatically
sudo systemctl enable docker
```

### 4. kubectl Context Issues
**Error:** `context "kind-kind-coder-faaas" does not exist`

**Solution:**
```bash
# Check available contexts
kubectl config get-contexts

# Set correct context
kubectl config use-context kind-coder-faaas
```

## 🚀 WSL2 Performance Optimization

### Memory Configuration
Create `~/.wslconfig` (Windows side):
```ini
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
```

### Resource Monitoring
```bash
# Check WSL2 memory usage
free -h

# Check Docker resources
docker system df

# Monitor Kubernetes resources
kubectl top nodes
kubectl top pods -A
```

## 🔍 Advanced Troubleshooting

### Check Cluster Health
```bash
# Verify Kind cluster
kind get clusters
kubectl cluster-info

# Check node status
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A
```

### Fission Component Status
```bash
# Check Fission pods
kubectl get pods -n fission

# Check specific component logs
kubectl logs -n fission deployment/router
kubectl logs -n fission deployment/executor
kubectl logs -n fission deployment/buildermgr

# Describe failing pods
kubectl describe pod <pod-name> -n fission
```

### Network Issues
```bash
# Test pod networking
kubectl exec -it <pod-name> -n fission -- ping google.com

# Check services
kubectl get svc -n fission

# Test port forwarding
kubectl port-forward -n fission service/router 8080:80
```

## 🛠️ Manual Recovery Steps

### 1. Clean Installation
```bash
# Clean everything
kind delete cluster --name coder-faaas
docker system prune -f

# Restart WSL2
wsl --shutdown
# (restart from Windows)

# Run WSL2 setup
./scripts/setup-wsl2.sh
```

### 2. Partial Recovery
```bash
# If cluster exists but Fission failed
helm uninstall fission -n fission
kubectl delete namespace fission faas

# Recreate namespaces and retry
kubectl create namespace fission
kubectl create namespace faas
helm install fission fission-charts/fission-all -n fission --timeout=600s
```

### 3. Component-by-Component Check
```bash
# Check each component individually
components=("router" "executor" "webhook" "buildermgr" "storagesvc")
for component in "${components[@]}"; do
  echo "Checking $component..."
  kubectl get deployment $component -n fission
  kubectl logs deployment/$component -n fission --tail=10
done
```

## 📊 System Requirements

### Minimum Requirements
- **WSL2 Memory:** 4GB
- **WSL2 Processors:** 2 cores
- **Disk Space:** 10GB free
- **Docker:** Version 20.10+

### Recommended
- **WSL2 Memory:** 8GB
- **WSL2 Processors:** 4 cores
- **Disk Space:** 20GB free
- **Docker:** Latest version

## 🔗 Useful Commands

### Environment Info
```bash
# Check WSL version
wsl --version

# Check versions
docker version
kubectl version --client
helm version
kind version

# Check system resources
df -h
free -h
lscpu
```

### Access Services
```bash
# Port forward Coder (WSL2 method)
kubectl port-forward -n fission service/coder-server 31315:8080 &

# Access from Windows browser
# http://localhost:31315
```

### Reset Everything
```bash
# Nuclear option - reset everything
kind delete cluster --name coder-faaas
docker system prune -af
wsl --shutdown
# Restart WSL2 and run setup-wsl2.sh
```

## 📞 Getting Help

If you continue to have issues:

1. **Check logs:** `kubectl logs -n fission deployment/router`
2. **Check resources:** `kubectl top nodes` and `free -h`
3. **Try minimal setup:** Comment out Coder deployment and test Fission only
4. **Increase timeouts:** Edit `setup-wsl2.sh` and increase timeout values

### Common Error Patterns

| Error Pattern | Likely Cause | Solution |
|---------------|--------------|----------|
| `timed out waiting` | Resource constraints | Increase WSL2 memory |
| `ImagePullBackOff` | Network/registry issues | Check Docker and network |
| `CrashLoopBackOff` | Component configuration | Check component logs |
| `context does not exist` | kubectl configuration | Reset kubectl context |

Remember: WSL2 environments are resource-constrained compared to native Linux. Be patient with timeouts and consider increasing resource allocation. 