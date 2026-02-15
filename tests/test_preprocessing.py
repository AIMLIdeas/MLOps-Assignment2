"""
Unit Tests for Data Preprocessing Module
Tests preprocessing functions for Cat/Dogs image data
"""
import pytest
import numpy as np
import torch
from src.data_preprocessing import (
    preprocess_image,
    load_cat_dogs_data,
    create_data_loaders,
    flatten_image,
    normalize_pixel_values
)


class TestPreprocessImage:
    """Test image preprocessing function for Cat/Dogs"""
    def test_preprocess_image_path(self, tmp_path):
        from PIL import Image
        import numpy as np
        # Create a dummy RGB image and save
        img = Image.fromarray(np.random.randint(0, 255, (128, 128, 3), dtype=np.uint8))
        img_path = tmp_path / "test.jpg"
        img.save(img_path)
        # Preprocess
        result = preprocess_image(str(img_path))
        # Check output shape
        assert result.shape == (1, 3, 128, 128), f"Expected shape (1, 3, 128, 128), got {result.shape}"
        assert isinstance(result, torch.Tensor)


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
    """Test data loading functions for Cat/Dogs"""
    @pytest.mark.slow
    def test_load_cat_dogs_data(self, tmp_path):
        # Create dummy directory structure: cat and dog folders with one image each
        import shutil
        from PIL import Image
        import numpy as np
        data_dir = tmp_path / "cat_dogs"
        train_dir = data_dir / "train"
        val_dir = data_dir / "val"
        (train_dir / "cat").mkdir(parents=True, exist_ok=True)
        (train_dir / "dog").mkdir(parents=True, exist_ok=True)
        (val_dir / "cat").mkdir(parents=True, exist_ok=True)
        (val_dir / "dog").mkdir(parents=True, exist_ok=True)
        # Create dummy images
        for split in [train_dir, val_dir]:
            for cls in ["cat", "dog"]:
                img = Image.fromarray(np.random.randint(0, 255, (128, 128, 3), dtype=np.uint8))
                img.save(split / cls / "img1.jpg")
        # Call the data loader with the dummy directory
        train_dataset, val_dataset = load_cat_dogs_data(data_dir=str(data_dir))
        assert hasattr(train_dataset, '__len__')
        assert hasattr(val_dataset, '__len__')
    @pytest.mark.slow
    def test_create_data_loaders(self, tmp_path):
        # Create dummy directory structure: cat and dog folders with one image each
        from PIL import Image
        import numpy as np
        data_dir = tmp_path / "cat_dogs"
        train_dir = data_dir / "train"
        val_dir = data_dir / "val"
        (train_dir / "cat").mkdir(parents=True, exist_ok=True)
        (train_dir / "dog").mkdir(parents=True, exist_ok=True)
        (val_dir / "cat").mkdir(parents=True, exist_ok=True)
        (val_dir / "dog").mkdir(parents=True, exist_ok=True)
        # Create dummy images
        for split in [train_dir, val_dir]:
            for cls in ["cat", "dog"]:
                img = Image.fromarray(np.random.randint(0, 255, (128, 128, 3), dtype=np.uint8))
                img.save(split / cls / "img1.jpg")
        # Call the data loader with the dummy directory
        train_dataset, val_dataset = load_cat_dogs_data(data_dir=str(data_dir))
        train_loader, val_loader = create_data_loaders(train_dataset, val_dataset, batch_size=2)
        batch = next(iter(train_loader))
        images, labels = batch
        assert images.shape[1:] == (3, 128, 128)
        assert images.shape[0] == 2, "Batch size should be 2"
        assert labels.shape[0] == 2, "Should have 2 labels"


class TestEdgeCases:
    """Test edge cases and error handling"""
    
    def test_negative_values(self, tmp_path):
        """Test preprocessing with negative values"""
        from PIL import Image
        import numpy as np
        # Create an image with negative values, clip to valid range for saving
        image = np.random.randint(-100, 100, (128, 128, 3), dtype=np.int32)
        image = np.clip(image, 0, 255).astype(np.uint8)
        img = Image.fromarray(image)
        img_path = tmp_path / "neg_test.jpg"
        img.save(img_path)
        result = preprocess_image(str(img_path))
        assert result.shape == (1, 3, 128, 128)
    
    def test_large_values(self, tmp_path):
        """Test preprocessing with large values"""
        from PIL import Image
        import numpy as np
        # Create an image with large values, clip to valid range for saving
        image = np.random.rand(128, 128, 3) * 1000
        image = np.clip(image, 0, 255).astype(np.uint8)
        img = Image.fromarray(image)
        img_path = tmp_path / "large_test.jpg"
        img.save(img_path)
        result = preprocess_image(str(img_path))
        assert result.shape == (1, 3, 128, 128)
    
    def test_normalize_small_range(self):
        """Test normalization with very small value range"""
        image = np.array([1.0, 1.0001, 1.0002])
        
        result = normalize_pixel_values(image)
        
        assert result.min() >= 0.0 and result.max() <= 1.0, "Should be in [0, 1] range"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
