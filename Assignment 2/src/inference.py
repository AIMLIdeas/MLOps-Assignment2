"""
Inference Module
Handles model loading and prediction for Cats vs Dogs classification
"""
import torch
import numpy as np
import os
from src.data_preprocessing import preprocess_image
from src.model import CatsDogsCNN


class ModelInference:
    """
    Model inference handler for Cats vs Dogs binary classification
    """
    def __init__(self, model_path='models/cats_dogs_cnn_model.pt'):
        """
        Initialize inference handler
        
        Args:
            model_path: Path to saved model
        """
        self.model_path = model_path
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = None
        self.class_names = ['Cat', 'Dog']
        self.load_model()
    
    def load_model(self):
        """
        Load trained model from disk
        """
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Model file not found at {self.model_path}")
        
        # Initialize and load model
        self.model = CatsDogsCNN(dropout_rate=0.5).to(self.device)
        self.model.load_state_dict(torch.load(self.model_path, map_location=self.device))
        self.model.eval()
        
        print(f"Model loaded from {self.model_path}")
    
    def predict(self, image_input):
        """
        Make prediction on a single image
        
        Args:
            image_input: Can be:
                - PIL Image
                - numpy array of shape (224, 224, 3) or (H, W, 3)
                - file path to image
            
        Returns:
            dict with prediction, probabilities, and confidence
        """
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")
        
        # Preprocess image
        image_tensor = preprocess_image(image_input)
        image_tensor = image_tensor.to(self.device)
        
        # Make prediction
        with torch.no_grad():
            output = self.model(image_tensor)
            probability = torch.sigmoid(output).item()
        
        # Binary classification: probability is for class 1 (Dog)
        predicted_class = 1 if probability > 0.5 else 0
        confidence = probability if predicted_class == 1 else (1 - probability)
        
        return {
            'prediction': predicted_class,
            'prediction_label': self.class_names[predicted_class],
            'probabilities': {
                'Cat': 1 - probability,
                'Dog': probability
            },
            'confidence': confidence
        }
    
    def predict_batch(self, image_batch):
        """
        Make predictions on a batch of images
        
        Args:
            image_batch: List of images (each can be PIL Image, numpy array, or file path)
            
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


def load_model_for_inference(model_path='models/cats_dogs_cnn_model.pt'):
    """
    Convenience function to load model for inference
    
    Args:
        model_path: Path to saved model
        
    Returns:
        ModelInference instance
    """
    return ModelInference(model_path)


def get_prediction_with_confidence(model_inference, image_input, confidence_threshold=0.8):
    """
    Get prediction with confidence check
    
    Args:
        model_inference: ModelInference instance
        image_input: Input image (PIL Image, numpy array, or file path)
        confidence_threshold: Minimum confidence threshold
        
    Returns:
        dict with prediction and confidence flag
    """
    result = model_inference.predict(image_input)
    
    return {
        **result,
        'high_confidence': result['confidence'] >= confidence_threshold,
        'threshold': confidence_threshold
    }

