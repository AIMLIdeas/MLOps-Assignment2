#!/bin/bash
# Script to clear old instances and redeploy latest build

set -e

echo "============================================"
echo "Redeployment Script"
echo "============================================"
echo ""

# Step 1: Configure AWS credentials
echo "Step 1: Configuring AWS credentials..."
echo "Please enter your AWS Access Key ID:"
read -r AWS_ACCESS_KEY_ID
echo "Please enter your AWS Secret Access Key:"
read -rs AWS_SECRET_ACCESS_KEY
echo ""

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

# Verify credentials
echo "Verifying AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ Error: Invalid AWS credentials"
    exit 1
fi
echo "✓ AWS credentials verified"
echo ""

# Step 2: Update kubeconfig
echo "Step 2: Configuring kubectl access..."
aws eks update-kubeconfig --region us-east-1 --name mlops-assignment2-cluster
echo "✓ kubectl configured"
echo ""

# Step 3: Check current deployment status
echo "Step 3: Checking current deployment..."
kubectl get pods -n mlops
echo ""
kubectl get deployment cat-dogs-deployment -n mlops -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
echo ""

# Step 4: Delete old pods to force image pull
echo "Step 4: Clearing old instances..."
echo "Restarting deployment to pull latest image..."
kubectl rollout restart deployment/cat-dogs-deployment -n mlops
echo "✓ Deployment restart initiated"
echo ""

# Step 5: Wait for rollout
echo "Step 5: Waiting for new pods to be ready..."
kubectl rollout status deployment/cat-dogs-deployment -n mlops --timeout=5m
echo "✓ Rollout complete"
echo ""

# Step 6: Verify new deployment
echo "Step 6: Verifying new deployment..."
kubectl get pods -n mlops
echo ""

# Step 7: Get pod details
POD_NAME=$(kubectl get pods -n mlops -l app=cat-dogs-classifier -o jsonpath='{.items[0].metadata.name}')
echo "Latest pod: $POD_NAME"
echo ""
echo "Image:"
kubectl get pod "$POD_NAME" -n mlops -o jsonpath='{.spec.containers[0].image}'
echo ""
echo ""
echo "Recent logs:"
kubectl logs "$POD_NAME" -n mlops --tail=20
echo ""

# Step 8: Test health endpoint
echo "Step 8: Testing application health..."
LOADBALANCER=$(kubectl get svc cat-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "LoadBalancer URL: http://$LOADBALANCER"
echo ""
sleep 10  # Wait for service to be fully ready
echo "Health check:"
curl -s "http://$LOADBALANCER/health" | python3 -m json.tool || echo "Health endpoint not ready yet"
echo ""

echo "============================================"
echo "✓ Redeployment Complete!"
echo "============================================"
echo ""
echo "Access the application at:"
echo "http://$LOADBALANCER"
echo ""
echo "To check model status:"
echo "curl http://$LOADBALANCER/health"
