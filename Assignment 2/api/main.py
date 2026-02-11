"""
FastAPI Inference Service with Monitoring
Provides REST API for MNIST digit classification
"""
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, field_validator
import numpy as np
import time
import logging
from datetime import datetime
from typing import List, Optional, Union
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
    title="MNIST Digit Classifier API",
    description="REST API for MNIST digit classification with monitoring",
    version="1.0.0"
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


class PredictionRequest(BaseModel):
    """Request model for prediction endpoint"""
    image: Union[List[float], List[List[float]]] = Field(
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


@app.get("/", response_class=HTMLResponse, tags=["General"])
async def root():
    """Serve the UI dashboard"""
    static_file = os.path.join(os.path.dirname(__file__), "static", "index.html")
    if os.path.exists(static_file):
        with open(static_file, "r") as f:
            return HTMLResponse(content=f.read())
    
    # Fallback if static file not found
    return {
        "message": "MNIST Digit Classifier API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "predict": "/predict (POST)",
            "model-info": "/model-info",
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
        }
    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        return {
            "total_predictions": 0,
            "average_confidence": 0.0,
            "average_inference_time_ms": 0.0
        }


@app.get("/model-info", tags=["General"])
async def model_info():
    """Get detailed model information"""
    try:
        # Get model architecture info if available
        model_details = {
            "model_type": "Convolutional Neural Network (CNN)",
            "version": "1.0.0",
            "api_version": "1.0.0",
            "input_size": "28x28 pixels",
            "num_classes": "10 (digits 0-9)",
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
                model_path = os.getenv('MODEL_PATH', 'models/mnist_cnn_model.pt')
                if os.path.exists(model_path):
                    size_bytes = os.path.getsize(model_path)
                    size_mb = size_bytes / (1024 * 1024)
                    model_details["model_size"] = f"{size_mb:.2f} MB"
                
            except Exception as e:
                logger.error(f"Error getting model details: {e}")
                model_details["model_loaded"] = False
        else:
            model_details["model_loaded"] = False
        
        # Add placeholder metrics (you can replace with actual training metrics)
        model_details.update({
            "accuracy": "98.5%",
            "epochs": "10",
            "dataset": "MNIST",
            "training_samples": "60,000",
            "test_samples": "10,000"
        })
        
        return model_details
        
    except Exception as e:
        logger.error(f"Error in model-info endpoint: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


class ImagePredictionRequest(BaseModel):
    """Request model for image-based prediction"""
    image: str = Field(..., description="Base64 encoded image")


@app.post("/predict-image", tags=["Prediction"])
async def predict_image(request: ImagePredictionRequest):
    """
    Predict digit from base64 encoded image (e.g., from canvas drawing)
    
    Args:
        request: ImagePredictionRequest with base64 image
        
    Returns:
        Prediction with confidence score
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
        
        # Convert to grayscale
        image = image.convert('L')
        
        # Resize to 28x28
        image = image.resize((28, 28), Image.Resampling.LANCZOS)
        
        # Convert to numpy array and normalize
        image_array = np.array(image, dtype=np.float32)
        
        # Invert colors (canvas is black on white, MNIST is white on black)
        image_array = 255 - image_array
        
        # Normalize to [0, 1]
        image_array = image_array / 255.0
        
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
        
        logger.info(
            f"Image prediction: {result['prediction']} - "
            f"Confidence: {result['confidence']:.4f}"
        )
        
        return {
            "prediction": result['prediction'],
            "confidence": result['confidence'],
            "probabilities": result['probabilities'],
            "inference_time_ms": inference_time_ms
        }
        
    except Exception as e:
        logger.error(f"Image prediction failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


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
