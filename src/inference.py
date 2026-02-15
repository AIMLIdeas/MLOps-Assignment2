"""
Inference Module
Handles model loading and prediction
"""
import torch
import numpy as np
import os
from src.data_preprocessing import preprocess_image
from src.model import CatDogsCNN


def load_model_for_inference(model_path='models/cat_dogs_cnn_model.pt'):
    pass
def get_prediction_with_confidence(model_inference, image_array, confidence_threshold=0.8):
    pass

# Inference handler for Cat/Dogs classifier
class ModelInference:
    """
    Model inference handler for Cat/Dogs classifier
    """
    def __init__(self, model_path='models/cat_dogs_cnn_model.pt'):
        self.model_path = model_path
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = None
        self.load_model()

    def load_model(self):
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Model file not found at {self.model_path}")
        self.model = CatDogsCNN().to(self.device)
        self.model.load_state_dict(torch.load(self.model_path, map_location=self.device))
        self.model.eval()
        print(f"Model loaded from {self.model_path}")

    def predict(self, image_path):
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")
        image_tensor = preprocess_image(image_path).to(self.device)
        with torch.no_grad():
            output = self.model(image_tensor)
            probabilities = torch.nn.functional.softmax(output, dim=1)
            confidence, predicted = torch.max(probabilities, 1)
        probabilities_np = probabilities.cpu().numpy()[0]
        predicted_class = predicted.item()
        confidence_score = confidence.item()
        return {
            'prediction': predicted_class,
            'probabilities': probabilities_np.tolist(),
            'confidence': confidence_score
        }

    def predict_batch(self, image_paths):
        results = []
        for image_path in image_paths:
            result = self.predict(image_path)
            results.append(result)
        return results

    def is_loaded(self):
        return self.model is not None

def load_model_for_inference(model_path='models/cat_dogs_cnn_model.pt'):
    return ModelInference(model_path)

def get_prediction_with_confidence(model_inference, image_path, confidence_threshold=0.8):
    result = model_inference.predict(image_path)
    return {
        **result,
        'high_confidence': result['confidence'] >= confidence_threshold,
        'threshold': confidence_threshold
    }
