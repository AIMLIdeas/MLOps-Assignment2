# EKS Cluster Creation Scripts

This directory contains scripts to create and manage EKS clusters using AWS CLI and eksctl.

## Available Scripts

### 1. `create-eks-cluster.sh` (Recommended - Uses eksctl)

**Simple and fast** - Uses eksctl to create the cluster with minimal commands.

```bash
./scripts/create-eks-cluster.sh [cluster-name] [region] [node-type] [min-nodes] [max-nodes] [desired-nodes]
```

**Example:**
```bash
# Use defaults
./scripts/create-eks-cluster.sh

# Custom configuration
./scripts/create-eks-cluster.sh mlops-assignment2-cluster us-east-1 t3.medium 2 4 2
```

**What it does:**
- ✅ Creates VPC with public/private subnets
- ✅ Creates EKS cluster (Kubernetes 1.28)
- ✅ Creates managed node group (2-4 t3.medium instances)
- ✅ Configures kubectl automatically
- ✅ Enables OIDC provider for IAM roles
- ✅ Sets up IAM roles and policies
- ⏱️ Takes ~15-20 minutes

---

### 2. `create-eks-awscli.sh` (Advanced - Pure AWS CLI)

**Full control** - Creates everything step-by-step using only AWS CLI (no eksctl).

```bash
./scripts/create-eks-awscli.sh [cluster-name] [region]
```

**Example:**
```bash
./scripts/create-eks-awscli.sh mlops-assignment2-cluster us-east-1
```

**What it does:**
- ✅ Creates VPC (10.0.0.0/16)
- ✅ Creates Internet Gateway
- ✅ Creates 4 subnets (2 public, 2 private) across 2 AZs
- ✅ Creates NAT Gateway with Elastic IP
- ✅ Creates route tables and associations
- ✅ Creates EKS cluster IAM role
- ✅ Creates EKS cluster
- ✅ Configures kubectl
- ✅ Creates node group IAM role
- ✅ Creates managed node group
- ✅ Saves resource IDs to `/tmp/eks-resources-[cluster-name].txt`
- ⏱️ Takes ~25-30 minutes

**Advantages:**
- Complete visibility into all resources
- No dependency on eksctl
- Resource IDs saved for cleanup

---

### 3. `delete-eks-cluster.sh`

**Cleanup script** - Deletes the cluster and all associated resources.

```bash
./scripts/delete-eks-cluster.sh [cluster-name] [region] [method]
```

**Methods:**
- `eksctl` - For clusters created with eksctl (default)
- `awscli` - For clusters created with AWS CLI

**Example:**
```bash
# Delete eksctl cluster
./scripts/delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 eksctl

# Delete AWS CLI cluster
./scripts/delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 awscli
```

**What it does:**
- ⚠️ Prompts for confirmation
- 🗑️ Deletes node groups
- 🗑️ Deletes EKS cluster
- 🗑️ Deletes VPC, subnets, NAT Gateway, Internet Gateway
- 🗑️ Releases Elastic IPs
- 🗑️ Deletes IAM roles
- ⏱️ Takes ~10-15 minutes

---

## Prerequisites

### Required Tools

Install these before running the scripts:

#### 1. AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
```

#### 2. kubectl
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### 3. eksctl (for create-eks-cluster.sh and delete with eksctl method)
```bash
# macOS
brew install eksctl

# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

#### 4. jq (for create-eks-awscli.sh)
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq  # Debian/Ubuntu
sudo yum install jq      # RHEL/CentOS
```

### AWS Credentials

Ensure your AWS credentials are configured:

```bash
# Option 1: Use AWS CLI configure
aws configure

# Option 2: Set environment variables
export AWS_ACCESS_KEY_ID="AKIAZTZ245PGKGRL6H47"
export AWS_SECRET_ACCESS_KEY="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"
export AWS_REGION="us-east-1"

