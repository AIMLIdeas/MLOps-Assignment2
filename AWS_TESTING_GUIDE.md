# Testing Your Application on AWS EKS

Complete guide to test your cats-dogs classifier running on AWS EKS.

---

## Prerequisites

Before testing, ensure:
1. ✅ EKS cluster is created: `mlops-assignment2-cluster`
2. ✅ Application is deployed (via GitHub Actions or manual deployment)
3. ✅ kubectl is configured: `aws eks update-kubeconfig --name mlops-assignment2-cluster --region us-east-1`

---

## Step 1: Get the LoadBalancer URL

### Method 1: Via kubectl
```bash
# Get the LoadBalancer URL
kubectl get svc cat-dogs-service -n mlops

# Extract just the URL
LOADBALANCER_URL=$(kubectl get svc cat-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$LOADBALANCER_URL"
```

**Example Output:**
```
NAME                TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
cat-dogs-service    LoadBalancer   10.100.45.123   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6-123456789.us-east-1.elb.amazonaws.com   80:31234/TCP   5m
```

### Method 2: Via GitHub Actions
Check the GitHub Actions summary:
```
https://github.com/AIMLIdeas/MLOps-Assignment2/actions
```
The LoadBalancer URL will be displayed in the deployment summary.

---

## Step 2: Test Health Endpoint

### Basic Health Check
```bash
# Set the URL (replace with your actual LoadBalancer URL)
export API_URL="http://a1b2c3d4-123456789.us-east-1.elb.amazonaws.com"

# Test health endpoint
curl $API_URL/health
```

**Expected Response:**
```json
{"status": "healthy", "model": "loaded"}
```

### Verbose Health Check
```bash
# Get detailed response with headers
curl -v $API_URL/health
```

### Check Response Time
```bash
# Measure response time
time curl $API_URL/health
```

---

## Step 3: Test Root Endpoint

```bash
# Test the root endpoint
curl $API_URL/

# In browser, navigate to:
# http://<your-loadbalancer-url>/
```

**Expected:** HTML page with API documentation and upload form

---

## Step 4: Test Image Prediction (API)

### Test with Sample Image URL
```bash
# Test prediction with a cat image
curl -X POST "$API_URL/predict" \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"}'
```

**Expected Response:**
```json
{
  "prediction": "cat",
  "confidence": 0.9876,
  "model_version": "v1.0"
}
```

### Test with Local Image Upload
```bash
# Download a test image
curl -o test_cat.jpg "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400"

# Upload and predict
curl -X POST "$API_URL/predict" \
  -F "file=@test_cat.jpg"
```

### Test with Dog Image
```bash
# Test with a dog image
curl -X POST "$API_URL/predict" \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://images.unsplash.com/photo-1543466835-00a7907e9de1"}'
```

---

## Step 5: Monitor Application Logs

### View Real-Time Logs
```bash
# Stream logs from all pods
kubectl logs -f -l app=cat-dogs-classifier -n mlops

# Tail last 50 lines
kubectl logs -l app=cat-dogs-classifier -n mlops --tail=50

# Follow logs from a specific pod
POD_NAME=$(kubectl get pods -n mlops -l app=cat-dogs-classifier -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f $POD_NAME -n mlops
```

### Check for Errors
```bash
# Search for errors in logs
kubectl logs -l app=cat-dogs-classifier -n mlops --tail=100 | grep -i error

# Search for warnings
kubectl logs -l app=cat-dogs-classifier -n mlops --tail=100 | grep -i warning
```

---

## Step 6: Check Pod and Service Status

### Check Pods
```bash
# View all pods in mlops namespace
kubectl get pods -n mlops

# Get detailed pod information
kubectl get pods -n mlops -o wide

# Describe a specific pod (for troubleshooting)
kubectl describe pod <pod-name> -n mlops
```

**Expected Output:**
```
NAME                                   READY   STATUS    RESTARTS   AGE
cat-dogs-deployment-7d8f9c5b4-abc12   1/1     Running   0          10m
cat-dogs-deployment-7d8f9c5b4-def34   1/1     Running   0          10m
```

### Check Service
```bash
# View service details
kubectl get svc -n mlops

# Describe service (includes LoadBalancer details)
kubectl describe svc cat-dogs-service -n mlops
```

### Check Endpoints
```bash
# Verify service endpoints (should show pod IPs)
kubectl get endpoints cat-dogs-service -n mlops
```

---

## Step 7: Test Auto-Scaling

