# Modular Deployment Architecture

## 🏗️ Overview

This project uses a **modular two-layer deployment architecture** that separates infrastructure provisioning from application deployment:

```
┌─────────────────────────────────────────────────────┐
│               DEPLOYMENT PIPELINE                    │
└─────────────────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                  │
        ▼                                  ▼
┌──────────────────┐            ┌──────────────────┐
│  Layer 1:        │            │  Layer 2:        │
│  Infrastructure  │   ────►    │  Application     │
│  (CloudFormation)│            │  (Kubernetes)    │
└──────────────────┘            └──────────────────┘
   • VPC                            • Pods/Deployments
   • Subnets                         • Services
   • NAT Gateway                     • ConfigMaps
   • EKS Cluster                     • HPA
   • Node Groups                     • LoadBalancer
```

## 🔄 Workflow Comparison

### ❌ Old Approach (Conflicts)
- **Two workflows** trying to create the same EKS cluster
- `cd.yml` → Used eksctl (Kubernetes version 1.34 - invalid!)
- `cd-cloudformation.yml` → Used CloudFormation (Kubernetes version 1.28)
- **Result:** Stack collisions, deployment failures

### ✅ New Modular Approach
- **Single workflow**: `cd-cloudformation.yml`
- **Phase 1:** CloudFormation creates infrastructure (VPC + EKS)
- **Phase 2:** Kubectl deploys application to EKS
- **Old workflow:** Renamed to `cd-eksctl.yml.disabled` (preserved but inactive)

## 📋 Deployment Layers

### Layer 1: Infrastructure (CloudFormation)

**Purpose:** Provision AWS infrastructure resources

**Components:**
- **VPC Stack** (`vpc-stack.yaml`)
  - VPC with CIDR 10.0.0.0/16
  - 2 Public subnets (multi-AZ)
  - 2 Private subnets (multi-AZ)
  - Internet Gateway
  - NAT Gateway
  - Route tables
  - S3 VPC Endpoint

- **EKS Stack** (`eks-stack.yaml`)
  - EKS Cluster (Kubernetes v1.28)
  - Managed node group
  - Auto-scaling: 2-4 nodes (t3.medium)
  - IAM roles (cluster + nodes)
  - Security groups
  - CloudWatch logging

**Deployment Time:** ~20 minutes (EKS cluster creation)

**Termination Protection:** DISABLED for easy cleanup

### Layer 2: Application (Kubernetes)

**Purpose:** Deploy application workloads to EKS

**Components:**
- **Namespace** (`namespace.yaml`)
  - Isolated namespace: `mlops`

- **ConfigMap** (`configmap.yaml`)
  - Application configuration
  - Environment variables

- **Deployment** (`deployment.yaml`)
  - Cat/Dogs classifier pods
  - 2 replicas
  - Rolling update strategy
  - Health checks (liveness/readiness)
  - Resource requests/limits

- **Service** (`service.yaml`)
  - Type: LoadBalancer (NLB)
  - Exposes port 80 → 8000
  - Cross-zone load balancing

- **HPA** (`hpa.yaml`)
  - Horizontal Pod Autoscaler
  - CPU-based scaling
  - 2-10 replicas

**Deployment Time:** ~2 minutes

**Image:** `ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:latest`

## 🚀 Deployment Methods

### Method 1: GitHub Actions (Recommended for Production)

**Workflow:** `.github/workflows/cd-cloudformation.yml`

**Trigger:**
```bash
# Automatic: Push to main branch
git push origin main

# Manual: Go to Actions tab → Run workflow
# Select: deploy-eks
```

**What happens:**

1. ✅ **Validate:** Check AWS credentials
2. 🏗️ **Deploy VPC:** Create network infrastructure (if not exists)
3. ⚙️ **Deploy EKS:** Create Kubernetes cluster (if not exists)
4. ⏳ **Wait:** Cluster becomes ACTIVE (~15-20 min first time)
5. 📦 **Deploy App:** Apply all Kubernetes manifests
6. 🔍 **Verify:** Check pod status and rollout
7. 🌐 **Get URL:** Retrieve LoadBalancer endpoint
8. ✅ **Summary:** Display deployment details

**GitHub Secrets Required:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Method 2: Local Deployment (Recommended for Development)

**Script:** `deployment/cloudformation/deploy-stacks.sh`

```bash
# Deploy infrastructure only
cd deployment/cloudformation
./deploy-stacks.sh deploy

# Check stack status
./manage-stacks.sh list

# Configure kubectl (after EKS is ready)
aws eks update-kubeconfig --name mlops-assignment2-cluster --region us-east-1

# Deploy application manually
kubectl apply -f ../kubernetes/namespace.yaml
kubectl apply -f ../kubernetes/configmap.yaml
kubectl apply -f ../kubernetes/deployment.yaml
kubectl apply -f ../kubernetes/service.yaml
kubectl apply -f ../kubernetes/hpa.yaml

# Check deployment
kubectl get pods -n mlops
kubectl get svc -n mlops
```

## 🔧 Key Features

### 1. Separation of Concerns

**Infrastructure (CloudFormation):**
- Managed by AWS CloudFormation service
- Version controlled in Git
- Changes tracked through stack updates
- Can be deployed independently

**Application (Kubernetes):**
- Managed by Kubernetes control plane
- Deployed to existing infrastructure
- Can be updated without infrastructure changes
- Rolling updates with zero downtime

