# AWS EKS Deployment Guide

This guide explains how to deploy the MNIST Classifier service to AWS EKS using the GitHub Container Registry image.

## Prerequisites

### 1. Required Tools
All tools are already installed:
- ✅ AWS CLI v2.33.18
- ✅ eksctl v0.222.0
- ✅ kubectl v1.35.0

### 2. AWS Account Setup
- AWS account with appropriate permissions
- IAM user with EKS, EC2, and VPC permissions

### 3. GitHub Credentials
- GitHub Personal Access Token (PAT) with `read:packages` scope
- Access to the repository: ghcr.io/aimlideas/mnist-classifier

## Configuration Steps

### Step 1: Configure AWS Credentials

```bash
aws configure
```

Enter your AWS credentials:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **Default region**: `us-east-1`
- **Default output format**: `json`

Verify configuration:
```bash
aws sts get-caller-identity
```

### Step 2: Set Environment Variables

```bash
export GITHUB_USERNAME="aimlideas"
export GITHUB_PAT="your_github_personal_access_token"
export GITHUB_EMAIL="your_email@example.com"
```

### Step 3: Review Cluster Configuration

Edit `deployment/kubernetes/eks-cluster-config.yaml` if needed:
- Cluster name: `mnist-classifier-cluster`
- Region: `us-east-1`
- Node type: `t3.medium` (2 vCPUs, 4 GB RAM)
- Node count: 2-4 (autoscaling)

## Deployment Options

### Option A: Automated Deployment (Recommended)

Run the deployment script:

```bash
chmod +x deployment/deploy-to-aws.sh
./deployment/deploy-to-aws.sh
```

This script will:
1. ✅ Verify prerequisites
2. ✅ Check AWS credentials
3. ✅ Create EKS cluster (if not exists)
4. ✅ Create namespace
5. ✅ Create GitHub Container Registry secret
6. ✅ Deploy ConfigMap
7. ✅ Deploy application
8. ✅ Deploy service (LoadBalancer)
9. ✅ Deploy HPA (autoscaling)
10. ✅ Display service endpoint

**Estimated time**: 15-20 minutes for cluster creation + 3-5 minutes for deployment

### Option B: Manual Deployment

#### 1. Create EKS Cluster

```bash
eksctl create cluster -f deployment/kubernetes/eks-cluster-config.yaml
```

#### 2. Update kubeconfig

```bash
aws eks update-kubeconfig --name mnist-classifier-cluster --region us-east-1
```

#### 3. Create Namespace

```bash
kubectl apply -f deployment/kubernetes/namespace.yaml
```

#### 4. Create GitHub Container Registry Secret

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_PAT \
  --docker-email=$GITHUB_EMAIL \
  --namespace=mlops
```

#### 5. Deploy Application

```bash
# Deploy ConfigMap
kubectl apply -f deployment/kubernetes/configmap.yaml

# Deploy application
kubectl apply -f deployment/kubernetes/deployment.yaml

# Deploy service
kubectl apply -f deployment/kubernetes/service.yaml

