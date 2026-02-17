#!/bin/bash

################################################################################
# EKS Cluster Creation Script (Pure AWS CLI)
# 
# This script creates an EKS cluster using only AWS CLI commands
# (no eksctl - full control over all resources)
# 
# Prerequisites:
#   - AWS CLI installed and configured
#   - kubectl installed
#   - jq installed (for JSON parsing)
#
# Usage:
#   ./create-eks-awscli.sh [cluster-name] [region]
#
# Example:
#   ./create-eks-awscli.sh mlops-assignment2-cluster us-east-1
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
K8S_VERSION="1.28"
NODE_TYPE="t3.medium"
MIN_NODES=2
MAX_NODES=4
DESIRED_NODES=2

# VPC Configuration
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_1_CIDR="10.0.1.0/24"
PUBLIC_SUBNET_2_CIDR="10.0.2.0/24"
PRIVATE_SUBNET_1_CIDR="10.0.3.0/24"
PRIVATE_SUBNET_2_CIDR="10.0.4.0/24"

# Get availability zones
AZ1="${REGION}a"
AZ2="${REGION}b"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  EKS Cluster Creation (AWS CLI)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Cluster Name:    $CLUSTER_NAME"
echo "  Region:          $REGION"
echo "  Kubernetes:      $K8S_VERSION"
echo "  VPC CIDR:        $VPC_CIDR"
echo ""

################################################################################
# Check Prerequisites
################################################################################

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}ERROR: $1 is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} $1 is installed"
}

echo -e "${YELLOW}Checking prerequisites...${NC}"
check_command aws
check_command kubectl
check_command jq
echo ""

################################################################################
# Verify AWS Credentials
################################################################################

echo -e "${YELLOW}Verifying AWS credentials...${NC}"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "${GREEN}✓${NC} AWS Account: $AWS_ACCOUNT"
echo -e "${GREEN}✓${NC} AWS User: $AWS_USER"
echo ""

################################################################################
# Step 1: Create VPC
################################################################################

echo -e "${BLUE}Step 1: Creating VPC...${NC}"
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "$VPC_CIDR" \
    --region "$REGION" \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$CLUSTER_NAME-vpc},{Key=Project,Value=mlops-assignment2}]" \
    --query 'Vpc.VpcId' \
    --output text)

echo -e "${GREEN}✓${NC} VPC Created: $VPC_ID"

# Enable DNS support
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support --region "$REGION"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames --region "$REGION"
echo -e "${GREEN}✓${NC} DNS support enabled"
echo ""

################################################################################
# Step 2: Create Internet Gateway
################################################################################

echo -e "${BLUE}Step 2: Creating Internet Gateway...${NC}"
IGW_ID=$(aws ec2 create-internet-gateway \
    --region "$REGION" \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$CLUSTER_NAME-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$REGION"
echo -e "${GREEN}✓${NC} Internet Gateway Created and Attached: $IGW_ID"
echo ""

################################################################################
# Step 3: Create Subnets
################################################################################

echo -e "${BLUE}Step 3: Creating Subnets...${NC}"

# Public Subnet 1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$PUBLIC_SUBNET_1_CIDR" \
    --availability-zone "$AZ1" \
    --region "$REGION" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$CLUSTER_NAME-public-$AZ1},{Key=kubernetes.io/role/elb,Value=1}]" \
    --query 'Subnet.SubnetId' \
    --output text)

# Public Subnet 2
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$PUBLIC_SUBNET_2_CIDR" \
    --availability-zone "$AZ2" \
    --region "$REGION" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$CLUSTER_NAME-public-$AZ2},{Key=kubernetes.io/role/elb,Value=1}]" \
    --query 'Subnet.SubnetId' \
    --output text)

# Private Subnet 1
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$PRIVATE_SUBNET_1_CIDR" \
    --availability-zone "$AZ1" \
    --region "$REGION" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$CLUSTER_NAME-private-$AZ1},{Key=kubernetes.io/role/internal-elb,Value=1}]" \
    --query 'Subnet.SubnetId' \
    --output text)

