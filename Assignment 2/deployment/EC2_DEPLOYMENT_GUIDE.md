# AWS EC2 Deployment Guide

This guide explains how to deploy the Cats vs Dogs Classifier service to AWS EC2 using Docker and the GitHub Container Registry image.

## Why EC2 vs EKS?

**EC2 Advantages:**
- ✅ **Lower Cost**: ~$8-15/month vs ~$152/month for EKS
- ✅ **Simpler Setup**: Single instance, no cluster management
- ✅ **Faster Deployment**: 3-5 minutes vs 15-20 minutes
- ✅ **Good for**: Development, testing, low-traffic production

**EKS Advantages:**
- ✅ **Auto-scaling**: Kubernetes manages multiple pods
- ✅ **High Availability**: Multi-AZ deployment
- ✅ **Good for**: High-traffic production, microservices

## Prerequisites

### 1. Required Tools
All tools are already installed:
- ✅ AWS CLI v2.33.18

### 2. AWS Account Setup
- AWS account with EC2 permissions
- IAM user with EC2, VPC, and Security Group permissions

### 3. GitHub Credentials (Optional)
- GitHub Personal Access Token (PAT) with `read:packages` scope
- Only needed if the repository is private

## Deployment Options

### Option A: Automated Deployment (Recommended)

#### Step 1: Configure AWS

```bash
aws configure
```

Enter your credentials:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **Default region**: `us-east-1`
- **Default output format**: `json`

Verify:
```bash
aws sts get-caller-identity
```

#### Step 2: Set Environment Variables (Optional)

```bash
# Optional: Only needed for private repositories
export GITHUB_USERNAME="aimlideas"
export GITHUB_PAT="your_github_pat_here"

# Optional: Customize instance configuration
export INSTANCE_TYPE="t3.micro"  # Default: t3.micro ($8/month)
export AWS_REGION="us-east-1"     # Default: us-east-1
export KEY_NAME="cats-dogs-key"       # Default: cats-dogs-key
```

#### Step 3: Run Deployment Script

```bash
chmod +x deployment/ec2/deploy-ec2.sh
./deployment/ec2/deploy-ec2.sh
```

**Deployment time**: 3-5 minutes

The script will:
1. ✅ Verify AWS credentials
2. ✅ Create security group (ports 80, 22)
3. ✅ Create SSH key pair (saved to ~/.ssh/cats-dogs-key.pem)
4. ✅ Launch EC2 instance
5. ✅ Install Docker and Docker Compose
6. ✅ Pull and start the Cats vs Dogs classifier container
7. ✅ Display instance details and service URL

#### Step 4: Test the Service

```bash
# Get the public IP from deployment output
PUBLIC_IP="your_instance_public_ip"

# Test health endpoint
curl http://$PUBLIC_IP/health

# Expected response:
# {"status":"healthy","model_loaded":true,"timestamp":"..."}

# Test prediction
curl -X POST http://$PUBLIC_IP/predict \
  -H "Content-Type: application/json" \
  -d '{
    "image": [0.0, 0.0, ...(784 values)...]
  }'
```

### Option B: CloudFormation Template

#### Step 1: Create Stack

```bash
aws cloudformation create-stack \
  --stack-name cats-dogs-classifier-stack \
  --template-body file://deployment/ec2/cloudformation-template.yaml \
  --parameters \
    ParameterKey=KeyName,ParameterValue=your-key-name \
    ParameterKey=InstanceType,ParameterValue=t3.micro \
    ParameterKey=GitHubUsername,ParameterValue=aimlideas \
    ParameterKey=GitHubPAT,ParameterValue=your_pat_here \
  --region us-east-1
```

#### Step 2: Wait for Stack Creation

```bash
aws cloudformation wait stack-create-complete \
  --stack-name cats-dogs-classifier-stack \
  --region us-east-1
```

#### Step 3: Get Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name cats-dogs-classifier-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

### Option C: Manual Deployment

#### Step 1: Create Security Group

```bash
# Get default VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)

# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name cats-dogs-classifier-sg \
  --description "Cats vs Dogs Classifier Security Group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Add inbound rules
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
```

#### Step 2: Create Key Pair

