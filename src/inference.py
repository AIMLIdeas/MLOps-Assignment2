"""
Inference Module
Handles model loading and prediction
"""
import torch
import numpy as np
import os
from src.data_preprocessing import preprocess_image
from src.model import MNISTBasicCNN


class ModelInference:
    """
    Model inference handler
    """
    def __init__(self, model_path='models/mnist_cnn_model.pt'):
        """
        Initialize inference handler
        
        Args:
            model_path: Path to saved model
        """
        self.model_path = model_path
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = None
        self.load_model()
    
    def load_model(self):
        """
        Load trained model from disk
        """
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Model file not found at {self.model_path}")
        
        # Initialize and load model
        self.model = MNISTBasicCNN().to(self.device)
        self.model.load_state_dict(torch.load(self.model_path, map_location=self.device))
        self.model.eval()
        
        print(f"Model loaded from {self.model_path}")
    
    def predict(self, image_array):
        """
        Make prediction on a single image
        
        Args:
            image_array: numpy array of shape (28, 28) or (784,)
            
        Returns:
            dict with prediction, probabilities, and confidence
        """
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")
        
        # Preprocess image
        image_tensor = preprocess_image(image_array)
        image_tensor = image_tensor.to(self.device)
        
        # Make prediction
        with torch.no_grad():
            output = self.model(image_tensor)
            probabilities = torch.nn.functional.softmax(output, dim=1)
            confidence, predicted = torch.max(probabilities, 1)
        
        # Convert to numpy
        probabilities_np = probabilities.cpu().numpy()[0]
        predicted_class = predicted.item()
        confidence_score = confidence.item()
        
        return {
            'prediction': predicted_class,
            'probabilities': probabilities_np.tolist(),
            'confidence': confidence_score
        }
    
    def predict_batch(self, image_batch):
        """
        Make predictions on a batch of images
        
        Args:
            image_batch: numpy array of shape (batch_size, 28, 28) or (batch_size, 784)
            
        Returns:
            List of prediction dictionaries
        """
        results = []
        for image in image_batch:
            result = self.predict(image)
            results.append(result)
        
        return results
    
    def is_loaded(self):
        """
        Check if model is loaded
        
        Returns:
            bool indicating if model is loaded
        """
        return self.model is not None


def load_model_for_inference(model_path='models/mnist_cnn_model.pt'):
    """
    Convenience function to load model for inference
    
    Args:
        model_path: Path to saved model
        
    Returns:
        ModelInference instance
    """
    return ModelInference(model_path)


def get_prediction_with_confidence(model_inference, image_array, confidence_threshold=0.8):
    """
    Get prediction with confidence check
    
    Args:
        model_inference: ModelInference instance
        image_array: Input image
        confidence_threshold: Minimum confidence threshold
        
    Returns:
        dict with prediction and confidence flag
    """
    result = model_inference.predict(image_array)
    
    return {
        **result,
        'high_confidence': result['confidence'] >= confidence_threshold,
        'threshold': confidence_threshold
    }
