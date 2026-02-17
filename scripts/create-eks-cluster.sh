#!/bin/bash

################################################################################
# EKS Cluster Creation Script
# 
# This script creates an EKS cluster using eksctl and configures kubectl
# 
# Prerequisites:
#   - AWS CLI installed and configured
#   - eksctl installed
#   - kubectl installed
#
# Usage:
#   ./create-eks-cluster.sh [cluster-name] [region]
#
# Example:
#   ./create-eks-cluster.sh mlops-assignment2-cluster us-east-1
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${1:-mlops-assignment2-cluster}"
REGION="${2:-us-east-1}"
NODE_TYPE="${3:-t3.medium}"
MIN_NODES="${4:-2}"
MAX_NODES="${5:-4}"
DESIRED_NODES="${6:-2}"
K8S_VERSION="1.28"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  EKS Cluster Creation Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Cluster Name:    $CLUSTER_NAME"
echo "  Region:          $REGION"
echo "  Kubernetes:      $K8S_VERSION"
echo "  Node Type:       $NODE_TYPE"
echo "  Nodes (min/desired/max): $MIN_NODES/$DESIRED_NODES/$MAX_NODES"
echo ""

################################################################################
# Check Prerequisites
################################################################################

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}ERROR: $1 is not installed${NC}"
        echo "Please install $1 and try again"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} $1 is installed"
}

echo -e "${YELLOW}Checking prerequisites...${NC}"
check_command aws
check_command eksctl
check_command kubectl
echo ""

################################################################################
# Verify AWS Credentials
################################################################################

echo -e "${YELLOW}Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "${GREEN}✓${NC} AWS Account: $AWS_ACCOUNT"
echo -e "${GREEN}✓${NC} AWS User: $AWS_USER"
echo ""

################################################################################
# Check if Cluster Already Exists
################################################################################

echo -e "${YELLOW}Checking if cluster already exists...${NC}"
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &> /dev/null; then
    echo -e "${YELLOW}⚠ Cluster '$CLUSTER_NAME' already exists in $REGION${NC}"
    read -p "Do you want to delete and recreate it? (yes/no): " RECREATE
    if [ "$RECREATE" = "yes" ]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" --wait
        echo -e "${GREEN}✓${NC} Cluster deleted"
    else
        echo -e "${BLUE}Skipping cluster creation. Configuring kubectl instead...${NC}"
        aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
        echo -e "${GREEN}✓${NC} kubectl configured"
        exit 0
    fi
fi
echo ""

################################################################################
# Create EKS Cluster
################################################################################

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Creating EKS Cluster${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}⚠ This will take 15-20 minutes...${NC}"
echo ""

# Create cluster using eksctl
eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --version "$K8S_VERSION" \
  --nodegroup-name "standard-workers" \
  --node-type "$NODE_TYPE" \
  --nodes "$DESIRED_NODES" \
  --nodes-min "$MIN_NODES" \
  --nodes-max "$MAX_NODES" \
  --managed \
  --with-oidc \
  --ssh-access=false \
  --external-dns-access \
  --full-ecr-access \
  --alb-ingress-access \
  --tags "Project=mlops-assignment2,Environment=production,ManagedBy=eksctl"

echo ""
echo -e "${GREEN}✓${NC} EKS Cluster created successfully"
echo ""

################################################################################
# Configure kubectl
################################################################################

echo -e "${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
echo -e "${GREEN}✓${NC} kubectl configured"
echo ""

################################################################################
# Verify Cluster
################################################################################

echo -e "${YELLOW}Verifying cluster...${NC}"
kubectl cluster-info
echo ""
kubectl get nodes
echo ""
echo -e "${GREEN}✓${NC} Cluster is ready"
echo ""

################################################################################
# Display Cluster Information
################################################################################

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Cluster Information${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Get cluster endpoint
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.endpoint' --output text)
echo -e "${GREEN}Cluster Endpoint:${NC} $CLUSTER_ENDPOINT"

# Get cluster security group
CLUSTER_SG=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo -e "${GREEN}Security Group:${NC} $CLUSTER_SG"

# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo -e "${GREEN}VPC ID:${NC} $VPC_ID"

# Get node group status
echo ""
echo -e "${GREEN}Node Groups:${NC}"
eksctl get nodegroup --cluster "$CLUSTER_NAME" --region "$REGION"

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "1. Deploy your application:"
echo "   kubectl apply -f deployment/kubernetes/"
echo ""
echo "2. Check deployment status:"
echo "   kubectl get pods -n mlops"
echo ""
echo "3. Get service URL:"
echo "   kubectl get svc -n mlops"
echo ""
echo "4. View cluster details:"
echo "   eksctl get cluster --name $CLUSTER_NAME --region $REGION"
echo ""
echo "5. Delete cluster (when done):"
echo "   eksctl delete cluster --name $CLUSTER_NAME --region $REGION"
echo ""
echo -e "${GREEN}✓ EKS Cluster setup complete!${NC}"
