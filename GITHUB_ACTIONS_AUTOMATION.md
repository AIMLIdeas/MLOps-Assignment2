# GitHub Actions Automation - Complete Overview

## ✅ Confirmation: ALL AWS Infrastructure & Docker Operations Are Automated via GitHub Actions

This document confirms that **all** Docker image builds, AWS deployments, and infrastructure operations (except initial EKS cluster creation) are fully automated through GitHub Actions workflows.

---

## 🎯 What You Do Manually (One-Time Setup)

### 1. Create EKS Cluster (One-Time)
```bash
# Run this ONCE to create the cluster
./scripts/create-eks-cluster-local.sh
```
**Takes:** ~15-20 minutes  
**Creates:**
- EKS Cluster: `mlops-assignment2-cluster`
- VPC with public/private subnets
- Node group (2-4 t3.medium instances)
- Configures kubectl automatically

### 2. Add GitHub Secrets (One-Time)
Go to: **Settings → Secrets and variables → Actions**

Required secrets:
- `AWS_ACCESS_KEY_ID`: `<your-aws-access-key-id>`
- `AWS_SECRET_ACCESS_KEY`: `<your-aws-secret-access-key>`

---

## 🤖 What GitHub Actions Automates (Everything Else)

### Workflow 1: Build and Push Docker Image
**File:** `.github/workflows/build-docker.yml`  
**Status:** ✅ Active

**Triggers Automatically When:**
- You push code changes to `main` branch
- Changes to: `Dockerfile`, `requirements.txt`, `src/**`, `api/**`, `models/**`

**What It Does:**
1. ✅ Builds Docker image for AWS (linux/amd64)
2. ✅ Pushes to GitHub Container Registry (GHCR)
3. ✅ Tags image with:
   - `latest` (for production)
   - `sha-<commit>` (for traceability)
4. ✅ Uses build cache for faster builds

**Output:**
```
ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:latest
ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:sha-<commit>
```

**No AWS credentials needed** - Uses GitHub token automatically

---

### Workflow 2: Test Docker Image
**File:** `.github/workflows/ci.yml`  
**Status:** ✅ Active

**Triggers Automatically When:**
- Build workflow completes successfully

**What It Does:**
1. ✅ Pulls Docker image from GHCR
2. ✅ Runs container smoke tests
3. ✅ Verifies API endpoints work
4. ✅ Validates image health

**No manual intervention required**

---

### Workflow 3: Deploy Application to EKS
**File:** `.github/workflows/cd-deploy-app.yml`  
**Status:** ✅ Active

**Triggers Automatically When:**
- You push changes to: `src/**`, `api/**`, `deployment/kubernetes/**`
- Docker build completes

**What It Does:**
1. ✅ Configures AWS credentials from secrets
2. ✅ Connects to EKS cluster: `mlops-assignment2-cluster`
3. ✅ Configures kubectl (v1.31)
4. ✅ Deploys Kubernetes manifests:
   - Namespace (`mlops`)
   - ConfigMap (environment config)
   - Deployment (2-4 pods with autoscaling)
   - Service (LoadBalancer for public access)
   - HPA (Horizontal Pod Autoscaler)
5. ✅ Waits for pods to be ready
6. ✅ Retrieves LoadBalancer URL
7. ✅ Displays deployment summary

**Uses AWS credentials** - From GitHub secrets

**Output:** Application URL (LoadBalancer endpoint)

---

## 📊 Complete Automation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Developer Action: git push origin main                          │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ WORKFLOW 1: Build & Push Docker Image                          │
│ - Builds Docker image                                           │
│ - Pushes to ghcr.io/aimlideas/mlops-assignment2/...            │
│ - Tags: latest, sha-<commit>                                    │
│ ✅ NO AWS credentials needed (uses GitHub token)                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ WORKFLOW 2: Test Docker Image                                  │
│ - Pulls image from GHCR                                         │
│ - Runs smoke tests                                              │
│ - Validates API health                                          │
│ ✅ Fully automated                                               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ WORKFLOW 3: Deploy to EKS                                       │
│ - Uses AWS credentials from GitHub secrets                     │
│ - Connects to existing EKS cluster                             │
│ - Deploys Kubernetes manifests                                  │
│ - Creates/updates:                                              │
│   • Namespace (mlops)                                           │
│   • Deployment (2-4 pods)                                       │
│   • Service (LoadBalancer)                                      │
│   • HPA (autoscaling)                                           │
│ - Retrieves LoadBalancer URL                                    │
│ ✅ Uses AWS credentials from secrets                             │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Result: Application Running on EKS                             │
│ - Accessible via LoadBalancer URL                               │
│ - Auto-scaled based on CPU/memory                               │
│ - Zero downtime deployments                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security: How AWS Credentials Are Used

### ❌ NOT in Docker Build Workflow
- Docker build workflow **DOES NOT** use AWS credentials
- Pushes to GHCR (GitHub Container Registry) using GitHub token
- No AWS involvement in image building

