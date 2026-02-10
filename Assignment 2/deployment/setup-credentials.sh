#!/bin/bash
# AWS Credentials and GitHub PAT Setup Helper
# This script helps you configure AWS credentials and GitHub PAT for deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AWS & GitHub Credentials Setup ===${NC}\n"

# Function to validate AWS credentials
validate_aws_creds() {
    if aws sts get-caller-identity >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Step 1: AWS Credentials
echo -e "${YELLOW}Step 1: AWS Credentials Setup${NC}\n"

if validate_aws_creds; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    USER=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓ AWS credentials are already configured and valid!${NC}"
    echo -e "  Account: $ACCOUNT"
    echo -e "  User: $USER\n"
    read -p "Do you want to reconfigure AWS credentials? (y/N): " RECONFIG
    if [[ ! "$RECONFIG" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Keeping existing AWS credentials.${NC}\n"
    else
        echo -e "\n${YELLOW}Running aws configure...${NC}"
        aws configure
    fi
else
    echo -e "${RED}AWS credentials are not configured or invalid.${NC}\n"
    echo -e "${YELLOW}You need:${NC}"
    echo -e "  1. AWS Access Key ID"
    echo -e "  2. AWS Secret Access Key"
    echo -e "  3. Default region (recommended: us-east-1)"
    echo -e "  4. Default output format (recommended: json)\n"
    echo -e "${BLUE}To get AWS credentials:${NC}"
    echo -e "  1. Go to: https://console.aws.amazon.com/"
    echo -e "  2. Navigate to: IAM → Users → [Your User] → Security Credentials"
    echo -e "  3. Click 'Create access key'"
    echo -e "  4. Download or copy the Access Key ID and Secret Access Key\n"
    
    read -p "Do you want to configure AWS credentials now? (Y/n): " CONFIGURE
    if [[ ! "$CONFIGURE" =~ ^[Nn]$ ]]; then
        echo -e "\n${YELLOW}Running aws configure...${NC}\n"
        aws configure
        echo ""
        if validate_aws_creds; then
            ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
            echo -e "\n${GREEN}✓ AWS credentials configured successfully!${NC}"
            echo -e "  Account: $ACCOUNT\n"
        else
            echo -e "\n${RED}✗ AWS credentials validation failed. Please check your credentials.${NC}\n"
            exit 1
        fi
    else
        echo -e "${YELLOW}Skipping AWS credentials setup.${NC}\n"
    fi
fi

# Step 2: GitHub PAT
echo -e "${YELLOW}Step 2: GitHub Personal Access Token (PAT) Setup${NC}\n"

if [ -n "$GITHUB_PAT" ]; then
    echo -e "${GREEN}✓ GITHUB_PAT environment variable is already set!${NC}"
    echo -e "  Value: ${GITHUB_PAT:0:8}...${GITHUB_PAT: -4}\n"
    read -p "Do you want to update GITHUB_PAT? (y/N): " UPDATE_PAT
    if [[ ! "$UPDATE_PAT" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Keeping existing GITHUB_PAT.${NC}\n"
    else
        read -sp "Enter your GitHub Personal Access Token: " NEW_PAT
        echo ""
        if [ -n "$NEW_PAT" ]; then
            export GITHUB_PAT="$NEW_PAT"
            echo -e "${GREEN}✓ GITHUB_PAT updated!${NC}\n"
        fi
    fi
else
    echo -e "${YELLOW}GITHUB_PAT is not set.${NC}"
    echo -e "This is required to pull images from GitHub Container Registry.\n"
    echo -e "${BLUE}To create a GitHub PAT:${NC}"
    echo -e "  1. Go to: https://github.com/settings/tokens"
    echo -e "  2. Click 'Generate new token (classic)'"
    echo -e "  3. Select scope: ${YELLOW}read:packages${NC}"
    echo -e "  4. Copy the generated token\n"
    
    read -p "Do you want to set GITHUB_PAT now? (Y/n): " SET_PAT
    if [[ ! "$SET_PAT" =~ ^[Nn]$ ]]; then
        read -sp "Enter your GitHub Personal Access Token: " NEW_PAT
        echo ""
        if [ -n "$NEW_PAT" ]; then
            export GITHUB_PAT="$NEW_PAT"
            echo -e "${GREEN}✓ GITHUB_PAT set successfully!${NC}\n"
        else
            echo -e "${YELLOW}⚠ No token entered. You can set it later with:${NC}"
            echo -e "  export GITHUB_PAT='your_token_here'\n"
        fi
    else
        echo -e "${YELLOW}⚠ Skipping GITHUB_PAT setup. Set it later with:${NC}"
        echo -e "  export GITHUB_PAT='your_token_here'\n"
    fi
fi

# Step 3: Set GitHub Username
echo -e "${YELLOW}Step 3: GitHub Username${NC}\n"

if [ -n "$GITHUB_USERNAME" ]; then
    echo -e "${GREEN}✓ GITHUB_USERNAME is set to: $GITHUB_USERNAME${NC}\n"
else
    export GITHUB_USERNAME="aimlideas"
    echo -e "${GREEN}✓ GITHUB_USERNAME set to: $GITHUB_USERNAME${NC}\n"
fi

# Step 4: Save to profile (optional)
echo -e "${YELLOW}Step 4: Persist Environment Variables (Optional)${NC}\n"
echo -e "Do you want to save GITHUB_PAT to your shell profile?"
echo -e "${YELLOW}⚠ Warning: This will store the token in plain text${NC}\n"
read -p "Save to ~/.zshrc? (y/N): " SAVE_PROFILE

if [[ "$SAVE_PROFILE" =~ ^[Yy]$ ]]; then
    if [ -n "$GITHUB_PAT" ]; then
        # Check if already in file
        if grep -q "export GITHUB_PAT=" ~/.zshrc 2>/dev/null; then
            echo -e "${YELLOW}GITHUB_PAT already exists in ~/.zshrc${NC}"
        else
            echo "" >> ~/.zshrc
            echo "# GitHub Container Registry credentials" >> ~/.zshrc
            echo "export GITHUB_USERNAME=\"$GITHUB_USERNAME\"" >> ~/.zshrc
            echo "export GITHUB_PAT=\"$GITHUB_PAT\"" >> ~/.zshrc
            echo -e "${GREEN}✓ Environment variables saved to ~/.zshrc${NC}"
            echo -e "${YELLOW}Run: source ~/.zshrc to apply${NC}\n"
        fi
    fi
else
    echo -e "${YELLOW}Environment variables not saved to profile.${NC}"
    echo -e "They will only be available in this session.\n"
fi

# Summary
echo -e "${BLUE}=== Setup Summary ===${NC}\n"

if validate_aws_creds; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✓ AWS Credentials: Configured${NC}"
    echo -e "  Account: $ACCOUNT"
else
    echo -e "${RED}✗ AWS Credentials: Not configured${NC}"
fi

if [ -n "$GITHUB_PAT" ]; then
    echo -e "${GREEN}✓ GitHub PAT: Set${NC}"
else
    echo -e "${YELLOW}⚠ GitHub PAT: Not set${NC}"
fi

if [ -n "$GITHUB_USERNAME" ]; then
    echo -e "${GREEN}✓ GitHub Username: $GITHUB_USERNAME${NC}"
fi

# Final instructions
echo -e "\n${BLUE}=== Next Steps ===${NC}\n"

if validate_aws_creds && [ -n "$GITHUB_PAT" ]; then
    echo -e "${GREEN}All credentials are configured! You can now deploy.${NC}\n"
    echo -e "Run the pre-flight check:"
    echo -e "  ${YELLOW}./deployment/verify-eks-prerequisites.sh${NC}\n"
    echo -e "If all checks pass, deploy with:"
    echo -e "  ${YELLOW}./deployment/deploy-to-aws.sh${NC} (EKS - ~\$152/month, 15-20 min)"
    echo -e "  ${YELLOW}./deployment/ec2/deploy-ec2.sh${NC} (EC2 - ~\$9/month, 3-5 min)\n"
else
    if ! validate_aws_creds; then
        echo -e "${YELLOW}⚠ AWS credentials still need to be configured${NC}"
        echo -e "  Run: ${YELLOW}aws configure${NC}\n"
    fi
    if [ -z "$GITHUB_PAT" ]; then
        echo -e "${YELLOW}⚠ GitHub PAT still needs to be set${NC}"
        echo -e "  Run: ${YELLOW}export GITHUB_PAT='your_token_here'${NC}\n"
    fi
    echo -e "After fixing, run this script again or run the pre-flight check:"
    echo -e "  ${YELLOW}./deployment/verify-eks-prerequisites.sh${NC}\n"
fi
