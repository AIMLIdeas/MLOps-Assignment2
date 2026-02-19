# Prometheus Quick Start Guide

This is a TL;DR version. For full details, see [PROMETHEUS_AWS_INTEGRATION.md](PROMETHEUS_AWS_INTEGRATION.md)

## Fastest Path: Deploy Prometheus to EKS (5 minutes)

### Prerequisites
- AWS EKS cluster running
- kubectl configured
- Your API already exposes `/metrics` endpoint


### Access Prometheus

**AWS Prometheus URL:** http://a513b9214446b450f8a77c2e43a6ee1d-1115903209.us-east-1.elb.amazonaws.com:9090

### Useful Prometheus Queries

Copy-paste these into Prometheus Graph tab:

```promql
# Total API requests
sum(api_requests_total)

# Request rate per second
rate(api_requests_total[5m])

# Request rate by endpoint
sum(rate(api_requests_total[5m])) by (endpoint)

# Average latency (in seconds)
rate(api_request_latency_seconds_sum[5m]) / rate(api_request_latency_seconds_count[5m])

# 50th percentile latency (median)
histogram_quantile(0.50, sum(rate(api_request_latency_seconds_bucket[5m])) by (le))

# 95th percentile latency
histogram_quantile(0.95, sum(rate(api_request_latency_seconds_bucket[5m])) by (le))

# 99th percentile latency
histogram_quantile(0.99, sum(rate(api_request_latency_seconds_bucket[5m])) by (le))

# Total predictions made
sum(predictions_total)

# Predictions by class (cat vs dog)
sum(predictions_total) by (label)

# Request rate by status code
sum(rate(api_requests_total[5m])) by (status)

# Error rate (5xx errors as percentage)
(sum(rate(api_requests_total{status=~"5.."}[5m])) / sum(rate(api_requests_total[5m]))) * 100

# Successful request rate (2xx)
sum(rate(api_requests_total{status=~"2.."}[5m]))
```

---