### ✅ ONLY in Deployment Workflow
- CD deployment workflow **DOES** use AWS credentials
- From GitHub secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- Only for:
  - Connecting to EKS cluster
  - Deploying Kubernetes manifests
  - No infrastructure creation (that's manual)

---

## 📦 What Gets Deployed

### Kubernetes Resources (All Automated)

1. **Namespace**
   - `mlops` namespace for isolation

2. **ConfigMap**
   - Environment variables
   - Application configuration

3. **Deployment**
   - Container: `ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:latest`
   - Replicas: 2-4 (auto-scaled)
   - Resources: CPU/memory requests and limits
   - Health checks: liveness and readiness probes

4. **Service**
   - Type: LoadBalancer (AWS Network Load Balancer)
   - Port: 80 (external) → 8000 (container)
   - Public internet access

5. **HPA (Horizontal Pod Autoscaler)**
   - Auto-scales based on CPU (70% threshold)
   - Min: 2 pods, Max: 4 pods

---

## 🎬 Your Complete Workflow

### Initial Setup (One-Time):
```bash
# 1. Create EKS cluster (one-time, ~15-20 min)
./scripts/create-eks-cluster-local.sh

# 2. Add GitHub secrets (one-time)
# Go to Settings → Secrets and variables → Actions
# Add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
```

### Daily Development (Fully Automated):
```bash
# 1. Make code changes
vim src/model.py

# 2. Commit and push
git add .
git commit -m "Update model logic"
git push origin main

# 3. ✨ Magic happens automatically:
#    - Docker image builds and pushes to GHCR
#    - Tests run on the new image
#    - Application deploys to EKS
#    - LoadBalancer URL updates
```

### Monitor Deployment:
```bash
# Watch GitHub Actions progress
# Go to: https://github.com/AIMLIdeas/MLOps-Assignment2/actions

# Or check locally:
kubectl get pods -n mlops
kubectl get svc -n mlops
kubectl logs -l app=cat-dogs-classifier -n mlops --tail=50
```

---

## 🚀 Deployment Speed

| Phase | Time | Automated? |
|-------|------|------------|
| Docker Build | 2-5 min | ✅ Yes |
| Docker Tests | 1-2 min | ✅ Yes |
| Deploy to EKS | 2-3 min | ✅ Yes |
| **Total (from git push)** | **5-10 min** | ✅ Fully automated |

---

## 📋 Workflow Status

| Workflow | File | Status | Purpose |
|----------|------|--------|---------|
| **Build Docker** | `build-docker.yml` | ✅ Active | Build & push image to GHCR |
| **Test Docker** | `ci.yml` | ✅ Active | Validate image works |
| **Deploy to EKS** | `cd-deploy-app.yml` | ✅ Active | Deploy to Kubernetes |
| CloudFormation | `cd-cloudformation.yml.disabled` | 🔴 Disabled | Full infra (not needed) |
| eksctl | `cd-eksctl.yml.disabled` | 🔴 Disabled | Alternative method |

---

## 🛠️ What AWS Infrastructure Exists

### Created by You (One-Time):
- ✅ EKS Cluster: `mlops-assignment2-cluster`
- ✅ VPC with subnets
- ✅ Node group (EC2 instances)
- ✅ IAM roles for EKS

### Created by GitHub Actions (Automated):
- ✅ Kubernetes Namespace: `mlops`
- ✅ Kubernetes Deployment (pods)
- ✅ Kubernetes Service (LoadBalancer)
- ✅ AWS Network Load Balancer (via Service)
- ✅ HPA (autoscaling)

### NOT Created by GitHub Actions:
- ❌ VPC (you create once)
- ❌ EKS Cluster (you create once)
- ❌ Node Groups (you create once)

---

## 🔍 Verify Everything Is Automated

### Check GitHub Actions:
```bash
# View all workflows
https://github.com/AIMLIdeas/MLOps-Assignment2/actions

# View specific workflow runs
# - Build and Push Docker Image (should run on every push)
# - CI - Test Docker Image (runs after build)
# - CD - Deploy Application to EKS (runs after code changes)
```

### Check Docker Images:
```bash
# View packages on GitHub
https://github.com/AIMLIdeas/MLOps-Assignment2/pkgs/container/mlops-assignment2%2Fcats-dogs-classifier

# Pull latest image
docker pull ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:latest
```

### Check EKS Deployment:
```bash
# Get LoadBalancer URL
kubectl get svc cat-dogs-service -n mlops

# Check pods
kubectl get pods -n mlops

# View logs
kubectl logs -l app=cat-dogs-classifier -n mlops
```

---

## 💡 Key Takeaways

### ✅ What's Automated (No Manual Work):
1. **Docker image build** → Automatic on code push
2. **Push to GHCR** → Automatic after build
3. **Image testing** → Automatic after push
4. **Deploy to EKS** → Automatic after tests pass
5. **LoadBalancer provisioning** → Automatic by Kubernetes
6. **Pod scaling** → Automatic by HPA
7. **Rolling updates** → Automatic on new deployments

### 🔧 What You Do Once:
1. **Create EKS cluster** → Run script once
2. **Add GitHub secrets** → Configure once
3. **Delete cluster** → When project is done

### 📝 What You Do Daily:
1. **Write code** → Normal development
2. **Git push** → Everything else is automatic

---

## 🎯 Summary

**YES ✅ - Everything is automated via GitHub Actions:**

- Docker image build and push → **GitHub Actions** (no AWS)
- Image testing → **GitHub Actions** (no AWS)
- EKS deployment → **GitHub Actions** (uses AWS credentials)
- LoadBalancer creation → **Kubernetes** (automatic)
- Autoscaling → **Kubernetes HPA** (automatic)

**The ONLY manual step is creating the EKS cluster once** (which you're about to do with `./scripts/create-eks-cluster-local.sh`).

After that, every `git push` triggers the full pipeline automatically! 🚀

---

## 📞 Next Steps

1. ✅ **Create EKS cluster** (run the script now)
2. ✅ **Add GitHub secrets** (if not done)
3. ✅ **Push code changes** → Watch automation work
4. ✅ **Access your app** via LoadBalancer URL

**Everything else happens automatically!**