# Option 3: Use AWS credentials file
# ~/.aws/credentials
[default]
aws_access_key_id = AKIAZTZ245PGKGRL6H47
aws_secret_access_key = jyd96XoDCZkjFzsWa/DXzzflxzoFP32i68lYHohM
```

### Required IAM Permissions

Your AWS user needs these permissions:
- EKS: Full access (create/delete clusters, node groups)
- EC2: Full access (VPC, subnets, security groups, etc.)
- IAM: Create/delete roles and attach policies
- CloudWatch: Create log groups (for EKS logging)

---

## Quick Start

### Step 1: Create EKS Cluster

**Option A - Using eksctl (Recommended):**
```bash
./scripts/create-eks-cluster.sh
```

**Option B - Using AWS CLI:**
```bash
./scripts/create-eks-awscli.sh
```

### Step 2: Verify Cluster

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check EKS cluster
aws eks describe-cluster --name mlops-assignment2-cluster --region us-east-1
```

### Step 3: Deploy Application

```bash
# Apply all Kubernetes manifests
kubectl apply -f deployment/kubernetes/

# Check deployment
kubectl get all -n mlops

# Get LoadBalancer URL
kubectl get svc cat-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 4: Clean Up (When Done)

```bash
# Using eksctl
./scripts/delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 eksctl

# Using AWS CLI
./scripts/delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 awscli
```

---

## Comparison: eksctl vs AWS CLI

| Feature | eksctl | AWS CLI |
|---------|--------|---------|
| **Ease of Use** | ⭐⭐⭐⭐⭐ Simple | ⭐⭐⭐ Complex |
| **Speed** | ⏱️ 15-20 min | ⏱️ 25-30 min |
| **Control** | 🎛️ High-level | 🎛️ Granular |
| **Visibility** | 📦 Abstracted | 🔍 Full visibility |
| **Dependencies** | Requires eksctl | AWS CLI only |
| **Best For** | Quick setup | Learning/Custom config |
| **Cleanup** | Automated | Manual + Script |

---

## Configuration Details

### Default Cluster Configuration

Both scripts create a cluster with these defaults:

| Setting | Value |
|---------|-------|
| **Cluster Name** | mlops-assignment2-cluster |
| **Region** | us-east-1 |
| **Kubernetes Version** | 1.28 |
| **Node Type** | t3.medium (2 vCPU, 4GB RAM) |
| **Min Nodes** | 2 |
| **Max Nodes** | 4 |
| **Desired Nodes** | 2 |
| **VPC CIDR** | 10.0.0.0/16 |
| **Availability Zones** | 2 (us-east-1a, us-east-1b) |

### Network Configuration

| Resource | CIDR/Details |
|----------|--------------|
| **VPC** | 10.0.0.0/16 |
| **Public Subnet 1** | 10.0.1.0/24 (us-east-1a) |
| **Public Subnet 2** | 10.0.2.0/24 (us-east-1b) |
| **Private Subnet 1** | 10.0.3.0/24 (us-east-1a) |
| **Private Subnet 2** | 10.0.4.0/24 (us-east-1b) |
| **NAT Gateway** | 1 (in us-east-1a) |
| **Internet Gateway** | 1 |

---

## Troubleshooting

### Issue: "eksctl: command not found"

**Solution:** Install eksctl or use the AWS CLI script
```bash
brew install eksctl
# OR
./scripts/create-eks-awscli.sh
```

### Issue: "Cluster already exists"

**Solution:** Delete existing cluster first
```bash
./scripts/delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 eksctl
```

Or choose a different cluster name:
```bash
./scripts/create-eks-cluster.sh my-new-cluster us-east-1
```

### Issue: "Insufficient IAM permissions"

**Solution:** Ensure your AWS user has required permissions:
```bash
# Check current user
aws sts get-caller-identity

# Test EKS permissions
aws eks list-clusters --region us-east-1
```

### Issue: "VPC limit exceeded"

**Solution:** Delete unused VPCs or request limit increase
```bash
# List VPCs
aws ec2 describe-vpcs --region us-east-1

