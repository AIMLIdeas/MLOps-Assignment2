#!/bin/bash
# Quick AWS Deployment - Fixes credentials and deploys to AWS
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Cats vs Dogs Classifier - AWS Deployment ===${NC}\n"

# Step 1: Fix AWS credentials
echo -e "${YELLOW}Step 1: AWS Credentials${NC}"
echo -e "Access Key ID: AKIAZTZ245PGKGRL6H47\n"

read -sp "Enter your AWS Secret Access Key: " AWS_SECRET
echo ""

if [ -z "$AWS_SECRET" ]; then
    echo -e "${RED}Error: Secret key cannot be empty${NC}"
    exit 1
fi

# Update credentials file
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = AKIAZTZ245PGKGRL6H47
aws_secret_access_key = $AWS_SECRET
EOF

echo -e "${GREEN}✓ AWS credentials updated${NC}\n"

# Validate credentials
echo -e "${YELLOW}Validating AWS credentials...${NC}"
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    USER=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓ AWS credentials valid!${NC}"
    echo -e "  Account: $ACCOUNT"
    echo -e "  User: $USER\n"
else
    echo -e "${RED}✗ Invalid AWS credentials. Please check your secret key.${NC}"
    exit 1
fi

# Step 2: GitHub credentials
echo -e "${YELLOW}Step 2: GitHub Container Registry Access${NC}"
echo -e "Repository: ghcr.io/aimlideas/cats-dogs-classifier:latest\n"

read -p "Do you need to set GitHub PAT? (y/N): " NEED_PAT
if [[ "$NEED_PAT" =~ ^[Yy]$ ]]; then
    read -sp "Enter your GitHub Personal Access Token: " GITHUB_PAT
    echo ""
    export GITHUB_PAT
    export GITHUB_USERNAME="aimlideas"
    echo -e "${GREEN}✓ GitHub credentials set${NC}\n"
else
    echo -e "${YELLOW}⚠ Skipping GitHub PAT (will use public access)${NC}\n"
fi

# Step 3: Choose deployment option
echo -e "${YELLOW}Step 3: Choose Deployment Option${NC}\n"
echo -e "1) ${GREEN}EC2${NC} - Single instance (~\$9/month, 3-5 min deployment)"
echo -e "2) ${BLUE}EKS${NC} - Kubernetes cluster (~\$152/month, 15-20 min deployment)\n"
read -p "Select option (1 or 2): " OPTION

case $OPTION in
    1)
        echo -e "\n${GREEN}Deploying to EC2...${NC}\n"
        ./deployment/ec2/deploy-ec2.sh
        ;;
    2)
        echo -e "\n${BLUE}Deploying to EKS...${NC}\n"
        echo -e "${YELLOW}Running pre-flight check...${NC}"
        ./deployment/verify-eks-prerequisites.sh
        
        if [ $? -eq 0 ]; then
            echo -e "\n${GREEN}Starting EKS deployment...${NC}\n"
            ./deployment/deploy-to-aws.sh
        else
            echo -e "\n${RED}Pre-flight check failed. Please fix errors above.${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac
