#!/bin/bash
# Complete EKS Deployment after node group is ready
# Run this script once the node group is ACTIVE

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'  
NC='\033[0m'

echo -e "${GREEN}=== Completing MNIST Classifier EKS Deployment ===${NC}\n"

# Check node group status
echo -e "${YELLOW}Checking node group status...${NC}"
STATUS=$(aws eks describe-nodegroup --cluster-name mnist-classifier-cluster --nodegroup-name mnist-ng-1 --region us-east-1 --query 'nodegroup.status' --output text)
echo "Node group status: $STATUS"

if [ "$STATUS" != "ACTIVE" ]; then
    echo -e "${YELLOW}Node group is not ready yet. Current status: $STATUS${NC}"
    echo -e "${YELLOW}Waiting for node group to become ACTIVE...${NC}"
    while [ "$STATUS" != "ACTIVE" ]; do
        sleep 30
        STATUS=$(aws eks describe-nodegroup --cluster-name mnist-classifier-cluster --nodegroup-name mnist-ng-1 --region us-east-1 --query 'nodegroup.status' --output text)
        echo "Status: $STATUS"
    done
fi

echo -e "${GREEN}✓ Node group is ACTIVE${NC}\n"

# Wait for nodes to be ready
echo -e "${YELLOW}Waiting for nodes to be ready...${NC}"
sleep 30
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Show nodes
echo -e "\n${GREEN}Nodes:${NC}"
kubectl get nodes

# Variables
NAMESPACE="mlops"
GITHUB_USERNAME="${GITHUB_USERNAME:-aimlideas}"
GITHUB_PAT="${GITHUB_PAT:-ghp_placeholder}"
GITHUB_EMAIL="${GITHUB_EMAIL:-2024aa05960@wilp.bits-pilani.ac.in}"

# Namespace should already exist from cluster creation
echo -e "\n${YELLOW}Verifying namespace...${NC}"
kubectl get namespace $NAMESPACE || kubectl apply -f deployment/kubernetes/namespace.yaml

# Create GitHub Container Registry secret
echo -e "\n${YELLOW}Creating GitHub Container Registry secret...${NC}"
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USERNAME \
    --docker-password=$GITHUB_PAT \
    --docker-email=$GITHUB_EMAIL \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ GitHub Container Registry secret created${NC}"

# Deploy ConfigMap
echo -e "\n${YELLOW}Deploying ConfigMap...${NC}"
kubectl apply -f deployment/kubernetes/configmap.yaml
echo -e "${GREEN}✓ ConfigMap deployed${NC}"

# Deploy application
echo -e "\n${YELLOW}Deploying MNIST Classifier...${NC}"
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
kubectl wait --for=condition=ready pod -l app=mnist-classifier -n $NAMESPACE --timeout=300s

# Get service endpoint
echo -e "\n${YELLOW}Getting service endpoint...${NC}"
echo -e "${GREEN}Waiting for LoadBalancer to be provisioned (this may take a few minutes)...${NC}"
sleep 60

ENDPOINT=$(kubectl get svc mnist-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$ENDPOINT" ]; then
    ENDPOINT=$(kubectl get svc mnist-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

while [ -z "$ENDPOINT" ]; do
    echo "Waiting for LoadBalancer endpoint..."
    sleep 15
    ENDPOINT=$(kubectl get svc mnist-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$ENDPOINT" ]; then
        ENDPOINT=$(kubectl get svc mnist-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
done

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\n${GREEN}Service Endpoint:${NC} http://$ENDPOINT"
echo -e "\n${YELLOW}Test the service:${NC}"
echo -e "  curl http://$ENDPOINT/health"
echo -e "\n${YELLOW}View logs:${NC}"
echo -e "  kubectl logs -f -l app=mnist-classifier -n $NAMESPACE"
echo -e "\n${YELLOW}View pods:${NC}"
echo -e "  kubectl get pods -n $NAMESPACE"
echo -e "\n${YELLOW}View service:${NC}"
echo -e "  kubectl get svc -n $NAMESPACE"
echo -e "\n${YELLOW}View HPA status:${NC}"
echo -e "  kubectl get hpa -n $NAMESPACE"
