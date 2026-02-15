"""
Model Training Module with MLflow Tracking
Implements a baseline CNN for Cat/Dogs classification
"""
import torch
import torch.nn as nn
import torch.optim as optim
import mlflow
import mlflow.pytorch
import numpy as np
from sklearn.metrics import confusion_matrix, classification_report
import matplotlib.pyplot as plt
import seaborn as sns
import os
from tqdm import tqdm





# CNN for Cat/Dogs binary classification
class CatDogsCNN(nn.Module):
    """
    Simple CNN architecture for Cat/Dogs binary classification
    """
    def __init__(self):
        super(CatDogsCNN, self).__init__()
        # 3 input channels for RGB images
        self.conv1 = nn.Conv2d(3, 32, kernel_size=3, padding=1)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        self.pool = nn.MaxPool2d(2, 2)
        self.fc1 = nn.Linear(64 * 32 * 32, 128)  # for 128x128 input
        self.fc2 = nn.Linear(128, 2)  # 2 classes: cat, dog
        self.dropout = nn.Dropout(0.25)
        self.relu = nn.ReLU()

    def forward(self, x):
        x = self.relu(self.conv1(x))
        x = self.pool(x)
        x = self.relu(self.conv2(x))
        x = self.pool(x)
        x = x.view(-1, 64 * 32 * 32)
        x = self.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.fc2(x)
        return x


def train_epoch(model, train_loader, criterion, optimizer, device):
    """
    Train for one epoch
    
    Args:
        model: Neural network model
        train_loader: Training data loader
        criterion: Loss function
        optimizer: Optimizer
        device: Device to train on
        
    Returns:
        Average loss for the epoch
    """
    model.train()
    running_loss = 0.0
    
    for batch_idx, (data, target) in enumerate(tqdm(train_loader, desc="Training")):
        data, target = data.to(device), target.to(device)
        
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item()
    
    return running_loss / len(train_loader)


def evaluate_model(model, test_loader, criterion, device):
    """
    Evaluate model on test data
    
    Args:
        model: Neural network model
        test_loader: Test data loader
        criterion: Loss function
        device: Device to evaluate on
        
    Returns:
        test_loss, accuracy, predictions, true_labels
    """
    model.eval()
    test_loss = 0.0
    correct = 0
    all_preds = []
    all_labels = []
    
    with torch.no_grad():
        for data, target in tqdm(test_loader, desc="Evaluating"):
            data, target = data.to(device), target.to(device)
            output = model(data)
            test_loss += criterion(output, target).item()
            
            pred = output.argmax(dim=1, keepdim=True)
            correct += pred.eq(target.view_as(pred)).sum().item()
            
            all_preds.extend(pred.cpu().numpy())
            all_labels.extend(target.cpu().numpy())
    
    test_loss /= len(test_loader)
    accuracy = 100. * correct / len(test_loader.dataset)
    
    return test_loss, accuracy, np.array(all_preds).flatten(), np.array(all_labels)


def plot_confusion_matrix(y_true, y_pred, save_path='confusion_matrix.png'):
    """
    Plot and save confusion matrix
    
    Args:
        y_true: True labels
        y_pred: Predicted labels
        save_path: Path to save plot
    """
    cm = confusion_matrix(y_true, y_pred)
    
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
    plt.title('Confusion Matrix')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.tight_layout()
    plt.savefig(save_path)
    plt.close()
    
    return save_path


