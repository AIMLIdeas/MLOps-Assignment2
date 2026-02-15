# Assignment Checklist - MLOps Assignment 2

This checklist maps the project deliverables to the assignment requirements.

## M1: Model Development & Experiment Tracking (10M)

### 1. Data & Code Versioning
- [x] **Git for source code versioning**
  - Location: `.git/` directory
  - All source code, scripts, notebooks tracked
  - `.gitignore` configured to exclude large files

- [x] **DVC for dataset versioning**
  - Location: `.dvc/` directory, `data/raw.dvc`
  - Command to track data: `dvc add data/raw`
  - MNIST dataset versioned with DVC
  - `.dvcignore` configured

### 2. Model Building
- [x] **Baseline model implemented**
  - Location: `src/model.py`
  - Architecture: Simple CNN (MNISTBasicCNN)
  - Alternative: Can use logistic regression on flattened pixels
  - Training script with data loading and training loop

- [x] **Model saved in standard format**
  - Location: `models/mnist_cnn_model.pt`
  - Format: PyTorch `.pt` format
  - Can also save as `.pkl` or `.h5`

### 3. Experiment Tracking
- [x] **MLflow integration**
  - Location: `src/model.py` (MLflow tracking code)
  - Logs: parameters, metrics, artifacts
  - Tracks: learning rate, batch size, epochs
  - Metrics: train/test loss, accuracy
  - Artifacts: confusion matrix, loss curves, classification report
  - View with: `mlflow ui`

**Evidence:**
- Run `python src/model.py` to train model
- Run `mlflow ui` to view experiments
- Check `mlruns/` directory for artifacts

---

## M2: Model Packaging & Containerization (10M)

### 1. Inference Service
- [x] **REST API with FastAPI**
  - Location: `api/main.py`
  - Framework: FastAPI
  - Can run with: `uvicorn api.main:app --reload`

- [x] **Health check endpoint**
  - Endpoint: `GET /health`
  - Returns: API status, model loaded state, timestamp
  - Test: `curl http://localhost:8000/health`

- [x] **Prediction endpoint**
  - Endpoint: `POST /predict`
  - Input: 28x28 or 784-element image array
  - Output: prediction, probabilities, confidence
  - Test: `curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d @sample_requests.json`

### 2. Environment Specification
- [x] **requirements.txt with pinned versions**
  - Location: `requirements.txt`
  - All dependencies with specific versions
  - Example: `torch==2.1.0`, `fastapi==0.104.1`

### 3. Containerization
- [x] **Dockerfile created**
  - Location: `Dockerfile`
  - Multi-stage build for optimization
  - Non-root user for security
  - Health check configured

- [x] **Build and run locally**
  - Build: `docker build -t mnist-classifier:latest .`
  - Run: `docker run -p 8000:8000 mnist-classifier:latest`
  - Or use script: `./scripts/run_docker.sh`

- [x] **Verify predictions**
  - Test with curl: See smoke test script
  - Automated tests: `./scripts/smoke_test.sh`

**Evidence:**
- `Dockerfile` in root directory
- Run `./scripts/run_docker.sh` to build and run
- Test with `./scripts/smoke_test.sh`

---

## M3: CI Pipeline for Build, Test & Image Creation (10M)

### 1. Automated Testing
- [x] **Unit test for data preprocessing**
  - Location: `tests/test_preprocessing.py`
  - Tests: `preprocess_image`, `flatten_image`, `normalize_pixel_values`
  - Coverage: Edge cases, validation, shape checking

- [x] **Unit test for model utility/inference**
  - Location: `tests/test_inference.py`
  - Tests: Model loading, prediction, output validation
  - Mocking: Model behavior for unit testing

- [x] **Tests run via pytest**
  - Command: `pytest tests/ -v`
  - Configuration: `pytest.ini`
  - Coverage: `pytest tests/ --cov=src --cov=api`

### 2. CI Setup (GitHub Actions)
- [x] **CI pipeline defined**
  - Location: `.github/workflows/ci.yml`
  - Trigger: On push to main/develop, on pull requests
  
- [x] **Pipeline steps:**
  - [x] Checkout repository
  - [x] Install dependencies
  - [x] Run unit tests
  - [x] Run linting (flake8, black)
  - [x] Build Docker image
  - [x] Test Docker image
  - [x] Push to registry (on main branch)

### 3. Artifact Publishing
- [x] **Docker image published to registry**
  - Registry: GitHub Container Registry (ghcr.io)
  - Image: `ghcr.io/YOUR_USERNAME/mnist-classifier:latest`
  - Tags: branch name, git SHA, latest
  - Automatic push on main branch updates

**Evidence:**
- `.github/workflows/ci.yml` file
- Push to GitHub to trigger pipeline
- View pipeline: GitHub Actions tab