```bash
aws ec2 create-key-pair \
  --key-name cats-dogs-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/cats-dogs-key.pem

chmod 400 ~/.ssh/cats-dogs-key.pem
```

#### Step 3: Launch Instance

```bash
# Get latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

# Launch instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name cats-dogs-key \
  --security-group-ids $SG_ID \
  --user-data file://deployment/ec2/user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cats-dogs-classifier-instance}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
```

#### Step 4: Wait for Instance

```bash
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
```

#### Step 5: Get Public IP

```bash
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Public IP: $PUBLIC_IP"
echo "Service URL: http://$PUBLIC_IP"
```

## Verification

### Check Instance Status

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=cats-dogs-classifier-instance" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table
```

### SSH to Instance

```bash
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP
```

### View Container Logs

```bash
# Via SSH
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP 'docker logs cats-dogs-classifier'

# Or after SSH login
docker logs -f cats-dogs-classifier
docker ps
docker-compose ps
```

### Test Service

```bash
# Health check
curl http://$PUBLIC_IP/health

# Metrics
curl http://$PUBLIC_IP/metrics

# Stats
curl http://$PUBLIC_IP/stats

# Prediction test
curl -X POST http://$PUBLIC_IP/predict \
  -H "Content-Type: application/json" \
  -d @tests/sample_image.json
```

## Management

### View Logs

```bash
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP 'docker logs -f cats-dogs-classifier'
```

### Restart Service

```bash
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP 'cd cats-dogs-app && docker-compose restart'
```

### Update to Latest Image

```bash
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP 'cd cats-dogs-app && docker-compose pull && docker-compose up -d'
```

### Stop Instance (to save costs)

```bash
aws ec2 stop-instances --instance-ids $INSTANCE_ID
```

### Start Instance

```bash
aws ec2 start-instances --instance-ids $INSTANCE_ID

# Note: Public IP will change. Get new IP:
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### Terminate Instance (permanent deletion)

```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

### Delete CloudFormation Stack

```bash
aws cloudformation delete-stack --stack-name cats-dogs-classifier-stack
```

## Cost Estimation

### t3.micro (Recommended for Development/Testing)
- **Specs**: 2 vCPUs, 1 GB RAM
- **Cost**: ~$0.0104/hour = ~$7.50/month
- **Use case**: Light traffic, testing

### t3.small (Recommended for Production)
- **Specs**: 2 vCPUs, 2 GB RAM
- **Cost**: ~$0.0208/hour = ~$15/month
- **Use case**: Production with moderate traffic

### t3.medium
- **Specs**: 2 vCPUs, 4 GB RAM
- **Cost**: ~$0.0416/hour = ~$30/month
- **Use case**: High traffic production

### Additional Costs
- **EBS Storage**: 20 GB gp3 = ~$1.60/month
- **Data Transfer**: First 100 GB free, then ~$0.09/GB
- **Total estimated**: ~$9-32/month depending on instance type

### Cost Optimization Tips
1. ✅ Use **Spot Instances** for 70% discount (non-critical workloads)
2. ✅ Stop instances during off-hours
3. ✅ Use **Reserved Instances** for 1-year commitment (40% discount)
4. ✅ Enable **Auto-Shutdown** for unused instances
5. ✅ Use smaller instance types (t3.micro sufficient for light traffic)

## Monitoring

### CloudWatch Metrics

```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Set Up CloudWatch Alarms

```bash
# High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name cats-dogs-high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --evaluation-periods 2
```

## Security Best Practices

### 1. Restrict SSH Access

Edit security group to allow SSH only from your IP:

```bash
MY_IP=$(curl -s ifconfig.me)
aws ec2 revoke-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $MY_IP/32
```

### 2. Use HTTPS with Load Balancer

For production, use Application Load Balancer with SSL certificate:

```bash
# Create ALB
aws elbv2 create-load-balancer \
  --name cats-dogs-alb \
  --subnets subnet-xxx subnet-yyy \
  --security-groups $SG_ID

# Add SSL certificate from ACM
aws elbv2 create-listener \
  --load-balancer-arn <alb-arn> \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=<acm-cert-arn> \
  --default-actions Type=forward,TargetGroupArn=<target-group-arn>
```

### 3. Enable AWS Systems Manager

