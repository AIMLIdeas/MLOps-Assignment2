"""
Unit Tests for Model Inference Module
Tests model loading and prediction functions
"""
import pytest
import numpy as np
import torch
import os
from unittest.mock import Mock, patch, MagicMock
from src.inference import (
    ModelInference,
    load_model_for_inference,
    get_prediction_with_confidence
)


class TestModelInference:
    """Test ModelInference class"""
    
    @pytest.fixture
    def mock_model(self):
        """Create a mock model"""
        mock = MagicMock()
        mock.eval = Mock()
        mock.to = Mock(return_value=mock)
        return mock
    
    @pytest.fixture
    def mock_model_path(self, tmp_path):
        """Create a temporary model file"""
        model_path = tmp_path / "test_model.pt"
        
        # Create a simple state dict
        state_dict = {
            'conv1.weight': torch.randn(32, 1, 3, 3),
            'conv1.bias': torch.randn(32)
        }
        torch.save(state_dict, model_path)
        
        return str(model_path)
    
    def test_model_not_found(self):
        """Test error when model file doesn't exist"""
        with pytest.raises(FileNotFoundError):
            ModelInference(model_path='nonexistent_model.pt')
    
    @patch('src.inference.MNISTBasicCNN')
    @patch('src.inference.torch.load')
    @patch('src.inference.os.path.exists')
    def test_model_loading(self, mock_exists, mock_torch_load, mock_cnn):
        """Test model loading"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_cnn.return_value = mock_model
        mock_torch_load.return_value = {}
        
        # Create inference handler
        inference = ModelInference(model_path='test_model.pt')
        
        # Verify model was initialized and loaded
        assert inference.model is not None
        mock_cnn.assert_called_once()
        mock_torch_load.assert_called_once()
    
    @patch('src.inference.MNISTBasicCNN')
    @patch('src.inference.torch.load')
    @patch('src.inference.os.path.exists')
    def test_is_loaded(self, mock_exists, mock_torch_load, mock_cnn):
        """Test is_loaded method"""
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_cnn.return_value = mock_model
        mock_torch_load.return_value = {}
        
        inference = ModelInference(model_path='test_model.pt')
        
        assert inference.is_loaded() is True
    
    @patch('src.inference.MNISTBasicCNN')
    @patch('src.inference.torch.load')
    @patch('src.inference.os.path.exists')
    @patch('src.inference.preprocess_image')
    def test_predict(self, mock_preprocess, mock_exists, mock_torch_load, mock_cnn):
        """Test prediction method"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_cnn.return_value = mock_model
        mock_torch_load.return_value = {}
        
        # Mock prediction output
        mock_output = torch.randn(1, 10)
        mock_model.return_value = mock_output
        
        # Mock preprocessed image
        mock_tensor = torch.randn(1, 1, 28, 28)
        mock_preprocess.return_value = mock_tensor
        
        # Create inference handler
        inference = ModelInference(model_path='test_model.pt')
        
        # Make prediction
        image = np.random.rand(28, 28)
        result = inference.predict(image)
        
        # Verify result structure
        assert 'prediction' in result
        assert 'probabilities' in result
        assert 'confidence' in result
        assert isinstance(result['prediction'], int)
        assert isinstance(result['probabilities'], list)
        assert isinstance(result['confidence'], float)
        assert len(result['probabilities']) == 10
    
    @patch('src.inference.MNISTBasicCNN')
    @patch('src.inference.torch.load')
    @patch('src.inference.os.path.exists')
    def test_predict_without_loaded_model(self, mock_exists, mock_torch_load, mock_cnn):
        """Test prediction fails when model not loaded"""
        mock_exists.return_value = True
        mock_cnn.return_value = MagicMock()
        mock_torch_load.return_value = {}
        
        inference = ModelInference(model_path='test_model.pt')
        inference.model = None  # Simulate model not loaded
        
        with pytest.raises(RuntimeError):
            inference.predict(np.random.rand(28, 28))


