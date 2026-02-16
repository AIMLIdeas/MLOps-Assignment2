# Assignment Checklist - MLOps Assignment 2

This checklist maps the project deliverables to the assignment requirements.

## M1: Model Development & Experiment Tracking (10M)

### 1. Data & Code Versioning
- [x] **Git for source code versioning**
  - Location: `.git/` directory
  - All source code, scripts, notebooks tracked
  - `.gitignore` configured to exclude large files

  - Location: `.dvc/` directory, `data/raw.dvc`
  - Command to track data: `dvc add data/raw`
  - Cat/Dogs dataset versioned with DVC
  - `.dvcignore` configured

### 2. Model Building
  - Location: `src/model.py`
  - Architecture: Simple CNN (MNISTBasicCNN)
  - Architecture: Simple CNN (CatDogsCNN)
  - Alternative: Can use logistic regression on flattened pixels
  - Training script with data loading and training loop

  - Location: `models/cat_dogs_cnn_model.pt`
  - Format: PyTorch `.pt` format
  - Can also save as `.pkl` or `.h5`

### 3. Experiment Tracking
  - Location: `src/model.py` (MLflow tracking code)
  - Logs: parameters, metrics, artifacts
  - Tracks: learning rate, batch size, epochs
  - Metrics: train/test loss, accuracy
  - Artifacts: confusion matrix, loss curves, classification report
  - View with: `mlflow ui`

**Evidence:**


## M2: Model Packaging & Containerization (10M)

### 1. Inference Service
  - Location: `api/main.py`
  - Framework: FastAPI
  - Can run with: `uvicorn api.main:app --reload`

  - Endpoint: `GET /health`
  - Returns: API status, model loaded state, timestamp
  - Test: `curl http://localhost:8000/health`

  - Endpoint: `POST /predict`
 - Input: RGB image file (128x128)
 - Output: prediction (cat/dog), probabilities, confidence
  - Test: `curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d @sample_requests.json`

### 2. Environment Specification
  - Location: `requirements.txt`
  - All dependencies with specific versions
  - Example: `torch==2.1.0`, `fastapi==0.104.1`

### 3. Containerization
  - Location: `Dockerfile`
  - Multi-stage build for optimization
  - Non-root user for security
  - Health check configured

 - Build: `docker build -t cat-dogs-classifier:latest .`
 - Run: `docker run -p 8000:8000 cat-dogs-classifier:latest`
  - Or use script: `./scripts/run_docker.sh`

  - Test with curl: See smoke test script
  - Automated tests: `./scripts/smoke_test.sh`

**Evidence:**


## M3: CI Pipeline for Build, Test & Image Creation (10M)

### 1. Automated Testing
  - Location: `tests/test_preprocessing.py`
  - Tests: `preprocess_image`, `flatten_image`, `normalize_pixel_values`
  - Coverage: Edge cases, validation, shape checking

  - Location: `tests/test_inference.py`
  - Tests: Model loading, prediction, output validation
  - Mocking: Model behavior for unit testing

  - Command: `pytest tests/ -v`
  - Configuration: `pytest.ini`
  - Coverage: `pytest tests/ --cov=src --cov=api`

### 2. CI Setup (GitHub Actions)
  - Location: `.github/workflows/ci.yml`
  - Trigger: On push to main/develop, on pull requests
  
  **Test Stage (all branches):**
  - [x] Checkout repository
  - [x] Install dependencies
  - [x] Run unit tests (pytest)
  
  **Build & Push Stage (main branch only):**
  - [x] Build Docker image
  - [x] Push to GHCR with two tags:
    * `:latest` for convenience
    * `:${{github.sha}}` for immutable versioning
  - [x] Only runs after tests pass
  
  **Key Principle**: Build once, test the built artifact

### 3. Artifact Publishing
  - Registry: GitHub Container Registry (ghcr.io)
  - Image: `ghcr.io/YOUR_USERNAME/mnist-classifier:latest`
  - Tags: branch name, git SHA, latest
  - Automatic push on main branch updates

**Evidence:**


## M4: CD Pipeline & Deployment (10M)

### 1. Deployment Target
  - Location: `deployment/kubernetes/`
  - Files:
    - `deployment.yaml` - Application deployment
    - `service.yaml` - LoadBalancer service
    - `hpa.yaml` - Horizontal Pod Autoscaler
    - `configmap.yaml` - Configuration

  - Location: `deployment/docker-compose.yml`
  - Services: API + Prometheus
  - Quick start: `docker-compose up`

