#!/bin/bash
# Script to build and run the Docker container locally

set -e

echo "Building MNIST Classifier Docker Image..."
echo "=========================================="

# Build the Docker image
docker build -t mnist-classifier:latest .

echo ""
echo "✓ Docker image built successfully!"
echo ""
echo "Starting container..."
echo "===================="

# Run the container
docker run -d \
    --name mnist-api \
    -p 8000:8000 \
    -v $(pwd)/logs:/app/logs \
    mnist-classifier:latest

echo ""
echo "✓ Container started successfully!"
echo ""
echo "Waiting for API to be ready..."

# Wait for the API to be ready
sleep 5

# Check health
for i in {1..10}; do
    if curl -s http://localhost:8000/health > /dev/null; then
        echo "✓ API is ready!"
        echo ""
        echo "API is running at: http://localhost:8000"
        echo "API documentation: http://localhost:8000/docs"
        echo ""
        echo "To view logs:"
        echo "  docker logs -f mnist-api"
        echo ""
        echo "To stop the container:"
        echo "  docker stop mnist-api"
        echo "  docker rm mnist-api"
        exit 0
    fi
    sleep 2
done

echo "✗ API failed to start"
echo "Check logs with: docker logs mnist-api"
exit 1
