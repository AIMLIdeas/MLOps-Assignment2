# MLOps Pipeline Architecture

This document describes the complete MLOps pipeline architecture.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MLOps Pipeline                               │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   M1: Dev    │ ───> │  M2: Package │ ───> │  M3: CI      │
│              │      │              │      │              │
│ • Model      │      │ • FastAPI    │      │ • Testing    │
│ • MLflow     │      │ • Docker     │      │ • Build      │
│ • DVC        │      │ • API        │      │ • Push       │
└──────────────┘      └──────────────┘      └──────────────┘
                                                    │
                                                    ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  M5: Monitor │ <─── │  M4: Deploy  │ <─── │  CI/CD       │
│              │      │              │      │              │
│ • Logging    │      │ • Kubernetes │      │ • GitHub     │
│ • Metrics    │      │ • Smoke Test │      │ • Actions    │
│ • Dashboard  │      │ • Rollback   │      │              │
└──────────────┘      └──────────────┘      └──────────────┘
```

## Detailed Component Architecture

### 1. Data Flow

```
┌─────────────┐
│ MNIST Data  │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ DVC Versioning  │
└──────┬──────────┘
       │
       ▼
┌──────────────────────────────────┐
│  Data Preprocessing              │
│  • Normalization                 │
│  • Augmentation (optional)       │
│  • Validation splits             │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────────┐
│  Model Training  │
│  • CNN           │
│  • MLflow track  │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Trained Model   │
│  • .pt file      │
│  • Artifacts     │
└──────────────────┘
```

### 2. CI/CD Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│                    Code Push (Git)                           │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                  GitHub Actions - CI                         │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Checkout    │→ │ Install Deps │→ │ Run Tests    │       │
│  └─────────────┘  └──────────────┘  └──────┬───────┘       │
│                                              │               │
│  ┌─────────────┐  ┌──────────────┐  ┌──────▼───────┐       │
│  │ Push Image  │← │ Build Docker │← │ Lint Code    │       │
│  └─────┬───────┘  └──────────────┘  └──────────────┘       │
└────────┼──────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────┐
│              Container Registry (GHCR)                       │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                  GitHub Actions - CD                         │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Pull Image  │→ │ Deploy K8s   │→ │ Smoke Tests  │       │
│  └─────────────┘  └──────────────┘  └──────┬───────┘       │
│                                              │               │
│                                    ┌─────────▼────────┐      │
│                                    │ Success/Rollback │      │
│                                    └──────────────────┘      │
└──────────────────────────────────────────────────────────────┘
```

### 3. Deployment Architecture (Kubernetes)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                           │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  LoadBalancer Service                  │    │
│  │                   (Port 80 → 8000)                     │    │
│  └────────────────────────┬───────────────────────────────┘    │
│                           │                                     │
│  ┌────────────────────────▼───────────────────────────────┐    │
│  │              Deployment (mnist-deployment)             │    │
│  │                                                        │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │    │
│  │  │  Pod 1   │  │  Pod 2   │  │  Pod N   │           │    │
│  │  │          │  │          │  │          │           │    │
│  │  │ FastAPI  │  │ FastAPI  │  │ FastAPI  │           │    │
│  │  │  + Model │  │  + Model │  │  + Model │           │    │
│  │  └──────────┘  └──────────┘  └──────────┘           │    │
│  │                                                        │    │
│  └────────────────────────┬───────────────────────────────┘    │
│                           │                                     │
│  ┌────────────────────────▼───────────────────────────────┐    │
│  │      Horizontal Pod Autoscaler (HPA)                   │    │
│  │      Min: 2 replicas, Max: 5 replicas                  │    │
│  │      Target: 70% CPU, 80% Memory                       │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 4. Monitoring Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      API Service                             │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Request     │  │ Middleware   │  │ Metrics      │       │
│  │ Handler     │→ │ Logging      │→ │ Collection   │       │
│  └─────────────┘  └──────────────┘  └──────┬───────┘       │
└─────────────────────────────────────────────┼───────────────┘
                                              │
                  ┌───────────────────────────┼───────────────┐
                  │                           │               │
                  ▼                           ▼               ▼
         ┌─────────────────┐       ┌──────────────┐  ┌──────────────┐
         │ Application     │       │ Prometheus   │  │ Prediction   │
         │ Logs            │       │ Metrics      │  │ Logs         │
         │ (stdout/stderr) │       │ (/metrics)   │  │ (JSONL)      │
         └─────────────────┘       └──────────────┘  └──────────────┘
                  │                       │                   │
                  └───────────┬───────────┴───────────────────┘
                              │
                              ▼
                   ┌────────────────────┐
                   │  Monitoring Stack  │
                   │                    │
                   │  • Logs Analysis   │
                   │  • Metrics Viz     │
                   │  • Alerting        │
                   └────────────────────┘
