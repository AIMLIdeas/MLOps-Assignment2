# Prometheus Integration with AWS EKS

This guide covers three approaches to integrate Prometheus monitoring with your AWS EKS deployment.

## Current Setup
- Your API already exposes Prometheus metrics at `/metrics` endpoint
- Metrics include: request counts, latency histograms, and prediction counts
- Currently running Prometheus locally via Docker Compose

## Option 1: Deploy Prometheus Directly to EKS (Recommended for Quick Start)

### Deploy Prometheus

```bash
# Apply Prometheus manifests
kubectl apply -f deployment/kubernetes/prometheus-deployment.yaml

# Check deployment status
kubectl get pods -n mlops -l app=prometheus
kubectl get svc -n mlops prometheus

# Get Prometheus URL
kubectl get svc -n mlops prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Access Prometheus Dashboard

```bash
# Get the LoadBalancer URL
PROMETHEUS_URL=$(kubectl get svc -n mlops prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Prometheus URL: http://${PROMETHEUS_URL}:9090"

# Open in browser
open "http://${PROMETHEUS_URL}:9090"
```

### Verify Metrics Collection

1. Open Prometheus UI
2. Go to Status → Targets
3. Verify `cats-dogs-api` job shows UP status
4. Query metrics: `api_requests_total`, `api_request_latency_seconds`

### Useful Prometheus Queries

```promql
# Total requests
sum(api_requests_total)

# Request rate (per second)
rate(api_requests_total[5m])

# Average latency
rate(api_request_latency_seconds_sum[5m]) / rate(api_request_latency_seconds_count[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(api_request_latency_seconds_bucket[5m]))

# Predictions by class
predictions_total{label="cat"}
predictions_total{label="dog"}

# Error rate
sum(rate(api_requests_total{status=~"5.."}[5m])) / sum(rate(api_requests_total[5m]))
```

---

## Option 2: AWS Managed Prometheus (AMP) - Production Grade

AWS Managed Service for Prometheus is fully managed, scalable, and integrates with CloudWatch.

### Setup AMP Workspace

```bash
# Create AMP workspace
aws amp create-workspace \
  --alias mlops-cats-dogs \
  --region us-east-1

# Get workspace ID
WORKSPACE_ID=$(aws amp list-workspaces --region us-east-1 \
  --query 'workspaces[?alias==`mlops-cats-dogs`].workspaceId' \
  --output text)

echo "Workspace ID: $WORKSPACE_ID"
```

### Deploy Prometheus Agent to EKS

Create `deployment/kubernetes/prometheus-amp.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-amp-config
  namespace: mlops
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      external_labels:
        cluster: mlops-eks-cluster
        environment: production
    
    scrape_configs:
      - job_name: 'cats-dogs-api'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - mlops
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: cat-dogs-classifier
          - source_labels: [__meta_kubernetes_pod_ip]
            action: replace
            target_label: __address__
            replacement: $1:8000
        metrics_path: '/metrics'
    
    remote_write:
      - url: https://aps-workspaces.us-east-1.amazonaws.com/workspaces/${WORKSPACE_ID}/api/v1/remote_write
        queue_config:
          max_samples_per_send: 1000
          max_shards: 200
          capacity: 2500
        sigv4:
          region: us-east-1

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-amp
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-amp
  template:
    metadata:
      labels:
        app: prometheus-amp
    spec:
      serviceAccountName: prometheus-amp
      containers:
      - name: prometheus
        image: public.ecr.aws/prometheus/prometheus:latest
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-amp-config
      - name: prometheus-storage
        emptyDir: {}

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-amp
  namespace: mlops
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/PrometheusServiceAccountRole
```

### Create IAM Role for AMP

```bash
# Create IAM policy
cat > amp-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "aps:RemoteWrite",
        "aps:QueryMetrics",
        "aps:GetSeries",
        "aps:GetLabels",
        "aps:GetMetricMetadata"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name AMPWritePolicy \
  --policy-document file://amp-policy.json

# Create service account with IRSA
eksctl create iamserviceaccount \
  --name prometheus-amp \
  --namespace mlops \
  --cluster mlops-eks-cluster \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AMPWritePolicy \
  --approve \
  --region us-east-1
```

### Query AMP from AWS Console

1. Go to Amazon Managed Service for Prometheus console
2. Select your workspace
3. Use Query Builder or PromQL editor
4. Or integrate with Grafana (see Option 3)

**Costs**: ~$0.10/million samples ingested + $0.024/GB stored

---

## Option 3: Add Grafana for Visualization

### Deploy Grafana to EKS

Create `deployment/kubernetes/grafana-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"  # Change this!
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: mlops
spec:
  type: LoadBalancer
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
```

### Deploy and Access Grafana

```bash
# Deploy Grafana
kubectl apply -f deployment/kubernetes/grafana-deployment.yaml

# Get Grafana URL
GRAFANA_URL=$(kubectl get svc -n mlops grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana URL: http://${GRAFANA_URL}:3000"
echo "Username: admin"
echo "Password: admin123"
```

### Configure Grafana Data Source

1. Login to Grafana
2. Configuration → Data Sources → Add data source
3. Select Prometheus
4. **For Option 1**: URL: `http://prometheus.mlops.svc.cluster.local:9090`
   **For Option 2 (AMP)**: Use AWS data source plugin and your workspace URL
5. Save & Test

### Import Dashboard

1. Create → Import
2. Use this JSON or paste ID: 1860 (Node Exporter Full)
3. Or create custom dashboard with these panels:

**Request Rate Panel:**
```promql
sum(rate(api_requests_total[5m])) by (method, endpoint)
```

**Latency Panel (P95, P99):**
```promql
histogram_quantile(0.95, rate(api_request_latency_seconds_bucket[5m]))
histogram_quantile(0.99, rate(api_request_latency_seconds_bucket[5m]))
```

**Predictions Panel:**
```promql
sum(predictions_total) by (label)
```

**Error Rate Panel:**
```promql
sum(rate(api_requests_total{status=~"5.."}[5m])) / sum(rate(api_requests_total[5m])) * 100
```

---

## Option 4: CloudWatch Container Insights

For AWS-native monitoring without Prometheus:

```bash
# Install Container Insights
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/mlops-eks-cluster/;s/{{region_name}}/us-east-1/" | kubectl apply -f -

# View metrics in CloudWatch Console
# CloudWatch → Container Insights → Performance monitoring
```

---

## Recommended Approach

**For Development/Testing**: Option 1 (Direct Prometheus deployment)
- Simple setup
- Quick to deploy
- Free (just EC2 costs)

**For Production**: Option 2 (AWS Managed Prometheus) + Option 3 (Grafana)
- Fully managed
- Scalable
- Integrates with AWS ecosystem
- Long-term retention

---

## Testing Your Setup

```bash
# Generate some traffic
API_URL="http://a464126408ba744778040079b625c9b4-1b7df649871d3e3b.elb.us-east-1.amazonaws.com"

# Health checks
for i in {1..10}; do
  curl $API_URL/health
  sleep 1
done

# Predictions
curl -X POST $API_URL/predict-image \
  -H "Content-Type: application/json" \
  -d '{"image":"'"$(base64 -i sample_image.jpg)"'"}'

# View stats
curl $API_URL/stats

# Check raw metrics
curl $API_URL/metrics
```

Then verify metrics appear in your Prometheus/Grafana dashboards.

---

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check if Prometheus can reach the app
kubectl exec -n mlops deployment/prometheus -- wget -O- http://cat-dogs-deployment.mlops.svc.cluster.local:8000/metrics

# Check Prometheus logs
kubectl logs -n mlops deployment/prometheus --tail=50

# Verify service discovery
kubectl get pods -n mlops -l app=cat-dogs-classifier -o wide
```

### No Data in Grafana

1. Check data source configuration (Test connection)
2. Verify Prometheus is collecting metrics (check targets)
3. Check time range in Grafana (last 5 minutes)
4. Ensure pods are running: `kubectl get pods -n mlops`

### High Memory Usage

```bash
# Reduce retention time
--storage.tsdb.retention.time=3d

# Or use persistent volume instead of emptyDir
# Create PVC and mount to /prometheus
```

---

## Cost Estimates (AWS)

**Option 1 (Self-hosted)**:
- Additional EC2 costs for Prometheus pod: ~$5-10/month (small instance)

**Option 2 (AMP)**:
- ~10,000 samples/min = ~$15/month
- Storage: ~$5/month for 200GB
- **Total**: ~$20/month

**Option 3 (+ Grafana)**:
- Add ~$5/month for Grafana pod

**Option 4 (Container Insights)**:
- ~$0.30 per GB of logs ingested
- Custom metrics: $0.30 per metric/month
- **Total**: ~$10-30/month depending on volume

---

## Next Steps

1. **Choose your option** (recommend starting with Option 1)
2. **Deploy Prometheus** to EKS
3. **Verify metrics** are being collected
4. **Set up Grafana** for visualization (optional but recommended)
5. **Create alerts** in Prometheus or CloudWatch
6. **Document your dashboards** for the team

For production deployments, consider:
- Persistent storage for Prometheus data
- Grafana user authentication
- Alertmanager configuration
- Backup and disaster recovery
