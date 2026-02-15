# Complete Setup Guide - MLOps Assignment 2

This guide walks through setting up and running the complete MLOps pipeline from scratch.

## Prerequisites

Before starting, ensure you have:

- **Python 3.9+** installed
- **Docker** installed and running
- **Git** installed
- **kubectl** (for Kubernetes deployment)
- A **GitHub account** (for CI/CD)

## Step-by-Step Setup

### 1. Initial Setup

```bash
# Navigate to project directory
cd "Assignment 2"

# Run setup script
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This will:
- Create virtual environment
- Install dependencies
- Initialize Git and DVC
- Create necessary directories

### 2. Train the Model (M1)

```bash
# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Train the model with MLflow tracking
python src/model.py
```

**Expected Output:**
- Training progress for 5 epochs
- Final accuracy ~98%
- Model saved to `models/mnist_cnn_model.pt`
- MLflow artifacts in `mlruns/`

**View MLflow UI:**
```bash
mlflow ui
# Open http://localhost:5000 in browser
```

### 3. Version Data with DVC (M1)

```bash
# Add data to DVC tracking
dvc add data/raw

# Commit to Git
git add data/raw.dvc .gitignore
git commit -m "Track MNIST dataset with DVC"

# Optional: Setup remote storage
# dvc remote add -d myremote s3://mybucket/dvcstore
# dvc push
```

### 4. Test the API Locally (M2)

```bash
# Start the FastAPI server
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

**Test endpoints:**

```bash
# Health check
curl http://localhost:8000/health

# Prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d @sample_requests.json

# Metrics
curl http://localhost:8000/metrics

# API documentation
# Open http://localhost:8000/docs in browser
```

### 5. Run Unit Tests (M3)

```bash
# Run all tests
pytest tests/ -v

# Run specific test file
pytest tests/test_preprocessing.py -v

# Run with coverage
pytest tests/ --cov=src --cov=api --cov-report=html

# View coverage report
open htmlcov/index.html
```

### 6. Build and Run Docker Container (M2)

```bash
# Quick method using script
./scripts/run_docker.sh

# Or manual method
docker build -t mnist-classifier:latest .
docker run -d -p 8000:8000 --name mnist-api mnist-classifier:latest

# Test Docker container
./scripts/smoke_test.sh

# View logs
docker logs -f mnist-api

# Stop container
docker stop mnist-api
docker rm mnist-api
```

### 7. Run with Docker Compose

```bash
# Start services (API + Prometheus)
docker-compose -f deployment/docker-compose.yml up -d

# View logs
docker-compose -f deployment/docker-compose.yml logs -f

# Check services
docker-compose -f deployment/docker-compose.yml ps

# Stop services
docker-compose -f deployment/docker-compose.yml down
```

### 8. Setup CI/CD Pipeline (M3, M4)

#### Configure GitHub Repository

1. **Create GitHub repository:**
   ```bash
   # Create repo on GitHub, then:
   git remote add origin https://github.com/YOUR_USERNAME/mlops-assignment2.git
   git branch -M main
   git push -u origin main
   ```

2. **Setup Container Registry:**
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Create token with `write:packages` permission
   - Token is automatically used by GitHub Actions

3. **Configure Secrets (if needed):**
   - Go to repository Settings → Secrets and variables → Actions
   - Add `KUBE_CONFIG` if deploying to Kubernetes

#### Trigger CI Pipeline

```bash
# Any push to main branch triggers CI
git add .
git commit -m "Update model configuration"
git push origin main

# View pipeline at: https://github.com/YOUR_USERNAME/REPO_NAME/actions
```

**CI Pipeline will:**
1. Run unit tests
2. Check code with linting
3. Build Docker image
4. Push to GitHub Container Registry

### 9. Deploy to Kubernetes (M4)

#### Option A: Local Kubernetes (Minikube/Docker Desktop)

```bash
# Enable Kubernetes in Docker Desktop or start Minikube
minikube start  # If using Minikube

# Update image reference in deployment.yaml
# Replace YOUR_USERNAME with your GitHub username

# Apply manifests
kubectl apply -f deployment/kubernetes/

# Check deployment
kubectl get pods
kubectl get svc

# Port forward to access locally
kubectl port-forward service/mnist-service 8000:80

# Test deployment
curl http://localhost:8000/health
```

