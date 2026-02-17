#!/usr/bin/env python3
"""
Training Script for Cats-Dogs Classifier
Downloads sample data and trains the model
"""
import os
import sys
import urllib.request
import zipfile
import shutil
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import torch
import torchvision
from torchvision import datasets, transforms
from torch.utils.data import DataLoader, random_split
import numpy as np
from tqdm import tqdm

from src.model import CatDogsCNN, train_model


def download_kaggle_cats_dogs_sample():
    """
    Download a small sample of cats and dogs images
    Using a publicly available dataset
    """
    print("Setting up cats-dogs dataset...")
    
    data_dir = Path("data/raw/cat_dogs")
    train_dir = data_dir / "train"
    val_dir = data_dir / "val"
    
    # Create directories
    for split in ['train', 'val']:
        for category in ['cats', 'dogs']:
            (data_dir / split / category).mkdir(parents=True, exist_ok=True)
    
    print(f"✓ Created directory structure at {data_dir}")
    
    # Download CIFAR-10 dataset and extract cats and dogs
    print("Downloading CIFAR-10 dataset (contains cats and dogs)...")
    
    transform = transforms.Compose([
        transforms.Resize((128, 128)),
        transforms.ToTensor(),
    ])
    
    # CIFAR-10 classes: ['airplane', 'automobile', 'bird', 'cat', 'deer', 'dog', 'frog', 'horse', 'ship', 'truck']
    # cat = index 3, dog = index 5
    cifar_train = torchvision.datasets.CIFAR10(root='data/raw', train=True, download=True)
    cifar_test = torchvision.datasets.CIFAR10(root='data/raw', train=False, download=True)
    
    print("Extracting cats and dogs images...")
    
    def extract_images(dataset, output_dir, max_per_class=500):
        """Extract cat and dog images from CIFAR-10"""
        cat_count = 0
        dog_count = 0
        
        for idx, (img, label) in enumerate(tqdm(dataset, desc=f"Processing {output_dir.name}")):
            if label == 3 and cat_count < max_per_class:  # Cat
                save_path = output_dir / "cats" / f"cat_{cat_count:04d}.png"
                img.save(save_path)
                cat_count += 1
            elif label == 5 and dog_count < max_per_class:  # Dog
                save_path = output_dir / "dogs" / f"dog_{dog_count:04d}.png"
                img.save(save_path)
                dog_count += 1
            
            if cat_count >= max_per_class and dog_count >= max_per_class:
                break
        
        return cat_count, dog_count
    
    # Extract training images
    train_cats, train_dogs = extract_images(cifar_train, train_dir, max_per_class=400)
    print(f"✓ Extracted {train_cats} cats and {train_dogs} dogs for training")
    
    # Extract validation images
    val_cats, val_dogs = extract_images(cifar_test, val_dir, max_per_class=100)
    print(f"✓ Extracted {val_cats} cats and {val_dogs} dogs for validation")
    
    return data_dir


def train_quick_model(epochs=10):
    """
    Train a cats-dogs model with configurable epochs
    """
    print("\n" + "="*70)
    print("Training Cats-Dogs Classifier")
    print("="*70)
    
    # Check if data exists, if not download it
    data_dir = Path("data/raw/cat_dogs")
    if not (data_dir / "train").exists():
        data_dir = download_kaggle_cats_dogs_sample()
    else:
        print(f"Using existing data at {data_dir}")
    
    # Train model with specified epochs
    print("\nStarting training...")
    model, accuracy = train_model(
        epochs=epochs,
        batch_size=32,
        learning_rate=0.001,
        experiment_name="cat_dogs_quick_deploy",
        data_dir=str(data_dir)
    )
    
    print("\n" + "="*70)
    print(f"✓ Training Complete!")
    print(f"✓ Final Accuracy: {accuracy:.2f}%")
    print(f"✓ Model saved to: models/cat_dogs_cnn_model.pt")
    print("="*70)
    
    return model, accuracy


def verify_model():
    """
    Verify the trained model can be loaded and used for inference
    """
    print("\nVerifying model...")
    
    from src.inference import ModelInference
    
    try:
        model_inference = ModelInference('models/cat_dogs_cnn_model.pt')
        print("✓ Model loaded successfully")
        print(f"✓ Model is ready for inference")
        return True
    except Exception as e:
        print(f"✗ Model verification failed: {e}")
        return False


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Train Cats-Dogs Classifier')
    parser.add_argument('--download-only', action='store_true', 
                        help='Only download data without training')
    parser.add_argument('--verify-only', action='store_true',
                        help='Only verify existing model')
    parser.add_argument('--epochs', type=int, default=10,
                        help='Number of training epochs (default: 10)')
    
    args = parser.parse_args()
    
    if args.verify_only:
        verify_model()
    elif args.download_only:
        download_kaggle_cats_dogs_sample()
        print("\n✓ Data download complete!")
    else:
        # Full training pipeline
        model, accuracy = train_quick_model(epochs=args.epochs)
        
        # Verify the model
        if verify_model():
            print("\n✓ All checks passed! Model is ready for deployment.")
            print("\nNext steps:")
            print("1. Test locally: python -m api.main")
            print("2. Build Docker: docker build -t cats-dogs-classifier .")
            print("3. Deploy to AWS: Push changes and GitHub Actions will deploy")
        else:
            print("\n✗ Model verification failed. Please check the training logs.")
            sys.exit(1)
