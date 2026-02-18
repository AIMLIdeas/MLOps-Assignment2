# Assignment Checklist - MLOps Assignment 2

This checklist maps the project deliverables to the assignment requirements.

## M1: Model Development & Experiment Tracking (10M)
Objective: Build a baseline model, track experiments, and version all artifacts.
Tasks:
1. Data & Code Versioning
Use Git for source code versioning (project structure, scripts, and notebooks).
Use DVC (or Git‐LFS) for dataset versioning and to track pre-processed data.
2. Model Building
Implement at least one baseline model (e.g., simple CNN or logistic regression on flattened
pixels).
Save the trained model in a standard serialized format (e.g., .pkl, .pt, .h5).
3. Experiment Tracking
Use an open-source tracker like MLflow/Neptune to log runs, parameters, metrics, and
artifacts (confusion matrix, loss curves)

### 1. Data & Code Versioning
- [x] **Git for source code versioning**
  - Location: `.git/` - https://github.com/AIMLIdeas/MLOps-Assignment2
  - All source code, scripts, notebooks tracked
  - `.gitignore` configured to exclude large files

  - Location: `.dvc/` directory, `data/raw.dvc`
  - Cat/Dogs dataset versioned with DVC
  - `.dvcignore` configured

### 2. Model Building
  - Location: `src/model.py`
  - Architecture: Simple CNN (CatDogsCNN)
  - Training script with data loading and training loop

  - Location: `models/cat_dogs_cnn_model.pt`
  - Format: PyTorch `.pt` format

### 3. Experiment Tracking
  - Location: `src/model.py` (MLflow tracking code)
  - Logs: parameters, metrics, artifacts
  - Tracks: learning rate, batch size, epochs
  - Metrics: train/test loss, accuracy
  - Artifacts: confusion matrix, loss curves, classification report
  - View with: `mlflow ui`

**Evidence:**


## M2: Model Packaging & Containerization (10M)
Objective: Package the trained model into a reproducible, containerized service.
Tasks:
1. Inference Service
Wrap the trained model with a simple REST API using FastAPI/Flask.
Implement at least two endpoints: health check and prediction (accepts input and returns class
probabilities/label).
2. Environment Specification
Define dependencies using requirements.txt
Ensure version pinning for all key ML libraries for reproducibility.
3. Containerization
Create a Dockerfile to containerize the inference service.
Build and run the image locally and verify predictions via curl/Postman
### 1. Inference Service
  - Location: `api/main.py`
  - Framework: FastAPI

  - Endpoint: `GET /health`
  - Returns: API status, model loaded state, timestamp
  - Test: `curl http://localhost:8000/health`
  - AWS URL: http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com/health

  - Endpoint: `POST /predict`
 - Input: RGB image file (128x128)
 - Output: prediction (cat/dog), probabilities, confidence
  - Test: `curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d @sample_requests.json`
  - AWS URL: http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com/predict

- [x] **POST /predict-image endpoint**
  - Endpoint: `POST /predict-image`
  - Input: Base64 encoded image
  - Output: prediction (cat/dog), probabilities, confidence
  - Test: `curl -X POST http://localhost:8000/predict-image -H "Content-Type: application/json" -d '{"image":"base64_string"}'`
  - AWS URL: http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com/predict-image

- [x] **GET /model-info endpoint**
  - Endpoint: `GET /model-info`
  - Returns: Model architecture, parameters, training details
  - Test: `curl http://localhost:8000/model-info`
  - AWS URL: http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com/model-info

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

  - Test with curl: See smoke test script
  - Automated tests: `./scripts/smoke_test.sh`

**Evidence:**


## M3: CI Pipeline for Build, Test & Image Creation (10M)
Objective: Implement Continuous Integration to automatically test, package, and build container
images
Tasks:
1. Automated Testing : Write unit tests for at least one data pre-processing function and
One model utility/inference function. Ensure tests run via pytest or similar.

2. CI Setup (Choose one: GitHub Actions / GitLab CI / Jenkins / Tekton)
Define a pipeline that on every push/merge request, checks out the repository, installs
dependencies, runs unit tests, and builds the Docker image
3. Artifact Publishing: Configure the pipeline to push the Docker image to a container registry
(e.g., Docker Hub, GitHub Container Registry, local registry).
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

