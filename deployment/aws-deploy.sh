#!/bin/bash

# AWS Deployment Script for Hydration App
# This script automates the deployment to AWS EC2 for participant testing

set -e  # Exit on any error

echo "☁️ Starting AWS Deployment for Hydration App..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first:"
    echo "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    echo "unzip awscliv2.zip"
    echo "sudo ./aws/install"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run: aws configure"
    exit 1
fi

# Get AWS account info
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
print_status "AWS Account: $AWS_ACCOUNT_ID"
print_status "AWS Region: $AWS_REGION"

# Configuration
APP_NAME="hydration-app"
ENVIRONMENT="production"
INSTANCE_TYPE="t3.medium"
KEY_PAIR_NAME="hydration-app-key"
SECURITY_GROUP_NAME="hydration-app-sg"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"

print_step "Step 1: Creating VPC and Networking"

# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$APP_NAME-vpc
print_status "Created VPC: $VPC_ID"

# Enable DNS resolution
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$APP_NAME-igw
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
print_status "Created Internet Gateway: $IGW_ID"

# Create Subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=$APP_NAME-subnet
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch
print_status "Created Subnet: $SUBNET_ID"

# Create Route Table
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=Name,Value=$APP_NAME-rt
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $ROUTE_TABLE_ID
print_status "Created Route Table: $ROUTE_TABLE_ID"

print_step "Step 2: Creating Security Group"

# Create Security Group
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "Security group for Hydration App" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $SECURITY_GROUP_ID --tags Key=Name,Value=$APP_NAME-sg

# Add inbound rules
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 3000 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 5000 --cidr 0.0.0.0/0
print_status "Created Security Group: $SECURITY_GROUP_ID"

print_step "Step 3: Creating Key Pair"

# Create Key Pair
if ! aws ec2 describe-key-pairs --key-names $KEY_PAIR_NAME &> /dev/null; then
    aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --query 'KeyMaterial' --output text > ${KEY_PAIR_NAME}.pem
    chmod 400 ${KEY_PAIR_NAME}.pem
    print_status "Created Key Pair: $KEY_PAIR_NAME"
else
    print_warning "Key Pair $KEY_PAIR_NAME already exists"
fi

print_step "Step 4: Creating RDS Database"

# Create DB Subnet Group
aws rds create-db-subnet-group \
    --db-subnet-group-name $APP_NAME-db-subnet-group \
    --db-subnet-group-description "Subnet group for Hydration App database" \
    --subnet-ids $SUBNET_ID \
    --query 'DBSubnetGroup.DBSubnetGroupName' --output text

# Create DB Security Group
DB_SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $APP_NAME-db-sg --description "Security group for Hydration App database" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $DB_SECURITY_GROUP_ID --protocol tcp --port 5432 --source-group $SECURITY_GROUP_ID

# Generate random password
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Create RDS Instance
DB_INSTANCE_IDENTIFIER="$APP_NAME-db"
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.4 \
    --master-username hydration_user \
    --master-user-password $DB_PASSWORD \
    --allocated-storage 20 \
    --storage-type gp2 \
    --vpc-security-group-ids $DB_SECURITY_GROUP_ID \
    --db-subnet-group-name $APP_NAME-db-subnet-group \
    --backup-retention-period 7 \
    --multi-az \
    --storage-encrypted \
    --no-publicly-accessible \
    --query 'DBInstance.DBInstanceIdentifier' --output text

print_status "Creating RDS Database: $DB_INSTANCE_IDENTIFIER"
print_warning "Database creation takes 5-10 minutes..."

# Wait for database to be available
aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_IDENTIFIER
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_IDENTIFIER --query 'DBInstances[0].Endpoint.Address' --output text)
print_status "Database is ready: $DB_ENDPOINT"

print_step "Step 5: Creating ElastiCache Redis"

# Create Redis Subnet Group
aws elasticache create-cache-subnet-group \
    --cache-subnet-group-name $APP_NAME-redis-subnet-group \
    --cache-subnet-group-description "Subnet group for Hydration App Redis" \
    --subnet-ids $SUBNET_ID

# Create Redis Security Group
REDIS_SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $APP_NAME-redis-sg --description "Security group for Hydration App Redis" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $REDIS_SECURITY_GROUP_ID --protocol tcp --port 6379 --source-group $SECURITY_GROUP_ID

# Create Redis Cluster
REDIS_CLUSTER_ID="$APP_NAME-redis"
aws elasticache create-cache-cluster \
    --cache-cluster-id $REDIS_CLUSTER_ID \
    --cache-node-type cache.t3.micro \
    --engine redis \
    --num-cache-nodes 1 \
    --vpc-security-group-ids $REDIS_SECURITY_GROUP_ID \
    --cache-subnet-group-name $APP_NAME-redis-subnet-group \
    --query 'CacheCluster.CacheClusterId' --output text

print_status "Creating Redis Cluster: $REDIS_CLUSTER_ID"
print_warning "Redis creation takes 3-5 minutes..."

# Wait for Redis to be available
aws elasticache wait cache-cluster-available --cache-cluster-id $REDIS_CLUSTER_ID
REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters --cache-cluster-id $REDIS_CLUSTER_ID --query 'CacheClusters[0].RedisEndpoint.Address' --output text)
print_status "Redis is ready: $REDIS_ENDPOINT"

print_step "Step 6: Creating EC2 Instance"

# Get latest Ubuntu AMI
AMI_ID=$(aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)
print_status "Using AMI: $AMI_ID"