### Check Current HPA Status
```bash
# View Horizontal Pod Autoscaler
kubectl get hpa -n mlops

# Detailed HPA information
kubectl describe hpa cat-dogs-hpa -n mlops
```

**Expected Output:**
```
NAME             REFERENCE                        TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
cat-dogs-hpa     Deployment/cat-dogs-deployment   20%/70%   2         4         2          15m
```

### Simulate Load (Trigger Auto-Scaling)
```bash
# Install Apache Bench (if not installed)
# macOS: brew install apache-bench
# Linux: sudo apt-get install apache2-utils

# Generate load (1000 requests, 10 concurrent)
ab -n 1000 -c 10 $API_URL/health

# Or use a loop
for i in {1..100}; do
  curl -s $API_URL/health > /dev/null &
done

# Watch HPA scale up
watch kubectl get hpa -n mlops
watch kubectl get pods -n mlops
```

---

## Step 8: Performance Testing

### Simple Load Test
```bash
# Test with 100 concurrent requests
for i in {1..100}; do
  curl -X POST "$API_URL/predict" \
    -H "Content-Type: application/json" \
    -d '{"image_url": "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"}' &
done
wait

echo "Load test complete"
```

### Measure Response Times
```bash
# Test response time with multiple requests
for i in {1..10}; do
  echo "Request $i:"
  time curl -s $API_URL/health > /dev/null
done
```

### Apache Bench Load Test
```bash
# 1000 requests, 50 concurrent users
ab -n 1000 -c 50 -p payload.json -T application/json $API_URL/predict

# Where payload.json contains:
# {"image_url": "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"}
```

---

## Step 9: Test from Different Locations

### Test from Local Machine
```bash
curl $API_URL/health
```

### Test from Another EC2 Instance
```bash
# SSH into an EC2 instance in the same region
ssh ec2-user@<ec2-ip>

# Test from there
curl http://<loadbalancer-url>/health
```

### Test from Browser
Open in your browser:
```
http://<loadbalancer-url>/
http://<loadbalancer-url>/health
```

---

## Step 10: Verify Kubernetes Features

### Test Rolling Updates (Zero Downtime)
```bash
# Scale deployment
kubectl scale deployment cat-dogs-deployment -n mlops --replicas=3

# Watch pods update
watch kubectl get pods -n mlops

# Update image (simulating new deployment)
kubectl set image deployment/cat-dogs-deployment cat-dogs-api=ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:latest -n mlops

# Monitor rollout
kubectl rollout status deployment/cat-dogs-deployment -n mlops

# Should show rolling update without downtime
```

### Test Pod Resilience
```bash
# Delete a pod (Kubernetes will recreate it)
POD_NAME=$(kubectl get pods -n mlops -l app=cat-dogs-classifier -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_NAME -n mlops

# Watch new pod being created
watch kubectl get pods -n mlops

# Application should remain accessible during pod recreation
curl $API_URL/health
```

---

## Complete Test Script

Save this as `test-aws-deployment.sh`:

```bash
#!/bin/bash

echo "======================================"
echo "Testing AWS EKS Deployment"
echo "======================================"
echo ""

# Get LoadBalancer URL
echo "1. Getting LoadBalancer URL..."
LOADBALANCER_URL=$(kubectl get svc cat-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LOADBALANCER_URL" ]; then
    echo "❌ Error: LoadBalancer URL not found"
    echo "   Make sure the application is deployed"
    exit 1
fi

API_URL="http://$LOADBALANCER_URL"
echo "✅ API URL: $API_URL"
echo ""

# Test health endpoint
echo "2. Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$API_URL/health")
if [ $? -eq 0 ]; then
    echo "✅ Health check passed"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo "❌ Health check failed"
    exit 1
fi
echo ""

# Test root endpoint
echo "3. Testing root endpoint..."
ROOT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/")
if [ "$ROOT_RESPONSE" = "200" ]; then
    echo "✅ Root endpoint accessible (HTTP $ROOT_RESPONSE)"
else
    echo "⚠️  Root endpoint returned HTTP $ROOT_RESPONSE"
fi
echo ""

# Test prediction endpoint
echo "4. Testing prediction endpoint..."
PREDICT_RESPONSE=$(curl -s -X POST "$API_URL/predict" \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"}')

if [ $? -eq 0 ] && [[ $PREDICT_RESPONSE == *"prediction"* ]]; then
    echo "✅ Prediction endpoint working"
    echo "   Response: $PREDICT_RESPONSE"
else
    echo "❌ Prediction endpoint failed"
    echo "   Response: $PREDICT_RESPONSE"
fi
echo ""

# Check pod status
echo "5. Checking pod status..."
POD_STATUS=$(kubectl get pods -n mlops -l app=cat-dogs-classifier --no-headers)
echo "$POD_STATUS"

RUNNING_PODS=$(echo "$POD_STATUS" | grep -c "Running")
echo "✅ Running pods: $RUNNING_PODS"
echo ""

# Check HPA status
echo "6. Checking auto-scaling..."
HPA_STATUS=$(kubectl get hpa -n mlops --no-headers)
echo "$HPA_STATUS"
echo ""

# Performance test
echo "7. Running performance test (10 requests)..."
TOTAL_TIME=0
for i in {1..10}; do
    START=$(date +%s.%N)
    curl -s "$API_URL/health" > /dev/null
    END=$(date +%s.%N)
    TIME=$(echo "$END - $START" | bc)
    TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc)
done
AVG_TIME=$(echo "scale=3; $TOTAL_TIME / 10" | bc)
echo "✅ Average response time: ${AVG_TIME}s"
echo ""

echo "======================================"
echo "✅ All tests completed!"
echo "======================================"
echo ""
echo "Application URL: $API_URL"
echo "Test the web interface: $API_URL/"
```

