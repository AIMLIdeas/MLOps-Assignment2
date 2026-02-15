"""
Model Training Module with MLflow Tracking
Implements a CNN for Cats vs Dogs binary classification
"""
import torch
import torch.nn as nn
import torch.optim as optim
import mlflow
import mlflow.pytorch
import numpy as np
from sklearn.metrics import confusion_matrix, classification_report, roc_auc_score
import matplotlib.pyplot as plt
import seaborn as sns
import os
from tqdm import tqdm

try:
    from data_preprocessing import load_cats_dogs_data, create_data_loaders
except ImportError:
    from src.data_preprocessing import load_cats_dogs_data, create_data_loaders


class CatsDogsCNN(nn.Module):
    """
    CNN architecture for Cats vs Dogs binary classification
    Input: 224x224 RGB images
    Output: Binary classification (Cat=0, Dog=1)
    """
    def __init__(self, dropout_rate=0.5):
        super(CatsDogsCNN, self).__init__()
        
        # Convolutional blocks
        self.conv_block1 = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.Conv2d(32, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.MaxPool2d(2, 2)  # 224 -> 112
        )
        
        self.conv_block2 = nn.Sequential(
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.Conv2d(64, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.MaxPool2d(2, 2)  # 112 -> 56
        )
        
        self.conv_block3 = nn.Sequential(
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(),
            nn.Conv2d(128, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(),
            nn.MaxPool2d(2, 2)  # 56 -> 28
        )
        
        self.conv_block4 = nn.Sequential(
            nn.Conv2d(128, 256, kernel_size=3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(),
            nn.Conv2d(256, 256, kernel_size=3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(),
            nn.MaxPool2d(2, 2)  # 28 -> 14
        )
        
        # Global average pooling
        self.global_avg_pool = nn.AdaptiveAvgPool2d((1, 1))
        
        # Fully connected layers
        self.fc = nn.Sequential(
            nn.Dropout(dropout_rate),
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.Dropout(dropout_rate),
            nn.Linear(128, 1)  # Binary classification
        )
        
    def forward(self, x):
        x = self.conv_block1(x)
        x = self.conv_block2(x)
        x = self.conv_block3(x)
        x = self.conv_block4(x)
        x = self.global_avg_pool(x)
        x = x.view(x.size(0), -1)  # Flatten
        x = self.fc(x)
        return x


# Keep old class for backward compatibility
class MNISTBasicCNN(nn.Module):
    """
    Deprecated: Kept for backward compatibility
    Use CatsDogsCNN instead
    """
    def __init__(self):
        super(MNISTBasicCNN, self).__init__()
        raise NotImplementedError(
            "MNISTBasicCNN is deprecated. Use CatsDogsCNN for Cats vs Dogs classification."
        )


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
    correct = 0
    total = 0
    
    for batch_idx, (data, target) in enumerate(tqdm(train_loader, desc="Training")):
        data, target = data.to(device), target.to(device)
        target = target.float().unsqueeze(1)  # Binary classification target
        
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item()
        
        # Calculate accuracy
        predicted = (torch.sigmoid(output) > 0.5).float()
        total += target.size(0)
        correct += (predicted == target).sum().item()
    
    avg_loss = running_loss / len(train_loader)
    accuracy = 100. * correct / total
    
    return avg_loss, accuracy


def evaluate_model(model, test_loader, criterion, device):
    """
    Evaluate model on test data
    
    Args:
        model: Neural network model
        test_loader: Test data loader
        criterion: Loss function
        device: Device to evaluate on
        
    Returns:
        test_loss, accuracy, predictions, true_labels, probabilities
    """
    model.eval()
    test_loss = 0.0
    correct = 0
    total = 0
    all_preds = []
    all_labels = []
    all_probs = []
    
    with torch.no_grad():
        for data, target in tqdm(test_loader, desc="Evaluating"):
            data, target = data.to(device), target.to(device)
            target_binary = target.float().unsqueeze(1)
            
            output = model(data)
            test_loss += criterion(output, target_binary).item()
            
            # Get probabilities and predictions
            probs = torch.sigmoid(output)
            predicted = (probs > 0.5).float()
            
            total += target.size(0)
            correct += (predicted.squeeze() == target.float()).sum().item()
            
            all_preds.extend(predicted.cpu().numpy().flatten())
            all_labels.extend(target.cpu().numpy())
            all_probs.extend(probs.cpu().numpy().flatten())
    
    test_loss /= len(test_loader)
    accuracy = 100. * correct / total
    
    return test_loss, accuracy, np.array(all_preds), np.array(all_labels), np.array(all_probs)


def plot_confusion_matrix(y_true, y_pred, class_names=['Cat', 'Dog'], save_path='confusion_matrix.png'):
    """
    Plot and save confusion matrix
    
    Args:
        y_true: True labels
        y_pred: Predicted labels
        class_names: Names of classes
        save_path: Path to save plot
    """
    cm = confusion_matrix(y_true, y_pred)
    
    plt.figure(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                xticklabels=class_names, yticklabels=class_names)
    plt.title('Confusion Matrix')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.tight_layout()
    plt.savefig(save_path)
    plt.close()
    
    return save_path


def plot_training_curves(train_losses, val_losses, train_accs, val_accs, save_path='training_curves.png'):
    """
    Plot training curves
    
    Args:
        train_losses: List of training losses
        val_losses: List of validation losses
        train_accs: List of training accuracies
        val_accs: List of validation accuracies
        save_path: Path to save plot
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 5))
    
    # Loss curves
    epochs = range(1, len(train_losses) + 1)
    ax1.plot(epochs, train_losses, 'b-', label='Training Loss', linewidth=2)
    ax1.plot(epochs, val_losses, 'r-', label='Validation Loss', linewidth=2)
    ax1.set_title('Training and Validation Loss', fontsize=14, fontweight='bold')
    ax1.set_xlabel('Epoch', fontsize=12)
    ax1.set_ylabel('Loss', fontsize=12)
    ax1.legend(fontsize=10)
    ax1.grid(True, alpha=0.3)
    
    # Accuracy curves
    ax2.plot(epochs, train_accs, 'b-', label='Training Accuracy', linewidth=2)
    ax2.plot(epochs, val_accs, 'r-', label='Validation Accuracy', linewidth=2)
    ax2.set_title('Training and Validation Accuracy', fontsize=14, fontweight='bold')
    ax2.set_xlabel('Epoch', fontsize=12)
    ax2.set_ylabel('Accuracy (%)', fontsize=12)
    ax2.legend(fontsize=10)
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    
    return save_path


def train_model(epochs=20, batch_size=32, learning_rate=0.001, experiment_name="cats_dogs_classification"):
    """
    Complete training pipeline with MLflow tracking
    
    Args:
        epochs: Number of training epochs
        batch_size: Batch size
        learning_rate: Learning rate
        experiment_name: MLflow experiment name
    """
    # Set MLflow experiment
    mlflow.set_experiment(experiment_name)
    
    # Start MLflow run
    with mlflow.start_run():
        # Log parameters
        mlflow.log_param("epochs", epochs)
        mlflow.log_param("batch_size", batch_size)
        mlflow.log_param("learning_rate", learning_rate)
        mlflow.log_param("model_architecture", "CatsDogsCNN")
        mlflow.log_param("input_size", "224x224x3")
        mlflow.log_param("task", "binary_classification")
        
        # Device configuration - support CUDA, MPS (Apple Silicon), or CPU
        if torch.cuda.is_available():
            device = torch.device("cuda")
        elif torch.backends.mps.is_available():
            device = torch.device("mps")
        else:
            device = torch.device("cpu")
        print(f"Using device: {device}")
        mlflow.log_param("device", str(device))
        
        # Load data
        print("Loading Cats vs Dogs dataset...")
        train_dataset, val_dataset, test_dataset = load_cats_dogs_data(
            data_dir='data/raw/cats_dogs/PetImages',
            train_split=0.8,
            val_split=0.1,
            test_split=0.1,
            augment_train=True
        )
        
        train_loader, val_loader, test_loader = create_data_loaders(
            train_dataset, val_dataset, test_dataset, batch_size=batch_size
        )
        
        # Initialize model
        model = CatsDogsCNN(dropout_rate=0.5).to(device)
        criterion = nn.BCEWithLogitsLoss()  # Binary cross-entropy with logits
        optimizer = optim.Adam(model.parameters(), lr=learning_rate)
        
        # Learning rate scheduler
        scheduler = optim.lr_scheduler.ReduceLROnPlateau(
            optimizer, mode='min', factor=0.5, patience=3
        )
        
        # Training loop
        train_losses = []
        val_losses = []
        train_accs = []
        val_accs = []
        best_val_acc = 0.0
        
        print(f"\nTraining for {epochs} epochs...")
        for epoch in range(1, epochs + 1):
            print(f"\n{'='*60}")
            print(f"Epoch {epoch}/{epochs}")
            print('='*60)
            
            # Train
            train_loss, train_acc = train_epoch(model, train_loader, criterion, optimizer, device)
            train_losses.append(train_loss)
            train_accs.append(train_acc)
            
            # Validate
            val_loss, val_acc, val_preds, val_labels, val_probs = evaluate_model(
                model, val_loader, criterion, device
            )
            val_losses.append(val_loss)
            val_accs.append(val_acc)
            
            # Update learning rate
            scheduler.step(val_loss)
            
            print(f"\nTrain Loss: {train_loss:.4f}, Train Acc: {train_acc:.2f}%")
            print(f"Val Loss: {val_loss:.4f}, Val Acc: {val_acc:.2f}%")
            
            # Log metrics to MLflow
            mlflow.log_metric("train_loss", train_loss, step=epoch)
            mlflow.log_metric("train_accuracy", train_acc, step=epoch)
            mlflow.log_metric("val_loss", val_loss, step=epoch)
            mlflow.log_metric("val_accuracy", val_acc, step=epoch)
            mlflow.log_metric("learning_rate", optimizer.param_groups[0]['lr'], step=epoch)
            
            # Save best model
            if val_acc > best_val_acc:
                best_val_acc = val_acc
                os.makedirs("models", exist_ok=True)
                best_model_path = "models/cats_dogs_best.pt"
                torch.save(model.state_dict(), best_model_path)
                print(f"✓ New best model saved with validation accuracy: {val_acc:.2f}%")
        
        # Final evaluation on test set
        print("\n" + "="*60)
        print("Final Evaluation on Test Set")
        print("="*60)
        
        # Load best model
        model.load_state_dict(torch.load(best_model_path))
        
        test_loss, test_acc, test_preds, test_labels, test_probs = evaluate_model(
            model, test_loader, criterion, device
        )
        
        # Calculate AUC-ROC
        auc_score = roc_auc_score(test_labels, test_probs)
        
        print(f"\nTest Loss: {test_loss:.4f}")
        print(f"Test Accuracy: {test_acc:.2f}%")
        print(f"AUC-ROC Score: {auc_score:.4f}")
        
        # Log final metrics
        mlflow.log_metric("final_test_accuracy", test_acc)
        mlflow.log_metric("final_test_loss", test_loss)
        mlflow.log_metric("auc_roc", auc_score)
        mlflow.log_metric("best_val_accuracy", best_val_acc)
        
        # Generate and log confusion matrix
        cm_path = plot_confusion_matrix(test_labels, test_preds, save_path='confusion_matrix.png')
        mlflow.log_artifact(cm_path)
        os.remove(cm_path)
        
        # Generate and log training curves
        curves_path = plot_training_curves(
            train_losses, val_losses, train_accs, val_accs, save_path='training_curves.png'
        )
        mlflow.log_artifact(curves_path)
        os.remove(curves_path)
        
        # Log classification report
        report = classification_report(
            test_labels, test_preds, 
            target_names=['Cat', 'Dog'],
            digits=4
        )
        print("\nClassification Report:")
        print(report)
        with open("classification_report.txt", "w") as f:
            f.write("Cats vs Dogs Classification Report\n")
            f.write("="*50 + "\n\n")
            f.write(report)
            f.write(f"\n\nAUC-ROC Score: {auc_score:.4f}\n")
        mlflow.log_artifact("classification_report.txt")
        os.remove("classification_report.txt")
        
        # Save final model
        final_model_path = "models/cats_dogs_cnn_model.pt"
        torch.save(model.state_dict(), final_model_path)
        print(f"\n✓ Final model saved to {final_model_path}")
        
        # Log model to MLflow
        mlflow.pytorch.log_model(model, "model")
        mlflow.log_artifact(final_model_path)
        
        print(f"\n{'='*60}")
        print("Training Summary")
        print('='*60)
        print(f"✓ Best Validation Accuracy: {best_val_acc:.2f}%")
        print(f"✓ Final Test Accuracy: {test_acc:.2f}%")
        print(f"✓ AUC-ROC Score: {auc_score:.4f}")
        print(f"✓ MLflow run ID: {mlflow.active_run().info.run_id}")
        
        return model, test_acc


if __name__ == "__main__":
    print("=" * 60)
    print("Cats vs Dogs Binary Classification Model Training")
    print("=" * 60)
    print("\nDataset: Cats and Dogs from Kaggle")
    print("Task: Pet adoption platform image classification")
    print("Input: 224x224 RGB images")
    print("Output: Binary classification (Cat vs Dog)")
    
    # Train model
    model, accuracy = train_model(epochs=5, batch_size=32, learning_rate=0.001)
    
    print("\n" + "=" * 60)
    print("Training Complete!")
    print("=" * 60)
    print("\nTo view MLflow tracking UI, run:")
    print("  mlflow ui")
    print("\nThen open http://localhost:5000 in your browser")