Install SSM agent for secure shell access without SSH keys:

```bash
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
```

Connect via Session Manager:
```bash
aws ssm start-session --target $INSTANCE_ID
```

### 4. Regular Updates

Enable automatic security updates:

```bash
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP
sudo yum install -y yum-cron
sudo systemctl enable yum-cron
sudo systemctl start yum-cron
```

## Troubleshooting

### Service Not Responding

```bash
# Check if instance is running
aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name'

# Check security group rules
aws ec2 describe-security-groups --group-ids $SG_ID

# SSH and check Docker
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP
docker ps
docker logs cats-dogs-classifier
```

### Container Not Starting

```bash
# Check Docker logs
docker logs cats-dogs-classifier

# Check if image pulled successfully
docker images | grep cats-dogs

# Manually pull image
docker pull ghcr.io/aimlideas/cats-dogs-classifier:latest

# Restart container
cd ~/cats-dogs-app
docker-compose down
docker-compose up -d
```

### Connection Timeout

```bash
# Check security group allows port 80
aws ec2 describe-security-groups --group-ids $SG_ID

# Check instance is in running state
aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name'

# Check user data script completed
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP 'cat /var/log/cloud-init-output.log'
```

### High Memory Usage

```bash
# Connect to instance
ssh -i ~/.ssh/cats-dogs-key.pem ec2-user@$PUBLIC_IP

# Check memory
free -h
docker stats

# Restart container to free memory
docker-compose restart
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    AWS Cloud                         │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │         VPC (Default)                      │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────┐     │    │
│  │  │  Security Group                  │     │    │
│  │  │  - Port 80 (HTTP)                │     │    │
│  │  │  - Port 22 (SSH)                 │     │    │
│  │  └──────────────┬───────────────────┘     │    │
│  │                 │                          │    │
│  │  ┌──────────────▼───────────────────┐     │    │
│  │  │  EC2 Instance (t3.micro)         │     │    │
│  │  │                                  │     │    │
│  │  │  ┌────────────────────────────┐  │     │    │
│  │  │  │  Docker Container          │  │     │    │
│  │  │  │  cats-dogs-classifier:latest   │  │     │    │
│  │  │  │  Port: 8000 → 80          │  │     │    │
│  │  │  │  Image: ghcr.io           │  │     │    │
│  │  │  └────────────────────────────┘  │     │    │
│  │  │                                  │     │    │
│  │  │  Public IP: x.x.x.x             │     │    │
│  │  └──────────────────────────────────┘     │    │
│  │                                            │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
└───────────────────────┬──────────────────────────────┘
                        │
                 ┌──────▼──────┐
                 │   Internet  │
                 └─────────────┘
```

## Next Steps

After successful EC2 deployment:

1. ✅ Set up **Elastic IP** for static IP address
2. ✅ Configure **Route 53** for custom domain
3. ✅ Add **Application Load Balancer** for HTTPS
4. ✅ Set up **CloudWatch** monitoring and alarms
5. ✅ Enable **Auto Scaling** for traffic spikes
6. ✅ Configure **S3** for log storage
7. ✅ Set up **AWS Backup** for instance snapshots
8. ✅ Implement **CI/CD** pipeline for automated deployments
9. ✅ Add **AWS WAF** for security
10. ✅ Configure **VPC Peering** for private services

## Support

For issues or questions:
- Check logs: `docker logs cats-dogs-classifier`
- View CloudWatch: AWS Console → CloudWatch → Logs
- Check AWS EC2 documentation: https://docs.aws.amazon.com/ec2/
- Instance troubleshooting: https://aws.amazon.com/premiumsupport/knowledge-center/

## Comparison: EC2 vs EKS

| Feature | EC2 | EKS |
|---------|-----|-----|
| **Monthly Cost** | ~$9-15 | ~$152 |
| **Setup Time** | 3-5 min | 15-20 min |
| **Complexity** | Low | High |
| **Scalability** | Manual | Automatic |
| **High Availability** | Single instance | Multi-AZ |
| **Best For** | Dev/Test/Small prod | Production/Microservices |
| **Management** | Simple | Kubernetes required |

**Recommendation**: Use EC2 for development and low-traffic production. Migrate to EKS when you need auto-scaling and high availability.
