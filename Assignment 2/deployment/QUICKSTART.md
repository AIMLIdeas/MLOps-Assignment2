# Quick Start: Deploy to AWS EKS

## Prerequisites Check
```bash
# Verify tools installed
aws --version        # aws-cli/2.33.18
kubectl version      # v1.35.0
eksctl version       # v0.222.0
```

## Step 1: Configure AWS
```bash
# Configure AWS credentials
aws configure

# Verify credentials
aws sts get-caller-identity
```

## Step 2: Set GitHub Credentials
```bash
export GITHUB_USERNAME="aimlideas"
export GITHUB_PAT="your_github_personal_access_token_here"
export GITHUB_EMAIL="your_email@example.com"
```

To create a GitHub PAT:
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scope: `read:packages`
4. Copy the token

## Step 3: Deploy (Choose One)

### Option A: Automated (One Command)
```bash
./deployment/deploy-to-aws.sh
```

### Option B: Manual (Step by Step)
```bash
# 1. Create EKS cluster (15-20 min)
eksctl create cluster -f deployment/kubernetes/eks-cluster-config.yaml

# 2. Update kubeconfig
aws eks update-kubeconfig --name cats-dogs-classifier-cluster --region us-east-1

# 3. Create namespace
kubectl apply -f deployment/kubernetes/namespace.yaml

# 4. Create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_PAT \
  --docker-email=$GITHUB_EMAIL \
  --namespace=mlops

# 5. Deploy all resources
kubectl apply -f deployment/kubernetes/configmap.yaml
kubectl apply -f deployment/kubernetes/deployment.yaml
kubectl apply -f deployment/kubernetes/service.yaml
kubectl apply -f deployment/kubernetes/hpa.yaml

# 6. Wait for pods
kubectl wait --for=condition=ready pod -l app=cats-dogs-classifier -n mlops --timeout=300s

# 7. Get service endpoint
kubectl get svc cats-dogs-service -n mlops
```

## Step 4: Test Deployment
```bash
# Get endpoint
ENDPOINT=$(kubectl get svc cats-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health
curl http://$ENDPOINT/health

# Test prediction
curl -X POST http://$ENDPOINT/predict \
  -H "Content-Type: application/json" \
  -d '{"image": [0.0, ...(784 values)...]}'
```

## Monitoring Commands
```bash
# View pods
kubectl get pods -n mlops

# View logs
kubectl logs -f -l app=cats-dogs-classifier -n mlops

# View HPA status
kubectl get hpa -n mlops

# View metrics
kubectl top pods -n mlops
```

## Cleanup
```bash
# Delete deployment
kubectl delete -f deployment/kubernetes/ -n mlops

# Delete cluster
eksctl delete cluster --name cats-dogs-classifier-cluster --region us-east-1
```

## Cost Estimate
- **EKS Control Plane**: ~$73/month
- **EC2 Nodes** (2x t3.medium): ~$60/month
- **Network Load Balancer**: ~$16/month
- **Storage** (EBS): ~$3/month
- **Total**: ~$152/month

## Troubleshooting
```bash
# Check pod status
kubectl describe pod <pod-name> -n mlops

# Check events
kubectl get events -n mlops --sort-by='.lastTimestamp'

# Verify secret
kubectl get secret ghcr-secret -n mlops -o yaml

# Check logs
kubectl logs <pod-name> -n mlops
```

## Files Modified
- ✅ [deployment.yaml](kubernetes/deployment.yaml) - Updated image to ghcr.io, added imagePullSecrets
- ✅ [service.yaml](kubernetes/service.yaml) - Added AWS LoadBalancer annotations
- ✅ [configmap.yaml](kubernetes/configmap.yaml) - Added AWS region config
- ✅ [hpa.yaml](kubernetes/hpa.yaml) - Updated namespace to mlops
- ✅ [namespace.yaml](kubernetes/namespace.yaml) - Defines mlops namespace

## New Files Created
- ✅ [secret-ghcr.yaml](kubernetes/secret-ghcr.yaml) - GitHub Container Registry secret template
- ✅ [eks-cluster-config.yaml](kubernetes/eks-cluster-config.yaml) - EKS cluster configuration
- ✅ [deploy-to-aws.sh](deploy-to-aws.sh) - Automated deployment script
- ✅ [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md) - Comprehensive deployment guide

## Next Steps
1. Configure AWS credentials: `aws configure`
2. Set GitHub PAT: `export GITHUB_PAT="..."`
3. Run deployment: `./deployment/deploy-to-aws.sh`
4. Test service: `curl http://$ENDPOINT/health`