### 2. CD / GitOps Flow
  - Location: `.github/workflows/cd.yml`
  - Trigger: Automatic on successful CI completion (workflow_run event)
  
  - [x] Detect SHA-tagged image from CI workflow
  - [x] Configure AWS credentials
  - [x] Update EKS kubeconfig
  - [x] Apply Kubernetes manifests
  - [x] Deploy specific tested image (kubectl set image)
  - [x] Wait for rollout status
  - [x] Run smoke tests

  **Trigger Options:**
  - Automatic: When CI workflow completes successfully
  - Manual: workflow_dispatch with optional image tag input
  
  **Key Principle**: Never rebuild - only deploy pre-tested images from CI

### 3. Smoke Tests / Health Check
  - Location: `scripts/smoke_test.sh`
  - Tests:
    - Health endpoint
    - Prediction endpoint
    - Invalid input handling
    - Metrics endpoint
    - Response validation

  - Runs automatically in CD pipeline
  - Can run manually: `./scripts/smoke_test.sh`
  - Fails pipeline if tests fail

  - Automatic rollback on failure
  - Command: `kubectl rollout undo deployment/mnist-deployment`

**Evidence:**


## M5: Monitoring, Logs & Final Submission (10M)

### 1. Basic Monitoring & Logging
  - Location: `api/main.py` (middleware)
  - Logs: Request method, path, status, latency
  - Excludes: Sensitive data
  - Format: Structured logging with timestamps

  - Location: `logs/predictions.jsonl`
  - Logs: timestamp, prediction, confidence, inference_time
  - Format: JSON Lines for easy parsing

  - Prometheus metrics endpoint: `/metrics`
  - Metrics:
    - `api_requests_total` - Request counter
    - `api_request_latency_seconds` - Latency histogram
    - `predictions_total` - Predictions by class
  - Dashboard: Available at `/stats` endpoint

### 2. Model Performance Tracking (Post-Deployment)
  - Location: `scripts/evaluate_performance.py`
  - Function: Evaluate model on test data
  - Metrics: accuracy, precision, recall, F1
  - Latency: average, P50, P95, P99

  - Real requests logged to `logs/predictions.jsonl`
  - Can simulate with: `scripts/generate_samples.py`
  - Batch evaluation supported

  - Reports saved to: `logs/performance/`
  - Format: JSON with full metrics
  - History: `performance_history.jsonl`
  - Command: `python scripts/evaluate_performance.py`

**Evidence:**


## Additional Deliverables

### Documentation
  - Project overview
  - Quick start guide
  - API documentation
  - All milestones covered

  - Step-by-step setup instructions
  - Verification checklist
  - Troubleshooting guide

  - Location: `deployment/kubernetes/README.md`
  - Deployment instructions
  - Scaling and monitoring guides

### Scripts

### Configuration Files


## Quick Verification Commands

### M1 Verification
```bash
# Check Git
git log --oneline

# Check DVC
dvc status

# Train model
python src/model.py

# View MLflow
mlflow ui
```

### M2 Verification
```bash
# Check dependencies
pip list | grep -E "torch|fastapi|mlflow"

# Run API
uvicorn api.main:app --reload

# Test endpoints
curl http://localhost:8000/health
curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d '{...}'

# Docker
docker build -t mnist-classifier:latest .
docker run -p 8000:8000 mnist-classifier:latest
```

### M3 Verification
```bash
# Run tests
pytest tests/ -v --cov=src --cov=api

# Check CI file
cat .github/workflows/ci.yml

# Trigger CI (push to GitHub)
git push origin main
```

### M4 Verification
```bash
# Check manifests
ls -la deployment/kubernetes/

# Deploy
kubectl apply -f deployment/kubernetes/
kubectl get pods

# Smoke tests
./scripts/smoke_test.sh

# Check CD file
cat .github/workflows/cd.yml
```

### M5 Verification
```bash
# Check logs
cat logs/predictions.jsonl

# View metrics
curl http://localhost:8000/metrics

# Evaluate performance
python scripts/evaluate_performance.py

# View stats
curl http://localhost:8000/stats
```


## Submission Package

The complete submission includes:

1. **Source Code**
   - `src/` - Model and preprocessing code
   - `api/` - FastAPI service
   - `tests/` - Unit tests
   - `scripts/` - Utility scripts

2. **Configuration**
   - `requirements.txt`
   - `Dockerfile`
   - `.github/workflows/` - CI/CD pipelines
   - `deployment/` - Kubernetes manifests

3. **Documentation**
   - `README.md`
   - `SETUP_GUIDE.md`
   - `ASSIGNMENT_CHECKLIST.md`
   - `deployment/kubernetes/README.md`

4. **Versioning**
   - `.git/` - Git repository
   - `.dvc/` - DVC configuration
   - `data/*.dvc` - Data version files

5. **Artifacts** (after running)
   - `models/` - Trained model
   - `mlruns/` - MLflow experiments
   - `logs/` - Prediction and performance logs

All requirements across M1-M5 are fully implemented and tested.