#### Option B: Cloud Kubernetes (GKE, EKS, AKS)

```bash
# Configure kubectl for your cluster
# For GKE:
# gcloud container clusters get-credentials CLUSTER_NAME

# Apply manifests
kubectl apply -f deployment/kubernetes/

# Get external IP
kubectl get svc mnist-service

# Test deployment
curl http://EXTERNAL_IP/health
```

### 10. Run Smoke Tests (M4)

```bash
# Test local deployment
API_URL=http://localhost:8000 ./scripts/smoke_test.sh

# Test Kubernetes deployment
API_URL=http://$(kubectl get svc mnist-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}') \
  ./scripts/smoke_test.sh
```

### 11. Monitor Performance (M5)

#### View Logs

```bash
# Docker
docker logs mnist-api

# Kubernetes
kubectl logs -f deployment/mnist-deployment

# View prediction logs
cat logs/predictions.jsonl
```

#### Check Metrics

```bash
# Prometheus metrics
curl http://localhost:8000/metrics

# API statistics
curl http://localhost:8000/stats
```

#### Evaluate Model Performance

```bash
# Run performance evaluation
python scripts/evaluate_performance.py --num-samples 1000

# View results
cat logs/performance/performance_*.json

# View performance history
cat logs/performance/performance_history.jsonl
```

## Verification Checklist

### M1: Model Development & Experiment Tracking
- [ ] Git repository initialized
- [ ] DVC initialized and tracking data
- [ ] Model trained and saved (models/mnist_cnn_model.pt)
- [ ] MLflow tracking runs visible (mlflow ui)
- [ ] Model accuracy > 95%

### M2: Model Packaging & Containerization
- [ ] FastAPI service running
- [ ] Health endpoint returns 200
- [ ] Prediction endpoint works
- [ ] Docker image builds successfully
- [ ] Container runs and serves predictions
- [ ] requirements.txt has pinned versions

### M3: CI Pipeline
- [ ] Unit tests pass locally (pytest)
- [ ] GitHub Actions CI workflow exists
- [ ] CI runs on push/PR
- [ ] Tests run in CI
- [ ] Docker image builds in CI
- [ ] Image pushed to registry

### M4: CD Pipeline & Deployment
- [ ] Kubernetes manifests exist
- [ ] Deployment successful
- [ ] Service accessible
- [ ] Smoke tests pass
- [ ] CD pipeline configured
- [ ] Rollback mechanism in place

### M5: Monitoring & Logging
- [ ] Request/response logging works
- [ ] Prediction logs saved
- [ ] Metrics endpoint accessible
- [ ] Performance evaluation script works
- [ ] Latency tracking functional

## Troubleshooting

### Model not found error
```bash
# Ensure model is trained
python src/model.py

# Check model file exists
ls -lh models/mnist_cnn_model.pt
```

### Import errors
```bash
# Reinstall dependencies
pip install -r requirements.txt

# Check Python path
python -c "import sys; print(sys.path)"
```

### Docker issues
```bash
# Check Docker is running
docker ps

# View build logs
docker build -t mnist-classifier:latest . --no-cache

# Check container logs
docker logs mnist-api
```

### Kubernetes issues
```bash
# Check pod status
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.metadata.creationTimestamp'
```

## Additional Resources

- **API Documentation**: http://localhost:8000/docs
- **MLflow UI**: http://localhost:5000
- **Prometheus**: http://localhost:9090 (if using docker-compose)
- **GitHub Actions**: https://github.com/YOUR_USERNAME/REPO_NAME/actions

## Next Steps

1. **Improve Model**: Experiment with different architectures
2. **Add Features**: Implement confidence thresholds, batch prediction
3. **Enhance Monitoring**: Add Grafana dashboards
4. **Scale**: Configure auto-scaling in Kubernetes
5. **Security**: Add authentication, rate limiting
6. **Data Drift**: Implement drift detection

## Support

For issues or questions:
1. Check the README.md
2. Review deployment/kubernetes/README.md
3. Check logs: `docker logs` or `kubectl logs`
4. Run smoke tests: `./scripts/smoke_test.sh`
