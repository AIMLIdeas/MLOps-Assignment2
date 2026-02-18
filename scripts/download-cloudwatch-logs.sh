#!/bin/bash

#######################################################
# CloudWatch Logs Downloader
# Downloads logs from AWS CloudWatch to local files
#######################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
OUTPUT_DIR="logs/cloudwatch"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
TIME_RANGE="1h"  # Default: last 1 hour

# Log group names
EKS_LOG_GROUP="/aws/eks/mlops-assignment2-cluster/cluster"
EC2_LOG_GROUP="/aws/ec2/mlops-mnist"

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}   CloudWatch Logs Downloader${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Download CloudWatch logs from AWS EKS or EC2 deployments

OPTIONS:
    -t, --type TYPE          Log type: 'eks', 'ec2', or 'both' (default: both)
    -r, --region REGION      AWS region (default: us-east-1)
    -d, --duration DURATION  Time range: 1h, 6h, 12h, 24h, 7d (default: 1h)
    -o, --output DIR         Output directory (default: logs/cloudwatch)
    -g, --log-group GROUP    Custom log group name
    -s, --start START        Start time (Unix timestamp in milliseconds)
    -e, --end END            End time (Unix timestamp in milliseconds)
    -f, --filter PATTERN     Filter pattern for log events
    -l, --limit LIMIT        Maximum number of log events (default: 10000)
    -h, --help               Show this help message

EXAMPLES:
    # Download last hour of EKS logs
    $0 --type eks --duration 1h

    # Download last 24 hours of EC2 logs
    $0 --type ec2 --duration 24h

    # Download both EKS and EC2 logs from last 6 hours
    $0 --type both --duration 6h

    # Download with custom time range
    $0 --type eks --start 1640000000000 --end 1640100000000

    # Download with filter pattern
    $0 --type eks --filter "ERROR" --duration 1h

    # Download from custom log group
    $0 --log-group /aws/containerinsights/my-cluster/application --duration 1h

TIME FORMATS:
    1h  = Last 1 hour
    6h  = Last 6 hours
    12h = Last 12 hours
    24h = Last 24 hours
    7d  = Last 7 days
    30d = Last 30 days

EOF
}

# Parse command line arguments
TYPE="both"
CUSTOM_LOG_GROUP=""
START_TIME=""
END_TIME=""
FILTER_PATTERN=""
LIMIT=10000

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            TYPE="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -d|--duration)
            TIME_RANGE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -g|--log-group)
            CUSTOM_LOG_GROUP="$2"
            shift 2
            ;;
        -s|--start)
            START_TIME="$2"
            shift 2
            ;;
        -e|--end)
            END_TIME="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER_PATTERN="$2"
            shift 2
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Calculate time range
calculate_time_range() {
    local duration=$1
    local end_ms=$(date +%s)000  # Current time in milliseconds
    local start_ms
    
    case $duration in
        1h)
            start_ms=$((end_ms - 3600000))  # 1 hour
            ;;
        6h)
            start_ms=$((end_ms - 21600000))  # 6 hours
            ;;
        12h)
            start_ms=$((end_ms - 43200000))  # 12 hours
            ;;
        24h)
            start_ms=$((end_ms - 86400000))  # 24 hours
            ;;
        7d)
            start_ms=$((end_ms - 604800000))  # 7 days
            ;;
        30d)
            start_ms=$((end_ms - 2592000000))  # 30 days
            ;;
        *)
            print_error "Invalid duration: $duration"
            exit 1
            ;;
    esac
    
    echo "$start_ms $end_ms"
}

# Check if log group exists
check_log_group() {
    local log_group=$1
    
    if aws logs describe-log-groups \
        --log-group-name-prefix "$log_group" \
        --region "$REGION" \
        --output json 2>/dev/null | grep -q "$log_group"; then
        return 0
    else
        return 1
    fi
}

