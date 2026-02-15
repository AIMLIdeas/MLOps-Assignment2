"""
Unit Tests for Data Preprocessing Module
Tests preprocessing functions for Cats vs Dogs classification
"""
import pytest
import numpy as np
import torch
from PIL import Image
from src.data_preprocessing import (
    preprocess_image,
    normalize_pixel_values,
    get_data_transforms
)


class TestPreprocessImage:
    """Test image preprocessing function"""
    
    def test_preprocess_pil_image(self):
        """Test preprocessing of PIL Image"""
        # Create a random RGB image
        image = Image.new('RGB', (256, 256))
        
        # Preprocess
        result = preprocess_image(image)
        
        # Check output shape (1, 3, 224, 224)
        assert result.shape == (1, 3, 224, 224), f"Expected shape (1, 3, 224, 224), got {result.shape}"
        
        # Check it's a tensor
        assert isinstance(result, torch.Tensor), "Result should be a PyTorch tensor"
    
    def test_preprocess_numpy_array(self):
        """Test preprocessing of numpy array"""
        # Create random RGB numpy array
        image = np.random.rand(224, 224, 3)
        
        # Preprocess
        result = preprocess_image(image)
        
        # Check output shape
        assert result.shape == (1, 3, 224, 224), f"Expected shape (1, 3, 224, 224), got {result.shape}"
        
        # Check it's a tensor
        assert isinstance(result, torch.Tensor), "Result should be a PyTorch tensor"
    
    def test_preprocess_different_size(self):
        """Test preprocessing resizes images correctly"""
        # Create image with different size
        image = Image.new('RGB', (512, 512))
        
        # Preprocess
        result = preprocess_image(image)
        
        # Check it was resized to 224x224
        assert result.shape == (1, 3, 224, 224), "Image should be resized to 224x224"
    
    def test_preprocess_grayscale_conversion(self):
        """Test that grayscale images are converted to RGB"""
        # Create grayscale image
        image = Image.new('L', (256, 256))
        
        # Preprocess
        result = preprocess_image(image)
        
        # Should have 3 channels
        assert result.shape[1] == 3, "Grayscale image should be converted to RGB"
    
    def test_preprocess_normalization(self):
        """Test that preprocessing applies ImageNet normalization"""
        # Create image with known values
        image = np.ones((224, 224, 3)) * 0.5
        
        # Preprocess
        result = preprocess_image(image)
        
        # Check that values are normalized (not in [0, 1] range)
        assert result.min() < 0 or result.max() > 1, "ImageNet normalization should be applied"


class TestGetDataTransforms:
    """Test data transforms function"""
    
    def test_get_transforms_with_augmentation(self):
        """Test getting transforms with augmentation"""
        train_transform, val_transform = get_data_transforms(augment=True)
        
        assert train_transform is not None
        assert val_transform is not None
    
    def test_get_transforms_without_augmentation(self):
        """Test getting transforms without augmentation"""
        train_transform, val_transform = get_data_transforms(augment=False)
        
        assert train_transform is not None
        assert val_transform is not None
    
    def test_flatten_already_flattened(self):
        """Test flattening of already flattened image"""


class TestNormalizePixelValues:
    """Test pixel normalization function"""
    
    def test_normalize_to_0_1(self):
        """Test normalization to [0, 1] range"""
        image = np.array([0, 128, 255])
        
        result = normalize_pixel_values(image, min_val=0.0, max_val=1.0)
        
        assert result.min() == 0.0, "Minimum should be 0.0"
        assert result.max() == 1.0, "Maximum should be 1.0"
    
    def test_normalize_to_custom_range(self):
        """Test normalization to custom range"""
        image = np.array([0, 50, 100])
        
        result = normalize_pixel_values(image, min_val=-1.0, max_val=1.0)
        
        assert np.isclose(result.min(), -1.0, atol=1e-5), "Minimum should be -1.0"
        assert np.isclose(result.max(), 1.0, atol=1e-5), "Maximum should be 1.0"
    
    def test_normalize_constant_image(self):
        """Test normalization of constant image (all same values)"""
        image = np.ones((224, 224, 3)) * 5.0
        
        result = normalize_pixel_values(image, min_val=0.0, max_val=1.0)
        
        # Should return zeros for constant image
        assert np.all(result == 0.0), "Constant image should normalize to zeros"


class TestEdgeCases:
    """Test edge cases and error handling"""
    
    def test_negative_values(self):
        """Test preprocessing with negative values"""
        image = np.random.randn(224, 224, 3)  # Can have negative values
        
        # Should not raise an error
        result = preprocess_image(image)
        
        assert result.shape == (1, 3, 224, 224)
    
    def test_large_values(self):
        """Test preprocessing with large values"""
        image = np.random.rand(224, 224, 3) * 1000
        
        # Should not raise an error
        result = preprocess_image(image)
        
        assert result.shape == (1, 3, 224, 224)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

