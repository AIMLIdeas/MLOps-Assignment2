#!/bin/bash

################################################################################
# EKS Cluster Deletion Script
# 
# This script deletes an EKS cluster and all associated resources
# 
# Usage:
#   ./delete-eks-cluster.sh [cluster-name] [region] [method]
#
# Methods:
#   eksctl  - Delete cluster created with eksctl (default)
#   awscli  - Delete cluster created with pure AWS CLI
#
# Example:
#   ./delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 eksctl
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
METHOD="${3:-eksctl}"

echo -e "${RED}================================================${NC}"
echo -e "${RED}  EKS Cluster Deletion${NC}"
echo -e "${RED}================================================${NC}"
echo ""
echo -e "${YELLOW}⚠ WARNING: This will delete the following:${NC}"
echo "  - EKS Cluster: $CLUSTER_NAME"
echo "  - All node groups"
echo "  - Associated VPC and networking resources"
echo "  - LoadBalancers and EBS volumes"
echo ""
read -p "Are you sure you want to delete? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Deletion cancelled${NC}"
    exit 0
fi

echo ""

################################################################################
# Delete using eksctl
################################################################################

if [ "$METHOD" = "eksctl" ]; then
    echo -e "${BLUE}Deleting cluster using eksctl...${NC}"
    echo -e "${YELLOW}⚠ This will take 10-15 minutes...${NC}"
    
    if command -v eksctl &> /dev/null; then
        eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" --wait
        echo -e "${GREEN}✓${NC} Cluster deleted successfully"
    else
        echo -e "${RED}ERROR: eksctl not installed${NC}"
        echo "Install eksctl or use: $0 $CLUSTER_NAME $REGION awscli"
        exit 1
    fi
    exit 0
fi

################################################################################
# Delete using AWS CLI
################################################################################

if [ "$METHOD" = "awscli" ]; then
    echo -e "${BLUE}Deleting cluster using AWS CLI...${NC}"
    
    # Load resource IDs if available
    if [ -f "/tmp/eks-resources-$CLUSTER_NAME.txt" ]; then
        echo -e "${YELLOW}Loading resource IDs from file...${NC}"
        source /tmp/eks-resources-$CLUSTER_NAME.txt
    fi
    
    # Step 1: Delete node groups
    echo -e "${BLUE}Step 1: Deleting node groups...${NC}"
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --query 'nodegroups' --output text 2>/dev/null || echo "")
    
    if [ -n "$NODE_GROUPS" ]; then
        for NG in $NODE_GROUPS; do
            echo "  Deleting node group: $NG"
            aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NG" --region "$REGION"
        done
        
        # Wait for node groups to be deleted
        for NG in $NODE_GROUPS; do
            echo "  Waiting for $NG to be deleted..."
            aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NG" --region "$REGION"
        done
        echo -e "${GREEN}✓${NC} Node groups deleted"
    else
        echo -e "${YELLOW}No node groups found${NC}"
    fi
    echo ""
    
    # Step 2: Delete EKS cluster
    echo -e "${BLUE}Step 2: Deleting EKS cluster...${NC}"
    if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &> /dev/null; then
        aws eks delete-cluster --name "$CLUSTER_NAME" --region "$REGION"
        echo "  Waiting for cluster to be deleted..."
        aws eks wait cluster-deleted --name "$CLUSTER_NAME" --region "$REGION"
        echo -e "${GREEN}✓${NC} EKS cluster deleted"
    else
        echo -e "${YELLOW}Cluster not found${NC}"
    fi
    echo ""
    
    # Step 3: Delete VPC and networking (if resource IDs are available)
    if [ -n "${VPC_ID:-}" ]; then
        echo -e "${BLUE}Step 3: Cleaning up VPC and networking...${NC}"
        
        # Delete NAT Gateway
        if [ -n "${NAT_GW_ID:-}" ]; then
            echo "  Deleting NAT Gateway..."
            aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW_ID" --region "$REGION" || true
            sleep 30  # Wait for NAT Gateway to start deleting
        fi
        
        # Detach and delete Internet Gateway
        if [ -n "${IGW_ID:-}" ]; then
            echo "  Detaching and deleting Internet Gateway..."
            aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION" || true
            aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$REGION" || true
        fi
        
        # Release Elastic IP
        EIP_ALLOC=$(aws ec2 describe-addresses --region "$REGION" --filters "Name=tag:Name,Values=$CLUSTER_NAME-nat-eip" --query 'Addresses[0].AllocationId' --output text 2>/dev/null || echo "")
        if [ -n "$EIP_ALLOC" ] && [ "$EIP_ALLOC" != "None" ]; then
            echo "  Releasing Elastic IP..."
            aws ec2 release-address --allocation-id "$EIP_ALLOC" --region "$REGION" || true
        fi
        
        # Delete subnets
        echo "  Deleting subnets..."
        SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --query 'Subnets[].SubnetId' --output text)
        for SUBNET in $SUBNETS; do
            aws ec2 delete-subnet --subnet-id "$SUBNET" --region "$REGION" || true
        done
        
        # Delete route tables
        echo "  Deleting route tables..."
        ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
        for RT in $ROUTE_TABLES; do
            aws ec2 delete-route-table --route-table-id "$RT" --region "$REGION" || true
        done
        
        # Delete VPC
        echo "  Deleting VPC..."
        sleep 10  # Wait for dependencies to be removed
        aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" || true
        
        echo -e "${GREEN}✓${NC} VPC and networking cleaned up"
    else
        echo -e "${YELLOW}Step 3: No VPC resource IDs found, skipping VPC cleanup${NC}"
        echo "  You may need to manually delete the VPC from AWS Console"
    fi
    echo ""
    
    # Step 4: Delete IAM roles
    echo -e "${BLUE}Step 4: Deleting IAM roles...${NC}"
    
    CLUSTER_ROLE_NAME="${CLUSTER_ROLE_NAME:-$CLUSTER_NAME-cluster-role}"
    NODE_ROLE_NAME="${NODE_ROLE_NAME:-$CLUSTER_NAME-node-role}"
    
    # Delete cluster role
    if aws iam get-role --role-name "$CLUSTER_ROLE_NAME" &> /dev/null; then
        echo "  Detaching policies from cluster role..."
        aws iam detach-role-policy --role-name "$CLUSTER_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy || true
        aws iam detach-role-policy --role-name "$CLUSTER_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController || true
        echo "  Deleting cluster role..."
        aws iam delete-role --role-name "$CLUSTER_ROLE_NAME" || true
    fi
    
    # Delete node role
    if aws iam get-role --role-name "$NODE_ROLE_NAME" &> /dev/null; then
        echo "  Detaching policies from node role..."
        aws iam detach-role-policy --role-name "$NODE_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy || true
        aws iam detach-role-policy --role-name "$NODE_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy || true
        aws iam detach-role-policy --role-name "$NODE_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true
        echo "  Deleting node role..."
        aws iam delete-role --role-name "$NODE_ROLE_NAME" || true
    fi
    
    echo -e "${GREEN}✓${NC} IAM roles deleted"
    echo ""
    
    # Clean up resource file
    if [ -f "/tmp/eks-resources-$CLUSTER_NAME.txt" ]; then
        rm -f "/tmp/eks-resources-$CLUSTER_NAME.txt"
    fi
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Deletion Complete${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}✓${NC} EKS cluster '$CLUSTER_NAME' has been deleted"
echo ""
echo -e "${YELLOW}Note:${NC} Some AWS resources may take a few minutes to fully delete"
echo "      Check the AWS Console to verify all resources are removed"
echo ""
