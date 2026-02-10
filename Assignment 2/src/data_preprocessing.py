"""
Data Preprocessing Module
Handles loading and preprocessing MNIST data
"""
import numpy as np
import torch
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
import os


def download_mnist_data(data_dir='data/raw'):
    """
    Download MNIST dataset
    
    Args:
        data_dir: Directory to save raw data
        
    Returns:
        train_dataset, test_dataset
    """
    os.makedirs(data_dir, exist_ok=True)
    
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    train_dataset = datasets.MNIST(
        data_dir, 
        train=True, 
        download=True, 
        transform=transform
    )
    
    test_dataset = datasets.MNIST(
        data_dir, 
        train=False, 
        download=True,
        transform=transform
    )
    
    return train_dataset, test_dataset


def create_data_loaders(train_dataset, test_dataset, batch_size=64):
    """
    Create train and test data loaders
    
    Args:
        train_dataset: Training dataset
        test_dataset: Test dataset
        batch_size: Batch size for training
        
    Returns:
        train_loader, test_loader
    """
    train_loader = DataLoader(
        train_dataset, 
        batch_size=batch_size, 
        shuffle=True
    )
    
    test_loader = DataLoader(
        test_dataset, 
        batch_size=batch_size, 
        shuffle=False
    )
    
    return train_loader, test_loader


def preprocess_image(image_array):
    """
    Preprocess a single image for inference
    
    Args:
        image_array: numpy array of shape (28, 28) or (784,)
        
    Returns:
        Preprocessed tensor of shape (1, 1, 28, 28)
    """
    # Reshape if flattened
    if len(image_array.shape) == 1:
        image_array = image_array.reshape(28, 28)
    
    # Normalize using MNIST statistics
    mean = 0.1307
    std = 0.3081
    image_array = (image_array - mean) / std
    
    # Convert to tensor and add batch and channel dimensions
    image_tensor = torch.FloatTensor(image_array)
    image_tensor = image_tensor.unsqueeze(0).unsqueeze(0)  # (1, 1, 28, 28)
    
    return image_tensor


def flatten_image(image_array):
    """
    Flatten image array for simple models
    
    Args:
        image_array: numpy array of shape (28, 28) or (1, 28, 28)
        
    Returns:
        Flattened array of shape (784,)
    """
    return image_array.flatten()


def normalize_pixel_values(image_array, min_val=0.0, max_val=1.0):
    """
    Normalize pixel values to specified range
    
    Args:
        image_array: Input image array
        min_val: Minimum value
        max_val: Maximum value
        
    Returns:
        Normalized image array
    """
    image_min = image_array.min()
    image_max = image_array.max()
    
    if image_max - image_min == 0:
        return np.zeros_like(image_array)
    
    normalized = (image_array - image_min) / (image_max - image_min)
    normalized = normalized * (max_val - min_val) + min_val
    
    return normalized


def save_processed_data(data, filepath):
    """
    Save processed data to disk
    
    Args:
        data: Data to save
        filepath: Path to save file
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    np.save(filepath, data)
    print(f"Saved processed data to {filepath}")


def load_processed_data(filepath):
    """
    Load processed data from disk
    
    Args:
        filepath: Path to data file
        
    Returns:
        Loaded data
    """
    return np.load(filepath)
