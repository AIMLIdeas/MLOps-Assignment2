#!/bin/bash

# ===============================
# GHCR CONFIGURATION
# ===============================
# Read credentials from environment variables
# Set these before running: export GITHUB_USERNAME=xxx GITHUB_PAT=xxx
GITHUB_USERNAME="${GITHUB_USERNAME:-AIMLIdeas}"
GITHUB_PAT="${GITHUB_PAT}"
NAMESPACE="aimlideas/mlops-assignment2"
REPO="cats-dogs-classifier"
TAG="latest"

# Get current git SHA
GIT_SHA=$(git rev-parse HEAD)

FULL_IMAGE_LATEST="ghcr.io/$NAMESPACE/$REPO:$TAG"
FULL_IMAGE_SHA="ghcr.io/$NAMESPACE/$REPO:$GIT_SHA"

if [ -z "$GITHUB_PAT" ]; then
  echo "Error: GITHUB_PAT environment variable is not set"
  echo "Please export GITHUB_PAT=your_token before running this script"
  exit 1
fi

echo "==================================="
echo "Git SHA: $GIT_SHA"
echo "==================================="

echo "==================================="
echo "Logging into GitHub Container Registry..."
echo "==================================="
echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

echo "==================================="
echo "Setting up Docker Buildx for multi-platform builds..."
echo "==================================="
docker buildx create --use --name multiplatform-builder || docker buildx use multiplatform-builder

echo "==================================="
echo "Building and pushing multi-platform image..."
echo "Platform: linux/amd64,linux/arm64"
echo "==================================="
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  --tag $FULL_IMAGE_LATEST \
  --tag $FULL_IMAGE_SHA \
  .

echo "==================================="
echo "DONE 🚀"
echo "Images pushed as:"
echo "  - $FULL_IMAGE_LATEST"
echo "  - $FULL_IMAGE_SHA"
echo "==================================="
