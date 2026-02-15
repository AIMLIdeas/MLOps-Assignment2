# MLOps Assignment 2 - Cats vs Dogs Classification for Pet Adoption Platform

This project demonstrates a complete MLOps pipeline for a **Cats vs Dogs binary image classification** model designed for a pet adoption platform. The project covers model development, containerization, CI/CD, monitoring, and deployment.

## 🎯 Project Overview

**Task**: Binary Image Classification (Cats vs Dogs)  
**Application**: Pet Adoption Platform  
**Dataset**: Kaggle Cats and Dogs Classification Dataset  
**Input**: 224x224 RGB images  
**Output**: Binary classification (Cat=0, Dog=1)  
**Architecture**: Custom CNN with data augmentation

## 📊 Dataset

- **Source**: [Kaggle - Dog and Cat Classification Dataset](https://www.kaggle.com/datasets/bhavikjikadara/dog-and-cat-classification-dataset)
- **Total Images**: ~25,000 images
- **Split**: 
  - Training: 80% (~20,000 images)
  - Validation: 10% (~2,500 images)
  - Test: 10% (~2,500 images)
- **Preprocessing**: 
  - Resize to 224x224 RGB
  - ImageNet normalization
  - Data augmentation (RandomCrop, HorizontalFlip, Rotation, ColorJitter)

## Project Structure

```
.
├── data/                      # Data directory
│   ├── raw/                   
│   │   └── cats_dogs/         # Kaggle dataset
│   │       └── PetImages/
│   │           ├── Cat/       # Cat images
│   │           └── Dog/       # Dog images
│   └── processed/             # Preprocessed data
├── src/                       # Source code
│   ├── data_preprocessing.py  # Data preprocessing (224x224 RGB, augmentation)
│   ├── model.py              # CNN model training
│   └── inference.py          # Model inference utilities
├── api/                       # FastAPI service
│   └── main.py               # REST API endpoints (file upload, base64)
├── tests/                     # Unit tests
│   ├── test_preprocessing.py
│   ├── test_inference.py
│   └── test_api.py
├── deployment/                # Deployment configurations
│   ├── kubernetes/           # K8s manifests
│   └── docker-compose.yml    # Docker Compose setup
├── .github/                   # CI/CD workflows
│   └── workflows/
├── scripts/                   # Utility scripts
├── models/                    # Saved models
│   └── cats_dogs_cnn_model.pt
├── Dockerfile                 # Container image
├── requirements.txt           # Python dependencies
└── README.md                  # This file
```

## 🚀 Milestones

### M1: Model Development & Experiment Tracking ✓
- **Git** for source code versioning
- **DVC** for dataset versioning
- Custom CNN model for binary classification
- **MLflow** for experiment tracking
- Data augmentation for better generalization

### M2: Model Packaging & Containerization ✓
- **FastAPI** REST API with file upload and base64 endpoints
- Support for RGB image classification
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
- Kaggle Account & API credentials
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

### 2. Download Dataset from Kaggle

```bash
# Setup Kaggle credentials (if not already done)
# Download your kaggle.json from https://www.kaggle.com/settings
mkdir -p ~/.kaggle
cp /path/to/kaggle.json ~/.kaggle/
chmod 600 ~/.kaggle/kaggle.json

# Download dataset
kaggle datasets download -d bhavikjikadara/dog-and-cat-classification-dataset -p data/raw/cats_dogs --unzip
```

### 3. Initialize DVC

```bash
# Initialize DVC
dvc init

# Add data to DVC tracking
dvc add data/raw/cats_dogs
git add data/raw/cats_dogs.dvc .gitignore
git commit -m "Add cats vs dogs dataset to DVC"
```

### 4. Train Model

```bash
# Train the Cats vs Dogs CNN model with MLflow tracking
python src/model.py
```

View MLflow UI:
```bash
mlflow ui
# Open http://localhost:5000
```

### 5. Run API Locally

```bash
# Start FastAPI server
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

API Documentation:
- Interactive docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

Test endpoints:
```bash
# Health check
curl http://localhost:8000/health

# Predict with image file
curl -X POST "http://localhost:8000/predict" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/path/to/cat_or_dog_image.jpg"

# Get model info
curl http://localhost:8000/model-info
```

### 6. Run with Docker

```bash
# Build image
docker build -t cats-dogs-classifier:latest .

# Run container
docker run -p 8000:8000 cats-dogs-classifier:latest
```

### 7. Deploy with Docker Compose

```bash
docker-compose -f deployment/docker-compose.yml up
```

### 8. Deploy to Kubernetes

```bash
# Apply manifestskubectl apply -f deployment/kubernetes/

# Check status
kubectl get pods
kubectl get svc

# Port forward
kubectl port-forward service/cats-dogs-service 8000:80
```

### 9. Run Tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=src --cov=api
```

## 📡 API Endpoints

### Health Check
```
GET /health
Response: {
  "status": "healthy",
  "model_loaded": true,
  "timestamp": "2026-02-15T...",
  "version": "2.0.0"
}
```

### Prediction (File Upload)
```
POST /predict
Content-Type: multipart/form-data
Body: file=<image_file>

Response: {
  "prediction": 1,
  "prediction_label": "Dog",
  "probabilities": {
    "Cat": 0.15,
    "Dog": 0.85
  },
  "confidence": 0.85,
  "inference_time_ms": 45.2
}
```

### Prediction (Base64)
```
POST /predict-base64
Content-Type: application/json
Body: {"image": "<base64_encoded_image>"}

Response: {
  "prediction": 0,
  "prediction_label": "Cat",
  "probabilities": {
    "Cat": 0.92,
    "Dog": 0.08
  },
  "confidence": 0.92,
  "inference_time_ms": 42.8
}
```

### Model Info
```
GET /model-info
Response: {
  "model_type": "Convolutional Neural Network (CNN)",
  "task": "Binary Image Classification",
  "application": "Pet Adoption Platform - Cat vs Dog Classifier",
  "input_size": "224x224 RGB",
  "num_classes": "2 (Cat, Dog)",
  "class_mapping": {"0": "Cat", "1": "Dog"},
  ...
}
```

### Statistics
```
GET /stats
Response: {
  "total_predictions": 1543,
  "average_confidence": 0.87,
  "average_inference_time_ms": 43.5,
  "class_distribution": {
    "Cat": 756,
    "Dog": 787
  }
}
```

### Metrics (Prometheus)
```
GET /metrics
Response: Prometheus-formatted metrics
```

## 🔄 CI/CD Pipeline

### Continuous Integration (GitHub Actions)
On every push/PR:
1. Checkout code
2. Install dependencies
3. Run unit tests
4. Build Docker image
5. Push to container registry

### Continuous Deployment
On main branch updates:
1. Pull latest image
2. Deploy to Kubernetes/Docker Compose
3. Run smoke tests
4. Rollback on failure

## 📊 Monitoring

The API includes built-in monitoring:
- Request/response logging
- Latency tracking
- Request count metrics per class (Cat/Dog)
- Error tracking
- Performance metrics

View logs:
```bash
# Docker
docker logs <container-id>

# Kubernetes
kubectl logs -f deployment/cats-dogs-deployment
```

## 🔖 Model Versioning

Models are versioned using:
- Git tags for code versions
- MLflow for model artifact and metrics tracking
- DVC for large dataset files

## ⚡ Performance

- **Model Accuracy**: Target ~85-90% on test set
- **Input**: 224x224 RGB images
- **Classes**: 2 (Cat, Dog)
- **Inference Latency**: ~30-50ms per prediction
- **API Response Time**: ~50-100ms
- **Model Size**: ~15-20 MB

## 🏗️ Model Architecture

**CatsDogsCNN**:
- 4 Convolutional blocks with BatchNorm and MaxPooling
- Global Average Pooling
- Fully connected layers with Dropout (0.5)
- Binary cross-entropy loss
- Adam optimizer with learning rate scheduling

**Data Augmentation**:
- Random Crop (256 → 224)
- Random Horizontal Flip
- Random Rotation (±15°)
- Color Jitter (brightness, contrast, saturation)

## 📝 Notes

- Model trained on Kaggle Cats and Dogs dataset
- Uses ImageNet normalization for transfer learning potential
- Binary classification optimized for pet adoption use case
- Supports both file upload and base64 encoded images
- Comprehensive logging for prediction tracking

## 🙏 Acknowledgments

- Dataset: [Kaggle - Dog and Cat Classification Dataset](https://www.kaggle.com/datasets/bhavikjikadara/dog-and-cat-classification-dataset)
- Framework: PyTorch, FastAPI, MLflow

## 📄 License

MIT License