# Download logs from a log group
download_logs() {
    local log_group=$1
    local output_file=$2
    local type_name=$3
    
    print_info "Downloading $type_name logs from: $log_group"
    
    # Check if log group exists
    if ! check_log_group "$log_group"; then
        print_error "Log group not found: $log_group"
        print_info "Skipping $type_name logs..."
        return 1
    fi
    
    # Build filter-log-events command
    local cmd="aws logs filter-log-events \
        --log-group-name \"$log_group\" \
        --region \"$REGION\" \
        --max-items $LIMIT"
    
    # Add time range
    if [[ -n "$START_TIME" && -n "$END_TIME" ]]; then
        cmd="$cmd --start-time $START_TIME --end-time $END_TIME"
    else
        read start end <<< $(calculate_time_range "$TIME_RANGE")
        cmd="$cmd --start-time $start --end-time $end"
    fi
    
    # Add filter pattern if provided
    if [[ -n "$FILTER_PATTERN" ]]; then
        cmd="$cmd --filter-pattern \"$FILTER_PATTERN\""
    fi
    
    # Execute and save
    print_info "Executing: $cmd"
    
    if eval "$cmd > \"$output_file\" 2>&1"; then
        local event_count=$(grep -o '"timestamp"' "$output_file" | wc -l | tr -d ' ')
        print_success "Downloaded $event_count log events to: $output_file"
        
        # Create a human-readable version
        local readable_file="${output_file%.json}.txt"
        extract_log_messages "$output_file" "$readable_file"
        print_success "Created readable log file: $readable_file"
        
        return 0
    else
        print_error "Failed to download logs from: $log_group"
        return 1
    fi
}

# Extract log messages to readable format
extract_log_messages() {
    local input_file=$1
    local output_file=$2
    
    echo "CloudWatch Logs - $(date)" > "$output_file"
    echo "=====================================" >> "$output_file"
    echo "" >> "$output_file"
    
    if command -v jq &> /dev/null; then
        # Use jq if available for better formatting
        jq -r '.events[] | "\(.timestamp | tonumber / 1000 | strftime("%Y-%m-%d %H:%M:%S")) - \(.message)"' \
            "$input_file" >> "$output_file" 2>/dev/null || \
        grep -o '"message":"[^"]*"' "$input_file" | \
            sed 's/"message":"//g' | sed 's/"$//g' >> "$output_file"
    else
        # Fallback: simple text extraction
        grep -o '"message":"[^"]*"' "$input_file" | \
            sed 's/"message":"//g' | sed 's/"$//g' >> "$output_file"
    fi
}

# Main execution
main() {
    print_header
    
    # Verify AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Verify AWS credentials
    print_info "Verifying AWS credentials..."
    if ! aws sts get-caller-identity --region "$REGION" &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        print_info "Run: aws configure"
        exit 1
    fi
    print_success "AWS credentials verified"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Set timestamp for filenames
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    echo ""
    print_info "Configuration:"
    echo "  Type: $TYPE"
    echo "  Region: $REGION"
    echo "  Time Range: $TIME_RANGE"
    echo "  Output Directory: $OUTPUT_DIR"
    if [[ -n "$FILTER_PATTERN" ]]; then
        echo "  Filter Pattern: $FILTER_PATTERN"
    fi
    echo ""
    
    # Download logs based on type
    if [[ "$CUSTOM_LOG_GROUP" != "" ]]; then
        # Download from custom log group
        OUTPUT_FILE="$OUTPUT_DIR/custom_${TIMESTAMP}.json"
        download_logs "$CUSTOM_LOG_GROUP" "$OUTPUT_FILE" "custom"
    elif [[ "$TYPE" == "eks" || "$TYPE" == "both" ]]; then
        # Download EKS logs
        EKS_OUTPUT="$OUTPUT_DIR/eks_${TIMESTAMP}.json"
        download_logs "$EKS_LOG_GROUP" "$EKS_OUTPUT" "EKS"
    fi
    
    if [[ "$TYPE" == "ec2" || "$TYPE" == "both" ]]; then
        # Download EC2 logs
        EC2_OUTPUT="$OUTPUT_DIR/ec2_${TIMESTAMP}.json"
        download_logs "$EC2_LOG_GROUP" "$EC2_OUTPUT" "EC2"
    fi
    
    echo ""
    print_success "Log download complete!"
    print_info "Logs saved to: $OUTPUT_DIR"
    
    # List downloaded files
    echo ""
    print_info "Downloaded files:"
    ls -lh "$OUTPUT_DIR" | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'
}

# Run main function
main
