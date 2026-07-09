#!/bin/bash
set -x
exec > >(tee /var/log/cloudvault-deploy.log) 2>&1

echo "===== STARTING CLOUDVAULT INSTANCE SETUP ====="

# 1. Update system
dnf update -y
dnf install -y docker git

# 2. Create swap file (prevents OOM during docker build on small instances)
if ! swapon --show | grep -q '/swapfile'; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Swap file created (2GB)"
fi

# 3. Start Docker
systemctl enable docker
systemctl start docker

# 4. Clone repos
mkdir -p /opt/cloudvault
cd /opt/cloudvault

echo "Cloning repositories..."
git clone https://github.com/YOUR_USERNAME/file_manager_backend.git backend
git clone https://github.com/YOUR_USERNAME/file_manager_frontend.git frontend

# 5. Fetch public IP
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Instance public IP: $PUBLIC_IP"

# 6. Build and run Backend (port mapping: host:3000 <- container:80)
echo "Building Rails backend..."
cd /opt/cloudvault/backend
docker build -t cloudvault-api .

docker run -d \
  --name cloudvault-api \
  -p 3000:80 \
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY=YOUR_RAILS_MASTER_KEY \
  -e DATABASE_URL=postgres://postgres:YOUR_DB_PASSWORD@YOUR_RDS_ENDPOINT:5432/cloudvault_production \
  -e AWS_REGION=us-east-1 \
  -e AWS_BUCKET_NAME=YOUR_S3_BUCKET \
  -e AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY \
  -e AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_KEY \
  -e JWT_SECRET=YOUR_JWT_SECRET \
  -e CORS_ORIGINS=http://$PUBLIC_IP \
  -e DOMAIN=$PUBLIC_IP \
  -e LAMBDA_WEBHOOK_SECRET=YOUR_LAMBDA_WEBHOOK_SECRET \
  --restart unless-stopped \
  cloudvault-api

# 7. Build and run Frontend
echo "Building React frontend..."
cd /opt/cloudvault/frontend
docker build -t cloudvault-ui .

docker run -d \
  --name cloudvault-ui \
  -p 80:80 \
  -e VITE_API_URL=http://$PUBLIC_IP:3000 \
  --restart unless-stopped \
  cloudvault-ui

echo "===== CLOUDVAULT DEPLOYMENT COMPLETE ====="
echo "Frontend: http://$PUBLIC_IP"
echo "Backend API: http://$PUBLIC_IP:3000"
