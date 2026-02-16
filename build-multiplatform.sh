#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Docker Build & Push for AWS ===${NC}"
echo ""

# ===============================
# CONFIGURATION
# ===============================
REGISTRY="ghcr.io"
REPO_OWNER="aimlideas"
NAMESPACE="aimlideas/mlops-assignment2"
REPO="cats-dogs-classifier"
PLATFORMS="linux/amd64"
BUILDER_NAME="aws-builder"

# Get credentials
GITHUB_USERNAME="${GITHUB_USERNAME:-$REPO_OWNER}"
GITHUB_TOKEN="${GITHUB_TOKEN:-$GITHUB_PAT}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: GitHub token not found!${NC}"
    echo ""
    echo "Please set GITHUB_TOKEN or GITHUB_PAT environment variable:"
    echo "  ${GREEN}export GITHUB_TOKEN=ghp_your_token_here${NC}"
    echo ""
    echo "To create a token:"
    echo "  1. Go to https://github.com/settings/tokens/new"
    echo "  2. Select scopes: ${YELLOW}write:packages, read:packages, delete:packages${NC}"
    echo "  3. Generate and copy the token"
    echo ""
    exit 1
fi

# Get git info
GIT_SHA=$(git rev-parse HEAD)
GIT_SHORT_SHA=$(git rev-parse --short HEAD)
BRANCH=$(git branch --show-current)

# Build image tags
FULL_IMAGE="${REGISTRY}/${NAMESPACE}/${REPO}"
TAG_LATEST="${FULL_IMAGE}:latest"
TAG_SHA="${FULL_IMAGE}:${GIT_SHA}"
TAG_SHORT_SHA="${FULL_IMAGE}:${GIT_SHORT_SHA}"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Registry:   ${REGISTRY}"
echo "  Repository: ${NAMESPACE}/${REPO}"
echo "  Platforms:  ${PLATFORMS}"
echo "  Branch:     ${BRANCH}"
echo "  Git SHA:    ${GIT_SHA}"
echo ""
echo -e "${YELLOW}Image tags:${NC}"
echo "  - ${TAG_LATEST}"
echo "  - ${TAG_SHA}"
echo "  - ${TAG_SHORT_SHA}"
echo ""

# ===============================
# STEP 1: Login to GHCR
# ===============================
echo -e "${BLUE}Step 1: Logging in to GitHub Container Registry...${NC}"
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Login successful${NC}"
    echo ""
else
    echo -e "${RED}✗ Login failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify your token has 'write:packages' scope"
    echo "  2. Ensure the token hasn't expired"
    echo "  3. Check your username matches the repository owner"
    echo ""
    exit 1
fi

# ===============================
# STEP 2: Setup Docker Buildx
# ===============================
echo -e "${BLUE}Step 2: Setting up Docker Buildx...${NC}"

# Remove existing builder if it exists
docker buildx rm "$BUILDER_NAME" 2>/dev/null || true

# Create new builder
docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap --use

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Buildx configured${NC}"
    docker buildx inspect --bootstrap
    echo ""
else
    echo -e "${RED}✗ Buildx setup failed${NC}"
    exit 1
fi

# ===============================
# STEP 3: Build & Push
# ===============================
echo -e "${BLUE}Step 3: Building and pushing Docker image for AWS...${NC}"
echo "This may take 5-8 minutes depending on your connection..."
echo ""

docker buildx build \
  --platform "$PLATFORMS" \
  --push \
  --tag "$TAG_LATEST" \
  --tag "$TAG_SHA" \
  --tag "$TAG_SHORT_SHA" \
  --progress=plain \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Build and push successful!${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Build and push failed${NC}"
    exit 1
fi

# ===============================
# SUCCESS
# ===============================
echo -e "${GREEN}=== Success! ===${NC}"
echo ""
echo -e "${YELLOW}Images pushed:${NC}"
echo "  - ${TAG_LATEST}"
echo "  - ${TAG_SHA}"
echo "  - ${TAG_SHORT_SHA}"
echo ""
echo -e "${YELLOW}Platform:${NC}"
echo "  - linux/amd64 (AWS standard)"
echo ""
echo "View at: https://github.com/${REPO_OWNER}/MLOps-Assignment2/pkgs/container/${REPO}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Pull the image on any platform:"
echo "     ${GREEN}docker pull ${TAG_LATEST}${NC}"
echo ""
echo "  2. Push code to trigger CI/CD:"
echo "     ${GREEN}git push origin ${BRANCH}${NC}"
echo ""

# Cleanup
docker buildx rm "$BUILDER_NAME" 2>/dev/null || true
