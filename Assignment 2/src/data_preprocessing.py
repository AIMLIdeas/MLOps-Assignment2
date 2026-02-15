"""
Data Preprocessing Module
Handles loading and preprocessing Cats vs Dogs classification data
"""
import numpy as np
import torch
from torchvision import datasets, transforms
from torch.utils.data import DataLoader, random_split, Subset
import os
import ssl
import urllib.request
from PIL import Image

# Fix SSL certificate verification issue on macOS
ssl._create_default_https_context = ssl._create_unverified_context


def get_data_transforms(augment=True):
    """
    Get data transforms for training and validation/test
    
    Args:
        augment: Whether to apply data augmentation
        
    Returns:
        train_transform, val_transform
    """
    # ImageNet statistics - commonly used for transfer learning
    mean = [0.485, 0.456, 0.406]
    std = [0.229, 0.224, 0.225]
    
    if augment:
        train_transform = transforms.Compose([
            transforms.Resize((256, 256)),
            transforms.RandomCrop(224),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(15),
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
            transforms.ToTensor(),
            transforms.Normalize(mean=mean, std=std)
        ])
    else:
        train_transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=mean, std=std)
        ])
    
    val_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std)
    ])
    
    return train_transform, val_transform


def load_cats_dogs_data(data_dir='data/raw/cats_dogs/PetImages', 
                        train_split=0.8, val_split=0.1, test_split=0.1,
                        augment_train=True):
    """
    Load Cats vs Dogs dataset and split into train/val/test
    
    Args:
        data_dir: Directory containing Cat and Dog folders
        train_split: Percentage of data for training (0.8 = 80%)
        val_split: Percentage of data for validation (0.1 = 10%)
        test_split: Percentage of data for test (0.1 = 10%)
        augment_train: Whether to apply data augmentation to training data
        
    Returns:
        train_dataset, val_dataset, test_dataset
    """
    if not os.path.exists(data_dir):
        raise FileNotFoundError(
            f"Data directory not found: {data_dir}\n"
            "Please download the dataset first using:\n"
            "kaggle datasets download -d bhavikjikadara/dog-and-cat-classification-dataset"
        )
    
    # Get transforms
    train_transform, val_transform = get_data_transforms(augment=augment_train)
    
    # Load full dataset with training transform initially
    full_dataset = datasets.ImageFolder(root=data_dir, transform=train_transform)
    
    # Calculate split sizes
    total_size = len(full_dataset)
    train_size = int(train_split * total_size)
    val_size = int(val_split * total_size)
    test_size = total_size - train_size - val_size
    
    # Split dataset
    train_dataset, val_dataset, test_dataset = random_split(
        full_dataset, 
        [train_size, val_size, test_size],
        generator=torch.Generator().manual_seed(42)  # For reproducibility
    )
    
    # Apply validation transform to val and test datasets
    val_dataset.dataset = datasets.ImageFolder(root=data_dir, transform=val_transform)
    test_dataset.dataset = datasets.ImageFolder(root=data_dir, transform=val_transform)
    
    print(f"Dataset splits - Train: {train_size}, Val: {val_size}, Test: {test_size}")
    print(f"Class mapping: {full_dataset.class_to_idx}")
    
    return train_dataset, val_dataset, test_dataset


def create_data_loaders(train_dataset, val_dataset=None, test_dataset=None, batch_size=32):
    """
    Create data loaders for train, validation, and test sets
    
    Args:
        train_dataset: Training dataset
        val_dataset: Validation dataset (optional)
        test_dataset: Test dataset (optional)
        batch_size: Batch size for training
        
    Returns:
        train_loader, val_loader, test_loader (val and test can be None)
    """
    train_loader = DataLoader(
        train_dataset, 
        batch_size=batch_size, 
        shuffle=True,
        num_workers=0,
        pin_memory=False  # Disable for MPS compatibility on macOS
    )
    
    val_loader = None
    if val_dataset is not None:
        val_loader = DataLoader(
            val_dataset, 
            batch_size=batch_size, 
            shuffle=False,
            num_workers=0,
            pin_memory=False  # Disable for MPS compatibility on macOS
        )
    
    test_loader = None
    if test_dataset is not None:
        test_loader = DataLoader(
            test_dataset, 
            batch_size=batch_size, 
            shuffle=False,
            num_workers=0,
            pin_memory=False  # Disable for MPS compatibility on macOS
        )
    
    return train_loader, val_loader, test_loader


def preprocess_image(image_input):
    """
    Preprocess a single image for inference
    
    Args:
        image_input: Can be:
            - PIL Image
            - numpy array of shape (224, 224, 3) or (H, W, 3)
            - file path to image
        
    Returns:
        Preprocessed tensor of shape (1, 3, 224, 224)
    """
    # ImageNet statistics
    mean = [0.485, 0.456, 0.406]
    std = [0.229, 0.224, 0.225]
    
    # Handle different input types
    if isinstance(image_input, str):
        # File path
        image = Image.open(image_input).convert('RGB')
    elif isinstance(image_input, np.ndarray):
        # Numpy array
        if image_input.max() <= 1.0:
            image_input = (image_input * 255).astype(np.uint8)
        image = Image.fromarray(image_input)
    elif isinstance(image_input, Image.Image):
        # PIL Image
        image = image_input.convert('RGB')
    else:
        raise ValueError(f"Unsupported input type: {type(image_input)}")
    
    # Apply transforms
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std)
    ])
    
    image_tensor = transform(image)
    image_tensor = image_tensor.unsqueeze(0)  # Add batch dimension (1, 3, 224, 224)
    image_tensor = transform(image)
    image_tensor = image_tensor.unsqueeze(0)  # Add batch dimension (1, 3, 224, 224)
    
    return image_tensor


def clean_corrupted_images(data_dir='data/raw/cats_dogs/PetImages'):
    """
    Remove corrupted images from the dataset
    Some images in the dataset may be corrupted or not proper JPEGs
    
    Args:
        data_dir: Directory containing Cat and Dog folders
        
    Returns:
        Number of corrupted images removed
    """
    from pathlib import Path
    
    corrupted_count = 0
    for folder in ['Cat', 'Dog']:
        folder_path = os.path.join(data_dir, folder)
        if not os.path.exists(folder_path):
            continue
            
        for img_file in Path(folder_path).glob('*.jpg'):
            try:
                img = Image.open(img_file)
                img.verify()  # Verify it's a valid image
                img = Image.open(img_file)  # Re-open after verify
                img.load()  # Actually load the image data
            except Exception as e:
                print(f"Removing corrupted image: {img_file}")
                img_file.unlink()
                corrupted_count += 1
    
    return corrupted_count


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


# Backward compatibility - keeping old function names as aliases
def download_mnist_data(data_dir='data/raw'):
    """
    Deprecated: This function is kept for backward compatibility
    Use load_cats_dogs_data instead
    """
    raise NotImplementedError(
        "MNIST support has been replaced with Cats vs Dogs classification.\n"
        "Use load_cats_dogs_data() instead."
    )

