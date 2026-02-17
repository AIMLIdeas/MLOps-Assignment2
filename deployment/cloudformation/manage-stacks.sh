#!/bin/bash

# CloudFormation Stack Management Utility
# Manage all stacks with termination protection disabled

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_NAME="mlops-mnist"
REGION="${AWS_REGION:-us-east-1}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# List all project stacks with details
list_stacks() {
    log_info "Listing all CloudFormation stacks for project: $PROJECT_NAME"
    echo ""
    
    aws cloudformation describe-stacks \
        --region "$REGION" \
        --query "Stacks[?Tags[?Key=='Project' && Value=='$PROJECT_NAME']].[StackName,StackStatus,EnableTerminationProtection,CreationTime]" \
        --output table
    
    echo ""
    log_info "Total stacks found:"
    aws cloudformation describe-stacks \
        --region "$REGION" \
        --query "Stacks[?Tags[?Key=='Project' && Value=='$PROJECT_NAME']].StackName" \
        --output text | wc -w
}

# Check termination protection status for all stacks
check_protection_status() {
    log_info "Checking termination protection status..."
    echo ""
    
    local stacks=$(aws cloudformation describe-stacks \
        --region "$REGION" \
        --query "Stacks[?Tags[?Key=='Project' && Value=='$PROJECT_NAME']].StackName" \
        --output text)
    
    if [ -z "$stacks" ]; then
        log_warning "No stacks found for project: $PROJECT_NAME"
        return
    fi
    
    local all_disabled=true
    
    for stack in $stacks; do
        local protection=$(aws cloudformation describe-stacks \
            --stack-name "$stack" \
            --region "$REGION" \
            --query 'Stacks[0].EnableTerminationProtection' \
            --output text)
        
        if [ "$protection" == "False" ]; then
            echo -e "${GREEN}✓${NC} $stack: Termination protection DISABLED"
        else
            echo -e "${RED}✗${NC} $stack: Termination protection ENABLED"
            all_disabled=false
        fi
    done
    
    echo ""
    if [ "$all_disabled" == "true" ]; then
        log_success "All stacks have termination protection DISABLED"
    else
        log_warning "Some stacks have termination protection ENABLED"
    fi
}

# Disable termination protection for all stacks
disable_all_protection() {
    log_info "Disabling termination protection for all stacks..."
    echo ""
    
    local stacks=$(aws cloudformation describe-stacks \
        --region "$REGION" \
        --query "Stacks[?Tags[?Key=='Project' && Value=='$PROJECT_NAME']].StackName" \
        --output text)
    
    if [ -z "$stacks" ]; then
        log_warning "No stacks found for project: $PROJECT_NAME"
        return
    fi
    
    for stack in $stacks; do
        log_info "Disabling termination protection for: $stack"
        
        if aws cloudformation update-termination-protection \
            --stack-name "$stack" \
            --no-enable-termination-protection \
            --region "$REGION" 2>/dev/null; then
            log_success "✓ $stack"
        else
            log_warning "⚠ Failed to update $stack (may already be disabled)"
        fi
    done
    
    echo ""
    log_success "Completed disabling termination protection"
    echo ""
    check_protection_status
}

# Enable termination protection for all stacks
enable_all_protection() {
    log_warning "Enabling termination protection for all stacks..."
    echo ""
    
    local stacks=$(aws cloudformation describe-stacks \
        --region "$REGION" \
        --query "Stacks[?Tags[?Key=='Project' && Value=='$PROJECT_NAME']].StackName" \
        --output text)
    
    if [ -z "$stacks" ]; then
        log_warning "No stacks found for project: $PROJECT_NAME"
        return
    fi
    
    for stack in $stacks; do
        log_info "Enabling termination protection for: $stack"
        
        if aws cloudformation update-termination-protection \
            --stack-name "$stack" \
            --enable-termination-protection \
            --region "$REGION" 2>/dev/null; then
            log_success "✓ $stack"
        else
            log_warning "⚠ Failed to update $stack"
        fi
    done
    
    echo ""
    log_success "Completed enabling termination protection"
}

# Get detailed stack information
stack_info() {
    local stack_name=$1
    
    if [ -z "$stack_name" ]; then
        log_error "Stack name required"
        echo "Usage: $0 info <stack-name>"
        exit 1
    fi
    
    log_info "Stack Information: $stack_name"
    echo ""
    
    # Stack details
    echo "=== Stack Details ==="
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].[StackName,StackStatus,EnableTerminationProtection,CreationTime,LastUpdatedTime]' \
        --output table
    
    echo ""
    echo "=== Stack Outputs ==="
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs' \
        --output table || echo "No outputs available"
    
    echo ""
    echo "=== Stack Resources ==="
    aws cloudformation describe-stack-resources \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'StackResources[*].[LogicalResourceId,ResourceType,ResourceStatus]' \
        --output table
    
    echo ""
    echo "=== Stack Tags ==="
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Tags' \
        --output table
}