### 2. Modular Updates

**Update Infrastructure Only:**
```bash
# GitHub Actions
Action: deploy-vpc  # or deploy-eks

# Local
./deploy-stacks.sh deploy
```

**Update Application Only:**
```bash
kubectl set image deployment/cat-dogs-deployment \
  cat-dogs-api=ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:v2.0 \
  -n mlops

kubectl rollout status deployment/cat-dogs-deployment -n mlops
```

**Update Both:**
```bash
# GitHub Actions automatically handles both layers
Action: deploy-eks  # Infrastructure + Application
```

### 3. No Resource Conflicts

- ✅ Only ONE workflow creates EKS cluster
- ✅ CloudFormation manages infrastructure lifecycle
- ✅ Kubernetes manages application lifecycle
- ✅ Clear boundaries between layers

## 📊 Version Matrix

| Component | Version | Location |
|-----------|---------|----------|
| Kubernetes | 1.28 | EKS Cluster |
| Node AMI | Amazon Linux 2 | Managed by AWS |
| Instance Type | t3.medium | Node Group |
| Python | 3.11 | Docker Image |
| FastAPI | Latest | Application |

## 🔍 Verification Steps

### 1. Check Infrastructure

```bash
# List CloudFormation stacks
./manage-stacks.sh list

# Get EKS cluster info
aws eks describe-cluster --name mlops-assignment2-cluster --region us-east-1

# Check nodes
kubectl get nodes
```

### 2. Check Application

```bash
# Check pods
kubectl get pods -n mlops

# Check service
kubectl get svc -n mlops

# Check HPA
kubectl get hpa -n mlops

# View logs
kubectl logs -n mlops deployment/cat-dogs-deployment --tail=50
```

### 3. Test Application

```bash
# Get LoadBalancer URL
SERVICE_URL=$(kubectl get svc cat-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl http://$SERVICE_URL/health

# Test prediction
curl -X POST -F "file=@test-image.jpg" http://$SERVICE_URL/predict
```

## 🗑️ Cleanup

### Option 1: Delete Everything

```bash
# GitHub Actions
Action: delete-stack
Stack Name: mlops-mnist-eks-production  # Delete EKS first
Action: delete-stack
Stack Name: mlops-mnist-vpc-production  # Then VPC

# Or Local
./manage-stacks.sh delete mlops-mnist-eks-production
./manage-stacks.sh delete mlops-mnist-vpc-production
```

### Option 2: Delete Application Only (Keep Infrastructure)

```bash
kubectl delete namespace mlops
```

### Option 3: Complete Cleanup

```bash
./manage-stacks.sh delete-all
```

## 🔐 Security Best Practices

1. **IAM Roles:** Use separate roles for cluster and nodes
2. **Security Groups:** Minimal ingress rules
3. **Private Subnets:** Nodes in private subnets (optional)
4. **Secrets:** Use Kubernetes secrets for sensitive data
5. **RBAC:** Enable Kubernetes RBAC
6. **Encryption:** EBS volumes encrypted by default

## 💰 Cost Optimization

### Monthly Costs (us-east-1)

| Resource | Cost |
|----------|------|
| EKS Control Plane | $72/month |
| 2x t3.medium nodes | ~$60/month |
| NAT Gateway | ~$32/month |
| Network Load Balancer | ~$16/month |
| Data Transfer | Variable |
| **Total** | **~$180/month** |

### Cost Saving Tips

1. **Development:** Delete stacks when not in use
   ```bash
   ./manage-stacks.sh delete-all
   ```

2. **Node Scaling:** Reduce to 1 node for testing
   ```bash
   # Update EKS stack with:
   # NodeGroupDesiredSize: 1
   # NodeGroupMinSize: 1
   ```

3. **Instance Type:** Use t3.small for development
   ```bash
   # Update EKS stack with:
   # NodeInstanceType: t3.small
   ```

## 🐛 Troubleshooting

### EKS Cluster Creation Fails

```bash
# Check stack events
./manage-stacks.sh events mlops-mnist-eks-production

# Common issues:
# - Account limits exceeded
# - IAM permissions missing
# - VPC quota limits
```

### Application Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n mlops

# Common issues:
# - Image pull errors (check GHCR access)
# - Resource limits too low
# - Health check failures
```

### LoadBalancer Not Getting External IP

```bash
# Check service
kubectl describe svc cat-dogs-service -n mlops

# Common issues:
# - Subnets not properly tagged
# - AWS Load Balancer Controller missing
# - Security group issues
```

## 📚 Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## 🔄 Migration from Old Setup

If you were using the old eksctl-based deployment:

1. ✅ **Already Done:** Old workflow disabled (`cd-eksctl.yml.disabled`)
2. ✅ **Already Done:** Kubernetes version fixed (1.28)
3. ✅ **Already Done:** New modular workflow active

**If you have existing cluster:**
```bash
# Option 1: Keep existing cluster, just deploy app
kubectl apply -f deployment/kubernetes/

# Option 2: Delete old cluster, create via CloudFormation
eksctl delete cluster --name mlops-assignment2-cluster
# Then run: deploy-eks action in GitHub
```

---

**Last Updated:** 2026-02-17  
**Architecture Version:** 2.0 (Modular)  
**Status:** ✅ Production Ready
