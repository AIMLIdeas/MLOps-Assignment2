#!/bin/bash
# Deploy Cats vs Dogs Classifier to AWS EKS
# This script deploys the Cats vs Dogs classifier service to AWS EKS using the GitHub Container Registry image

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Cats vs Dogs Classifier AWS EKS Deployment ===${NC}\n"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: aws CLI is not installed${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is not installed${NC}" >&2; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo -e "${RED}Error: eksctl is not installed${NC}" >&2; exit 1; }

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
aws sts get-caller-identity >/dev/null 2>&1 || { echo -e "${RED}Error: AWS credentials not configured. Run 'aws configure'${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ AWS credentials configured${NC}\n"

# Variables
CLUSTER_NAME="cats-dogs-classifier-cluster"
REGION="us-east-1"
NAMESPACE="mlops"
GITHUB_USERNAME="${GITHUB_USERNAME:-aimlideas}"
GITHUB_PAT="${GITHUB_PAT:-}"

# Check if cluster exists
echo -e "${YELLOW}Checking if EKS cluster exists...${NC}"
if eksctl get cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Cluster $CLUSTER_NAME already exists${NC}"
else
    echo -e "${YELLOW}Creating EKS cluster (this may take 15-20 minutes)...${NC}"
    eksctl create cluster -f deployment/kubernetes/eks-cluster-config.yaml
    echo -e "${GREEN}✓ Cluster created successfully${NC}"
fi

# Update kubeconfig
echo -e "\n${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
echo -e "${GREEN}✓ Kubeconfig updated${NC}"

# Create namespace
echo -e "\n${YELLOW}Creating namespace...${NC}"
kubectl apply -f deployment/kubernetes/namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}"

# Create GitHub Container Registry secret
echo -e "\n${YELLOW}Creating GitHub Container Registry secret...${NC}"
if [ -z "$GITHUB_PAT" ]; then
    echo -e "${RED}Error: GITHUB_PAT environment variable not set${NC}"
    echo -e "${YELLOW}Please set it with your GitHub Personal Access Token:${NC}"
    echo -e "  export GITHUB_PAT='your_github_pat_here'"
    echo -e "\nOr create the secret manually:"
    echo -e "  kubectl create secret docker-registry ghcr-secret \\"
    echo -e "    --docker-server=ghcr.io \\"
    echo -e "    --docker-username=YOUR_GITHUB_USERNAME \\"
    echo -e "    --docker-password=YOUR_GITHUB_PAT \\"
    echo -e "    --docker-email=YOUR_EMAIL \\"
    echo -e "    --namespace=$NAMESPACE"
    exit 1
fi

kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USERNAME \
    --docker-password=$GITHUB_PAT \
    --docker-email=${GITHUB_EMAIL:-user@example.com} \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ GitHub Container Registry secret created${NC}"

# Deploy ConfigMap
echo -e "\n${YELLOW}Deploying ConfigMap...${NC}"
kubectl apply -f deployment/kubernetes/configmap.yaml
echo -e "${GREEN}✓ ConfigMap deployed${NC}"

# Deploy application
echo -e "\n${YELLOW}Deploying Cats vs Dogs Classifier...${NC}"
kubectl apply -f deployment/kubernetes/deployment.yaml
echo -e "${GREEN}✓ Deployment created${NC}"

# Deploy service
echo -e "\n${YELLOW}Deploying Service...${NC}"
kubectl apply -f deployment/kubernetes/service.yaml
echo -e "${GREEN}✓ Service created${NC}"

# Deploy HPA
echo -e "\n${YELLOW}Deploying Horizontal Pod Autoscaler...${NC}"
kubectl apply -f deployment/kubernetes/hpa.yaml
echo -e "${GREEN}✓ HPA deployed${NC}"

# Wait for pods to be ready
echo -e "\n${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=cats-dogs-classifier -n $NAMESPACE --timeout=300s

# Get service endpoint
echo -e "\n${YELLOW}Getting service endpoint...${NC}"
echo -e "${GREEN}Waiting for LoadBalancer to be provisioned (this may take a few minutes)...${NC}"
kubectl get svc cats-dogs-service -n $NAMESPACE -w &
WATCH_PID=$!
sleep 60
kill $WATCH_PID 2>/dev/null || true

ENDPOINT=$(kubectl get svc cats-dogs-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$ENDPOINT" ]; then
    ENDPOINT=$(kubectl get svc cats-dogs-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\n${GREEN}Service Endpoint:${NC} http://$ENDPOINT"
echo -e "\n${YELLOW}Test the service:${NC}"
echo -e "  curl http://$ENDPOINT/health"
echo -e "\n${YELLOW}View logs:${NC}"
echo -e "  kubectl logs -f -l app=cats-dogs-classifier -n $NAMESPACE"
echo -e "\n${YELLOW}View pods:${NC}"
echo -e "  kubectl get pods -n $NAMESPACE"
echo -e "\n${YELLOW}View service:${NC}"
echo -e "  kubectl get svc -n $NAMESPACE"
echo -e "\n${YELLOW}View HPA status:${NC}"
echo -e "  kubectl get hpa -n $NAMESPACE"
echo -e "\n${YELLOW}Delete deployment:${NC}"
echo -e "  kubectl delete -f deployment/kubernetes/ -n $NAMESPACE"
echo -e "\n${YELLOW}Delete cluster:${NC}"
echo -e "  eksctl delete cluster --name $CLUSTER_NAME --region $REGION"