# Deploy HPA
kubectl apply -f deployment/kubernetes/hpa.yaml
```

## Verification

### Check Pod Status

```bash
kubectl get pods -n mlops
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS   AGE
mnist-deployment-xxxxxxxxx-xxxxx    1/1     Running   0          2m
mnist-deployment-xxxxxxxxx-xxxxx    1/1     Running   0          2m
```

### Check Service Status

```bash
kubectl get svc -n mlops
```

Expected output:
```
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)        AGE
mnist-service   LoadBalancer   10.100.xxx.xxx  xxxxx.elb.us-east-1.amazonaws.com   80:xxxxx/TCP   3m
```

### Check HPA Status

```bash
kubectl get hpa -n mlops
```

Expected output:
```
NAME        REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
mnist-hpa   Deployment/mnist-deployment   20%/70%   2         5         2          3m
```

### Test the Service

Get the LoadBalancer endpoint:
```bash
ENDPOINT=$(kubectl get svc mnist-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Service endpoint: http://$ENDPOINT"
```

Test health endpoint:
```bash
curl http://$ENDPOINT/health
```

Expected response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "timestamp": "2026-02-10T..."
}
```

Test prediction endpoint:
```bash
curl -X POST http://$ENDPOINT/predict \
  -H "Content-Type: application/json" \
  -d '{
    "image": [0.0, 0.0, 0.0, ... (784 values) ...]
  }'
```

## Monitoring

### View Logs

```bash
# All pods
kubectl logs -f -l app=mnist-classifier -n mlops

# Specific pod
kubectl logs -f <pod-name> -n mlops
```

### View Metrics

```bash
# Pod metrics
kubectl top pods -n mlops

# Node metrics
kubectl top nodes
```

### View Events

```bash
kubectl get events -n mlops --sort-by='.lastTimestamp'
```

## Scaling

### Manual Scaling

```bash
kubectl scale deployment mnist-deployment --replicas=3 -n mlops
```

### Auto-scaling (HPA)

The HPA is configured to:
- **Min replicas**: 2
- **Max replicas**: 5
- **Triggers**:
  - CPU > 70%
  - Memory > 80%

## Cost Optimization

Current estimated monthly cost (us-east-1):
- **EKS cluster**: ~$73/month (control plane)
- **EC2 instances**: ~$60/month (2 x t3.medium)
- **Load Balancer**: ~$16/month (NLB)
- **EBS volumes**: ~$3/month (30GB x 2)
- **Total**: ~$152/month

To reduce costs:
1. Use spot instances: Add to `eks-cluster-config.yaml`
2. Reduce node count during off-hours
3. Use smaller instance types (t3.small)
4. Delete cluster when not in use

## Cleanup

### Delete Deployment

```bash
kubectl delete -f deployment/kubernetes/ -n mlops
```

### Delete Cluster

```bash
eksctl delete cluster --name mnist-classifier-cluster --region us-east-1
```

**Note**: This will delete all resources including the VPC, subnets, and security groups.

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n mlops

# Check events
kubectl get events -n mlops

# Common issues:
# - Image pull errors: Check ghcr-secret
# - Resource limits: Check node capacity
```

### Image Pull Errors

```bash
# Verify secret exists
kubectl get secret ghcr-secret -n mlops

# Recreate secret
kubectl delete secret ghcr-secret -n mlops
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_PAT \
  --docker-email=$GITHUB_EMAIL \
  --namespace=mlops
```

### LoadBalancer Not Provisioning

```bash
# Check service events
kubectl describe svc mnist-service -n mlops

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer
```

### HPA Not Scaling

```bash
# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Install metrics server if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AWS Cloud                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │              EKS Cluster                          │   │
│  │  ┌────────────────────────────────────────────┐  │   │
│  │  │         mlops namespace                    │  │   │
│  │  │                                            │  │   │
│  │  │  ┌──────────────┐  ┌──────────────┐       │  │   │
│  │  │  │  Pod 1       │  │  Pod 2       │       │  │   │
│  │  │  │  mnist-api   │  │  mnist-api   │       │  │   │
│  │  │  │  (ghcr.io)   │  │  (ghcr.io)   │       │  │   │
│  │  │  └──────────────┘  └──────────────┘       │  │   │
│  │  │         ▲                  ▲               │  │   │
│  │  │         └──────────┬───────┘               │  │   │
│  │  │                    │                       │  │   │
│  │  │            ┌───────▼────────┐              │  │   │
│  │  │            │  Service (LB)  │              │  │   │
│  │  │            └───────┬────────┘              │  │   │
│  │  │                    │                       │  │   │
│  │  └────────────────────┼───────────────────────┘  │   │
│  │                       │                          │   │
│  └───────────────────────┼──────────────────────────┘   │
│                          │                              │
│                  ┌───────▼────────┐                     │
│                  │  Network LB    │                     │
│                  │  (AWS NLB)     │                     │
│                  └───────┬────────┘                     │
└──────────────────────────┼──────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   Internet  │
                    └─────────────┘
```

## Support

For issues or questions:
- Check logs: `kubectl logs -f -l app=mnist-classifier -n mlops`
- Review events: `kubectl get events -n mlops`
- Check AWS EKS documentation: https://docs.aws.amazon.com/eks/
- Check eksctl documentation: https://eksctl.io/

## Next Steps

After successful deployment:
1. Set up continuous deployment (CI/CD)
2. Configure CloudWatch monitoring
3. Set up alerting with SNS
4. Implement blue-green deployment
5. Add Prometheus/Grafana monitoring
6. Configure VPC peering for internal services
7. Set up AWS WAF for security
8. Enable pod security policies
9. Implement network policies
10. Set up backup and disaster recovery