class TestPredictionFunctions:
    """Test helper prediction functions"""
    
    @patch('src.inference.ModelInference')
    def test_load_model_for_inference(self, mock_model_inference):
        """Test load_model_for_inference function"""
        mock_instance = MagicMock()
        mock_model_inference.return_value = mock_instance
        
        result = load_model_for_inference('test_model.pt')
        
        assert result == mock_instance
        mock_model_inference.assert_called_once_with('test_model.pt')
    
    def test_get_prediction_with_confidence_high(self):
        """Test get_prediction_with_confidence with high confidence"""
        # Mock model inference
        mock_inference = MagicMock()
        mock_inference.predict.return_value = {
            'prediction': 5,
            'probabilities': [0.01] * 10,
            'confidence': 0.95
        }
        
        result = get_prediction_with_confidence(
            mock_inference, 
            np.random.rand(28, 28),
            confidence_threshold=0.8
        )
        
        assert result['prediction'] == 5
        assert result['high_confidence'] is True
        assert result['threshold'] == 0.8
    
    def test_get_prediction_with_confidence_low(self):
        """Test get_prediction_with_confidence with low confidence"""
        # Mock model inference
        mock_inference = MagicMock()
        mock_inference.predict.return_value = {
            'prediction': 3,
            'probabilities': [0.1] * 10,
            'confidence': 0.5
        }
        
        result = get_prediction_with_confidence(
            mock_inference,
            np.random.rand(28, 28),
            confidence_threshold=0.8
        )
        
        assert result['prediction'] == 3
        assert result['high_confidence'] is False
        assert result['threshold'] == 0.8


class TestPredictionOutput:
    """Test prediction output validation"""
    
    @patch('src.inference.MNISTBasicCNN')
    @patch('src.inference.torch.load')
    @patch('src.inference.os.path.exists')
    @patch('src.inference.preprocess_image')
    def test_prediction_output_range(self, mock_preprocess, mock_exists, mock_torch_load, mock_cnn):
        """Test that prediction is in valid range (0-9)"""
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_cnn.return_value = mock_model
        mock_torch_load.return_value = {}
        
        # Mock prediction for digit 7
        logits = torch.zeros(1, 10)
        logits[0, 7] = 10.0  # High value for class 7
        mock_model.return_value = logits
        
        mock_tensor = torch.randn(1, 1, 28, 28)
        mock_preprocess.return_value = mock_tensor
        
        inference = ModelInference(model_path='test_model.pt')
        result = inference.predict(np.random.rand(28, 28))
        
        assert 0 <= result['prediction'] <= 9, "Prediction should be between 0 and 9"
    
    @patch('src.inference.MNISTBasicCNN')
    @patch('src.inference.torch.load')
    @patch('src.inference.os.path.exists')
    @patch('src.inference.preprocess_image')
    def test_probabilities_sum_to_one(self, mock_preprocess, mock_exists, mock_torch_load, mock_cnn):
        """Test that probabilities sum to approximately 1.0"""
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_cnn.return_value = mock_model
        mock_torch_load.return_value = {}
        
        mock_output = torch.randn(1, 10)
        mock_model.return_value = mock_output
        
        mock_tensor = torch.randn(1, 1, 28, 28)
        mock_preprocess.return_value = mock_tensor
        
        inference = ModelInference(model_path='test_model.pt')
        result = inference.predict(np.random.rand(28, 28))
        
        prob_sum = sum(result['probabilities'])
        assert np.isclose(prob_sum, 1.0, atol=1e-5), "Probabilities should sum to 1.0"
    
    @patch('src.inference.MNISTBasicCNN')
    @patch('src.inference.torch.load')
    @patch('src.inference.os.path.exists')
    @patch('src.inference.preprocess_image')
    def test_confidence_matches_max_probability(self, mock_preprocess, mock_exists, mock_torch_load, mock_cnn):
        """Test that confidence equals max probability"""
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_cnn.return_value = mock_model
        mock_torch_load.return_value = {}
        
        mock_output = torch.randn(1, 10)
        mock_model.return_value = mock_output
        
        mock_tensor = torch.randn(1, 1, 28, 28)
        mock_preprocess.return_value = mock_tensor
        
        inference = ModelInference(model_path='test_model.pt')
        result = inference.predict(np.random.rand(28, 28))
        
        max_prob = max(result['probabilities'])
        assert np.isclose(result['confidence'], max_prob, atol=1e-5), \
            "Confidence should equal maximum probability"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
