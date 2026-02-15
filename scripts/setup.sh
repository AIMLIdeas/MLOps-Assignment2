#!/bin/bash
# Setup script for the MLOps project

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the project root (parent of scripts directory)
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project root directory
cd "$PROJECT_ROOT"

echo "========================================="
echo "MLOps Assignment 2 - Setup Script"
echo "========================================="
echo "Working directory: $PROJECT_ROOT"
echo ""

# Check Python version
echo "Checking Python version..."
python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
required_version="3.9"

# Convert versions to comparable integers (e.g., 3.9 -> 309, 3.10 -> 310)
python_ver_major=$(echo $python_version | cut -d. -f1)
python_ver_minor=$(echo $python_version | cut -d. -f2)
required_ver_major=$(echo $required_version | cut -d. -f1)
required_ver_minor=$(echo $required_version | cut -d. -f2)

python_ver_int=$((python_ver_major * 100 + python_ver_minor))
required_ver_int=$((required_ver_major * 100 + required_ver_minor))

if [ $python_ver_int -lt $required_ver_int ]; then
    echo "Error: Python $required_version or higher is required (found $python_version)"
    exit 1
fi
echo "✓ Python $python_version found"
echo ""

# Create virtual environment
echo "Creating virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi
echo ""

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate
echo "✓ Virtual environment activated"
echo ""

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip --quiet
echo "✓ pip upgraded"
echo ""

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt --quiet
echo "✓ Dependencies installed"
echo ""

# Create necessary directories
echo "Creating project directories..."
mkdir -p data/raw
mkdir -p data/processed
mkdir -p models
mkdir -p logs
mkdir -p logs/performance
echo "✓ Directories created"
echo ""

# Initialize Git (if not already initialized)
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    git add .
    git commit -m "Initial commit: MLOps Assignment 2 structure" || true
    echo "✓ Git repository initialized"
else
    echo "✓ Git repository already initialized"
fi
echo ""

# Initialize DVC
echo "Initializing DVC..."
if [ ! -d ".dvc" ]; then
    dvc init
    git add .dvc .dvcignore
    git commit -m "Initialize DVC" || true
    echo "✓ DVC initialized"
else
    echo "✓ DVC already initialized"
fi
echo ""

# Add data to DVC
echo "Setting up DVC for data versioning..."
if [ ! -f "data/raw/.dvc" ] && [ -d "data/raw" ]; then
    # Only add if there's data
    if [ "$(ls -A data/raw)" ]; then
        dvc add data/raw
        git add data/raw.dvc .gitignore
        git commit -m "Add raw data to DVC tracking" || true
        echo "✓ Data added to DVC tracking"
    else
        echo "ℹ No data to track yet (will be added after training)"
    fi
else
    echo "✓ Data already tracked by DVC or no data directory"
fi
echo ""

# Make scripts executable
echo "Making scripts executable..."
chmod +x scripts/*.sh
chmod +x scripts/*.py
echo "✓ Scripts are now executable"
echo ""

echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Train the model:"
echo "   python src/model.py"
echo ""
echo "2. Run tests:"
echo "   pytest tests/ -v"
echo ""
echo "3. Start the API:"
echo "   uvicorn api.main:app --reload"
echo ""
echo "4. Build Docker image:"
echo "   ./scripts/run_docker.sh"
echo ""
echo "5. View MLflow UI:"
echo "   mlflow ui"
echo ""
echo "For more information, see README.md"
echo ""
