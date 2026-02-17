#!/bin/bash

# CloudFormation Stack Deployment Script with Termination Protection DISABLED
# This script deploys all infrastructure stacks with termination protection explicitly disabled

set -e

# Configuration
PROJECT_NAME="mlops-mnist"
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-production}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    log_success "AWS CLI is installed"
}

# Function to validate AWS credentials
check_aws_credentials() {
    log_info "Validating AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured or invalid"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    log_success "AWS credentials validated"
    log_info "Account ID: $ACCOUNT_ID"
    log_info "User ARN: $USER_ARN"
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" &> /dev/null
}

# Function to get stack status
get_stack_status() {
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST"
}

# Function to disable termination protection
disable_termination_protection() {
    local stack_name=$1
    log_info "Disabling termination protection for stack: $stack_name"
    
    if stack_exists "$stack_name"; then
        aws cloudformation update-termination-protection \
            --stack-name "$stack_name" \
            --no-enable-termination-protection \
            --region "$REGION" 2>/dev/null || true
        
        log_success "Termination protection DISABLED for $stack_name"
    else
        log_warning "Stack $stack_name does not exist yet"
    fi
}

# Function to create or update stack with termination protection DISABLED
deploy_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters_file=$3
    local capabilities=$4
    
    log_info "=========================================="
    log_info "Deploying stack: $stack_name"
    log_info "Template: $template_file"
    log_info "=========================================="
    
    # Check if template file exists
    if [ ! -f "$template_file" ]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    # Validate template
    log_info "Validating CloudFormation template..."
    if ! aws cloudformation validate-template \
        --template-body "file://$template_file" \
        --region "$REGION" &> /dev/null; then
        log_error "Template validation failed for $template_file"
        return 1
    fi
    log_success "Template validation passed"
    
    # Prepare parameters
    local param_args=""
    if [ -f "$parameters_file" ]; then
        param_args="--parameters file://$parameters_file"
        log_info "Using parameters file: $parameters_file"
    fi
    
    # Prepare capabilities
    local capability_args=""
    if [ -n "$capabilities" ]; then
        capability_args="--capabilities $capabilities"
        log_info "Using capabilities: $capabilities"
    fi
    
    # Check current stack status
    local status=$(get_stack_status "$stack_name")
    log_info "Current stack status: $status"
    
    # If stack exists, disable termination protection first
    if stack_exists "$stack_name"; then
        disable_termination_protection "$stack_name"
        
        if [[ "$status" == *"ROLLBACK_COMPLETE"* ]]; then
            log_warning "Stack is in ROLLBACK_COMPLETE state. Deleting before recreating..."
            delete_stack "$stack_name"
            status="DOES_NOT_EXIST"
        fi
    fi
    
    # Deploy stack
    if [ "$status" == "DOES_NOT_EXIST" ]; then
        log_info "Creating new stack: $stack_name"
        
        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            $param_args \
            $capability_args \
            --no-enable-termination-protection \
            --region "$REGION" \
            --tags \
                Key=Project,Value=$PROJECT_NAME \
                Key=Environment,Value=$ENVIRONMENT \
                Key=ManagedBy,Value=CloudFormation \
                Key=TerminationProtection,Value=Disabled
        
        log_info "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete \
            --stack-name "$stack_name" \
            --region "$REGION"
        
        log_success "Stack created successfully: $stack_name"
    else
        log_info "Updating existing stack: $stack_name"
        
        if aws cloudformation update-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            $param_args \
            $capability_args \
            --region "$REGION" \
            --tags \
                Key=Project,Value=$PROJECT_NAME \
                Key=Environment,Value=$ENVIRONMENT \
                Key=ManagedBy,Value=CloudFormation \
                Key=TerminationProtection,Value=Disabled 2>&1 | tee /tmp/update-output.txt; then
            
            log_info "Waiting for stack update to complete..."
            aws cloudformation wait stack-update-complete \
                --stack-name "$stack_name" \
                --region "$REGION"
            
            # Ensure termination protection is disabled after update
            disable_termination_protection "$stack_name"
            
            log_success "Stack updated successfully: $stack_name"
        else
            if grep -q "No updates are to be performed" /tmp/update-output.txt; then
                log_warning "No updates needed for stack: $stack_name"
                # Still ensure protection is disabled
                disable_termination_protection "$stack_name"
            else
                log_error "Stack update failed: $stack_name"
                cat /tmp/update-output.txt
                return 1
            fi
        fi
    fi
    
    # Verify termination protection is disabled
    verify_termination_protection_disabled "$stack_name"
    
    # Display stack outputs
    display_stack_outputs "$stack_name"
    
    return 0
}

# Function to verify termination protection is disabled
verify_termination_protection_disabled() {
    local stack_name=$1
    log_info "Verifying termination protection status for: $stack_name"
    
    local protection_status=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].EnableTerminationProtection' \
        --output text)
    
    if [ "$protection_status" == "False" ]; then
        log_success "✓ Termination protection is DISABLED for $stack_name"
    else
        log_warning "⚠ Termination protection is ENABLED for $stack_name"
        log_info "Attempting to disable..."
        disable_termination_protection "$stack_name"
    fi
}

# Function to display stack outputs
display_stack_outputs() {
    local stack_name=$1
    log_info "Stack outputs for: $stack_name"
    
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
        --output table || log_warning "No outputs available for $stack_name"
}

# Function to delete stack
delete_stack() {
    local stack_name=$1
    log_warning "Deleting stack: $stack_name"
    
    # Disable termination protection before deletion
    disable_termination_protection "$stack_name"
    
    aws cloudformation delete-stack \
        --stack-name "$stack_name" \
        --region "$REGION"
    
    log_info "Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete \
        --stack-name "$stack_name" \
        --region "$REGION"
    
    log_success "Stack deleted successfully: $stack_name"
}

