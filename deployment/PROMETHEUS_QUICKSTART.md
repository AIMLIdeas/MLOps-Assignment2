# Prometheus Quick Start Guide

This is a TL;DR version. For full details, see [PROMETHEUS_AWS_INTEGRATION.md](PROMETHEUS_AWS_INTEGRATION.md)

## Fastest Path: Deploy Prometheus to EKS (5 minutes)

### Prerequisites
- AWS EKS cluster running
- kubectl configured
- Your API already exposes `/metrics` endpoint


### Access Prometheus
AWS Prometheus URL: http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com:9090


Prompts for Prometheus:

# Request rate per second
rate(api_requests_total[5m])

# Average latency
rate(api_request_latency_seconds_sum[5m]) / rate(api_request_latency_seconds_count[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(api_request_latency_seconds_bucket[5m]))

# Total predictions
sum(predictions_total)

# Predictions by class
sum(predictions_total) by (label)

# Error rate
sum(rate(api_requests_total{status=~"5.."}[5m])) / sum(rate(api_requests_total[5m])) * 100

---