# Delete unused VPC (replace vpc-xxx)
aws ec2 delete-vpc --vpc-id vpc-xxx --region us-east-1
```

### Issue: "kubectl: Unable to connect to the server"

**Solution:** Reconfigure kubectl
```bash
aws eks update-kubeconfig --name mlops-assignment2-cluster --region us-east-1
```

### Issue: Deletion fails with "DependencyViolation"

**Solution:** Manually clean up LoadBalancers and security groups
```bash
# List LoadBalancers
aws elbv2 describe-load-balancers --region us-east-1

# Delete LoadBalancer (replace arn)
aws elbv2 delete-load-balancer --load-balancer-arn <arn> --region us-east-1

# Wait a few minutes, then retry deletion
./scripts/delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 awscli
```

---

## Cost Estimate

Running the EKS cluster will incur these approximate costs:

| Resource | Monthly Cost |
|----------|--------------|
| EKS Control Plane | $73 |
| EC2 t3.medium x2 | $60 ($30 each) |
| NAT Gateway | $32 |
| EBS Volumes | $8 |
| Data Transfer | ~$10 |
| **Total** | **~$183/month** |

💡 **Cost Saving Tips:**
- Use Spot Instances for node groups (save 60-70%)
- Delete cluster when not in use
- Use smaller instance types (t3.small) for dev/test

---

## Next Steps

After creating the cluster:

1. ✅ **Deploy Application**
   ```bash
   kubectl apply -f deployment/kubernetes/
   ```

2. ✅ **Set up monitoring**
   ```bash
   kubectl apply -f deployment/prometheus.yml
   ```

3. ✅ **Configure autoscaling**
   - HPA already configured in deployment/kubernetes/hpa.yaml
   - Cluster Autoscaler for node scaling

4. ✅ **Set up CI/CD**
   - Use GitHub Actions workflow in `.github/workflows/cd-deploy-app.yml`

5. ✅ **Add custom domain** (optional)
   - Configure Route53
   - Set up SSL with ACM

---

## Additional Commands

### Cluster Management

```bash
# Get cluster details
eksctl get cluster --name mlops-assignment2-cluster --region us-east-1

# Scale node group
eksctl scale nodegroup --cluster mlops-assignment2-cluster --name standard-workers --nodes 3 --region us-east-1

# Update cluster version
eksctl update cluster --name mlops-assignment2-cluster --region us-east-1 --approve
```

### kubectl Commands

```bash
# List all resources
kubectl get all -n mlops

# View pod logs
kubectl logs -l app=cat-dogs-classifier -n mlops --tail=50

# Describe deployment
kubectl describe deployment cat-dogs-deployment -n mlops

# Port forward for local testing
kubectl port-forward svc/cat-dogs-service 8000:80 -n mlops
```

### AWS CLI Commands

```bash
# List EKS clusters
aws eks list-clusters --region us-east-1

# Describe cluster
aws eks describe-cluster --name mlops-assignment2-cluster --region us-east-1

# List node groups
aws eks list-nodegroups --cluster-name mlops-assignment2-cluster --region us-east-1

# Get kubeconfig
aws eks update-kubeconfig --name mlops-assignment2-cluster --region us-east-1
```

---

## Resources Created

### eksctl Method:
- EKS Cluster
- VPC with CloudFormation stack
- 2 public subnets, 2 private subnets
- Internet Gateway, NAT Gateway
- Route tables
- Security groups
- IAM roles (cluster + node group)
- Managed node group

### AWS CLI Method:
- EKS Cluster
- VPC
- Internet Gateway
- NAT Gateway + Elastic IP
- 4 subnets (2 public, 2 private)
- 2 route tables
- IAM roles (cluster + node group)
- Managed node group
- CloudWatch log group

All resource IDs are saved to `/tmp/eks-resources-[cluster-name].txt` for AWS CLI method.

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs: `aws logs tail /aws/eks/mlops-assignment2-cluster/cluster --follow`
3. Check EKS cluster events: `kubectl get events -n mlops`
4. Review script output and error messages

---

**Created:** February 2026  
**Version:** 1.0
