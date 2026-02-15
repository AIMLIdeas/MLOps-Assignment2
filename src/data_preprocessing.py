"""
Data Preprocessing Module
Handles loading and preprocessing Cat/Dogs image data
"""
import numpy as np
import torch
from torchvision import datasets, transforms
from torchvision.datasets import ImageFolder
from PIL import Image
from torch.utils.data import DataLoader
import os
import ssl
import urllib.request

# Fix SSL certificate verification issue on macOS
ssl._create_default_https_context = ssl._create_unverified_context



def load_cat_dogs_data(data_dir='data/raw/cat_dogs', img_size=128):
    """
    Load Cat/Dogs dataset using ImageFolder structure:
    data_dir/
        train/
            cats/
            dogs/
        val/
            cats/
            dogs/
    Args:
        data_dir: Root directory containing train/val folders
        img_size: Image resize size
    Returns:
        train_dataset, val_dataset
    """
    train_dir = os.path.join(data_dir, 'train')
    val_dir = os.path.join(data_dir, 'val')
    transform = transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])
    train_dataset = ImageFolder(train_dir, transform=transform)
    val_dataset = ImageFolder(val_dir, transform=transform)
    return train_dataset, val_dataset


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


def preprocess_image(image_path, img_size=128):
    """
    Preprocess a single image for inference (Cat/Dogs)
    Args:
        image_path: Path to image file
        img_size: Resize size
    Returns:
        Preprocessed tensor of shape (1, 3, img_size, img_size)
    """
    image = Image.open(image_path).convert('RGB')
    transform = transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])
    image_tensor = transform(image).unsqueeze(0)  # (1, 3, img_size, img_size)
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
