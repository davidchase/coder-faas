# 🏷️ Namespace Strategy: Isolation with Labels

## ✅ **Current Approach: Default Namespace with Smart Labeling**

This repository uses the **default namespace** with **consistent labeling** for function isolation. Here's why this is the best approach:

### 🎯 **Why Default Namespace?**

1. **✅ Fission Compatibility**: Fission's executor is pre-configured to work seamlessly with the `default` namespace
2. **✅ Zero Configuration**: No additional RBAC setup or executor reconfiguration needed
3. **✅ Proven Stability**: Works reliably across all Kubernetes distributions (Kind, Docker Desktop, etc.)
4. **✅ Consistent Behavior**: Functions scale and execute predictably

### 🏷️ **Isolation Through Labels**

All `coder-faas` resources use consistent labels:
- `project=coder-faas`
- `managed-by=coder`

**Functions are prefixed**: `coder-faas-{your-name}`
**Environment name**: `coder-faas-nodejs` (instead of just `nodejs`)

### 📊 **Benefits**

| Aspect | Default + Labels | Custom Namespace |
|--------|------------------|------------------|
| **Setup Complexity** | ✅ Simple | ❌ Complex RBAC |
| **Fission Compatibility** | ✅ Native | ❌ Requires config |
| **Function Scaling** | ✅ Works reliably | ⚠️ May fail |
| **Isolation** | ✅ Clear labeling | ✅ Physical separation |
| **Cleanup** | ✅ Easy filtering | ✅ Delete namespace |
| **Debugging** | ✅ Standard tools | ⚠️ Namespace-aware tools |

## 🔍 **Resource Identification**

### List Only Your Functions
```bash
# Using scripts
./scripts/manage-functions.sh list

# Manual filtering
kubectl get functions -l project=coder-faas
```

### Environment Management
```bash
# Create environment (done automatically)
fission env create --name coder-faas-nodejs --image ghcr.io/fission/node-env-22:latest --labels="project=coder-faas,managed-by=coder"

# List your environments
kubectl get environments -l project=coder-faas
```

### Complete Cleanup
```bash
# Clean all coder-faas functions
./scripts/manage-functions.sh cleanup

# Manual cleanup by labels
kubectl delete functions -l project=coder-faas
kubectl delete environments -l project=coder-faas
kubectl delete httptriggers -l project=coder-faas
```

## 🚨 **Avoiding Conflicts**

### With Your Local macOS Kubernetes
- ✅ All functions prefixed with `coder-faas-`
- ✅ Environment clearly named `coder-faas-nodejs`
- ✅ Easy to identify and separate from personal projects
- ✅ Scripts filter by labels, not just names

### Naming Conventions
```bash
# ✅ Good: Clear project identification
create-function.sh hello functions/hello.js     # Creates: coder-faas-hello
create-function.sh api functions/api.js         # Creates: coder-faas-api

# ❌ Avoid: Generic names that might conflict
# We automatically prefix everything with 'coder-faas-'
```

## 🔧 **Technical Details**

### Why Custom Namespaces Failed
```
1. Fission executor watches specific namespaces
2. Pool manager creates pods in configured namespace only
3. RBAC permissions need careful setup
4. Function scaling behavior differs across namespaces
```

### Current Implementation
```yaml
# Functions use labels for identification
metadata:
  name: coder-faas-hello
  labels:
    project: coder-faas
    managed-by: coder
  namespace: default

# Environment isolation
metadata:
  name: coder-faas-nodejs
  labels:
    project: coder-faas
    managed-by: coder
  namespace: default
```

## 📝 **Best Practices**

1. **Always use the provided scripts**: They handle labeling and naming automatically
2. **Don't create raw Fission resources**: Use `./scripts/create-function.sh`
3. **Regular cleanup**: Use `./scripts/manage-functions.sh cleanup` periodically
4. **Check before conflicts**: Use `./scripts/manage-functions.sh list` to see your functions

## 🔄 **Migration Notes**

If you have functions in other namespaces, you can migrate them:

```bash
# 1. Export function code
kubectl exec -n fission deployment/coder-server -- fission function get --name old-function -n other-namespace > /tmp/old-function.js

# 2. Create new function with proper naming
./scripts/create-function.sh migrated /tmp/old-function.js

# 3. Test the new function
./scripts/manage-functions.sh test migrated

# 4. Delete old function
kubectl exec -n fission deployment/coder-server -- fission function delete --name old-function -n other-namespace
```

---

**This approach ensures reliable operation while maintaining clear separation from your other Kubernetes resources.** 🎯 