Make it executable and run:
```bash
chmod +x test-aws-deployment.sh
./test-aws-deployment.sh
```

---

## Troubleshooting

### Issue: LoadBalancer URL Not Available
```bash
# Check if LoadBalancer is being created
kubectl describe svc cat-dogs-service -n mlops

# Check AWS ELB console
# https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#LoadBalancers
```

### Issue: Connection Timeout
```bash
# Check security group allows port 80
aws ec2 describe-security-groups --region us-east-1

# Check pod logs for errors
kubectl logs -l app=cat-dogs-classifier -n mlops --tail=100
```

### Issue: 503 Service Unavailable
```bash
# Check if pods are ready
kubectl get pods -n mlops

# Check pod events
kubectl get events -n mlops --sort-by='.lastTimestamp'

# Describe deployment
kubectl describe deployment cat-dogs-deployment -n mlops
```

### Issue: ImagePullBackOff
```bash
# Check if GHCR secret exists
kubectl get secret ghcr-secret -n mlops

# Recreate secret if needed (done automatically by CD workflow)
```

---

## Monitoring Commands

### Quick Status Check
```bash
# One-liner to check everything
echo "Pods:" && kubectl get pods -n mlops && \
echo "" && echo "Service:" && kubectl get svc -n mlops && \
echo "" && echo "HPA:" && kubectl get hpa -n mlops && \
echo "" && echo "Recent Events:" && kubectl get events -n mlops --sort-by='.lastTimestamp' | tail -5
```

### Watch Resources
```bash
# Watch pods in real-time
watch kubectl get pods -n mlops

# Watch HPA scaling
watch kubectl get hpa -n mlops

# Watch logs continuously
kubectl logs -f -l app=cat-dogs-classifier -n mlops
```

---

## AWS Console Verification

### Check EKS Cluster
```
https://console.aws.amazon.com/eks/home?region=us-east-1#/clusters/mlops-assignment2-cluster
```

### Check Load Balancers
```
https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#LoadBalancers
```

### Check EC2 Instances (EKS Nodes)
```
https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances
```

### Check CloudWatch Logs
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups
```

---

## Expected Test Results

### ✅ Successful Deployment:
- Health endpoint returns 200 OK
- Prediction endpoint returns JSON with prediction
- 2-4 pods running
- LoadBalancer has external URL
- Response time < 1 second
- HPA shows current CPU usage

### ⚠️ Common Issues:
- LoadBalancer pending: Wait 2-3 minutes for AWS to provision
- Pods not ready: Check logs for errors
- ImagePullBackOff: Authentication issue (fixed in latest workflow)
- High response time: Increase resources or number of pods

---

## Cleanup (When Done Testing)

```bash
# Delete the application (keeps cluster)
kubectl delete namespace mlops

# Or delete everything including cluster
./scripts/delete-eks-cluster.sh mlops-assignment2-cluster us-east-1 eksctl
```

---

## Summary

**Basic Test (30 seconds):**
```bash
kubectl get svc -n mlops  # Get URL
curl http://<loadbalancer-url>/health  # Test health
curl -X POST http://<loadbalancer-url>/predict -H "Content-Type: application/json" -d '{"image_url":"https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"}'  # Test prediction
```

**Full Test (5 minutes):**
```bash
./test-aws-deployment.sh  # Run complete test suite
```

Your application is production-ready on AWS! 🚀
