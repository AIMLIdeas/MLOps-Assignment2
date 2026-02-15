"""
Unit Tests for FastAPI Application
Tests API endpoints for Cats vs Dogs classification
"""
import pytest
from fastapi.testclient import TestClient
import numpy as np
from unittest.mock import Mock, patch, MagicMock
import base64
from io import BytesIO
from PIL import Image


@pytest.fixture
def mock_model_inference():
    """Mock ModelInference for testing"""
    mock = MagicMock()
    mock.is_loaded.return_value = True
    mock.predict.return_value = {
        'prediction': 1,
        'prediction_label': 'Dog',
        'probabilities': {'Cat': 0.2, 'Dog': 0.8},
        'confidence': 0.8
    }
    return mock


@pytest.fixture
def client(mock_model_inference):
    """Create test client with mocked model"""
    with patch('api.main.ModelInference', return_value=mock_model_inference):
        from api.main import app
        app.state.model_inference = mock_model_inference
        return TestClient(app)


class TestHealthEndpoint:
    """Test health check endpoint"""
    
    def test_health_check_healthy(self, client, mock_model_inference):
        """Test health check when model is loaded"""
        # Patch the global model_inference
        with patch('api.main.model_inference', mock_model_inference):
            response = client.get("/health")
            
            assert response.status_code == 200
            data = response.json()
            assert data['status'] == 'healthy'
            assert data['model_loaded'] is True
            assert 'timestamp' in data
            assert 'version' in data
    
    def test_health_check_degraded(self, client):
        """Test health check when model is not loaded"""
        with patch('api.main.model_inference', None):
            response = client.get("/health")
            
            assert response.status_code == 200
            data = response.json()
            assert data['status'] == 'degraded'
            assert data['model_loaded'] is False


class TestRootEndpoint:
    """Test root endpoint"""
    
    def test_root(self, client):
        """Test root endpoint returns API info"""
        response = client.get("/")
        
        assert response.status_code == 200
        data = response.json()
        assert 'message' in data
        assert 'version' in data
        assert 'endpoints' in data


class TestPredictEndpoint:
    """Test prediction endpoint"""
    
    def test_predict_with_file_upload(self, client, mock_model_inference):
        """Test successful prediction with file upload"""
        # Create a test image
        img = Image.new('RGB', (224, 224), color='red')
        img_bytes = BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        with patch('api.main.model_inference', mock_model_inference):
            response = client.post(
                "/predict",
                files={"file": ("test.png", img_bytes, "image/png")}
            )
        
        with patch('api.main.model_inference', mock_model_inference):
            response = client.post(
                "/predict",
                json={"image": image}
            )
            
            assert response.status_code == 200
            data = response.json()
            assert 'prediction' in data
            assert 'prediction_label' in data
            assert 'probabilities' in data
            assert 'confidence' in data
            assert 'inference_time_ms' in data
            assert data['prediction'] in [0, 1]
            assert data['prediction_label'] in ['Cat', 'Dog']
    
    def test_predict_base64(self, client, mock_model_inference):
        """Test prediction with base64 encoded image"""
        # Create a test image
        img = Image.new('RGB', (224, 224), color='blue')
        img_bytes = BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        # Encode to base64
        img_base64 = base64.b64encode(img_bytes.read()).decode('utf-8')
        
        with patch('api.main.model_inference', mock_model_inference):
            response = client.post(
                "/predict-base64",
                json={"image": img_base64}
            )
            
            assert response.status_code == 200
            data = response.json()
            assert 'prediction' in data
            assert 'prediction_label' in data
    
    def test_predict_model_not_loaded(self, client):
        """Test prediction when model is not loaded"""
        img = Image.new('RGB', (224, 224))
        img_bytes = BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        with patch('api.main.model_inference', None):
            response = client.post(
                "/predict",
                files={"file": ("test.png", img_bytes, "image/png")}
            )
            
            assert response.status_code == 503
            assert 'Model not loaded' in response.json()['detail']


class TestMetricsEndpoint:
    """Test metrics endpoint"""
    
    def test_metrics_endpoint(self, client):
        """Test Prometheus metrics endpoint"""
        response = client.get("/metrics")
        
        assert response.status_code == 200
        # Prometheus metrics should be in text format
        assert 'text/plain' in response.headers['content-type'] or \
               'text/plain; version=0.0.4' in response.headers['content-type']


class TestStatsEndpoint:
    """Test statistics endpoint"""
    
    def test_stats_endpoint(self, client):
        """Test stats endpoint"""
        response = client.get("/stats")
        
        assert response.status_code == 200
        data = response.json()
        assert 'total_predictions' in data
        assert 'class_distribution' in data


class TestModelInfoEndpoint:
    """Test model info endpoint"""
    
    def test_model_info(self, client):
        """Test model info endpoint"""
        response = client.get("/model-info")
        
        assert response.status_code == 200
        data = response.json()
        assert 'model_type' in data
        assert 'task' in data
        assert 'num_classes' in data


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

