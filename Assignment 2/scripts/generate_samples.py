#!/usr/bin/env python3
"""
Generate sample prediction requests for testing
"""
import json
import numpy as np
from pathlib import Path
from PIL import Image
from torchvision import transforms


def generate_sample_requests(num_samples=5, output_file='sample_requests.json'):
    """
    Generate sample prediction requests from Cats vs Dogs test data
    
    Args:
        num_samples: Number of sample requests to generate
        output_file: Output JSON file
    """
    print(f"Generating {num_samples} sample prediction requests...")
    
    # Load Cats vs Dogs test data
    transform = transforms.Compose([
        transforms.Resize((128, 128)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    # Get test images from cats_dogs dataset
    data_dir = Path('data/raw/cats_dogs/PetImages')
    cat_images = list((data_dir / 'Cat').glob('*.jpg'))[:num_samples//2 + 1]
    dog_images = list((data_dir / 'Dog').glob('*.jpg'))[:num_samples//2 + 1]
    
    all_images = cat_images + dog_images
    indices = np.random.choice(len(all_images), min(num_samples, len(all_images)), replace=False)
    
    samples = []
    
    for idx in indices:
        img_path = all_images[idx]
        # Label: 0 for Cat, 1 for Dog
        label = 0 if 'Cat' in str(img_path) else 1
        
        try:
            # Load and transform image
            image = Image.open(img_path).convert('RGB')
            image_tensor = transform(image)
            
            # Convert to numpy
            image_np = image_tensor.numpy()  # (3, 128, 128)
            
            # Create request
            request = {
                "true_label": int(label),
                "image": image_np.tolist()
            }
            
            samples.append(request)
        except Exception as e:
            print(f"Error processing {img_path}: {e}")
            continue
    
    # Save to file
    with open(output_file, 'w') as f:
        json.dump(samples, f, indent=2)
    
    print(f"✓ Saved {num_samples} samples to {output_file}")
    
    # Print example curl commands
    print("\nExample curl commands:")
    print("-" * 60)
    
    for i, sample in enumerate(samples[:2], 1):
        print(f"\nSample {i} (True label: {sample['true_label']}):")
        print("curl -X POST http://localhost:8000/predict \\")
        print("  -H 'Content-Type: application/json' \\")
        print(f"  -d '{{\"image\": {json.dumps(sample['image'][:2])[:100]}...}}'")
    
    print("\n" + "-" * 60)
    print(f"\nAll samples saved to: {output_file}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate sample prediction requests')
    parser.add_argument('--num-samples', type=int, default=5,
                       help='Number of samples to generate')
    parser.add_argument('--output', type=str, default='sample_requests.json',
                       help='Output file path')
    
    args = parser.parse_args()
    
    generate_sample_requests(args.num_samples, args.output)
