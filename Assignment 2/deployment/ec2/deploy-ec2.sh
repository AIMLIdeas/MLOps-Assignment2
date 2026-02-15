#!/bin/bash
# Deploy Cats vs Dogs Classifier to AWS EC2
# This script creates an EC2 instance and deploys the Cats vs Dogs classifier service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Cats vs Dogs Classifier AWS EC2 Deployment ===${NC}\n"

# Configuration
REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
AMI_ID="${AMI_ID:-}"  # Will auto-detect latest Amazon Linux 2023 if not set
KEY_NAME="${KEY_NAME:-cats-dogs-key}"
SECURITY_GROUP_NAME="cats-dogs-classifier-sg"
INSTANCE_NAME="cats-dogs-classifier-instance"
GITHUB_USERNAME="${GITHUB_USERNAME:-aimlideas}"
GITHUB_PAT="${GITHUB_PAT:-}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: aws CLI is not installed${NC}" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${YELLOW}Warning: jq not installed. Install with: brew install jq${NC}"; }

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
aws sts get-caller-identity >/dev/null 2>&1 || { echo -e "${RED}Error: AWS credentials not configured. Run 'aws configure'${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ AWS credentials configured${NC}\n"

# Get or create VPC
echo -e "${YELLOW}Getting default VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo -e "${RED}Error: No default VPC found in region $REGION${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Using VPC: $VPC_ID${NC}"

# Create or get security group
echo -e "\n${YELLOW}Creating security group...${NC}"
SG_ID=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --region $REGION \
        --group-name $SECURITY_GROUP_NAME \
        --description "Security group for Cats vs Dogs classifier" \
        --vpc-id $VPC_ID \
        --query 'GroupId' \
        --output text)
    
    # Add ingress rules
    aws ec2 authorize-security-group-ingress \
        --region $REGION \
        --group-id $SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --group-name $SECURITY_GROUP_NAME || true
    
    aws ec2 authorize-security-group-ingress \
        --region $REGION \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --group-name $SECURITY_GROUP_NAME || true
    
    echo -e "${GREEN}✓ Security group created: $SG_ID${NC}"
else
    echo -e "${GREEN}✓ Using existing security group: $SG_ID${NC}"
fi

# Create or get key pair
echo -e "\n${YELLOW}Checking SSH key pair...${NC}"
if ! aws ec2 describe-key-pairs --region $REGION --key-names $KEY_NAME >/dev/null 2>&1; then
    echo -e "${YELLOW}Creating new key pair: $KEY_NAME${NC}"
    aws ec2 create-key-pair \
        --region $REGION \
        --key-name $KEY_NAME \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/${KEY_NAME}.pem
    chmod 400 ~/.ssh/${KEY_NAME}.pem
    echo -e "${GREEN}✓ Key pair created and saved to ~/.ssh/${KEY_NAME}.pem${NC}"
else
    echo -e "${GREEN}✓ Using existing key pair: $KEY_NAME${NC}"
fi

# Get latest Amazon Linux 2023 AMI if not specified
if [ -z "$AMI_ID" ]; then
    echo -e "\n${YELLOW}Finding latest Amazon Linux 2023 AMI...${NC}"
    AMI_ID=$(aws ec2 describe-images \
        --region $REGION \
        --owners amazon \
        --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text)
    echo -e "${GREEN}✓ Using AMI: $AMI_ID${NC}"
fi

# Prepare user data script
echo -e "\n${YELLOW}Preparing user data script...${NC}"
USER_DATA=$(cat deployment/ec2/user-data.sh)
if [ ! -z "$GITHUB_PAT" ]; then
    USER_DATA="export GITHUB_USERNAME='${GITHUB_USERNAME}'
export GITHUB_PAT='${GITHUB_PAT}'
${USER_DATA}"
fi

# Launch EC2 instance
echo -e "\n${YELLOW}Launching EC2 instance...${NC}"
INSTANCE_ID=$(aws ec2 run-instances \
    --region $REGION \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=20,VolumeType=gp3}' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo -e "${GREEN}✓ Instance launched: $INSTANCE_ID${NC}"

# Wait for instance to be running
echo -e "\n${YELLOW}Waiting for instance to be running...${NC}"
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID
echo -e "${GREEN}✓ Instance is running${NC}"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --region $REGION \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo -e "\n${YELLOW}Waiting for instance initialization (this may take 2-3 minutes)...${NC}"
aws ec2 wait instance-status-ok --region $REGION --instance-ids $INSTANCE_ID

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\n${GREEN}Instance Details:${NC}"
echo -e "  Instance ID: $INSTANCE_ID"
echo -e "  Public IP: $PUBLIC_IP"
echo -e "  Instance Type: $INSTANCE_TYPE"
echo -e "  Region: $REGION"
echo -e "\n${GREEN}Service Endpoint:${NC}"
echo -e "  http://$PUBLIC_IP"
echo -e "\n${YELLOW}Test the service:${NC}"
echo -e "  curl http://$PUBLIC_IP/health"
echo -e "\n${YELLOW}SSH to instance:${NC}"
echo -e "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo -e "\n${YELLOW}View logs:${NC}"
echo -e "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'docker logs cats-dogs-classifier'"
echo -e "\n${YELLOW}Stop instance:${NC}"
echo -e "  aws ec2 stop-instances --region $REGION --instance-ids $INSTANCE_ID"
echo -e "\n${YELLOW}Terminate instance:${NC}"
echo -e "  aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID"
echo -e "\n${YELLOW}Note:${NC} The service may take 2-3 minutes to fully start after instance initialization."