# Function to list all stacks with their termination protection status
list_all_stacks() {
    log_info "Listing all CloudFormation stacks with termination protection status..."
    
    aws cloudformation describe-stacks \
        --region "$REGION" \
        --query 'Stacks[?Tags[?Key==`Project` && Value==`'$PROJECT_NAME'`]].[StackName,StackStatus,EnableTerminationProtection]' \
        --output table
}

# Function to disable termination protection for all project stacks
disable_all_termination_protections() {
    log_info "Disabling termination protection for all project stacks..."
    
    local stacks=$(aws cloudformation describe-stacks \
        --region "$REGION" \
        --query 'Stacks[?Tags[?Key==`Project` && Value==`'$PROJECT_NAME'`]].StackName' \
        --output text)
    
    for stack in $stacks; do
        disable_termination_protection "$stack"
    done
    
    log_success "Termination protection disabled for all stacks"
}

# Main deployment function
main() {
    log_info "=========================================="
    log_info "CloudFormation Deployment Script"
    log_info "Project: $PROJECT_NAME"
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    log_info "Termination Protection: DISABLED"
    log_info "=========================================="
    
    # Check prerequisites
    check_aws_cli
    check_aws_credentials
    
    # Get script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Parse command line arguments
    ACTION="${1:-deploy}"
    
    case $ACTION in
        deploy)
            log_info "Starting deployment of all stacks..."
            
            # Deploy VPC stack (if exists)
            if [ -f "$SCRIPT_DIR/vpc-stack.yaml" ]; then
                deploy_stack \
                    "${PROJECT_NAME}-vpc-${ENVIRONMENT}" \
                    "$SCRIPT_DIR/vpc-stack.yaml" \
                    "" \
                    "CAPABILITY_IAM"
            fi
            
            # Deploy EC2 stack (if exists)
            if [ -f "$SCRIPT_DIR/ec2-stack.yaml" ]; then
                deploy_stack \
                    "${PROJECT_NAME}-ec2-${ENVIRONMENT}" \
                    "$SCRIPT_DIR/ec2-stack.yaml" \
                    "$SCRIPT_DIR/ec2-parameters.json" \
                    "CAPABILITY_IAM"
            fi
            
            # Deploy EKS stack (if exists)
            if [ -f "$SCRIPT_DIR/eks-stack.yaml" ]; then
                deploy_stack \
                    "${PROJECT_NAME}-eks-${ENVIRONMENT}" \
                    "$SCRIPT_DIR/eks-stack.yaml" \
                    "" \
                    "CAPABILITY_NAMED_IAM"
            fi
            
            # Deploy monitoring stack (if exists)
            if [ -f "$SCRIPT_DIR/monitoring-stack.yaml" ]; then
                deploy_stack \
                    "${PROJECT_NAME}-monitoring-${ENVIRONMENT}" \
                    "$SCRIPT_DIR/monitoring-stack.yaml" \
                    "" \
                    "CAPABILITY_IAM"
            fi
            
            log_success "EKS deployment completed successfully!"
            list_all_stacks
            ;;
            
        deploy-ec2)
            log_info "Deploying EC2 stack (optional - application runs on EKS)..."
            
            # Deploy VPC first if it doesn't exist
            if [ -f "$SCRIPT_DIR/vpc-stack.yaml" ]; then
                if ! aws cloudformation describe-stacks --stack-name "${PROJECT_NAME}-vpc-${ENVIRONMENT}" --region "$REGION" 2>/dev/null; then
                    deploy_stack \
                        "${PROJECT_NAME}-vpc-${ENVIRONMENT}" \
                        "$SCRIPT_DIR/vpc-stack.yaml" \
                        "" \
                        "CAPABILITY_IAM"
                fi
            fi
            
            # Deploy EC2 stack
            if [ -f "$SCRIPT_DIR/ec2-stack.yaml" ]; then
                deploy_stack \
                    "${PROJECT_NAME}-ec2-${ENVIRONMENT}" \
                    "$SCRIPT_DIR/ec2-stack.yaml" \
                    "$SCRIPT_DIR/ec2-parameters.json" \
                    "CAPABILITY_IAM"
            fi
            
            log_success "EC2 stack deployed successfully!"
            list_all_stacks
            ;;
            
        delete)
            log_warning "Deleting all stacks..."
            STACK_NAME="${2}"
            
            if [ -z "$STACK_NAME" ]; then
                log_error "Please specify stack name: $0 delete <stack-name>"
                exit 1
            fi
            
            delete_stack "$STACK_NAME"
            ;;
            
        disable-protection)
            disable_all_termination_protections
            list_all_stacks
            ;;
            
        list)
            list_all_stacks
            ;;
            
        *)
            echo "Usage: $0 {deploy|deploy-ec2|delete <stack-name>|disable-protection|list}"
            echo ""
            echo "Commands:"
            echo "  deploy              - Deploy VPC + EKS stacks (primary deployment for application)"
            echo "  deploy-ec2          - Deploy EC2 stack (optional - application runs on EKS)"
            echo "  delete <stack-name> - Delete a specific stack"
            echo "  disable-protection  - Disable termination protection for all project stacks"
            echo "  list                - List all stacks with termination protection status"
            echo ""
            echo "Note: This application is deployed on EKS. EC2 deployment is optional."
            exit 1
            ;;
    esac
    
    log_success "Script completed successfully!"
}

# Run main function
main "$@"