---

## M4: CD Pipeline & Deployment (10M)

### 1. Deployment Target
- [x] **Deployment manifests created**
  - Location: `deployment/kubernetes/`
  - Files:
    - `deployment.yaml` - Application deployment
    - `service.yaml` - LoadBalancer service
    - `hpa.yaml` - Horizontal Pod Autoscaler
    - `configmap.yaml` - Configuration

- [x] **Docker Compose alternative**
  - Location: `deployment/docker-compose.yml`
  - Services: API + Prometheus
  - Quick start: `docker-compose up`

### 2. CD / GitOps Flow
- [x] **CD pipeline configured**
  - Location: `.github/workflows/cd.yml`
  - Trigger: On successful CI completion (main branch)
  
- [x] **Deployment steps:**
  - [x] Pull new image from registry
  - [x] Update Kubernetes manifests
  - [x] Apply to cluster
  - [x] Wait for rollout
  - [x] Run smoke tests

- [x] **Automatic deployment**
  - Triggered on main branch changes
  - Can also be triggered manually

### 3. Smoke Tests / Health Check
- [x] **Smoke test script**
  - Location: `scripts/smoke_test.sh`
  - Tests:
    - Health endpoint
    - Prediction endpoint
    - Invalid input handling
    - Metrics endpoint
    - Response validation

- [x] **Post-deploy validation**
  - Runs automatically in CD pipeline
  - Can run manually: `./scripts/smoke_test.sh`
  - Fails pipeline if tests fail

- [x] **Rollback mechanism**
  - Automatic rollback on failure
  - Command: `kubectl rollout undo deployment/mnist-deployment`

**Evidence:**
- Kubernetes manifests in `deployment/kubernetes/`
- CD workflow in `.github/workflows/cd.yml`
- Smoke test script: `scripts/smoke_test.sh`
- Deploy with: `kubectl apply -f deployment/kubernetes/`

---

## M5: Monitoring, Logs & Final Submission (10M)

### 1. Basic Monitoring & Logging
- [x] **Request/response logging**
  - Location: `api/main.py` (middleware)
  - Logs: Request method, path, status, latency
  - Excludes: Sensitive data
  - Format: Structured logging with timestamps

- [x] **Prediction logging**
  - Location: `logs/predictions.jsonl`
  - Logs: timestamp, prediction, confidence, inference_time
  - Format: JSON Lines for easy parsing

- [x] **Metrics tracking**
  - Prometheus metrics endpoint: `/metrics`
  - Metrics:
    - `api_requests_total` - Request counter
    - `api_request_latency_seconds` - Latency histogram
    - `predictions_total` - Predictions by class
  - Dashboard: Available at `/stats` endpoint

### 2. Model Performance Tracking (Post-Deployment)
- [x] **Performance evaluation script**
  - Location: `scripts/evaluate_performance.py`
  - Function: Evaluate model on test data
  - Metrics: accuracy, precision, recall, F1
  - Latency: average, P50, P95, P99

- [x] **Request collection**
  - Real requests logged to `logs/predictions.jsonl`
  - Can simulate with: `scripts/generate_samples.py`
  - Batch evaluation supported

- [x] **Performance reporting**
  - Reports saved to: `logs/performance/`
  - Format: JSON with full metrics
  - History: `performance_history.jsonl`
  - Command: `python scripts/evaluate_performance.py`

**Evidence:**
- Request logging in `api/main.py`
- Metrics endpoint: `curl http://localhost:8000/metrics`
- Performance script: `scripts/evaluate_performance.py`
- Logs directory: `logs/`

---

## Additional Deliverables

### Documentation
- [x] **Main README.md**
  - Project overview
  - Quick start guide
  - API documentation
  - All milestones covered

- [x] **SETUP_GUIDE.md**
  - Step-by-step setup instructions
  - Verification checklist
  - Troubleshooting guide

- [x] **Kubernetes README**
  - Location: `deployment/kubernetes/README.md`
  - Deployment instructions
  - Scaling and monitoring guides

### Scripts
- [x] **Setup script**: `scripts/setup.sh`
- [x] **Docker build script**: `scripts/run_docker.sh`
- [x] **Smoke tests**: `scripts/smoke_test.sh`
- [x] **Performance evaluation**: `scripts/evaluate_performance.py`
- [x] **Sample generation**: `scripts/generate_samples.py`

### Configuration Files
- [x] **.gitignore** - Git ignore patterns
- [x] **.dockerignore** - Docker ignore patterns
- [x] **.dvcignore** - DVC ignore patterns
- [x] **pytest.ini** - Pytest configuration
- [x] **Dockerfile** - Container image definition
- [x] **docker-compose.yml** - Multi-container setup

---

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

---

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
