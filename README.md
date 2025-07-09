# 🚀 Fission + Coder Development Environment

A portable serverless development environment that combines **Fission** (serverless functions) with **Coder code-server** (web-based VS Code) running on **Kubernetes** via **Kind**. This setup can be deployed on any machine supporting Docker and Kubernetes.

## 🎯 What This Provides

- **🔥 Fission**: Production-ready serverless functions platform
- **💻 Coder Code-Server**: Full VS Code experience in your browser  
- **☸️ Kubernetes**: Container orchestration with Kind (local cluster)
- **📦 Helm**: Package management for Kubernetes applications
- **🌐 Portable**: Works on macOS, Linux, Windows (WSL2)

## 📋 Prerequisites

Before you begin, ensure you have the following tools installed:

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Docker** | Container runtime | [Get Docker](https://docs.docker.com/get-docker/) |
| **kubectl** | Kubernetes CLI | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) |
| **Helm** | Kubernetes package manager | [Install Helm](https://helm.sh/docs/intro/install/) |
| **Kind** | Local Kubernetes clusters | [Install Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |

### Platform-Specific Installation

#### macOS
```bash
# Using Homebrew
brew install docker kubectl helm kind

# Start Docker Desktop
open -a Docker
```

#### Linux (Ubuntu/Debian)
```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install helm

# Kind
go install sigs.k8s.io/kind@v0.20.0
# Or download binary from releases
```

#### Windows (WSL2)
```bash
# Follow Linux instructions within WSL2
# Ensure Docker Desktop is configured for WSL2 integration
```

## 🚀 Quick Start

### Option 1: Fresh Installation (New Environment)

1. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd fission-coder-dev
   ```

2. **Run the setup script:**
   ```bash
   chmod +x scripts/setup.sh
   ./scripts/setup.sh
   ```

3. **Access your environment:**
   - 🌐 **Coder Code-Server**: http://localhost:31315
   - 🔑 **Password**: `coder`

### Option 2: Add to Existing Fission Setup

If you already have Fission running (like the user does), use this script to safely add Coder without breaking your existing setup [[memory:2602800]]:

1. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd fission-coder-dev
   ```

2. **Deploy Coder to your existing cluster:**
   ```bash
   chmod +x scripts/deploy-to-existing.sh
   ./scripts/deploy-to-existing.sh
   ```

## 📁 Repository Structure

```
fission-coder-dev/
├── config/
│   ├── kind-cluster.yaml         # Kind cluster configuration
│   └── fission-values.yaml       # Fission Helm chart values
├── manifests/
│   └── coder-server.yaml         # Coder code-server Kubernetes manifests
├── scripts/
│   ├── setup.sh                  # Complete environment setup
│   ├── deploy-to-existing.sh     # Deploy to existing Fission
│   └── cleanup.sh                # Environment cleanup
├── functions/
│   └── examples/                 # Sample functions
└── README.md                     # This file
```

## 🛠️ Usage Guide

### Accessing the Development Environment

1. **Open Coder in your browser:**
   ```
   http://localhost:31315
   ```
   Password: `coder`

2. **Open a terminal in Coder** and start developing!

### Creating Your First Function

#### Node.js Function
```bash
# In Coder terminal
cd /home/coder/workspace

# Create environment
fission env create --name nodejs --image fission/node-env

# Create function file
cat > hello.js << 'EOF'
module.exports = async function(context) {
    return {
        status: 200,
        body: {
            message: "Hello from Fission!",
            timestamp: new Date().toISOString()
        }
    };
}
EOF

# Deploy function
fission function create --name hello --env nodejs --code hello.js

# Test function
fission function test --name hello
```

#### Python Function
```bash
# Create environment
fission env create --name python --image fission/python-env

# Create function file
cat > hello.py << 'EOF'
def main():
    return {
        "message": "Hello from Python!",
        "timestamp": "2024-01-01T00:00:00Z"
    }
EOF

# Deploy function
fission function create --name hello-py --env python --code hello.py --entrypoint main

# Test function
fission function test --name hello-py
```

### Essential Commands

#### Fission Commands (run in Coder terminal)
```bash
# List environments
fission env list

# List functions  
fission function list

# Create HTTP trigger
fission httptrigger create --url /hello --function hello --name hello-trigger

# Test function via HTTP
curl http://router.fission.svc.cluster.local/hello

# View function logs
fission function logs --name hello

# Update function
fission function update --name hello --code hello.js

# Delete function
fission function delete --name hello
```

#### Kubernetes Commands
```bash
# Get all pods in fission namespace
kubectl get pods -n fission

# View Coder logs
kubectl logs -n fission deployment/coder-server

# Get services
kubectl get services -n fission

# Describe function (custom resource)
kubectl describe function hello -n default
```

## 🔧 Configuration

### Customizing Fission

Edit `config/fission-values.yaml` to customize:
- Resource limits
- Environment images
- Storage configuration
- Analytics settings

### Customizing Coder

Edit `manifests/coder-server.yaml` to customize:
- Password
- Resource allocation
- Additional tools installation
- Volume mounts

### Kind Cluster Configuration

Edit `config/kind-cluster.yaml` to customize:
- Node configuration
- Port mappings
- Extra mounts
- Network settings

## 🌍 Platform-Specific Notes

### macOS
- Ensure Docker Desktop is running and allocated sufficient resources
- Default resource allocation: 4GB RAM, 2 CPUs minimum recommended
- **Important**: Kind doesn't expose NodePorts directly on macOS. Use port forwarding scripts:
  ```bash
  # Start Coder access
  ./scripts/start-portforward.sh
  
  # Stop when done
  ./scripts/stop-portforward.sh
  ```

### Linux
- Ensure your user is in the `docker` group: `sudo usermod -aG docker $USER`
- Log out and back in after adding to docker group

### Windows (WSL2)
- Run all commands within WSL2
- Ensure Docker Desktop WSL2 integration is enabled
- Access URLs from Windows browser (localhost works across WSL2 boundary)

## 🧹 Cleanup

### Remove Everything
```bash
./scripts/cleanup.sh
```
Choose option 1 for complete cleanup (removes Kind cluster).

### Remove Only Applications (Keep Cluster)
```bash
./scripts/cleanup.sh
```
Choose option 2 for partial cleanup.

### Manual Cleanup
```bash
# Delete Kind cluster
kind delete cluster --name fission-dev

# Remove Helm releases
helm uninstall fission -n fission

# Delete namespace
kubectl delete namespace fission
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Cluster Creation Fails
```bash
# Check Docker is running
docker info

# Verify Kind installation
kind version

# Check available ports
lsof -i :31314
```

#### 2. Fission Installation Fails
```bash
# Check cluster status
kubectl cluster-info

# Verify Helm repositories
helm repo list

# Check namespace
kubectl get namespaces
```

#### 3. Coder Not Accessible
```bash
# Check pod status
kubectl get pods -n fission -l app=coder-server

# Check service
kubectl get service coder-server -n fission

# Check logs
kubectl logs -n fission deployment/coder-server

# macOS: Use port forwarding instead of NodePort
./scripts/start-portforward.sh
```

#### 4. Function Deployment Issues
```bash
# Check environments
fission env list

# Check function status
fission function list

# View detailed function info
kubectl describe function <function-name> -n default

# Check builder logs
kubectl logs -n fission-builder <builder-pod-name>
```

### Resource Requirements

| Component | CPU | Memory | Storage |
|-----------|-----|---------|---------|
| **Kind Cluster** | 1 CPU | 2GB | 10GB |
| **Fission Core** | 500m | 1GB | 2GB |
| **Coder Server** | 500m | 512MB | 1GB |
| **Total Recommended** | 2 CPU | 4GB | 20GB |

### Performance Tips

1. **Increase Docker resources** if pods keep restarting
2. **Use SSD storage** for better performance
3. **Close unnecessary applications** during development
4. **Monitor resource usage**: `kubectl top nodes` and `kubectl top pods -n fission`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple platforms
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License. See LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the troubleshooting section above
- Review Fission documentation: https://fission.io/docs/
- Review Coder documentation: https://coder.com/docs/code-server
- Create an issue in this repository

---

**Happy serverless development!** 🎉 