# Create user data script
cat > user-data.sh << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose git curl
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Clone the application
git clone https://github.com/divakargaba/Dehydration.git /home/ubuntu/app
chown -R ubuntu:ubuntu /home/ubuntu/app

# Create environment file
cat > /home/ubuntu/app/.env << 'ENVEOF'
POSTGRES_USER=hydration_user
POSTGRES_PASSWORD=DB_PASSWORD_PLACEHOLDER
DATABASE_URL=postgresql://hydration_user:DB_PASSWORD_PLACEHOLDER@DB_ENDPOINT_PLACEHOLDER:5432/hydration_app
REDIS_URL=redis://REDIS_ENDPOINT_PLACEHOLDER:6379/0
OPENAI_API_KEY=your_openai_api_key_here
JWT_SECRET_KEY=JWT_SECRET_PLACEHOLDER
ENCRYPTION_KEY=ENCRYPTION_KEY_PLACEHOLDER
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com
REACT_APP_API_URL=http://EC2_PUBLIC_IP_PLACEHOLDER:5000
GRAFANA_PASSWORD=admin123
ENVEOF

# Start the application
cd /home/ubuntu/app
docker-compose -f deployment/docker-compose.yml up -d

# Setup SSL with Let's Encrypt (optional)
# apt-get install -y certbot
# certbot --nginx -d yourdomain.com
EOF

# Launch EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_PAIR_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --user-data file://user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$APP_NAME'-instance}]' \
    --query 'Instances[0].InstanceId' --output text)

print_status "Launching EC2 Instance: $INSTANCE_ID"
print_warning "Instance launch takes 2-3 minutes..."

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
print_status "Instance is running: $PUBLIC_IP"

print_step "Step 7: Configuring Application"

# Generate secrets
JWT_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Update environment file on EC2
ssh -i ${KEY_PAIR_NAME}.pem -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "
cd /home/ubuntu/app
sed -i 's/DB_PASSWORD_PLACEHOLDER/$DB_PASSWORD/g' .env
sed -i 's/DB_ENDPOINT_PLACEHOLDER/$DB_ENDPOINT/g' .env
sed -i 's/REDIS_ENDPOINT_PLACEHOLDER/$REDIS_ENDPOINT/g' .env
sed -i 's/JWT_SECRET_PLACEHOLDER/$JWT_SECRET/g' .env
sed -i 's/ENCRYPTION_KEY_PLACEHOLDER/$ENCRYPTION_KEY/g' .env
sed -i 's/EC2_PUBLIC_IP_PLACEHOLDER/$PUBLIC_IP/g' .env
"

print_step "Step 8: Starting Application"

# Start the application
ssh -i ${KEY_PAIR_NAME}.pem -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "
cd /home/ubuntu/app
docker-compose -f deployment/docker-compose.yml down
docker-compose -f deployment/docker-compose.yml up -d
"

print_step "Step 9: Health Checks"

# Wait for services to start
print_warning "Waiting for services to start (2 minutes)..."
sleep 120

# Check if services are running
if curl -f http://$PUBLIC_IP:5000/health > /dev/null 2>&1; then
    print_status "✅ Backend is running"
else
    print_warning "⚠️ Backend health check failed"
fi

if curl -f http://$PUBLIC_IP:3000 > /dev/null 2>&1; then
    print_status "✅ Frontend is running"
else
    print_warning "⚠️ Frontend health check failed"
fi

print_status "🎉 AWS Deployment Complete!"
echo ""
echo "📱 Application URLs:"
echo "  Frontend: http://$PUBLIC_IP:3000"
echo "  Backend API: http://$PUBLIC_IP:5000"
echo "  Prometheus: http://$PUBLIC_IP:9090"
echo "  Grafana: http://$PUBLIC_IP:3001 (admin/admin123)"
echo ""
echo "🔑 SSH Access:"
echo "  ssh -i ${KEY_PAIR_NAME}.pem ubuntu@$PUBLIC_IP"
echo ""
echo "📊 AWS Resources Created:"
echo "  VPC: $VPC_ID"
echo "  EC2 Instance: $INSTANCE_ID"
echo "  RDS Database: $DB_INSTANCE_IDENTIFIER"
echo "  Redis Cluster: $REDIS_CLUSTER_ID"
echo "  Security Group: $SECURITY_GROUP_ID"
echo ""
echo "💰 Estimated Monthly Cost: ~$50-80"
echo "  EC2 t3.medium: ~$30/month"
echo "  RDS db.t3.micro: ~$15/month"
echo "  ElastiCache cache.t3.micro: ~$10/month"
echo "  Data transfer: ~$5-15/month"
echo ""
print_status "Ready for participant testing! 🚀"

# Save deployment info
cat > aws-deployment-info.txt << EOF
AWS Deployment Information
=========================

Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
VPC ID: $VPC_ID
Subnet ID: $SUBNET_ID
Security Group: $SECURITY_GROUP_ID

Database:
- Endpoint: $DB_ENDPOINT
- Password: $DB_PASSWORD

Redis:
- Endpoint: $REDIS_ENDPOINT

Application URLs:
- Frontend: http://$PUBLIC_IP:3000
- Backend: http://$PUBLIC_IP:5000
- Monitoring: http://$PUBLIC_IP:3001

SSH Access:
ssh -i ${KEY_PAIR_NAME}.pem ubuntu@$PUBLIC_IP

Generated: $(date)
EOF

print_status "Deployment information saved to aws-deployment-info.txt"
