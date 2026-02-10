"""
FastAPI Inference Service with Monitoring
Provides REST API for MNIST digit classification
"""
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator
import numpy as np
import time
import logging
from datetime import datetime
from typing import List, Optional
import os
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="MNIST Digit Classifier API",
    description="REST API for MNIST digit classification with monitoring",
    version="1.0.0"
)

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


class PredictionRequest(BaseModel):
    """Request model for prediction endpoint"""
    image: List[List[float]] = Field(
        ..., 
        description="28x28 image as 2D array or 784-element flattened array"
    )
    
    @field_validator('image')
    @classmethod
    def validate_image(cls, v):
        """Validate image dimensions"""
        arr = np.array(v)
        
        # Check if flattened (784,) or 2D (28, 28)
        if arr.shape == (784,):
            return v
        elif arr.shape == (28, 28):
            return v
        else:
            raise ValueError(
                f"Image must be either (28, 28) or (784,) shape, got {arr.shape}"
            )


class PredictionResponse(BaseModel):
    """Response model for prediction endpoint"""
    prediction: int = Field(..., description="Predicted digit (0-9)")
    probabilities: List[float] = Field(..., description="Probability for each class")
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
        from src.inference import ModelInference
        model_path = os.getenv('MODEL_PATH', 'models/mnist_cnn_model.pt')
        
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


@app.get("/", tags=["General"])
async def root():
    """Root endpoint"""
    return {
        "message": "MNIST Digit Classifier API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "predict": "/predict (POST)",
            "metrics": "/metrics",
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
        version="1.0.0"
    )


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
async def predict(request: PredictionRequest):
    """
    Prediction endpoint
    
    Accepts a 28x28 image and returns the predicted digit with probabilities
    
    Args:
        request: PredictionRequest containing the image data
        
    Returns:
        PredictionResponse with prediction, probabilities, and confidence
    """
    if model_inference is None or not model_inference.is_loaded():
        raise HTTPException(
            status_code=503, 
            detail="Model not loaded. Please try again later."
        )
    
    try:
        # Convert input to numpy array
        image_array = np.array(request.image, dtype=np.float32)
        
        # Log prediction request (without sensitive data)
        logger.info(f"Prediction request received - Image shape: {image_array.shape}")
        
        # Time inference
        start_time = time.time()
        
        # Make prediction
        result = model_inference.predict(image_array)
        
        # Calculate inference time
        inference_time_ms = (time.time() - start_time) * 1000
        
        # Record prediction metric
        PREDICTION_COUNT.labels(
            predicted_class=str(result['prediction'])
        ).inc()
        
        # Log prediction result
        logger.info(
            f"Prediction: {result['prediction']} - "
            f"Confidence: {result['confidence']:.4f} - "
            f"Inference time: {inference_time_ms:.2f}ms"
        )
        
        # Log to file for performance tracking
        log_prediction_to_file(
            prediction=result['prediction'],
            confidence=result['confidence'],
            inference_time_ms=inference_time_ms
        )
        
        return PredictionResponse(
            prediction=result['prediction'],
            probabilities=result['probabilities'],
            confidence=result['confidence'],
            inference_time_ms=inference_time_ms
        )
        
    except Exception as e:
        logger.error(f"Prediction failed: {str(e)}", exc_info=True)
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
            "prediction_distribution": stats.get("distribution", {}),
        }
    except Exception as e:
        logger.error(f"Failed to read stats: {str(e)}")
        return {
            "total_predictions": 0,
            "error": "Stats not available"
        }


def log_prediction_to_file(prediction: int, confidence: float, inference_time_ms: float):
    """
    Log prediction to file for performance tracking
    
    Args:
        prediction: Predicted class
        confidence: Confidence score
        inference_time_ms: Inference time in milliseconds
    """
    try:
        log_dir = "logs"
        os.makedirs(log_dir, exist_ok=True)
        
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "prediction": prediction,
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
                pred = entry["prediction"]
                predictions.append(pred)
                confidences.append(entry["confidence"])
                inference_times.append(entry["inference_time_ms"])
                
                distribution[str(pred)] = distribution.get(str(pred), 0) + 1
                
            except Exception as e:
                logger.error(f"Failed to parse log entry: {str(e)}")
                continue
    
    if not predictions:
        return {}
    
    return {
        "total": len(predictions),
        "avg_confidence": np.mean(confidences),
        "avg_inference_time": np.mean(inference_times),
        "distribution": distribution
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
