#!/bin/bash
# Pre-deployment verification for EKS
# This script checks all prerequisites before deploying to EKS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== EKS Deployment Pre-flight Check ===${NC}\n"

ERRORS=0
WARNINGS=0

# Check AWS CLI
echo -e "${YELLOW}[1/7] Checking AWS CLI...${NC}"
if command -v aws >/dev/null 2>&1; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    echo -e "${GREEN}✓ AWS CLI installed: $AWS_VERSION${NC}"
else
    echo -e "${RED}✗ AWS CLI not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check kubectl
echo -e "\n${YELLOW}[2/7] Checking kubectl...${NC}"
if command -v kubectl >/dev/null 2>&1; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>&1 | head -1)
    echo -e "${GREEN}✓ kubectl installed: $KUBECTL_VERSION${NC}"
else
    echo -e "${RED}✗ kubectl not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check eksctl
echo -e "\n${YELLOW}[3/7] Checking eksctl...${NC}"
if command -v eksctl >/dev/null 2>&1; then
    EKSCTL_VERSION=$(eksctl version)
    echo -e "${GREEN}✓ eksctl installed: $EKSCTL_VERSION${NC}"
else
    echo -e "${RED}✗ eksctl not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check AWS credentials
echo -e "\n${YELLOW}[4/7] Checking AWS credentials...${NC}"
if aws sts get-caller-identity >/dev/null 2>&1; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓ AWS credentials configured${NC}"
    echo -e "  Account: $AWS_ACCOUNT"
    echo -e "  User: $AWS_USER"
else
    echo -e "${RED}✗ AWS credentials not configured or invalid${NC}"
    echo -e "${YELLOW}  Run: aws configure${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check AWS region
echo -e "\n${YELLOW}[5/7] Checking AWS region...${NC}"
AWS_REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$AWS_REGION" ]; then
    echo -e "${RED}✗ AWS region not configured${NC}"
    echo -e "${YELLOW}  Run: aws configure set region us-east-1${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ AWS region: $AWS_REGION${NC}"
fi

# Check GitHub credentials
echo -e "\n${YELLOW}[6/7] Checking GitHub credentials...${NC}"
if [ -z "$GITHUB_PAT" ]; then
    echo -e "${YELLOW}⚠ GITHUB_PAT environment variable not set${NC}"
    echo -e "${YELLOW}  This is needed to pull from GitHub Container Registry${NC}"
    echo -e "${YELLOW}  Set with: export GITHUB_PAT='your_token_here'${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ GITHUB_PAT is set${NC}"
fi

# Check deployment files
echo -e "\n${YELLOW}[7/7] Checking deployment files...${NC}"
REQUIRED_FILES=(
    "deployment/kubernetes/namespace.yaml"
    "deployment/kubernetes/deployment.yaml"
    "deployment/kubernetes/service.yaml"
    "deployment/kubernetes/configmap.yaml"
    "deployment/kubernetes/hpa.yaml"
    "deployment/kubernetes/eks-cluster-config.yaml"
    "deployment/deploy-to-aws.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}  ✓ $file${NC}"
    else
        echo -e "${RED}  ✗ $file not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Summary
echo -e "\n${BLUE}=== Summary ===${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All required checks passed!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) - review above${NC}"
    fi
    echo -e "\n${GREEN}Ready to deploy!${NC}"
    echo -e "\nNext steps:"
    echo -e "  1. Set GitHub PAT: ${YELLOW}export GITHUB_PAT='your_token_here'${NC}"
    echo -e "  2. Run deployment: ${YELLOW}./deployment/deploy-to-aws.sh${NC}"
    echo -e "\nEstimated deployment time: 15-20 minutes"
    echo -e "Estimated cost: ~\$152/month (EKS control plane + 2 nodes)"
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found - fix before deploying${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC}"
    fi
    echo -e "\n${YELLOW}Please fix the errors above and run this script again.${NC}"
    exit 1
fi
