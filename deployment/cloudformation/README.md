# CloudFormation Deployment with Termination Protection DISABLED

This directory contains CloudFormation templates and deployment scripts for the MLOps MNIST Classifier project. **All stacks are configured with termination protection DISABLED** for easy cleanup and management.

## 🚀 Quick Start

### Deploy EKS (Primary Deployment)

**The application runs on EKS:**

```bash
cd deployment/cloudformation
chmod +x deploy-stacks.sh manage-stacks.sh
./deploy-stacks.sh deploy  # Deploys VPC + EKS
```

### Deploy Individual Stacks

```bash
# Deploy VPC only
./deploy-stacks.sh deploy-vpc

# Deploy EKS (requires VPC)
aws eks update-kubeconfig --name mlops-assignment2-cluster
kubectl get nodes
```

## 📁 Files Overview

### CloudFormation Templates

- **`vpc-stack.yaml`** - VPC with public/private subnets, NAT gateway, and endpoints
- **`eks-stack.yaml`** - EKS cluster with node groups and networking

### Scripts

- **`deploy-stacks.sh`** - Main deployment script with termination protection disabled
- **`manage-stacks.sh`** - Stack management utility (list, delete, check status)

## 🔧 Stack Management

### List All Stacks

```bash
./manage-stacks.sh list
```

### Check Termination Protection Status

```bash
./manage-stacks.sh check
```

### Disable Termination Protection (All Stacks)

```bash
./manage-stacks.sh disable
```

### Get Stack Details

```bash
./manage-stacks.sh info mlops-mnist-ec2-production
```

### Delete a Stack

```bash
./manage-stacks.sh delete mlops-mnist-ec2-production
```

### Delete All Stacks

```bash
./manage-stacks.sh delete-all
```

### View Stack Events

```bash
./manage-stacks.sh events mlops-mnist-vpc-production
```

## 🏗️ Architecture

### VPC Stack

Creates a complete network infrastructure:

- VPC with DNS support
- 2 Public subnets (multi-AZ)
- 2 Private subnets (multi-AZ)
- Internet Gateway
- NAT Gateway
- Route tables
- S3 VPC Endpoint

**Outputs:**
- VPC ID
- Subnet IDs
- NAT Gateway IP

### EC2 Stack

Deploys an EC2 instance with:

- Amazon Linux 2023 AMI
- Docker and Docker Compose pre-installed
- MNIST classifier container auto-start
- IAM role with CloudWatch and S3 access
- Security group (ports 80, 8000, 22)
- Elastic IP
- CloudWatch monitoring
- Systemd service for auto-restart

**Outputs:**
- Instance ID
- Public IP
- Service URL
- SSH command

### EKS Stack

Creates an EKS cluster with:

- Kubernetes version 1.28
- Managed node group
- Auto-scaling (2-4 nodes)
- IAM roles for cluster and nodes
- VPC integration
- CloudWatch logging

**Outputs:**
- Cluster name and endpoint
- Node group details
- Kubeconfig command

## 🔐 Termination Protection Status

**All stacks are deployed with termination protection DISABLED by default.**

This means:
- ✅ Stacks can be deleted directly without disabling protection
- ✅ Easier cleanup during development/testing
- ✅ Faster CI/CD pipeline operations
- ⚠️ Be careful not to accidentally delete production stacks

### Verification

After deployment, verify protection status:

```bash
./manage-stacks.sh check
```

Expected output:
```
✓ mlops-mnist-vpc-production: Termination protection DISABLED
✓ mlops-mnist-ec2-production: Termination protection DISABLED
✓ mlops-mnist-eks-production: Termination protection DISABLED
```

## 🔄 GitHub Actions CI/CD

The project includes automated CloudFormation deployment via GitHub Actions.

### Workflow: `.github/workflows/cd-cloudformation.yml`

**Triggers:**
- Push to `main` branch (CloudFormation changes)
- Manual dispatch with options
- Pull requests (validation only)