# Delete a stack (with protection disabled first)
delete_stack() {
    local stack_name=$1
    
    if [ -z "$stack_name" ]; then
        log_error "Stack name required"
        echo "Usage: $0 delete <stack-name>"
        exit 1
    fi
    
    log_warning "Preparing to delete stack: $stack_name"
    echo ""
    
    # Confirm deletion
    read -p "Are you sure you want to delete $stack_name? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Deletion cancelled"
        exit 0
    fi
    
    # Disable termination protection
    log_info "Disabling termination protection..."
    aws cloudformation update-termination-protection \
        --stack-name "$stack_name" \
        --no-enable-termination-protection \
        --region "$REGION" 2>/dev/null || true
    
    # Delete stack
    log_info "Deleting stack..."
    aws cloudformation delete-stack \
        --stack-name "$stack_name" \
        --region "$REGION"
    
    log_info "Stack deletion initiated. Waiting for completion..."
    log_warning "This may take several minutes..."
    
    aws cloudformation wait stack-delete-complete \
        --stack-name "$stack_name" \
        --region "$REGION"
    
    log_success "Stack deleted successfully: $stack_name"
}

# Delete all project stacks
delete_all_stacks() {
    log_warning "Preparing to delete ALL stacks for project: $PROJECT_NAME"
    echo ""
    
    list_stacks
    echo ""
    
    # Confirm deletion
    read -p "Are you sure you want to delete ALL stacks? (type 'DELETE ALL' to confirm): " confirm
    if [ "$confirm" != "DELETE ALL" ]; then
        log_info "Deletion cancelled"
        exit 0
    fi
    
    # Get all stacks
    local stacks=$(aws cloudformation describe-stacks \
        --region "$REGION" \
        --query "Stacks[?Tags[?Key=='Project' && Value=='$PROJECT_NAME']].StackName" \
        --output text)
    
    if [ -z "$stacks" ]; then
        log_warning "No stacks found to delete"
        return
    fi
    
    # Disable protection for all stacks first
    log_info "Disabling termination protection for all stacks..."
    disable_all_protection
    
    # Delete stacks in reverse dependency order
    echo ""
    log_info "Deleting stacks..."
    
    # Delete in order: EKS -> EC2 -> VPC
    for pattern in "eks" "ec2" "vpc"; do
        for stack in $stacks; do
            if echo "$stack" | grep -qi "$pattern"; then
                log_info "Deleting $stack..."
                aws cloudformation delete-stack \
                    --stack-name "$stack" \
                    --region "$REGION"
            fi
        done
    done
    
    log_info "All stack deletions initiated"
    log_warning "Stacks are being deleted in the background. This may take 10-20 minutes."
}

# Export stack template
export_template() {
    local stack_name=$1
    local output_file="${2:-${stack_name}-template.yaml}"
    
    if [ -z "$stack_name" ]; then
        log_error "Stack name required"
        echo "Usage: $0 export <stack-name> [output-file]"
        exit 1
    fi
    
    log_info "Exporting template for stack: $stack_name"
    
    aws cloudformation get-template \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'TemplateBody' \
        --output text > "$output_file"
    
    log_success "Template exported to: $output_file"
}

# Show stack events
show_events() {
    local stack_name=$1
    local count="${2:-20}"
    
    if [ -z "$stack_name" ]; then
        log_error "Stack name required"
        echo "Usage: $0 events <stack-name> [count]"
        exit 1
    fi
    
    log_info "Recent events for stack: $stack_name (showing last $count)"
    echo ""
    
    aws cloudformation describe-stack-events \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --max-items "$count" \
        --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
        --output table
}

# Show usage
show_usage() {
    cat << EOF
CloudFormation Stack Management Utility

Usage: $0 <command> [options]

Commands:
    list                    - List all project stacks with status
    check                   - Check termination protection status
    disable                 - Disable termination protection for all stacks
    enable                  - Enable termination protection for all stacks
    info <stack-name>       - Show detailed stack information
    delete <stack-name>     - Delete a specific stack
    delete-all              - Delete all project stacks
    export <stack-name>     - Export stack template to file
    events <stack-name>     - Show recent stack events

Environment Variables:
    AWS_REGION             - AWS region (default: us-east-1)
    PROJECT_NAME           - Project name filter (default: mlops-mnist)

Examples:
    $0 list
    $0 check
    $0 disable
    $0 info mlops-mnist-vpc-production
    $0 delete mlops-mnist-ec2-production
    $0 events mlops-mnist-eks-production

Note: All operations ensure termination protection is DISABLED before deletions.
EOF
}

# Main
case "${1:-list}" in
    list)
        list_stacks
        ;;
    check|status)
        check_protection_status
        ;;
    disable|disable-protection)
        disable_all_protection
        ;;
    enable|enable-protection)
        enable_all_protection
        ;;
    info|describe)
        stack_info "$2"
        ;;
    delete)
        delete_stack "$2"
        ;;
    delete-all)
        delete_all_stacks
        ;;
    export)
        export_template "$2" "$3"
        ;;
    events)
        show_events "$2" "$3"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
