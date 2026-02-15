"""
FastAPI Inference Service with Monitoring
Provides REST API for Cats vs Dogs classification for pet adoption platform
"""
from fastapi import FastAPI, HTTPException, Request, File, UploadFile
from fastapi.responses import JSONResponse, FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, field_validator
import numpy as np
import time
import logging
from datetime import datetime
from typing import List, Optional, Union, Dict
import os
import base64
import io
from PIL import Image
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import json
from src.inference import ModelInference

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Cats vs Dogs Classifier API",
    description="REST API for Cats vs Dogs classification for pet adoption platform",
    version="2.0.0"
)

# Mount static files
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Store start time for uptime calculation
START_TIME = datetime.utcnow()

# Prometheus metrics
REQUEST_COUNT = Counter(
    'api_requests_total', 
    'Total API requests', 
    ['endpoint', 'method', 'status']
)
REQUEST_LATENCY = Histogram(
    'api_request_latency_seconds', 
    'API request latency',
    ['endpoint']
)
PREDICTION_COUNT = Counter(
    'predictions_total', 
    'Total predictions made',
    ['predicted_class']
)

# Global model instance
model_inference = None


class PredictionResponse(BaseModel):
    """Response model for prediction endpoint"""
    prediction: int = Field(..., description="Predicted class (0=Cat, 1=Dog)")
    prediction_label: str = Field(..., description="Predicted class label")
    probabilities: Dict[str, float] = Field(..., description="Probability for each class")
    confidence: float = Field(..., description="Confidence score of prediction")
    inference_time_ms: float = Field(..., description="Inference time in milliseconds")


class HealthResponse(BaseModel):
    """Response model for health endpoint"""
    status: str
    model_loaded: bool
    timestamp: str
    version: str