def plot_training_curves(train_losses, test_losses, test_accuracies, save_path='training_curves.png'):
    """
    Plot training curves
    
    Args:
        train_losses: List of training losses
        test_losses: List of test losses
        test_accuracies: List of test accuracies
        save_path: Path to save plot
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 5))
    
    # Loss curves
    epochs = range(1, len(train_losses) + 1)
    ax1.plot(epochs, train_losses, 'b-', label='Training Loss')
    ax1.plot(epochs, test_losses, 'r-', label='Test Loss')
    ax1.set_title('Training and Test Loss')
    ax1.set_xlabel('Epoch')
    ax1.set_ylabel('Loss')
    ax1.legend()
    ax1.grid(True)
    
    # Accuracy curve
    ax2.plot(epochs, test_accuracies, 'g-', label='Test Accuracy')
    ax2.set_title('Test Accuracy')
    ax2.set_xlabel('Epoch')
    ax2.set_ylabel('Accuracy (%)')
    ax2.legend()
    ax2.grid(True)
    
    plt.tight_layout()
    plt.savefig(save_path)
    plt.close()
    
    return save_path



def train_model(epochs=5, batch_size=64, learning_rate=0.001, experiment_name="cat_dogs_baseline", data_dir='data/raw/cat_dogs'):
    """
    Complete training pipeline with MLflow tracking for Cat/Dogs
    Args:
        epochs: Number of training epochs
        batch_size: Batch size
        learning_rate: Learning rate
        experiment_name: MLflow experiment name
        data_dir: Directory for cat/dogs data
    """
    from src.data_preprocessing import load_cat_dogs_data, create_data_loaders
    mlflow.set_experiment(experiment_name)
    with mlflow.start_run():
        mlflow.log_param("epochs", epochs)
        mlflow.log_param("batch_size", batch_size)
        mlflow.log_param("learning_rate", learning_rate)
        mlflow.log_param("model_architecture", "CatDogsCNN")
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(f"Using device: {device}")
        mlflow.log_param("device", str(device))
        print("Loading Cat/Dogs dataset...")
        train_dataset, val_dataset = load_cat_dogs_data(data_dir)
        train_loader, val_loader = create_data_loaders(train_dataset, val_dataset, batch_size=batch_size)
        model = CatDogsCNN().to(device)
        criterion = nn.CrossEntropyLoss()
        optimizer = optim.Adam(model.parameters(), lr=learning_rate)
        train_losses = []
        val_losses = []
        val_accuracies = []
        print(f"\nTraining for {epochs} epochs...")
        for epoch in range(1, epochs + 1):
            print(f"\nEpoch {epoch}/{epochs}")
            train_loss = train_epoch(model, train_loader, criterion, optimizer, device)
            train_losses.append(train_loss)
            val_loss, accuracy, preds, labels = evaluate_model(model, val_loader, criterion, device)
            val_losses.append(val_loss)
            val_accuracies.append(accuracy)
            print(f"Train Loss: {train_loss:.4f}, Val Loss: {val_loss:.4f}, Accuracy: {accuracy:.2f}%")
            mlflow.log_metric("train_loss", train_loss, step=epoch)
            mlflow.log_metric("val_loss", val_loss, step=epoch)
            mlflow.log_metric("val_accuracy", accuracy, step=epoch)
        print("\nGenerating final metrics and artifacts...")
        val_loss, accuracy, preds, labels = evaluate_model(model, val_loader, criterion, device)
        mlflow.log_metric("final_accuracy", accuracy)
        mlflow.log_metric("final_val_loss", val_loss)
        cm_path = plot_confusion_matrix(labels, preds, 'confusion_matrix.png')
        mlflow.log_artifact(cm_path)
        os.remove(cm_path)
        curves_path = plot_training_curves(train_losses, val_losses, val_accuracies, 'training_curves.png')
        mlflow.log_artifact(curves_path)
        os.remove(curves_path)
        report = classification_report(labels, preds)
        print("\nClassification Report:")
        print(report)
        with open("classification_report.txt", "w") as f:
            f.write(report)
        mlflow.log_artifact("classification_report.txt")
        os.remove("classification_report.txt")
        os.makedirs("models", exist_ok=True)
        model_path = "models/cat_dogs_cnn_model.pt"
        torch.save(model.state_dict(), model_path)
        print(f"\nModel saved to {model_path}")
        mlflow.pytorch.log_model(model, "model")
        mlflow.log_artifact(model_path)
        print(f"\n✓ Training complete! Final accuracy: {accuracy:.2f}%")
        print(f"✓ MLflow run ID: {mlflow.active_run().info.run_id}")
        return model, accuracy


if __name__ == "__main__":
    print("=" * 60)
    print("Cat/Dogs Baseline Model Training with MLflow")
    print("=" * 60)
    # Train model
    model, accuracy = train_model(epochs=50, batch_size=64, learning_rate=0.001)
    
    print("\n" + "=" * 60)
    print("Training Complete!")
    print("=" * 60)
    print("\nTo view MLflow tracking UI, run:")
    print("  mlflow ui")
    print("\nThen open http://localhost:5000 in your browser")
