#!/bin/bash

################################################################################
# AWS EKS Application Test Script
# 
# This script tests the deployed application on AWS EKS
# 
# Usage:
#   ./test-aws-deployment.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Testing AWS EKS Deployment${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

################################################################################
# Check Prerequisites
################################################################################

echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo ""

################################################################################
# Get LoadBalancer URL
################################################################################

echo -e "${YELLOW}1. Getting LoadBalancer URL...${NC}"
LOADBALANCER_URL=$(kubectl get svc cat-dogs-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$LOADBALANCER_URL" ]; then
    echo -e "${RED}❌ Error: LoadBalancer URL not found${NC}"
    echo "   Make sure the application is deployed to EKS"
    echo ""
    echo "   Check deployment status:"
    echo "   kubectl get svc -n mlops"
    echo "   kubectl get pods -n mlops"
    exit 1
fi

API_URL="http://$LOADBALANCER_URL"
echo -e "${GREEN}✅ API URL: ${API_URL}${NC}"
echo ""

################################################################################
# Test Health Endpoint
################################################################################

echo -e "${YELLOW}2. Testing health endpoint...${NC}"
HEALTH_RESPONSE=$(curl -s "$API_URL/health" 2>/dev/null || echo "")

if [ -n "$HEALTH_RESPONSE" ] && [[ $HEALTH_RESPONSE == *"status"* ]]; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo -e "${RED}❌ Health check failed${NC}"
    echo "   Response: $HEALTH_RESPONSE"
    echo ""
    echo "   Checking pod logs..."
    kubectl logs -l app=cat-dogs-classifier -n mlops --tail=20
    exit 1
fi
echo ""

################################################################################
# Test Root Endpoint
################################################################################

echo -e "${YELLOW}3. Testing root endpoint...${NC}"
ROOT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/" 2>/dev/null || echo "000")

if [ "$ROOT_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ Root endpoint accessible (HTTP $ROOT_RESPONSE)${NC}"
else
    echo -e "${YELLOW}⚠️  Root endpoint returned HTTP $ROOT_RESPONSE${NC}"
fi
echo ""

################################################################################
# Test Prediction Endpoint with Cat Image
################################################################################

echo -e "${YELLOW}4. Testing prediction endpoint (cat image)...${NC}"
PREDICT_CAT=$(curl -s -X POST "$API_URL/predict" \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"}' 2>/dev/null || echo "")

if [ -n "$PREDICT_CAT" ] && [[ $PREDICT_CAT == *"prediction"* ]]; then
    echo -e "${GREEN}✅ Cat prediction working${NC}"
    echo "   Response: $PREDICT_CAT"
else
    echo -e "${RED}❌ Cat prediction failed${NC}"
    echo "   Response: $PREDICT_CAT"
fi
echo ""

################################################################################
# Test Prediction Endpoint with Dog Image
################################################################################

echo -e "${YELLOW}5. Testing prediction endpoint (dog image)...${NC}"
PREDICT_DOG=$(curl -s -X POST "$API_URL/predict" \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://images.unsplash.com/photo-1543466835-00a7907e9de1"}' 2>/dev/null || echo "")

if [ -n "$PREDICT_DOG" ] && [[ $PREDICT_DOG == *"prediction"* ]]; then
    echo -e "${GREEN}✅ Dog prediction working${NC}"
    echo "   Response: $PREDICT_DOG"
else
    echo -e "${RED}❌ Dog prediction failed${NC}"
    echo "   Response: $PREDICT_DOG"
fi
echo ""

################################################################################
# Check Pod Status
################################################################################

echo -e "${YELLOW}6. Checking pod status...${NC}"
POD_STATUS=$(kubectl get pods -n mlops -l app=cat-dogs-classifier --no-headers 2>/dev/null || echo "")

if [ -z "$POD_STATUS" ]; then
    echo -e "${RED}❌ No pods found${NC}"
else
    echo "$POD_STATUS"
    RUNNING_PODS=$(echo "$POD_STATUS" | grep -c "Running" || echo "0")
    TOTAL_PODS=$(echo "$POD_STATUS" | wc -l)
    
    if [ "$RUNNING_PODS" -gt 0 ]; then
        echo -e "${GREEN}✅ Running pods: $RUNNING_PODS/$TOTAL_PODS${NC}"
    else
        echo -e "${RED}❌ No running pods${NC}"
    fi
fi
echo ""

################################################################################
# Check HPA Status
################################################################################

echo -e "${YELLOW}7. Checking auto-scaling (HPA)...${NC}"
HPA_STATUS=$(kubectl get hpa -n mlops --no-headers 2>/dev/null || echo "")

if [ -z "$HPA_STATUS" ]; then
    echo -e "${YELLOW}⚠️  HPA not found${NC}"
else
    echo "$HPA_STATUS"
    echo -e "${GREEN}✅ HPA configured${NC}"
fi
echo ""

################################################################################
# Performance Test
################################################################################

echo -e "${YELLOW}8. Running performance test (10 requests)...${NC}"

if command -v bc &> /dev/null; then
    TOTAL_TIME=0
    SUCCESS_COUNT=0
    
    for i in {1..10}; do
        START=$(date +%s.%N)
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null || echo "000")
        END=$(date +%s.%N)
        
        if [ "$HTTP_CODE" = "200" ]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            TIME=$(echo "$END - $START" | bc)
            TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc)
        fi
    done
    
    if [ "$SUCCESS_COUNT" -gt 0 ]; then
        AVG_TIME=$(echo "scale=3; $TOTAL_TIME / $SUCCESS_COUNT" | bc)
        echo -e "${GREEN}✅ Success rate: $SUCCESS_COUNT/10${NC}"
        echo -e "${GREEN}✅ Average response time: ${AVG_TIME}s${NC}"
    else
        echo -e "${RED}❌ All requests failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  'bc' not installed, skipping detailed timing${NC}"
    
    SUCCESS_COUNT=0
    for i in {1..10}; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    done
    echo -e "${GREEN}✅ Success rate: $SUCCESS_COUNT/10${NC}"
fi
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${GREEN}Application URL:${NC} $API_URL"
echo ""
echo -e "${GREEN}Quick Access:${NC}"
echo "  Web Interface: $API_URL/"
echo "  Health Check:  $API_URL/health"
echo "  API Docs:      $API_URL/docs"
echo ""
echo -e "${GREEN}Test Commands:${NC}"
echo "  # Test health"
echo "  curl $API_URL/health"
echo ""
echo "  # Test prediction (cat)"
echo "  curl -X POST $API_URL/predict -H 'Content-Type: application/json' -d '{\"image_url\":\"https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba\"}'"
echo ""
echo "  # View logs"
echo "  kubectl logs -f -l app=cat-dogs-classifier -n mlops"
echo ""
echo "  # Check pods"
echo "  kubectl get pods -n mlops"
echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✅ Testing complete!${NC}"
echo -e "${BLUE}======================================${NC}"
