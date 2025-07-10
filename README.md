# Portable Fission + Coder Development Environment

A portable development environment that combines Fission (serverless functions) with coder-server (VS Code in browser) in a single Kubernetes cluster using Kind and Helm.

## 🎯 Features

- **Complete isolation**: Uses `faas` namespace for functions, leaving `default` namespace clean
- **Professional CLI**: Pure `fission -n faas` commands like enterprise setups
- **Portable**: Works on macOS, Linux, Windows, WSL2, and VDI environments
- **Integrated IDE**: VS Code accessible via browser at `http://localhost:31315`
- **No conflicts**: Your existing macOS Kubernetes setup remains untouched

## 🚀 Quick Start

### Prerequisites

- Docker Desktop
- Kind (`brew install kind` on macOS)
- Helm (`brew install helm` on macOS)
- kubectl

### Installation

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd coder-faaas
   chmod +x scripts/*.sh
   ```

2. **Deploy everything:**
   ```bash
   ./scripts/setup.sh
   ```

3. **Access your environment:**
   - **Coder IDE**: http://localhost:31315 (password: `coder123`)
   - **Fission functions**: Use `fission -n faas` commands

## 🛠️ Usage

### Creating Functions

All functions should be created in the `faas` namespace for proper isolation:

```bash
# Create environment
fission env create --name nodejs --image ghcr.io/fission/node-env --namespace faas

# Create function
fission function create --name hello --env nodejs --code hello.js --namespace faas

# Test function
fission function test --name hello --namespace faas

# List functions
fission function list --namespace faas
```

### Example Functions

Create `hello.js`:
```javascript
module.exports = async function(context) {
    return {
        status: 200,
        body: {
            message: "Hello from faas namespace!",
            timestamp: new Date().toISOString(),
            namespace: "faas"
        }
    };
}
```

Deploy and test:
```bash
fission function create --name hello --env nodejs --code hello.js --namespace faas
fission function test --name hello --namespace faas
```

### Namespace Separation

- **`faas` namespace**: Your serverless functions (isolated, portable)
- **`default` namespace**: Remains clean for your macOS Kubernetes
- **`fission` namespace**: Fission control plane (managed automatically)

## 🔧 Architecture

```
kind-coder-faaas cluster
├── fission namespace      # Fission control plane
├── faas namespace         # Your functions (isolated)
└── default namespace      # Clean/unused
```

The setup includes:
- **Router**: Routes function calls to correct namespace
- **Executor**: Manages function pods in faas namespace  
- **Controller**: Manages Fission resources
- **Coder-server**: Browser-based VS Code IDE

## 📝 Available Scripts

- `./scripts/setup.sh` - Complete environment setup
- `./scripts/cleanup.sh` - Clean teardown
- `./scripts/port-forward.sh` - Start port forwarding for coder-server

## 🐛 Troubleshooting

### Port Forwarding Issues
If port forwarding stops working:
```bash
./scripts/port-forward.sh
```

### Function Not Working
Ensure you're using the correct namespace:
```bash
fission function list --namespace faas
fission function test --name <function-name> --namespace faas
```

### Check Function Pods
```bash
kubectl get pods -n faas
kubectl logs -n faas <pod-name>
```

### Fission Component Status
```bash
kubectl get pods -n fission
kubectl logs -n fission deployment/router
```

## 🔄 Management Commands

### Restart Environment
```bash
./scripts/cleanup.sh
./scripts/setup.sh
```

### Update Fission
```bash
helm upgrade fission fission-charts/fission-all --namespace fission
```

### Backup Functions
```bash
fission function list --namespace faas > functions-backup.txt
```

## 📊 Monitoring

Check cluster status:
```bash
kubectl get pods -n fission    # Fission components
kubectl get pods -n faas       # Function pods  
kubectl get functions -n faas  # Function definitions
```

## 🎯 Why This Setup?

1. **Professional**: Uses `fission -n faas` like enterprise environments
2. **Portable**: Works identically across all platforms
3. **Isolated**: No interference with existing Kubernetes setups
4. **Complete**: Includes both serverless platform and development IDE
5. **Persistent**: Git-backed for team collaboration

## 📚 Next Steps

1. Create your first function in the `faas` namespace
2. Access the browser IDE at http://localhost:31315
3. Develop and test functions using the integrated environment
4. Share this portable setup with your team

## 🤝 Contributing

This environment is designed to be portable and reliable. Test any changes across multiple platforms before committing.

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