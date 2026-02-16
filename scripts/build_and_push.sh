#!/bin/bash

# Build and Push Docker Image to GHCR
# This script builds the Docker image locally and pushes it to GitHub Container Registry
# CI will then pull this image and run tests against it

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Docker Build and Push Script ===${NC}"

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: GITHUB_TOKEN environment variable is not set${NC}"
    echo "Please set it using: export GITHUB_TOKEN=your_token_here"
    echo "Or use GITHUB_PAT if you prefer: export GITHUB_TOKEN=\$GITHUB_PAT"
    exit 1
fi

# Get current git SHA
GIT_SHA=$(git rev-parse HEAD)
GIT_SHORT_SHA=$(git rev-parse --short HEAD)
BRANCH=$(git branch --show-current)

# Image details
REGISTRY="ghcr.io"
REPO_OWNER="aimlideas"
IMAGE_NAME="mlops-assignment2/cats-dogs-classifier"
FULL_IMAGE="${REGISTRY}/${REPO_OWNER}/${IMAGE_NAME}"

echo -e "${YELLOW}Git Information:${NC}"
echo "  Branch: $BRANCH"
echo "  SHA: $GIT_SHA"
echo "  Short SHA: $GIT_SHORT_SHA"
echo ""
echo -e "${YELLOW}Image Details:${NC}"
echo "  Registry: $REGISTRY"
echo "  Image: $FULL_IMAGE"
echo "  Tags: $GIT_SHA, latest"
echo ""

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes.${NC}"
    echo "It's recommended to commit all changes before building."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Login to GHCR
echo ""
echo -e "${GREEN}Step 2: Logging in to GitHub Container Registry...${NC}"
echo $GITHUB_TOKEN | docker login ghcr.io -u ${REPO_OWNER} --password-stdin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Login successful${NC}"
else
    echo -e "${RED}✗ Login failed${NC}"
    exit 1
fi

# Setup buildx for multi-platform
echo ""
echo -e "${GREEN}Step 3: Setting up Docker Buildx for multi-platform builds...${NC}"
docker buildx create --use --name multiplatform-builder 2>/dev/null || docker buildx use multiplatform-builder

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Buildx ready${NC}"
else
    echo -e "${RED}✗ Buildx setup failed${NC}"
    exit 1
fi

# Build and push multi-platform images
echo ""
echo -e "${GREEN}Step 4: Building and pushing multi-platform images...${NC}"
echo "Platform: linux/amd64,linux/arm64"
echo "Tags: ${GIT_SHA}, latest"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  --tag ${FULL_IMAGE}:${GIT_SHA} \
  --tag ${FULL_IMAGE}:latest \
  .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Push successful${NC}"
else
    echo -e "${RED}✗ Push failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Success! ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Push your code to GitHub:"
echo "   ${GREEN}git push origin ${BRANCH}${NC}"
echo ""
echo "2. CI will automatically pull and test this image:"
echo "   ${GREEN}${FULL_IMAGE}:${GIT_SHA}${NC}"
echo ""
echo "3. If tests pass, CD will deploy to AWS EKS"
echo ""
echo "Or trigger CI manually for a specific tag:"
echo "   Go to: https://github.com/AIMLIdeas/MLOps-Assignment2/actions/workflows/ci.yml"
echo ""
