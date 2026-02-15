"""
Unit Tests for Data Preprocessing Module
Tests preprocessing functions for MNIST data
"""
import pytest
import numpy as np
import torch
from src.data_preprocessing import (
    preprocess_image,
    flatten_image,
    normalize_pixel_values,
    download_mnist_data,
    create_data_loaders
)


class TestPreprocessImage:
    """Test image preprocessing function"""
    
    def test_preprocess_flattened_image(self):
        """Test preprocessing of flattened 784-element array"""
        # Create random flattened image
        image = np.random.rand(784)
        
        # Preprocess
        result = preprocess_image(image)
        
        # Check output shape
        assert result.shape == (1, 1, 28, 28), f"Expected shape (1, 1, 28, 28), got {result.shape}"
        
        # Check it's a tensor
        assert isinstance(result, torch.Tensor), "Result should be a PyTorch tensor"
    
    def test_preprocess_2d_image(self):
        """Test preprocessing of 28x28 2D array"""
        # Create random 2D image
        image = np.random.rand(28, 28)
        
        # Preprocess
        result = preprocess_image(image)
        
        # Check output shape
        assert result.shape == (1, 1, 28, 28), f"Expected shape (1, 1, 28, 28), got {result.shape}"
        
        # Check it's a tensor
        assert isinstance(result, torch.Tensor), "Result should be a PyTorch tensor"
    
    def test_preprocess_normalization(self):
        """Test that preprocessing applies normalization"""
        # Create image with known values
        image = np.ones((28, 28)) * 0.5
        
        # Preprocess
        result = preprocess_image(image)
        
        # Check normalization was applied
        mean = 0.1307
        std = 0.3081
        expected = (0.5 - mean) / std
        
        # Allow for small floating point differences
        assert np.allclose(result.numpy(), expected, atol=1e-5), "Normalization not applied correctly"
    
    def test_preprocess_zeros(self):
        """Test preprocessing of zero image"""
        image = np.zeros((28, 28))
        
        # Should not raise an error
        result = preprocess_image(image)
        
        assert result.shape == (1, 1, 28, 28)
    
    def test_preprocess_ones(self):
        """Test preprocessing of image with all ones"""
        image = np.ones((28, 28))
        
        # Should not raise an error
        result = preprocess_image(image)
        
        assert result.shape == (1, 1, 28, 28)


class TestFlattenImage:
    """Test image flattening function"""
    
    def test_flatten_2d_image(self):
        """Test flattening of 2D image"""
        image = np.random.rand(28, 28)
        
        result = flatten_image(image)
        
        assert result.shape == (784,), f"Expected shape (784,), got {result.shape}"
    
    def test_flatten_3d_image(self):
        """Test flattening of 3D image with channel dimension"""
        image = np.random.rand(1, 28, 28)
        
        result = flatten_image(image)
        
        assert result.shape == (784,), f"Expected shape (784,), got {result.shape}"
    
    def test_flatten_already_flattened(self):
        """Test flattening of already flattened image"""
        image = np.random.rand(784)
        
        result = flatten_image(image)
        
        assert result.shape == (784,), f"Expected shape (784,), got {result.shape}"
    
    def test_flatten_preserves_values(self):
        """Test that flattening preserves values"""
        image = np.arange(784).reshape(28, 28)
        
        result = flatten_image(image)
        
        assert np.array_equal(result, np.arange(784)), "Flattening changed values"


class TestNormalizePixelValues:
    """Test pixel normalization function"""
    
    def test_normalize_to_0_1(self):
        """Test normalization to [0, 1] range"""
        image = np.array([0, 128, 255])
        
        result = normalize_pixel_values(image, min_val=0.0, max_val=1.0)
        
        assert result.min() == 0.0, "Minimum should be 0.0"
        assert result.max() == 1.0, "Maximum should be 1.0"
        assert np.allclose(result[1], 0.5019607843137255, atol=1e-5), "Mid value incorrect"
    
    def test_normalize_to_custom_range(self):
        """Test normalization to custom range"""
        image = np.array([0, 50, 100])
        
        result = normalize_pixel_values(image, min_val=-1.0, max_val=1.0)
        
        assert np.isclose(result.min(), -1.0, atol=1e-5), "Minimum should be -1.0"
        assert np.isclose(result.max(), 1.0, atol=1e-5), "Maximum should be 1.0"
    
    def test_normalize_constant_image(self):
        """Test normalization of constant image (all same values)"""
        image = np.ones((28, 28)) * 5.0
        
        result = normalize_pixel_values(image, min_val=0.0, max_val=1.0)
        
        # Should return zeros for constant image
        assert np.all(result == 0.0), "Constant image should normalize to zeros"
    
    def test_normalize_preserves_shape(self):
        """Test that normalization preserves shape"""
        image = np.random.rand(28, 28)
        
        result = normalize_pixel_values(image)
        
        assert result.shape == image.shape, "Shape should be preserved"


class TestDataLoading:
    """Test data loading functions"""
    
    @pytest.mark.slow
    def test_download_mnist_data(self):
        """Test MNIST data download (may be slow)"""
        train_dataset, test_dataset = download_mnist_data()
        
        assert len(train_dataset) == 60000, "Training set should have 60000 samples"
        assert len(test_dataset) == 10000, "Test set should have 10000 samples"
    
    @pytest.mark.slow
    def test_create_data_loaders(self):
        """Test data loader creation"""
        train_dataset, test_dataset = download_mnist_data()
        train_loader, test_loader = create_data_loaders(
            train_dataset, test_dataset, batch_size=32
        )
        
        # Check batch from train loader
        batch = next(iter(train_loader))
        images, labels = batch
        
        assert images.shape[0] == 32, "Batch size should be 32"
        assert images.shape[1:] == (1, 28, 28), "Image shape should be (1, 28, 28)"
        assert labels.shape[0] == 32, "Should have 32 labels"


class TestEdgeCases:
    """Test edge cases and error handling"""
    
    def test_negative_values(self):
        """Test preprocessing with negative values"""
        image = np.random.randn(28, 28)  # Can have negative values
        
        # Should not raise an error
        result = preprocess_image(image)
        
        assert result.shape == (1, 1, 28, 28)
    
    def test_large_values(self):
        """Test preprocessing with large values"""
        image = np.random.rand(28, 28) * 1000
        
        # Should not raise an error
        result = preprocess_image(image)
        
        assert result.shape == (1, 1, 28, 28)
    
    def test_normalize_small_range(self):
        """Test normalization with very small value range"""
        image = np.array([1.0, 1.0001, 1.0002])
        
        result = normalize_pixel_values(image)
        
        assert result.min() >= 0.0 and result.max() <= 1.0, "Should be in [0, 1] range"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
