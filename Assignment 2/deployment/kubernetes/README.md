# Kubernetes Deployment Guide

This directory contains Kubernetes manifests for deploying the MNIST classifier API.

## Files

- `namespace.yaml` - Creates mlops namespace
- `deployment.yaml` - Main application deployment
- `service.yaml` - LoadBalancer service
- `hpa.yaml` - Horizontal Pod Autoscaler
- `configmap.yaml` - Configuration settings

## Prerequisites

- Kubernetes cluster (minikube, kind, Docker Desktop, or cloud provider)
- kubectl configured
- Docker image built and pushed to registry

## Quick Start

### 1. Update Image Reference

Edit `deployment.yaml` and replace `YOUR_USERNAME` with your GitHub username:

```yaml
image: ghcr.io/YOUR_USERNAME/mnist-classifier:latest
```

### 2. Deploy to Kubernetes

```bash
# Apply all manifests
kubectl apply -f deployment/kubernetes/

# Or apply individually
kubectl apply -f deployment/kubernetes/namespace.yaml
kubectl apply -f deployment/kubernetes/configmap.yaml
kubectl apply -f deployment/kubernetes/deployment.yaml
kubectl apply -f deployment/kubernetes/service.yaml
kubectl apply -f deployment/kubernetes/hpa.yaml
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods -l app=mnist-classifier

# Check service
kubectl get svc mnist-service

# Check deployment
kubectl get deployment mnist-deployment

# View logs
kubectl logs -f deployment/mnist-deployment
```

### 4. Access the API

#### For LoadBalancer (Cloud providers)
```bash
# Get external IP
kubectl get svc mnist-service

# Access API
curl http://<EXTERNAL-IP>/health
```

#### For Minikube
```bash
minikube service mnist-service
```

#### For Port Forwarding (Local)
```bash
kubectl port-forward service/mnist-service 8000:80

# Access API
curl http://localhost:8000/health
```

## Testing

```bash
# Health check
curl http://localhost:8000/health

# Prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "image": [[0.0, ...]]  # 28x28 or 784 values
  }'
```

## Monitoring

```bash
# Watch pods
kubectl get pods -l app=mnist-classifier -w

# Describe deployment
kubectl describe deployment mnist-deployment

# View events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check HPA status
kubectl get hpa mnist-hpa
```

## Scaling

### Manual Scaling
```bash
kubectl scale deployment mnist-deployment --replicas=5
```

### Auto-scaling
The HPA is configured to scale between 2-5 replicas based on CPU/memory usage.

## Updating

### Rolling Update
```bash
# Update image
kubectl set image deployment/mnist-deployment \
  mnist-api=ghcr.io/YOUR_USERNAME/mnist-classifier:v2

# Check rollout status
kubectl rollout status deployment/mnist-deployment

# View rollout history
kubectl rollout history deployment/mnist-deployment
```

### Rollback
```bash
# Rollback to previous version
kubectl rollout undo deployment/mnist-deployment

# Rollback to specific revision
kubectl rollout undo deployment/mnist-deployment --to-revision=2
```

## Cleanup

```bash
# Delete all resources
kubectl delete -f deployment/kubernetes/

# Or delete individually
kubectl delete deployment mnist-deployment
kubectl delete service mnist-service
kubectl delete hpa mnist-hpa
kubectl delete configmap mnist-config
```

## Troubleshooting

### Pod not starting
```bash
# Describe pod
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# Get events
kubectl get events --field-selector involvedObject.name=<pod-name>
```

### Service not accessible
```bash
# Check endpoints
kubectl get endpoints mnist-service

# Check service
kubectl describe service mnist-service

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://mnist-service/health
```

### Image pull errors
```bash
# Create image pull secret (if using private registry)
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN

# Reference in deployment
# spec.template.spec.imagePullSecrets:
# - name: regcred
```

## Best Practices

1. **Resource Limits**: Always set resource requests and limits
2. **Health Checks**: Configure liveness and readiness probes
3. **Rolling Updates**: Use rolling update strategy for zero-downtime deployments
4. **Auto-scaling**: Configure HPA for handling variable load
5. **Logging**: Ensure logs are accessible via kubectl logs
6. **Secrets**: Use Kubernetes secrets for sensitive data
7. **Monitoring**: Integrate with Prometheus/Grafana for metrics
