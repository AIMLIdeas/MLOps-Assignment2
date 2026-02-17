# Simplified CD Pipeline - Application Deployment Only

## Overview

This CD pipeline deploys **only the application** to an existing EKS cluster. Infrastructure (VPC/EKS) is assumed to already exist.

## Workflow: `cd-deploy-app.yml`

### What it Does

✅ Connects to existing EKS cluster: `mlops-assignment2-cluster`  
✅ Deploys Kubernetes manifests (namespace, configmap, deployment, service, HPA)  
✅ Waits for deployment to be ready  
✅ Retrieves LoadBalancer URL  

❌ Does **NOT** create VPC  
❌ Does **NOT** create EKS cluster  
❌ Does **NOT** use eksctl  

### Triggers

- **Push to main** when these paths change:
  - `src/**`
  - `api/**`
  - `deployment/kubernetes/**`
  - `.github/workflows/cd-deploy-app.yml`

- **Manual dispatch** via GitHub Actions UI

### Prerequisites

1. **Existing EKS cluster** named `mlops-assignment2-cluster` in `us-east-1`
2. **GitHub Secrets** configured:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

### Required Access

Your AWS credentials need:
- `eks:DescribeCluster`
- `eks:ListClusters`
- Full kubectl access to the cluster (via AWS IAM authentication)

## Quick Start

### 1. Add GitHub Secrets

Go to: **Settings → Secrets and variables → Actions**

Add:
- `AWS_ACCESS_KEY_ID`: `AKIAZTZ245PGKGRL6H47`
- `AWS_SECRET_ACCESS_KEY`: `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`

### 2. Trigger Deployment

**Option A: Push to main** (automatic)
```bash
git push origin main
```

**Option B: Manual dispatch**
1. Go to: **Actions → CD - Deploy Application to EKS**
2. Click **Run workflow**
3. Select environment (default: production)
4. Click **Run workflow**

### 3. Monitor Progress

- View workflow execution in GitHub Actions
- Check deployment summary for LoadBalancer URL
- Use provided kubectl commands to verify

## Deployment Flow

```
┌─────────────────────────────────────────────┐
│ 1. Configure AWS Credentials                │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ 2. Install & Configure kubectl              │
│    (connects to existing cluster)           │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ 3. Deploy Kubernetes Manifests              │
│    • namespace.yaml                          │
│    • configmap.yaml                          │
│    • deployment.yaml                         │
│    • service.yaml                            │
│    • hpa.yaml                                │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ 4. Wait for Rollout (5 min timeout)         │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ 5. Get LoadBalancer URL                     │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ ✓ Deployment Complete                       │
└─────────────────────────────────────────────┘
```

## Useful Commands

After deployment, use these commands locally:

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name mlops-assignment2-cluster

# Check pods
kubectl get pods -n mlops

# Check service
kubectl get svc -n mlops

# View logs
kubectl logs -l app=cat-dogs-classifier -n mlops --tail=50

# Get LoadBalancer URL
kubectl get svc cat-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Troubleshooting

### Issue: Workflow fails with "cluster not found"

**Solution:** Ensure the EKS cluster `mlops-assignment2-cluster` exists:
```bash
aws eks describe-cluster --name mlops-assignment2-cluster --region us-east-1
```

### Issue: Unauthorized error

**Solution:** Check IAM user has proper EKS permissions:
```bash
aws eks update-kubeconfig --name mlops-assignment2-cluster --region us-east-1
kubectl auth can-i '*' '*' --all-namespaces
```

### Issue: LoadBalancer pending

**Solution:** Wait a few minutes, LoadBalancer provisioning takes time:
```bash
kubectl get svc cat-dogs-service -n mlops -w
```

## Disabled Workflows

These workflows are preserved but disabled:

- `cd-cloudformation.yml.disabled` - Full infrastructure + app deployment
- `cd-eksctl.yml.disabled` - eksctl-based deployment

To re-enable, remove the `.disabled` extension.

## Architecture

```
                   GitHub Actions Workflow
                           │
                           ▼
                  AWS Credentials Setup
                           │
                           ▼
            ┌──────────────────────────┐
            │   Existing EKS Cluster   │
            │  mlops-assignment2-      │
            │       cluster            │
            └──────────────┬───────────┘
                           │
                           ▼
            ┌──────────────────────────┐
            │  Kubernetes Deployment   │
            │  - Namespace: mlops      │
            │  - Pods: 2-4 replicas    │
            │  - Service: LoadBalancer │
            │  - HPA: enabled          │
            └──────────────┬───────────┘
                           │
                           ▼
                  Network Load Balancer
                   (Public Access)
                           │
                           ▼
                    Application URL
```

## Next Steps

1. ✅ Add GitHub secrets
2. ✅ Push to main or manually trigger workflow
3. ✅ Wait for deployment to complete (~2-3 minutes)
4. ✅ Access application via LoadBalancer URL
5. ✅ Monitor with kubectl commands

---

**Note:** This workflow assumes infrastructure already exists. If you need to create infrastructure, use the disabled CloudFormation workflow or Terraform.
