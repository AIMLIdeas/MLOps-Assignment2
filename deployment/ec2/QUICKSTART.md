# Quick Start: Deploy to AWS EC2

## One-Command Deployment

```bash
# 1. Configure AWS
aws configure

# 2. Deploy
chmod +x deployment/ec2/deploy-ec2.sh
./deployment/ec2/deploy-ec2.sh
```

**That's it!** Your service will be running in 3-5 minutes. ⚡

## What You Get

- ✅ **EC2 instance** with Docker pre-installed
- ✅ **Cat/Dogs classifier** running on port 80
- ✅ **Public IP** for immediate access
- ✅ **SSH key** saved to ~/.ssh/mnist-key.pem
- ✅ **Security group** with HTTP (80) and SSH (22) access
- ✅ **Cost**: ~$9/month (t3.micro)

## Test Your Deployment

```bash
# Get IP from deployment output, then:
PUBLIC_IP="your_instance_ip"

# Test health
curl http://$PUBLIC_IP/health

# Test prediction (base64-encoded image)
curl -X POST http://$PUBLIC_IP/predict-image \
  -H "Content-Type: application/json" \
  -d '{"image": "<base64-encoded-cat-or-dog-image>"}'
```

## Management Commands

```bash
# Get instance details
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=cat-dogs-classifier-instance" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' \
  --output table

# SSH to instance
ssh -i ~/.ssh/mnist-key.pem ec2-user@$PUBLIC_IP

# View logs
ssh -i ~/.ssh/mnist-key.pem ec2-user@$PUBLIC_IP 'docker logs mnist-classifier'

# Stop instance (save costs)
aws ec2 stop-instances --instance-ids $INSTANCE_ID

# Start instance
aws ec2 start-instances --instance-ids $INSTANCE_ID

# Terminate instance (permanent)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

## Optional: CloudFormation Deployment

```bash
aws cloudformation create-stack \
  --stack-name cat-dogs-classifier \
  --template-body file://deployment/ec2/cloudformation-template.yaml \
  --parameters ParameterKey=KeyName,ParameterValue=your-existing-key \
  --region us-east-1

# Wait for completion
aws cloudformation wait stack-create-complete --stack-name cat-dogs-classifier

# Get outputs
aws cloudformation describe-stacks \
  --stack-name cat-dogs-classifier \
  --query 'Stacks[0].Outputs'
```

## Cost Comparison

| Option | Monthly Cost | Setup Time | Use Case |
|--------|-------------|------------|----------|
| **EC2 t3.micro** | **~$9** | **3-5 min** | **Dev/Test** ✅ |
| EC2 t3.small | ~$15 | 3-5 min | Production |
| EC2 t3.medium | ~$30 | 3-5 min | High traffic |
| EKS Cluster | ~$152 | 15-20 min | Enterprise |

## Files Created

- ✅ [deployment/ec2/deploy-ec2.sh](ec2/deploy-ec2.sh) - Automated deployment script
- ✅ [deployment/ec2/user-data.sh](ec2/user-data.sh) - EC2 initialization script
- ✅ [deployment/ec2/cloudformation-template.yaml](ec2/cloudformation-template.yaml) - CloudFormation IaC
- ✅ [deployment/EC2_DEPLOYMENT_GUIDE.md](EC2_DEPLOYMENT_GUIDE.md) - Complete guide

## Troubleshooting

### Can't connect to service?
```bash
# Check instance is running
aws ec2 describe-instances --filters "Name=tag:Name,Values=cat-dogs-classifier-instance"

# Check security group
aws ec2 describe-security-groups --filters "Name=group-name,Values=cat-dogs-classifier-sg"

# SSH and check Docker
ssh -i ~/.ssh/mnist-key.pem ec2-user@$PUBLIC_IP
docker ps
docker logs cat-dogs-classifier
```

### Update to latest image?
```bash
ssh -i ~/.ssh/mnist-key.pem ec2-user@$PUBLIC_IP
cd mnist-app
docker-compose pull
docker-compose up -d
```

## Next Steps

1. ✅ Deploy: `./deployment/ec2/deploy-ec2.sh`
2. ✅ Test: `curl http://$PUBLIC_IP/health`
3. ✅ Monitor: Check CloudWatch in AWS Console
4. ✅ Scale: Upgrade to t3.small or add Auto Scaling
5. ✅ Secure: Add HTTPS with Application Load Balancer

**Full documentation**: [EC2_DEPLOYMENT_GUIDE.md](EC2_DEPLOYMENT_GUIDE.md)
