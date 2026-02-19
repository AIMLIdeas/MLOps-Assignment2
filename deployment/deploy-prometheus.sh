#!/bin/bash

# Deploy Prometheus to AWS EKS
# This script deploys Prometheus for monitoring the cats-dogs classifier API

set -e

echo "=========================================="
echo "Prometheus Deployment to AWS EKS"
echo "=========================================="
echo ""

# Configuration
NAMESPACE="mlops"
REGION="us-east-1"
CLUSTER_NAME="mlops-eks-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is configured
echo "Checking kubectl configuration..."
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured or cannot connect to cluster${NC}"
    echo "Run: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
    exit 1
fi

echo -e "${GREEN}✓ kubectl configured${NC}"

# Check if namespace exists
echo ""
echo "Checking namespace..."
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}Namespace $NAMESPACE does not exist. Creating...${NC}"
    kubectl create namespace $NAMESPACE
else
    echo -e "${GREEN}✓ Namespace $NAMESPACE exists${NC}"
fi

# Deploy Prometheus
echo ""
echo "Deploying Prometheus..."
kubectl apply -f deployment/kubernetes/prometheus-deployment.yaml

# Wait for deployment
echo ""
echo "Waiting for Prometheus deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $NAMESPACE

# Wait for service to get LoadBalancer IP
echo ""
echo "Waiting for LoadBalancer to be provisioned (this may take 2-3 minutes)..."
while true; do
    LB_HOSTNAME=$(kubectl get svc prometheus -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$LB_HOSTNAME" ]; then
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo ""
echo -e "${GREEN}=========================================="
echo "Prometheus Deployed Successfully!"
echo "==========================================${NC}"
echo ""
echo "Prometheus URL: http://${LB_HOSTNAME}:9090"
echo ""
echo "Quick checks:"
echo "  1. View Prometheus UI: http://${LB_HOSTNAME}:9090"
echo "  2. Check targets: http://${LB_HOSTNAME}:9090/targets"
echo "  3. Run a query: http://${LB_HOSTNAME}:9090/graph"
echo ""
echo "Useful commands:"
echo "  - View Prometheus logs:"
echo "    kubectl logs -n $NAMESPACE deployment/prometheus --tail=50 -f"
echo ""
echo "  - Check Prometheus pod status:"
echo "    kubectl get pods -n $NAMESPACE -l app=prometheus"
echo ""
echo "  - Port forward locally (optional):"
echo "    kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090"
echo ""
echo "Sample Prometheus queries to try:"
echo "  - Total API requests: sum(api_requests_total)"
echo "  - Request rate: rate(api_requests_total[5m])"
echo "  - P95 latency: histogram_quantile(0.95, rate(api_request_latency_seconds_bucket[5m]))"
echo "  - Predictions by class: predictions_total"
echo ""
echo -e "${YELLOW}Note: It may take a few minutes for metrics to start appearing.${NC}"
echo ""
echo "Generate some traffic to see metrics:"
echo "  API_URL=\"http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com\""
echo "  curl \$API_URL/health"
echo "  curl \$API_URL/metrics"
echo ""
echo "For more information, see: deployment/PROMETHEUS_AWS_INTEGRATION.md"
echo ""
