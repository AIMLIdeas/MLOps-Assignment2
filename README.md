# MLOps Assignment 2 - Complete ML Pipeline

This project demonstrates a complete MLOps pipeline for a Cat/Dogs image classification model, covering model development, containerization, CI/CD, and monitoring.

## Project Structure

```
.
├── data/                      # Data directory (DVC tracked)
│   ├── raw/                   # Raw Cat/Dogs image data
│   └── processed/             # Preprocessed data
├── src/                       # Source code
│   ├── data_preprocessing.py  # Data preprocessing utilities
│   ├── model.py               # Model training
│   └── inference.py           # Model inference utilities
├── api/                       # FastAPI service
│   └── main.py               # REST API endpoints
├── tests/                     # Unit tests
│   ├── test_preprocessing.py
│   └── test_inference.py
├── deployment/                # Deployment configurations
│   ├── kubernetes/           # K8s manifests
│   └── docker-compose.yml    # Docker Compose setup
├── .github/                   # CI/CD workflows
│   └── workflows/
├── scripts/                   # Utility scripts
│   └── smoke_test.sh         # Post-deployment tests
├── models/                    # Saved models (cat_dogs_cnn_model.pt)
├── Dockerfile                 # Container image
├── requirements.txt           # Python dependencies
├── .dvc/                      # DVC configuration
└── README.md                  # This file
```

## Milestones

### M1: Model Development & Experiment Tracking ✓
- **Git** for source code versioning
- **DVC** for dataset versioning
- Baseline CNN model for Cat/Dogs classification
- **MLflow** for experiment tracking

### M2: Model Packaging & Containerization ✓
- **FastAPI** REST API with health and prediction endpoints
- Pinned dependencies in requirements.txt
- Docker containerization

### M3: CI Pipeline ✓
- Unit tests with pytest
- **GitHub Actions** CI pipeline
- Automated Docker image building and publishing

### M4: CD Pipeline & Deployment ✓
- Kubernetes deployment manifests
- Automated deployment on main branch changes
- Smoke tests for deployment validation

### M5: Monitoring & Logging ✓
- Request/response logging
- Basic metrics tracking (request count, latency)
- Model performance monitoring

## Quick Start

### Prerequisites
- Python 3.9+
- Docker
- Git
- DVC (optional, for data versioning)

### 1. Setup Environment

```bash
# Clone repository
git clone <your-repo-url>
cd "Assignment 2"

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Initialize DVC

```bash
# Initialize DVC
dvc init

# Add data to DVC tracking
dvc add data/raw/
git add data/raw/.dvc .gitignore
git commit -m "Add raw data to DVC"
```

### 3. Train Model

```bash
# Train baseline model with MLflow tracking
python src/model.py
```

View MLflow UI:
```bash
mlflow ui
# Open http://localhost:5000
```

### 4. Run API Locally

```bash
# Start FastAPI server
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

Test endpoints:
```bash
# Health check
curl http://localhost:8000/health

# Prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"image": [[0.0, 0.0, ...]]}'
```

### 5. Run with Docker

```bash
# Build image
docker build -t cats-dogs-classifier:latest .

# Run container
docker run -p 8000:8000 cats-dogs-classifier:latest
```

### 6. Deploy with Docker Compose

```bash
docker-compose -f deployment/docker-compose.yml up
```

### 7. Deploy to Kubernetes

```bash
# Apply manifests
kubectl apply -f deployment/kubernetes/

# Check status
kubectl get pods
kubectl get svc

# Port forward
kubectl port-forward service/cats-dogs-service 8000:80
```

### 8. Run Tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=src --cov=api
```

## API Endpoints

### Health Check
```
GET /health
Response: {"status": "healthy", "model_loaded": true}
```

### Prediction
```
POST /predict
Body: {"image": [[784 float values]]}
Response: {"prediction": 5, "probabilities": [0.01, ...], "confidence": 0.98}
```

## CI/CD Pipeline

### Developer Workflow
**Build and Push Docker Image Locally:**
```bash
# Set your GitHub token
export GITHUB_TOKEN=your_token_here

# Build and push image with git SHA tag
./scripts/build_and_push.sh

# Push code to GitHub
git push origin main
```

The script:
- Builds Docker image with current git SHA tag
- Pushes to GHCR: `ghcr.io/aimlideas/mlops-assignment2/cats-dogs-classifier:$SHA`
- Tags as `:latest` for convenience

### Continuous Integration (GitHub Actions)
**Single Test Job - Tests Pre-built Container:**

1. **Pull Image**: Downloads the Docker image you built locally from GHCR
2. **Test Inside Container**: Runs pytest inside the Docker container
3. **Health Check**: Starts container and verifies `/health` endpoint
4. **Mark Success**: If all tests pass, triggers CD

**Key Advantage**: Tests the **actual artifact** that will be deployed, not separate code

### Continuous Deployment
Automatically triggered when CI completes successfully:
1. Verifies tested image availability (SHA tag from CI)
2. Configures AWS credentials
3. Deploys exact tested Docker image to AWS EKS
4. Runs health checks and smoke tests
5. Verifies deployment status

**Complete Flow**:
```
Local: Build → Push to GHCR
         ↓
CI:    Pull → Test in Container → Pass ✓
         ↓
CD:    Deploy to AWS EKS
```

## Monitoring

The API includes built-in monitoring:
- Request/response logging
- Latency tracking
- Request count metrics
- Error tracking

View logs:
```bash
# Docker
docker logs <container-id>

# Kubernetes
kubectl logs -f deployment/cats-dogs-deployment
```

## Model Versioning

Models are versioned using:
- Git tags for code versions
- MLflow for model artifacts and metrics
- DVC for large data files

## Performance

- **Model Accuracy**: ~60% on Cats-Dogs test set
- **Inference Latency**: ~10-20ms per prediction
- **API Response Time**: ~50-100ms

## License

MIT License
