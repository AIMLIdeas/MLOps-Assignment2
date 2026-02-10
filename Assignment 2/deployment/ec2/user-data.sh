#!/bin/bash
# EC2 User Data Script
# This script runs on instance launch to set up the MNIST classifier service

set -e

# Update system
echo "Updating system packages..."
yum update -y

# Install Docker
echo "Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create application directory
echo "Creating application directory..."
mkdir -p /home/ec2-user/mnist-app
cd /home/ec2-user/mnist-app

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  mnist-api:
    image: ghcr.io/aimlideas/mnist-classifier:latest
    container_name: mnist-classifier
    ports:
      - "80:8000"
    environment:
      - MODEL_PATH=/app/models/mnist_cnn_model.pt
      - PYTHONUNBUFFERED=1
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Set GitHub credentials if provided
if [ ! -z "$GITHUB_USERNAME" ] && [ ! -z "$GITHUB_PAT" ]; then
    echo "Logging into GitHub Container Registry..."
    echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
fi

# Pull and start the application
echo "Starting MNIST classifier service..."
docker-compose pull
docker-compose up -d

# Set ownership
chown -R ec2-user:ec2-user /home/ec2-user/mnist-app

# Configure automatic updates
cat > /etc/cron.daily/update-mnist <<'EOF'
#!/bin/bash
cd /home/ec2-user/mnist-app
docker-compose pull
docker-compose up -d
EOF
chmod +x /etc/cron.daily/update-mnist

echo "MNIST Classifier service deployed successfully!"
echo "Service is available at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