**Actions Available:**
- `deploy-all` - Deploy all stacks
- `deploy-vpc` - Deploy VPC only
- `deploy-ec2` - Deploy EC2 only
- `deploy-eks` - Deploy EKS only
- `delete-stack` - Delete specific stack
- `disable-protection` - Disable protection for all stacks
- `list-stacks` - List all stacks

### Manual Deployment via GitHub Actions

1. Go to **Actions** tab in GitHub repository
2. Select **CD - CloudFormation Deployment Pipeline**
3. Click **Run workflow**
4. Choose:
   - Action (deploy-all, deploy-vpc, etc.)
   - Environment (production, staging, development)
   - Stack name (for delete action)
5. Click **Run workflow**

### Required GitHub Secrets

Configure these secrets in your repository:

- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `EC2_KEY_NAME` - EC2 key pair name (optional)

## 📝 Parameter Customization

### EC2 Parameters

Edit `ec2-parameters.json`:

```json
{
  "ParameterKey": "InstanceType",
  "ParameterValue": "t3.medium"
},
{
  "ParameterKey": "KeyName",
  "ParameterValue": "your-key-pair-name"
}
```

### Environment Variables

Set before running scripts:

```bash
export AWS_REGION=us-east-1
export ENVIRONMENT=production
export PROJECT_NAME=mlops-mnist
```

## 🛠️ Prerequisites

### AWS CLI

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
```

### EC2 Key Pair

Create an EC2 key pair for SSH access:

```bash
aws ec2 create-key-pair \
  --key-name mlops-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/mlops-key.pem

chmod 400 ~/.ssh/mlops-key.pem
```

### GitHub Container Registry Access

For private images, create a GitHub PAT:

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token with `read:packages` scope
3. Use in EC2 parameters or as GitHub secret

## 📊 Stack Costs

Estimated monthly costs (us-east-1):

| Stack | Resources | Estimated Cost |
|-------|-----------|----------------|
| VPC | NAT Gateway, IPs | $35/month |
| EC2 | t3.medium, EBS 30GB | $30/month |
| EKS | Control plane + 2 t3.medium nodes | $150/month |

**Total: ~$215/month**

> 💡 **Tip:** Delete stacks when not in use to save costs

## 🧪 Testing Deployments

### Test EC2 Deployment

```bash
# Get service URL
INSTANCE_IP=$(aws cloudformation describe-stacks \
  --stack-name mlops-mnist-ec2-production \
  --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' \
  --output text)

# Test health endpoint
curl http://$INSTANCE_IP:8000/health

# Test prediction
curl -X POST -F "file=@test-image.jpg" http://$INSTANCE_IP:8000/predict
```

### Test EKS Deployment

```bash
# Update kubeconfig
aws eks update-kubeconfig --name mlops-assignment2-cluster --region us-east-1

# Check nodes
kubectl get nodes

# Get service URL
kubectl get svc -n mlops
```

## 🔍 Troubleshooting

### Stack Creation Failed

View stack events:
```bash
./manage-stacks.sh events mlops-mnist-ec2-production
```

### Cannot Delete Stack

Disable termination protection:
```bash
./manage-stacks.sh disable
```

### Template Validation Errors

Validate template manually:
```bash
aws cloudformation validate-template \
  --template-body file://vpc-stack.yaml
```

### EC2 Instance Not Accessible

Check security group:
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=mlops-mnist"
```

## 🔗 Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/)
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)

## ⚠️ Important Notes

1. **Termination Protection**: All stacks have termination protection **DISABLED** by default
2. **Costs**: Remember to delete stacks when not in use
3. **Security**: Review security group rules before production deployment
4. **Backups**: Enable automated backups for production data
5. **Monitoring**: CloudWatch logs are enabled by default

## 📞 Support

For issues or questions:
1. Check stack events: `./manage-stacks.sh events <stack-name>`
2. Review CloudWatch logs in AWS Console
3. Check GitHub Actions workflow logs
4. See AWS CloudFormation console for detailed error messages

---

**Last Updated:** 2026-02-17
**Version:** 1.0.0