### 2. Build & Image Creation
- [x] **Docker Build Workflow**
  - Location: `.github/workflows/build-docker.yml`
  - Trigger: Automatic on push to main when code/dependencies change
  - Paths monitored: `Dockerfile`, `requirements.txt`, `src/**`, `api/**`, `models/**`
  
  **Build Process:**
  - [x] Multi-stage Docker build
  - [x] Platform: linux/amd64 (for AWS EKS compatibility)
  - [x] Tags images with git SHA and 'latest'
  - [x] Pushes to GitHub Container Registry (GHCR)
  - [x] Login to GHCR using GitHub token
  - [x] Build completes before CI testing begins
  
  **Manual Build Option:**
  - Script: `scripts/build_and_push.sh`
  - Builds locally with git SHA tag
  - Requires: `GITHUB_TOKEN` environment variable
  - Use case: Test builds before pushing code

### 3. CI Setup (GitHub Actions)
  - Location: `.github/workflows/ci.yml`
  - Trigger: On push to main/develop, on pull requests
  - Prerequisites: Docker image built in a seperate job and pushed to GHCR
  
  **Test Job (tests pre-built Docker container):**
  - [x] Set image tag (uses git SHA)
  - [x] Login to GHCR
  - [x] Pull Docker image from registry
  - [x] Run pytest inside the Docker container
  - [x] Start container and verify /health endpoint
  - [x] Mark successful if all tests pass
  
  **Developer Build Script:**
  - Location: `scripts/build_and_push.sh`
  - [x] Builds image with git SHA tag
  - [x] Pushes to GHCR: `ghcr.io/.../cats-dogs-classifier:$SHA`
  - [x] Requires GITHUB_TOKEN environment variable
  
  **Comments:**
  - Tests the actual Docker container (not separate code)
  - Simpler CI - just pull and test
  - Developers can test exact image locally before pushing
  - CI validates the deployable artifact

### 4. Artifact Publishing
  - Registry: GitHub Container Registry (ghcr.io)
  - Image: `ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier`
  - Tags: branch name, git SHA, latest
  - Automatic push on main branch updates

**Evidence:**


## M4: CD Pipeline & Deployment (10M)
Objective: Implement Continuous Deployment of the containerized model to a target environment.
Tasks:
1. Deployment Target
Choose one: local Kubernetes cluster (kind/minikube/microk8s), Docker Compose, or a
simple VM server.
Define infrastructure manifests: For Kubernetes: Deployment + Service YAML.
For Docker Compose: docker-compose.yml.

2. CD / GitOps Flow
Extend CI or use a CD tool (Argo CD, Jenkins, GitHub Actions environment) to:
- Pull the new image from the registry.
- Deploy/update the running service automatically on main branch changes.
3. Smoke Tests / Health Check
Implement a simple post-deploy smoke test (e.g., script that calls the health endpoint and one
prediction call).
Fail the pipeline if smoke tests fail

### 1. Deployment Target
  - VPC, EKS clusters were created onetime and configured using CloudFormation automation scripts
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
  - Prerequisites: Docker image tested successfully by CI
  
  - [x] Verify tested image availability (SHA tag)
  - [x] Configure AWS credentials
  - [x] Update EKS kubeconfig
  - [x] Apply Kubernetes manifests
  - [x] Deploy specific tested image (kubectl set image)
  - [x] Wait for rollout status
  - [x] Run smoke tests and health checks

  **Triggers:**
  - Automatic: When CI workflow completes successfully
  - Manual: workflow_dispatch with optional image tag input
  
  **Key Principle**: Deploy the exact Docker container that passed CI tests (built locally, tested in CI)

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
Objective: Monitor the deployed model and submit a consolidated package of all artifacts.
Tasks:
1. Basic Monitoring & Logging
Enable request/response logging in the inference service (excluding sensitive data).
Track basic metrics such as request count and latency (via logs, Prometheus, or simple in-app
counters).
2. Model Performance Tracking (Post‐Deployment)
Collect a small batch of real or simulated requests and true labels.

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
  - Test: `curl http://localhost:8000/metrics`
  - AWS URL: http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com/metrics

- [x] **Dashboard /stats endpoint**
  - Endpoint: `GET /stats`
  - Returns: Total predictions, average confidence, average inference time
  - Test: `curl http://localhost:8000/stats`
  - AWS URL: http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com/stats

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
- [x] **README.md**
  - Project overview
  - Quick start guide
  - API documentation
  - All milestones covered

- [x] **SETUP_GUIDE.md**
  - Step-by-step setup instructions
  - Verification checklist
  - Troubleshooting guide

- [x] **ASSIGNMENT_CHECKLIST.md** (this file)
  - Maps requirements to implementation
  - Evidence for each milestone (M1-M5)
  - Verification commands for each deliverable
  - Submission package details

- [x] **Deployment Documentation**
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
