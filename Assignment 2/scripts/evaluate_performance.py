#!/usr/bin/env python3
"""
Model Performance Tracking Script
Evaluates model performance on new data and logs results
"""
import json
import numpy as np
import torch
from datetime import datetime
from pathlib import Path
from sklearn.metrics import (
    accuracy_score,
    precision_recall_fscore_support,
    confusion_matrix,
    classification_report
)
from src.inference import ModelInference
from src.data_preprocessing import download_mnist_data, create_data_loaders


def evaluate_model_performance(model_path='models/mnist_cnn_model.pt', 
                               num_samples=1000,
                               output_dir='logs/performance'):
    """
    Evaluate model performance on test data
    
    Args:
        model_path: Path to model file
        num_samples: Number of samples to evaluate
        output_dir: Directory to save results
    """
    print("=" * 60)
    print("Model Performance Evaluation")
    print("=" * 60)
    
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Load model
    print(f"\nLoading model from {model_path}...")
    model_inference = ModelInference(model_path)
    
    # Load test data
    print("Loading test dataset...")
    _, test_dataset = download_mnist_data()
    
    # Limit samples if specified
    if num_samples < len(test_dataset):
        indices = np.random.choice(len(test_dataset), num_samples, replace=False)
        test_subset = torch.utils.data.Subset(test_dataset, indices)
    else:
        test_subset = test_dataset
        num_samples = len(test_dataset)
    
    print(f"Evaluating on {num_samples} samples...")
    
    # Make predictions
    predictions = []
    true_labels = []
    inference_times = []
    
    for i, (image, label) in enumerate(test_subset):
        if (i + 1) % 100 == 0:
            print(f"Progress: {i + 1}/{num_samples}")
        
        # Convert tensor to numpy
        image_np = image.numpy()
        
        # Time inference
        start_time = datetime.now()
        result = model_inference.predict(image_np)
        inference_time = (datetime.now() - start_time).total_seconds() * 1000
        
        predictions.append(result['prediction'])
        true_labels.append(label)
        inference_times.append(inference_time)
    
    # Calculate metrics
    print("\nCalculating metrics...")
    
    accuracy = accuracy_score(true_labels, predictions)
    precision, recall, f1, _ = precision_recall_fscore_support(
        true_labels, predictions, average='weighted'
    )
    
    cm = confusion_matrix(true_labels, predictions)
    report = classification_report(true_labels, predictions)
    
    # Calculate latency statistics
    avg_latency = np.mean(inference_times)
    p50_latency = np.percentile(inference_times, 50)
    p95_latency = np.percentile(inference_times, 95)
    p99_latency = np.percentile(inference_times, 99)
    
    # Print results
    print("\n" + "=" * 60)
    print("Performance Metrics")
    print("=" * 60)
    print(f"Accuracy:  {accuracy:.4f} ({accuracy*100:.2f}%)")
    print(f"Precision: {precision:.4f}")
    print(f"Recall:    {recall:.4f}")
    print(f"F1 Score:  {f1:.4f}")
    print("\n" + "=" * 60)
    print("Latency Statistics")
    print("=" * 60)
    print(f"Average:   {avg_latency:.2f} ms")
    print(f"P50:       {p50_latency:.2f} ms")
    print(f"P95:       {p95_latency:.2f} ms")
    print(f"P99:       {p99_latency:.2f} ms")
    print()
    
    print("Classification Report:")
    print(report)
    
    # Save results
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    results = {
        'timestamp': datetime.now().isoformat(),
        'model_path': model_path,
        'num_samples': num_samples,
        'metrics': {
            'accuracy': float(accuracy),
            'precision': float(precision),
            'recall': float(recall),
            'f1_score': float(f1)
        },
        'latency': {
            'average_ms': float(avg_latency),
            'p50_ms': float(p50_latency),
            'p95_ms': float(p95_latency),
            'p99_ms': float(p99_latency)
        },
        'confusion_matrix': cm.tolist(),
        'classification_report': report
    }
    
    # Save JSON report
    json_path = output_path / f"performance_{timestamp}.json"
    with open(json_path, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\n✓ Results saved to {json_path}")
    
    # Append to summary log
    summary_path = output_path / "performance_history.jsonl"
    with open(summary_path, 'a') as f:
        f.write(json.dumps({
            'timestamp': results['timestamp'],
            'accuracy': results['metrics']['accuracy'],
            'f1_score': results['metrics']['f1_score'],
            'avg_latency_ms': results['latency']['average_ms']
        }) + '\n')
    print(f"✓ Summary appended to {summary_path}")
    
    return results


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Evaluate model performance')
    parser.add_argument('--model-path', type=str, 
                       default='models/mnist_cnn_model.pt',
                       help='Path to model file')
    parser.add_argument('--num-samples', type=int, default=1000,
                       help='Number of samples to evaluate')
    parser.add_argument('--output-dir', type=str, 
                       default='logs/performance',
                       help='Output directory for results')
    
    args = parser.parse_args()
    
    evaluate_model_performance(
        model_path=args.model_path,
        num_samples=args.num_samples,
        output_dir=args.output_dir
    )
