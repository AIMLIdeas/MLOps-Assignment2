#!/bin/bash
# Script to add GHCR PAT to GitHub repository secrets

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📦 Adding GHCR_PAT to GitHub Repository Secrets${NC}"
echo ""

# Repository
REPO_OWNER="AIMLIdeas"
REPO_NAME="MLOps-Assignment2"

# GitHub PAT with proper permissions (read:packages, write:packages)
# Read from environment variable or prompt
if [ -z "$GHCR_PAT" ]; then
    echo -e "${YELLOW}Enter your GitHub Personal Access Token (PAT) with packages permissions:${NC}"
    read -s GHCR_PAT
    echo ""
fi

if [ -z "$GHCR_PAT" ]; then
    echo -e "${RED}❌ GHCR_PAT is required${NC}"
    echo ""
    echo "Usage:"
    echo "  GHCR_PAT=ghp_xxx ./scripts/add_ghcr_secret.sh"
    echo ""
    echo "Or run the script and enter the PAT when prompted."
    exit 1
fi

echo -e "${GREEN}Using GitHub CLI to add secret...${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo ""
    echo "Install it with:"
    echo "  brew install gh"
    echo ""
    echo "Or add secret manually at:"
    echo "  https://github.com/$REPO_OWNER/$REPO_NAME/settings/secrets/actions"
    echo ""
    echo "Secret name: GHCR_PAT"
    echo "Secret value: Your GitHub PAT with packages permissions"
    exit 1
fi

# Add secret using GitHub CLI
echo "Adding GHCR_PAT secret to $REPO_OWNER/$REPO_NAME..."
echo "$GHCR_PAT" | gh secret set GHCR_PAT --repo "$REPO_OWNER/$REPO_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ GHCR_PAT secret added successfully!${NC}"
    echo ""
    echo "The CD workflow will now use this PAT for GHCR authentication."
    echo ""
else
    echo ""
    echo -e "${RED}❌ Failed to add secret via CLI${NC}"
    echo ""
    echo "Add it manually at:"
    echo "  https://github.com/$REPO_OWNER/$REPO_NAME/settings/secrets/actions"
    echo ""
    echo "Secret name: GHCR_PAT"
    echo "Secret value: Your GitHub PAT with packages permissions"
    exit 1
fi

echo ""
echo -e "${YELLOW}🔍 Verifying secret...${NC}"
gh secret list --repo "$REPO_OWNER/$REPO_NAME" | grep GHCR_PAT

echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
