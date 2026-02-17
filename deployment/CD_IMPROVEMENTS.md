# CD Workflow Improvements

## Overview
Fixed the CD (Continuous Deployment) workflow to gracefully handle pod updates and ensure latest Docker images are always pulled with proper authentication.

## Changes Made

### 1. Enhanced GHCR Authentication
- **Before**: Used `GITHUB_TOKEN` which has limited permissions
- **After**: Uses `GHCR_PAT` secret with proper `packages:read` and `packages:write` permissions
- **Fallback**: Automatically falls back to `GITHUB_TOKEN` if `GHCR_PAT` is not configured
- **Configuration**: Added `scripts/add_ghcr_secret.sh` to easily configure the secret

### 2. Graceful Pod Restart
- **Added**: Force rollout restart after applying manifests
- **Benefit**: Ensures old pods gracefully terminate while new ones start
- **Implementation**: `kubectl rollout restart deployment/cat-dogs-deployment`

### 3. Latest Image Pull
- **Before**: Pods sometimes kept running old images even after deployment
- **After**: Every deployment forces pods to pull the latest image from GHCR
- **Verification**: Displays container image SHA in deployment summary

### 4. Improved Deployment Visibility
- Shows pod status before, during, and after restart
- Displays container image IDs to verify correct version
- Better debugging information in GitHub Actions summary

## Workflow Sequence

```
1. Create/Update GHCR pull secret with PAT
2. Apply Kubernetes manifests (namespace, configmap, deployment, service, HPA)
3. Force rollout restart (gracefully terminates old pods)
4. Wait for deployment to complete (10 minute timeout)
5. Verify pods are running with latest image
6. Display service URL and deployment summary
```

## Testing Results

### Deployment Verification
```bash
# Check pods - both new pods running with latest image
$ kubectl get pods -n mlops -l app=cat-dogs-classifier
NAME                                   READY   STATUS    RESTARTS   AGE
cat-dogs-deployment-74b455d798-6sgnx   1/1     Running   0          71s
cat-dogs-deployment-74b455d798-qld88   1/1     Running   0          87s

# Verify image SHA
Image: ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier@sha256:df1baf367d9f...
```

### Health Check
```bash
$ curl http://<loadbalancer>/health
{
  "status": "healthy",
  "model_loaded": true,
  "timestamp": "2026-02-17T18:15:36.242373",
  "version": "1.0.0"
}
```

### Error Handling Verification
```bash
# Test empty image data - returns 400 (not 500!)
$ curl -X POST http://<loadbalancer>/predict-image -d '{"image": ""}'
{"detail": "Image data is empty or missing"}
HTTP Status: 400

# Test invalid base64 - returns 400 (not 500!)
$ curl -X POST http://<loadbalancer>/predict-image -d '{"image": "invalid!!!"}'
{"detail": "Invalid base64 image data. Please ensure the image is properly encoded."}
HTTP Status: 400
```

## Benefits

✅ **No more ImagePullBackOff errors** - Proper GHCR authentication  
✅ **Always deploys latest code** - Force rollout restart pulls newest image  
✅ **Zero-downtime deployments** - Graceful pod termination  
✅ **Better visibility** - Shows which image version is deployed  
✅ **Better error handling** - Returns HTTP 400 for client errors (not 500)  

## Configuration

To set up the GHCR_PAT secret:

```bash
# Option 1: Use the script (interactive)
./scripts/add_ghcr_secret.sh

# Option 2: Use the script with environment variable
GHCR_PAT=ghp_your_token_here ./scripts/add_ghcr_secret.sh

# Option 3: Manual via GitHub CLI
gh secret set GHCR_PAT --repo AIMLIdeas/MLOps-Assignment2

# Option 4: Manual via GitHub UI
# https://github.com/AIMLIdeas/MLOps-Assignment2/settings/secrets/actions
```

## Commits

- **83412203**: CD workflow improvements (graceful restart, GHCR auth)
- **fa0bf43b**: Comprehensive API error handling
- **a6a70cff**: Fixed API for cats-dogs model (128x128 RGB)

## Next Steps

The CD workflow now:
1. Automatically recreates GHCR secret on every deployment
2. Forces pod restart to pull latest image
3. Waits for healthy pods before marking deployment successful
4. Shows deployment status in GitHub Actions summary

No manual intervention needed - just push to `main` branch and the full pipeline runs automatically! 🚀
