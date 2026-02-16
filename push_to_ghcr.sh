#!/bin/bash

# ===============================
# GHCR CONFIGURATION
# ===============================
# Read credentials from environment variables
# Set these before running: export GITHUB_USERNAME=xxx GITHUB_PAT=xxx
GITHUB_USERNAME="${GITHUB_USERNAME:-AIMLIdeas}"
GITHUB_PAT="${GITHUB_PAT}"
REPO="cats-dogs-classifier"
TAG="latest"
NAMESPACE="aimlideas"

FULL_IMAGE="ghcr.io/$NAMESPACE/$REPO:$TAG"

if [ -z "$GITHUB_PAT" ]; then
  echo "Error: GITHUB_PAT environment variable is not set"
  echo "Please export GITHUB_PAT=your_token before running this script"
  exit 1
fi

echo "==================================="
echo "Logging into GitHub Container Registry..."
echo "==================================="
echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

echo "==================================="
echo "Tagging image..."
echo "==================================="
docker tag $REPO:$TAG $FULL_IMAGE

echo "==================================="
echo "Pushing image to GHCR..."
echo "==================================="
docker push $FULL_IMAGE

echo "==================================="
echo "DONE 🚀"
echo "Image pushed as: $FULL_IMAGE"
echo "==================================="
