"""
Unit Tests for FastAPI Application
Tests API endpoints and functionality
"""
import pytest
from fastapi.testclient import TestClient
import numpy as np
from unittest.mock import Mock, patch, MagicMock


@pytest.fixture
def mock_model_inference():
    """Mock ModelInference for testing"""
    mock = MagicMock()
    mock.is_loaded.return_value = True
    mock.predict.return_value = {
        'prediction': 5,
        'probabilities': [0.05, 0.05, 0.05, 0.05, 0.05, 0.7, 0.01, 0.01, 0.01, 0.02],
        'confidence': 0.7
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
        """Test root endpoint returns API info or dashboard HTML"""
        response = client.get("/")
        assert response.status_code == 200
        content_type = response.headers.get('content-type', '')
        if 'application/json' in content_type:
            data = response.json()
            assert 'message' in data
            assert 'version' in data
            assert 'endpoints' in data
        elif 'text/html' in content_type:
            assert '<!DOCTYPE html>' in response.text or '<html' in response.text.lower()
        else:
            assert False, f"Unexpected content type: {content_type}"


class TestPredictEndpoint:
    """Test prediction endpoint"""
    
    def test_predict_success(self, client, mock_model_inference):
        """Test successful prediction"""
        # Create valid 28x28 image
        image = np.random.rand(28, 28).tolist()
        
        with patch('api.main.model_inference', mock_model_inference):
            response = client.post(
                "/predict",
                json={"image": image}
            )
            
            assert response.status_code == 200
            data = response.json()
            assert 'prediction' in data
            assert 'probabilities' in data
            assert 'confidence' in data
            assert 'inference_time_ms' in data
            assert data['prediction'] == 5
            assert len(data['probabilities']) == 10
    
    def test_predict_flattened_image(self, client, mock_model_inference):
        """Test prediction with flattened 784-element array"""
        # Create valid flattened image
        image = np.random.rand(784).tolist()
        
        with patch('api.main.model_inference', mock_model_inference):
            response = client.post(
                "/predict",
                json={"image": image}
            )
            
            assert response.status_code == 200
            data = response.json()
            assert 'prediction' in data
    
    def test_predict_invalid_shape(self, client):
        """Test prediction with invalid image shape"""
        # Create invalid image
        image = np.random.rand(20, 20).tolist()
        
        response = client.post(
            "/predict",
            json={"image": image}
        )
        
        assert response.status_code == 422  # Validation error
    
    def test_predict_model_not_loaded(self, client):
        """Test prediction when model is not loaded"""
        image = np.random.rand(28, 28).tolist()
        
        with patch('api.main.model_inference', None):
            response = client.post(
                "/predict",
                json={"image": image}
            )
            
            assert response.status_code == 503
            assert 'Model not loaded' in response.json()['detail']
    
    def test_predict_missing_image(self, client):
        """Test prediction without image data"""
        response = client.post(
            "/predict",
            json={}
        )
        
        assert response.status_code == 422  # Validation error


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


class TestRequestValidation:
    """Test request validation"""
    
    def test_invalid_json(self, client):
        """Test with invalid JSON"""
        response = client.post(
            "/predict",
            data="invalid json",
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 422
    
    def test_wrong_data_type(self, client):
        """Test with wrong data type"""
        response = client.post(
            "/predict",
            json={"image": "not a list"}
        )
        
        assert response.status_code == 422


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