```

## Technology Stack

### Development (M1)
- **Language**: Python 3.9+
- **ML Framework**: PyTorch
- **Experiment Tracking**: MLflow
- **Data Versioning**: DVC
- **Version Control**: Git

### Packaging (M2)
- **API Framework**: FastAPI
- **Server**: Uvicorn
- **Containerization**: Docker
- **Orchestration**: Docker Compose (optional)

### CI/CD (M3, M4)
- **CI/CD Platform**: GitHub Actions
- **Container Registry**: GitHub Container Registry (GHCR)
- **Deployment**: Kubernetes
- **Testing**: pytest

### Monitoring (M5)
- **Metrics**: Prometheus
- **Logging**: Python logging + JSON
- **Visualization**: Prometheus (optional: Grafana)

## Data Flow in Production

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP Request
       ▼
┌─────────────────────┐
│  Load Balancer      │
│  (K8s Service)      │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  FastAPI            │
│  ┌───────────────┐  │
│  │ Middleware    │  │  ← Logging, Metrics
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Preprocessing │  │  ← Normalize, validate
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Model         │  │  ← Inference
│  │ Inference     │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Response      │  │  ← Format output
│  └───────────────┘  │
└──────┬──────────────┘
       │ HTTP Response
       ▼
┌─────────────┐
│   Client    │
└─────────────┘
```

## Security Considerations

### Current Implementation
- Non-root user in Docker container
- Read-only filesystem where possible
- No sensitive data in logs
- Health checks for availability

### Future Enhancements
- API authentication (JWT, API keys)
- Rate limiting
- Input validation and sanitization
- TLS/HTTPS encryption
- Network policies in Kubernetes
- Secret management (K8s Secrets, Vault)

## Scalability

### Horizontal Scaling
- Kubernetes HPA: 2-5 replicas
- Metrics-based: CPU and memory
- Load balancer distributes traffic

### Vertical Scaling
- Resource requests/limits in K8s
- Can adjust based on workload

### Performance Optimization
- Model optimization (quantization, pruning)
- Batch inference support
- Caching for common requests
- Model serving frameworks (TorchServe, TensorFlow Serving)

## Reliability & Resilience

### High Availability
- Multiple replicas (min 2)
- Load balancing across pods
- Health checks (liveness, readiness)
- Rolling updates (zero downtime)

### Fault Tolerance
- Automatic pod restart on failure
- Rollback on deployment failure
- Smoke tests validate deployment
- Circuit breakers (future)

### Monitoring & Alerting
- Request/response logging
- Performance metrics
- Error tracking
- Latency monitoring

## Development Workflow

### Local Development
```
1. Setup environment
   └─> scripts/setup.sh

2. Make changes
   └─> Edit code

3. Test locally
   └─> pytest tests/
   └─> uvicorn api.main:app --reload

4. Commit changes
   └─> git commit -am "Description"
```

### Production Deployment
```
1. Push to GitHub
   └─> git push origin main

2. CI Pipeline runs
   └─> Tests
   └─> Build Docker image
   └─> Push to registry

3. CD Pipeline runs
   └─> Deploy to K8s
   └─> Run smoke tests
   └─> Monitor

4. Verification
   └─> Check logs
   └─> Check metrics
   └─> Validate predictions
```

## Cost Optimization

### Current Implementation
- Multi-stage Docker builds (smaller images)
- Resource limits prevent overuse
- Auto-scaling based on demand

### Future Optimizations
- Spot instances for non-critical workloads
- Model caching
- Request batching
- GPU usage optimization

## Disaster Recovery

### Backup Strategy
- Code: Git repository
- Data: DVC with remote storage
- Models: MLflow artifact store
- Configs: Git repository

### Recovery Procedures
1. **Service Failure**: Automatic pod restart
2. **Deployment Failure**: Automatic rollback
3. **Data Loss**: Restore from DVC remote
4. **Total Failure**: Redeploy from Git + DVC

## Future Enhancements

### Model Management
- A/B testing framework
- Canary deployments
- Shadow deployments
- Model versioning in production

### Advanced Monitoring
- Data drift detection
- Model performance degradation alerts
- Custom dashboards (Grafana)
- Distributed tracing

### Infrastructure
- Multi-region deployment
- CDN for static assets
- Service mesh (Istio)
- GitOps with ArgoCD or Flux

### ML Operations
- Automated retraining pipelines
- Feature stores
- Model registry
- Automated hyperparameter tuning

---

This architecture provides a solid foundation for a production ML system with room for growth and enhancement.
