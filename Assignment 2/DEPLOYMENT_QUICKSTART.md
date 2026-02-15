# AWS Deployment - Quick Start

## Your AWS Credentials
- **Access Key ID**: `AKIAZTZ245PGKGRL6H47`
- **Secret Access Key**: You need to provide this

## Deployment Steps

### Step 1: Configure AWS CLI

```bash
aws configure
```

When prompted, enter:
- **AWS Access Key ID**: `AKIAZTZ245PGKGRL6H47`
- **AWS Secret Access Key**: `[Enter your secret key]`
- **Default region**: `us-east-1`
- **Default output**: `json`

### Step 2: Verify Configuration

```bash
aws sts get-caller-identity
```

You should see your AWS account details.

### Step 3: Deploy to AWS

#### Option A: EC2 Deployment (Recommended)
**Best for**: Development, Testing, Low traffic
- **Cost**: ~$9/month
- **Time**: 3-5 minutes
- **Infrastructure**: Single EC2 instance with Docker

```bash
./deployment/ec2/deploy-ec2.sh
```

#### Option B: EKS Deployment (Kubernetes)
**Best for**: Production, High availability, Auto-scaling
- **Cost**: ~$152/month
- **Time**: 15-20 minutes  
- **Infrastructure**: Kubernetes cluster with 2+ nodes

```bash
./deployment/deploy-to-aws.sh
```

## After Deployment

### For EC2:
```bash
# Test the service (replace PUBLIC_IP with actual IP from deployment output)
curl http://PUBLIC_IP/health

# SSH to instance
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@PUBLIC_IP

# View logs
docker logs cats-dogs-classifier
```

### For EKS:
```bash
#Get service endpoint
kubectl get svc cats-dogs-service -n mlops

# Test the service
curl http://LOAD_BALANCER_URL/health

# View pods
kubectl get pods -n mlops

# View logs
kubectl logs -f -l app=cats-dogs-classifier -n mlops
```

## Troubleshooting

### AWS Credentials Error
```bash
# Reconfigure AWS
aws configure

# Test credentials
aws sts get-caller-identity
```

### GitHub Container Registry Access (if needed)
```bash
export GITHUB_USERNAME="aimlideas"
export GITHUB_PAT="your_github_token"
```

Only needed if repository is private. Get token from: https://github.com/settings/tokens (scope: `read:packages`)

## Cost Management

### EC2:
- **Stop instance** when not in use: `aws ec2 stop-instances --instance-ids INSTANCE_ID`
- **Terminate** to delete: `aws ec2 terminate-instances --instance-ids INSTANCE_ID`

### EKS:
- **Delete cluster**: `eksctl delete cluster --name cats-dogs-classifier-cluster --region us-east-1`

## Next Steps

1. Run: `aws configure`
2. Choose deployment option (EC2 recommended for testing)
3. Test your deployed service
4. Monitor costs in AWS Console → Billing Dashboard