# Private Subnet 2
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$PRIVATE_SUBNET_2_CIDR" \
    --availability-zone "$AZ2" \
    --region "$REGION" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$CLUSTER_NAME-private-$AZ2},{Key=kubernetes.io/role/internal-elb,Value=1}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo -e "${GREEN}✓${NC} Public Subnet 1: $PUBLIC_SUBNET_1 ($AZ1)"
echo -e "${GREEN}✓${NC} Public Subnet 2: $PUBLIC_SUBNET_2 ($AZ2)"
echo -e "${GREEN}✓${NC} Private Subnet 1: $PRIVATE_SUBNET_1 ($AZ1)"
echo -e "${GREEN}✓${NC} Private Subnet 2: $PRIVATE_SUBNET_2 ($AZ2)"

# Enable auto-assign public IP for public subnets
aws ec2 modify-subnet-attribute --subnet-id "$PUBLIC_SUBNET_1" --map-public-ip-on-launch --region "$REGION"
aws ec2 modify-subnet-attribute --subnet-id "$PUBLIC_SUBNET_2" --map-public-ip-on-launch --region "$REGION"
echo ""

################################################################################
# Step 4: Create NAT Gateway
################################################################################

echo -e "${BLUE}Step 4: Creating NAT Gateway...${NC}"

# Allocate Elastic IP
EIP_ALLOC=$(aws ec2 allocate-address \
    --domain vpc \
    --region "$REGION" \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$CLUSTER_NAME-nat-eip}]" \
    --query 'AllocationId' \
    --output text)

# Create NAT Gateway
NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$PUBLIC_SUBNET_1" \
    --allocation-id "$EIP_ALLOC" \
    --region "$REGION" \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$CLUSTER_NAME-nat}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo -e "${YELLOW}⏳ Waiting for NAT Gateway to become available...${NC}"
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID" --region "$REGION"
echo -e "${GREEN}✓${NC} NAT Gateway Created: $NAT_GW_ID"
echo ""

################################################################################
# Step 5: Create Route Tables
################################################################################

echo -e "${BLUE}Step 5: Creating Route Tables...${NC}"

# Public Route Table
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$CLUSTER_NAME-public-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Private Route Table
PRIVATE_RT=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$CLUSTER_NAME-private-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Create routes
aws ec2 create-route --route-table-id "$PUBLIC_RT" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$REGION"
aws ec2 create-route --route-table-id "$PRIVATE_RT" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID" --region "$REGION"

# Associate subnets with route tables
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_1" --route-table-id "$PUBLIC_RT" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_2" --route-table-id "$PUBLIC_RT" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_1" --route-table-id "$PRIVATE_RT" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_2" --route-table-id "$PRIVATE_RT" --region "$REGION"

echo -e "${GREEN}✓${NC} Route tables created and associated"
echo ""

################################################################################
# Step 6: Create EKS Cluster IAM Role
################################################################################

echo -e "${BLUE}Step 6: Creating EKS Cluster IAM Role...${NC}"

# Create trust policy
cat > /tmp/eks-cluster-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
CLUSTER_ROLE_NAME="$CLUSTER_NAME-cluster-role"
aws iam create-role \
    --role-name "$CLUSTER_ROLE_NAME" \
    --assume-role-policy-document file:///tmp/eks-cluster-trust-policy.json \
    --description "EKS cluster role for $CLUSTER_NAME" \
    || true  # Ignore if exists

# Attach policies
aws iam attach-role-policy --role-name "$CLUSTER_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam attach-role-policy --role-name "$CLUSTER_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController

CLUSTER_ROLE_ARN=$(aws iam get-role --role-name "$CLUSTER_ROLE_NAME" --query 'Role.Arn' --output text)
echo -e "${GREEN}✓${NC} Cluster IAM Role: $CLUSTER_ROLE_ARN"
echo ""

################################################################################
# Step 7: Create EKS Cluster
################################################################################

echo -e "${BLUE}Step 7: Creating EKS Cluster...${NC}"
echo -e "${YELLOW}⚠ This will take 10-15 minutes...${NC}"
echo ""

aws eks create-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --kubernetes-version "$K8S_VERSION" \
    --role-arn "$CLUSTER_ROLE_ARN" \
    --resources-vpc-config "subnetIds=$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2,$PUBLIC_SUBNET_1,$PUBLIC_SUBNET_2" \
    --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}' \
    --tags "Project=mlops-assignment2,Environment=production,ManagedBy=awscli"

