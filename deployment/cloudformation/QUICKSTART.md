# CloudFormation CD Pipeline - Quick Reference

## 🚀 Quick Commands

### Deploy Everything
```bash
cd deployment/cloudformation
./deploy-stacks.sh deploy
```

### Check Stack Status
```bash
./manage-stacks.sh list
./manage-stacks.sh check
```

### Delete Everything
```bash
./manage-stacks.sh delete-all
```

## 📦 Available Stacks

| Stack Name | Template | Purpose |
|------------|----------|---------|
| `mlops-mnist-vpc-production` | `vpc-stack.yaml` | Network infrastructure |
| `mlops-mnist-ec2-production` | `ec2-stack.yaml` | EC2 instance with Docker |
| `mlops-mnist-eks-production` | `eks-stack.yaml` | Kubernetes cluster |

## ✅ Termination Protection Status

**ALL STACKS**: Termination protection **DISABLED** by default

Verify with:
```bash
./manage-stacks.sh check
```

Expected output:
```
✓ mlops-mnist-vpc-production: Termination protection DISABLED
✓ mlops-mnist-ec2-production: Termination protection DISABLED
✓ mlops-mnist-eks-production: Termination protection DISABLED
```

## 🔧 Management Commands

```bash
# List all stacks
./manage-stacks.sh list

# Check protection status
./manage-stacks.sh check

# Disable protection (if needed)
./manage-stacks.sh disable

# Get stack details
./manage-stacks.sh info <stack-name>

# View events
./manage-stacks.sh events <stack-name>

# Delete single stack
./manage-stacks.sh delete <stack-name>

# Delete all stacks
./manage-stacks.sh delete-all
```

## 🌐 GitHub Actions Workflow

### Manual Deployment

1. Go to **Actions** tab
2. Select **CD - CloudFormation Deployment Pipeline**
3. Click **Run workflow**
4. Choose action and environment

### Available Actions

- `deploy-all` - Deploy all infrastructure
- `deploy-vpc` - VPC only
- `deploy-ec2` - EC2 only  
- `deploy-eks` - EKS only
- `delete-stack` - Delete specific stack
- `disable-protection` - Disable protection for all
- `list-stacks` - List all stacks

## 📋 Prerequisites Checklist

- [ ] AWS CLI installed and configured
- [ ] AWS credentials with CloudFormation permissions
- [ ] EC2 key pair created (for EC2 stack)
- [ ] GitHub secrets configured (for CI/CD)
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `EC2_KEY_NAME` (optional)

## 🎯 Common Use Cases

### Development: Deploy and Test EC2

```bash
# Deploy EC2 stack only
./deploy-stacks.sh deploy-ec2

# Get service URL
./manage-stacks.sh info mlops-mnist-ec2-production

# Test the deployment
curl http://<IP>:8000/health

# Delete when done
./manage-stacks.sh delete mlops-mnist-ec2-production
```

### Production: Deploy Complete Infrastructure

```bash
# Deploy all stacks
./deploy-stacks.sh deploy

# Verify deployment
./manage-stacks.sh list

# Check termination protection
./manage-stacks.sh check
```

### Cleanup: Remove All Resources

```bash
# Quick cleanup
./manage-stacks.sh delete-all

# Or delete individually in order:
./manage-stacks.sh delete mlops-mnist-eks-production
./manage-stacks.sh delete mlops-mnist-ec2-production
./manage-stacks.sh delete mlops-mnist-vpc-production
```

## 💰 Cost Management

### Check Current Resources

```bash
# List all stacks
./manage-stacks.sh list

# Check specific stack resources
./manage-stacks.sh info mlops-mnist-eks-production
```

### Stop/Start to Save Costs

```bash
# Stop EC2 instance
aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=mlops-mnist" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Start EC2 instance
aws ec2 start-instances --instance-ids <instance-id>
```

## 🧪 Testing After Deployment

### EC2 Stack
```bash
# Get IP
IP=$(aws cloudformation describe-stacks --stack-name mlops-mnist-ec2-production \
  --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' --output text)

# Test health
curl http://$IP:8000/health

# Test API
curl -X POST -F "file=@image.jpg" http://$IP:8000/predict
```

### EKS Stack
```bash
# Configure kubectl
aws eks update-kubeconfig --name mlops-assignment2-cluster

# Check cluster
kubectl get nodes
kubectl get pods -n mlops
```

## 🔍 Troubleshooting

### Stack creation failed
```bash
# View recent events
./manage-stacks.sh events <stack-name>

# Check CloudFormation console
# https://console.aws.amazon.com/cloudformation
```

### Cannot delete stack
```bash
# Disable termination protection
./manage-stacks.sh disable

# Try deleting again
./manage-stacks.sh delete <stack-name>
```

### Stack stuck in DELETE_FAILED
```bash
# Check dependencies
./manage-stacks.sh info <stack-name>

# Force delete via console or retry
aws cloudformation delete-stack --stack-name <stack-name>
```

## 🔐 Security Best Practices

1. **Review IAM Permissions**: Ensure minimal necessary permissions
2. **Security Groups**: Restrict SSH access to specific IPs
3. **Enable Encryption**: EBS volumes encrypted by default
4. **VPC Isolation**: Use private subnets for sensitive resources
5. **Regular Updates**: Keep AMIs and Kubernetes versions updated

## 📊 Monitoring

### CloudWatch Logs

```bash
# EC2 instance logs
aws logs tail /aws/ec2/mlops-mnist --follow

# EKS cluster logs
aws logs tail /aws/eks/mlops-assignment2-cluster/cluster --follow
```

### Stack Status Monitoring

```bash
# Continuously monitor stacks
watch -n 30 './manage-stacks.sh list'
```

---

**Quick Help**: `./manage-stacks.sh help`
