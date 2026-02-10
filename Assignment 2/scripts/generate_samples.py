#!/usr/bin/env python3
"""
Generate sample prediction requests for testing
"""
import json
import numpy as np
from torchvision import datasets, transforms


def generate_sample_requests(num_samples=5, output_file='sample_requests.json'):
    """
    Generate sample prediction requests from MNIST test data
    
    Args:
        num_samples: Number of sample requests to generate
        output_file: Output JSON file
    """
    print(f"Generating {num_samples} sample prediction requests...")
    
    # Load MNIST test data
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    test_dataset = datasets.MNIST(
        'data/raw',
        train=False,
        download=True,
        transform=transform
    )
    
    # Select random samples
    indices = np.random.choice(len(test_dataset), num_samples, replace=False)
    
    samples = []
    
    for idx in indices:
        image, label = test_dataset[idx]
        
        # Convert to numpy and reshape
        image_np = image.numpy().squeeze()  # (28, 28)
        
        # Create request
        request = {
            "true_label": int(label),
            "image": image_np.tolist()
        }
        
        samples.append(request)
    
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