# Wait for cluster to be active
echo -e "${YELLOW}⏳ Waiting for cluster to become active...${NC}"
aws eks wait cluster-active --name "$CLUSTER_NAME" --region "$REGION"
echo -e "${GREEN}✓${NC} EKS Cluster Created: $CLUSTER_NAME"
echo ""

################################################################################
# Step 8: Configure kubectl
################################################################################

echo -e "${BLUE}Step 8: Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
echo -e "${GREEN}✓${NC} kubectl configured"
echo ""

################################################################################
# Step 9: Create Node Group IAM Role
################################################################################

echo -e "${BLUE}Step 9: Creating Node Group IAM Role...${NC}"

# Create trust policy
cat > /tmp/eks-node-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role for nodes
NODE_ROLE_NAME="$CLUSTER_NAME-node-role"
aws iam create-role \
    --role-name "$NODE_ROLE_NAME" \
    --assume-role-policy-document file:///tmp/eks-node-trust-policy.json \
    --description "EKS node role for $CLUSTER_NAME" \
    || true  # Ignore if exists

# Attach policies
aws iam attach-role-policy --role-name "$NODE_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name "$NODE_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name "$NODE_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

NODE_ROLE_ARN=$(aws iam get-role --role-name "$NODE_ROLE_NAME" --query 'Role.Arn' --output text)
echo -e "${GREEN}✓${NC} Node IAM Role: $NODE_ROLE_ARN"
echo ""

################################################################################
# Step 10: Create EKS Node Group
################################################################################

echo -e "${BLUE}Step 10: Creating EKS Node Group...${NC}"
echo -e "${YELLOW}⚠ This will take 5-10 minutes...${NC}"
echo ""

aws eks create-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "standard-workers" \
    --region "$REGION" \
    --subnets "$PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_2" \
    --instance-types "$NODE_TYPE" \
    --scaling-config "minSize=$MIN_NODES,maxSize=$MAX_NODES,desiredSize=$DESIRED_NODES" \
    --node-role "$NODE_ROLE_ARN" \
    --tags "Project=mlops-assignment2,Environment=production"

# Wait for node group to be active
echo -e "${YELLOW}⏳ Waiting for node group to become active...${NC}"
aws eks wait nodegroup-active --cluster-name "$CLUSTER_NAME" --nodegroup-name "standard-workers" --region "$REGION"
echo -e "${GREEN}✓${NC} Node Group Created"
echo ""

################################################################################
# Step 11: Verify Cluster
################################################################################

echo -e "${BLUE}Step 11: Verifying Cluster...${NC}"
kubectl cluster-info
echo ""
kubectl get nodes
echo ""

################################################################################
# Display Summary
################################################################################

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Cluster Created Successfully!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Resources Created:${NC}"
echo "  VPC ID:              $VPC_ID"
echo "  Public Subnets:      $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "  Private Subnets:     $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
echo "  NAT Gateway:         $NAT_GW_ID"
echo "  Cluster Name:        $CLUSTER_NAME"
echo "  Cluster Role:        $CLUSTER_ROLE_ARN"
echo "  Node Role:           $NODE_ROLE_ARN"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "  1. Deploy application: kubectl apply -f deployment/kubernetes/"
echo "  2. Check status: kubectl get all -n mlops"
echo "  3. Get service URL: kubectl get svc -n mlops"
echo ""

# Save resource IDs to file
cat > /tmp/eks-resources-$CLUSTER_NAME.txt <<EOF
CLUSTER_NAME=$CLUSTER_NAME
REGION=$REGION
VPC_ID=$VPC_ID
PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1
PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2
PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1
PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2
NAT_GW_ID=$NAT_GW_ID
IGW_ID=$IGW_ID
PUBLIC_RT=$PUBLIC_RT
PRIVATE_RT=$PRIVATE_RT
CLUSTER_ROLE_NAME=$CLUSTER_ROLE_NAME
NODE_ROLE_NAME=$NODE_ROLE_NAME
EOF

echo -e "${GREEN}✓${NC} Resource IDs saved to: /tmp/eks-resources-$CLUSTER_NAME.txt"
echo ""
echo -e "${GREEN}✓ Setup Complete!${NC}"