@app.on_event("startup")
async def load_model():
    """Load model on startup"""
    global model_inference
    
    try:
        model_path = os.getenv('MODEL_PATH', 'models/cats_dogs_cnn_model.pt')
        
        logger.info(f"Loading model from {model_path}")
        model_inference = ModelInference(model_path)
        logger.info("Model loaded successfully")
        
    except Exception as e:
        logger.error(f"Failed to load model: {str(e)}")
        logger.warning("API will start but predictions will fail until model is loaded")


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Middleware to log all requests and track metrics"""
    start_time = time.time()
    
    # Log request
    logger.info(f"Request: {request.method} {request.url.path}")
    
    # Process request
    response = await call_next(request)
    
    # Calculate latency
    latency = time.time() - start_time
    
    # Record metrics
    REQUEST_COUNT.labels(
        endpoint=request.url.path,
        method=request.method,
        status=response.status_code
    ).inc()
    
    REQUEST_LATENCY.labels(
        endpoint=request.url.path
    ).observe(latency)
    
    # Log response
    logger.info(
        f"Response: {request.method} {request.url.path} - "
        f"Status: {response.status_code} - Latency: {latency:.3f}s"
    )
    
    return response


@app.get("/", response_class=HTMLResponse, tags=["General"])
async def root():
    """Serve the UI dashboard"""
    static_file = os.path.join(os.path.dirname(__file__), "static", "index.html")
    if os.path.exists(static_file):
        with open(static_file, "r") as f:
            return HTMLResponse(content=f.read())
    
    # Fallback if static file not found
    return {
        "message": "Cats vs Dogs Classifier API for Pet Adoption Platform",
        "version": "2.0.0",
        "task": "Binary Image Classification",
        "endpoints": {
            "health": "/health",
            "predict (file upload)": "/predict (POST)",
            "predict (base64)": "/predict-base64 (POST)",
            "model-info": "/model-info",
            "metrics": "/metrics",
            "stats": "/stats",
            "docs": "/docs"
        }
    }


@app.get("/health", response_model=HealthResponse, tags=["General"])
async def health_check():
    """
    Health check endpoint
    Returns API health status and model loading state
    """
    model_loaded = model_inference is not None and model_inference.is_loaded()
    
    return HealthResponse(
        status="healthy" if model_loaded else "degraded",
        model_loaded=model_loaded,
        timestamp=datetime.utcnow().isoformat(),
        version="2.0.0"
    )


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
async def predict(file: UploadFile = File(..., description="Image file (JPEG, PNG)")):
    """
    Prediction endpoint with file upload
    
    Accepts an image file and returns the predicted class (Cat or Dog)
    
    Args:
        file: Uploaded image file
        
    Returns:
        PredictionResponse with prediction, probabilities, and confidence
    """
    if model_inference is None or not model_inference.is_loaded():
        raise HTTPException(
            status_code=503, 
            detail="Model not loaded. Please try again later."
        )
    
    try:
        # Read image file
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes))
        
        # Log prediction request
        logger.info(f"Prediction request received - Image format: {image.format}, Size: {image.size}")
        
        # Time inference
        start_time = time.time()
        
        # Make prediction
        result = model_inference.predict(image)
        
        # Calculate inference time
        inference_time_ms = (time.time() - start_time) * 1000
        
        # Record prediction metric
        PREDICTION_COUNT.labels(
            predicted_class=result['prediction_label']
        ).inc()
        
        # Log prediction result
        logger.info(
            f"Prediction: {result['prediction_label']} ({result['prediction']}) - "
            f"Confidence: {result['confidence']:.4f} - "
            f"Inference time: {inference_time_ms:.2f}ms"
        )
        
        # Log to file for performance tracking
        log_prediction_to_file(
            prediction=result['prediction'],
            prediction_label=result['prediction_label'],
            confidence=result['confidence'],
            inference_time_ms=inference_time_ms
        )
        
        return PredictionResponse(
            prediction=result['prediction'],
            prediction_label=result['prediction_label'],
            probabilities=result['probabilities'],
            confidence=result['confidence'],
            inference_time_ms=inference_time_ms
        )
        
    except Exception as e:
        logger.error(f"Prediction failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


class Base64ImageRequest(BaseModel):
    """Request model for base64 encoded image"""
    image: str = Field(..., description="Base64 encoded image")


@app.post("/predict-base64", response_model=PredictionResponse, tags=["Prediction"])
async def predict_base64(request: Base64ImageRequest):
    """
    Prediction endpoint with base64 encoded image
    
    Accepts a base64 encoded image and returns the predicted class
    
    Args:
        request: Base64ImageRequest with base64 encoded image
        
    Returns:
        PredictionResponse with prediction, probabilities, and confidence
    """
    if model_inference is None or not model_inference.is_loaded():
        raise HTTPException(
            status_code=503, 
            detail="Model not loaded. Please try again later."
        )
    
    try:
        # Decode base64 image
        image_data = base64.b64decode(request.image)
        image = Image.open(io.BytesIO(image_data))
        
        # Log prediction request
        logger.info(f"Base64 prediction request - Image size: {image.size}")
        
        # Time inference
        start_time = time.time()
        
        # Make prediction
        result = model_inference.predict(image)
        
        # Calculate inference time
        inference_time_ms = (time.time() - start_time) * 1000
        
        # Record prediction metric
        PREDICTION_COUNT.labels(
            predicted_class=result['prediction_label']
        ).inc()
        
        logger.info(
            f"Prediction: {result['prediction_label']} - "
            f"Confidence: {result['confidence']:.4f}"
        )
        
        # Log to file
        log_prediction_to_file(
            prediction=result['prediction'],
            prediction_label=result['prediction_label'],
            confidence=result['confidence'],
            inference_time_ms=inference_time_ms
        )
        
        return PredictionResponse(
            prediction=result['prediction'],
            prediction_label=result['prediction_label'],
            probabilities=result['probabilities'],
            confidence=result['confidence'],
            inference_time_ms=inference_time_ms
        )
        
    except Exception as e:
        logger.error(f"Base64 prediction failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    """
    Prometheus metrics endpoint
    Returns metrics in Prometheus format
    """
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/stats", tags=["Monitoring"])
async def get_stats():
    """
    Get basic statistics about predictions
    """
    try:
        stats = read_prediction_stats()
        return {
            "total_predictions": stats.get("total", 0),
            "average_confidence": stats.get("avg_confidence", 0.0),
            "average_inference_time_ms": stats.get("avg_inference_time", 0.0),
            "class_distribution": stats.get("distribution", {})
        }
    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        return {
            "total_predictions": 0,
            "average_confidence": 0.0,
            "average_inference_time_ms": 0.0,
            "class_distribution": {}
        }


@app.get("/model-info", tags=["General"])
async def model_info():
    """Get detailed model information"""
    try:
        # Get model architecture info
        model_details = {
            "model_type": "Convolutional Neural Network (CNN)",
            "version": "2.0.0",
            "api_version": "2.0.0",
            "task": "Binary Image Classification",
            "application": "Pet Adoption Platform - Cat vs Dog Classifier",
            "input_size": "224x224 RGB",
            "num_classes": "2 (Cat, Dog)",
            "class_mapping": {"0": "Cat", "1": "Dog"},
            "framework": "PyTorch",
            "start_time": START_TIME.isoformat(),
            "uptime_seconds": (datetime.utcnow() - START_TIME).total_seconds(),
        }
        
        # Add model-specific info if model is loaded
        if model_inference and model_inference.is_loaded():
            try:
                import torch
                model = model_inference.model
                
                # Count parameters
                total_params = sum(p.numel() for p in model.parameters())
                trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
                
                model_details.update({
                    "total_parameters": f"{total_params:,}",
                    "trainable_parameters": f"{trainable_params:,}",
                    "model_loaded": True,
                })
                
                # Try to get model file size
                model_path = os.getenv('MODEL_PATH', 'models/cats_dogs_cnn_model.pt')
                if os.path.exists(model_path):
                    size_bytes = os.path.getsize(model_path)
                    size_mb = size_bytes / (1024 * 1024)
                    model_details["model_size"] = f"{size_mb:.2f} MB"
                
            except Exception as e:
                logger.error(f"Error getting model details: {e}")
                model_details["model_loaded"] = False
        else:
            model_details["model_loaded"] = False
        
        # Add dataset and training info
        model_details.update({
            "dataset": "Kaggle Cats and Dogs Dataset",
            "dataset_source": "bhavikjikadara/dog-and-cat-classification-dataset",
            "training_samples": "~20,000 (80%)",
            "validation_samples": "~2,500 (10%)",
            "test_samples": "~2,500 (10%)",
            "data_augmentation": "RandomCrop, HorizontalFlip, Rotation, ColorJitter"
        })
        
        return model_details
        
    except Exception as e:
        logger.error(f"Error in model-info endpoint: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


def log_prediction_to_file(prediction: int, prediction_label: str, confidence: float, inference_time_ms: float):
    """
    Log prediction to file for performance tracking
    
    Args:
        prediction: Predicted class (0 or 1)
        prediction_label: Predicted class label
        confidence: Confidence score
        inference_time_ms: Inference time in milliseconds
    """
    try:
        log_dir = "logs"
        os.makedirs(log_dir, exist_ok=True)
        
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "prediction": prediction,
            "prediction_label": prediction_label,
            "confidence": confidence,
            "inference_time_ms": inference_time_ms
        }
        
        log_file = os.path.join(log_dir, "predictions.jsonl")
        with open(log_file, "a") as f:
            f.write(json.dumps(log_entry) + "\n")
            
    except Exception as e:
        logger.error(f"Failed to log prediction to file: {str(e)}")


def read_prediction_stats():
    """
    Read and compute statistics from prediction logs
    
    Returns:
        Dictionary with prediction statistics
    """
    log_file = "logs/predictions.jsonl"
    
    if not os.path.exists(log_file):
        return {}
    
    predictions = []
    confidences = []
    inference_times = []
    distribution = {}
    
    with open(log_file, "r") as f:
        for line in f:
            try:
                entry = json.loads(line.strip())
                pred_label = entry.get("prediction_label", str(entry["prediction"]))
                predictions.append(pred_label)
                confidences.append(entry["confidence"])
                inference_times.append(entry["inference_time_ms"])
                
                distribution[pred_label] = distribution.get(pred_label, 0) + 1
                
            except Exception as e:
                logger.error(f"Failed to parse log entry: {str(e)}")
                continue
    
    if not predictions:
        return {}
    
    return {
        "total": len(predictions),
        "avg_confidence": float(np.mean(confidences)),
        "avg_inference_time": float(np.mean(inference_times)),
        "distribution": distribution
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

