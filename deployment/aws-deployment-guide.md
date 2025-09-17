# ☁️ AWS Deployment Guide for Hydration App

## Overview
This guide provides multiple methods to deploy your Hydration App to AWS for participant testing, from simple scripts to Infrastructure as Code.

## 🚀 Quick Start Options

### Option 1: Automated Script (Recommended for Beginners)
**Time: 15-20 minutes**

```bash
# 1. Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 2. Configure AWS credentials
aws configure

# 3. Run deployment script
./deployment/aws-deploy.sh
```

### Option 2: Terraform Infrastructure as Code (Recommended for Production)
**Time: 10-15 minutes**

```bash
# 1. Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# 2. Configure variables
cp deployment/aws-terraform/terraform.tfvars.example deployment/aws-terraform/terraform.tfvars
nano deployment/aws-terraform/terraform.tfvars

# 3. Deploy infrastructure
cd deployment/aws-terraform
terraform init
terraform plan
terraform apply
```

## 📋 Prerequisites

### Required Tools
- **AWS Account** with billing enabled
- **AWS CLI** v2.0+
- **Docker** and **Docker Compose**
- **Git** for code management
- **SSH Key Pair** (or create new one)

### AWS Permissions
Your AWS user/role needs these permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "rds:*",
                "elasticache:*",
                "iam:*",
                "cloudwatch:*",
                "logs:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### Cost Estimation
**Monthly costs for participant testing:**
- **EC2 t3.medium**: ~$30/month
- **RDS db.t3.micro**: ~$15/month  
- **ElastiCache cache.t3.micro**: ~$10/month
- **Application Load Balancer**: ~$18/month
- **Data Transfer**: ~$5-15/month
- **Total**: ~$78-88/month

## 🛠️ Method 1: Automated Script Deployment

### Step 1: Prepare Environment
```bash
# Clone your repository
git clone https://github.com/divakargaba/Dehydration.git
cd Dehydration

# Make script executable
chmod +x deployment/aws-deploy.sh
```

### Step 2: Configure AWS
```bash
# Install AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
# Enter your Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
```

### Step 3: Run Deployment
```bash
# Execute deployment script
./deployment/aws-deploy.sh
```

The script will:
1. ✅ Create VPC with public/private subnets
2. ✅ Set up security groups
3. ✅ Launch RDS PostgreSQL database
4. ✅ Create ElastiCache Redis cluster
5. ✅ Launch EC2 instance with application
6. ✅ Configure load balancer
7. ✅ Set up monitoring

### Step 4: Access Your Application
After deployment completes, you'll get:
```
📱 Application URLs:
  Frontend: http://YOUR_IP:3000
  Backend API: http://YOUR_IP:5000
  Prometheus: http://YOUR_IP:9090
  Grafana: http://YOUR_IP:3001 (admin/admin123)

🔑 SSH Access:
  ssh -i hydration-app-key.pem ubuntu@YOUR_IP
```

## 🔐 Security Configuration

### SSL/TLS Setup
```bash
# Install Certbot on EC2
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Environment Variables
```bash
# On EC2 instance, update .env file
nano /home/ubuntu/app/.env

# Add your actual values:
OPENAI_API_KEY=sk-proj-your-actual-key
POSTGRES_PASSWORD=your-secure-password
JWT_SECRET_KEY=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)
```

## 📊 Monitoring & Maintenance

### CloudWatch Setup
```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure monitoring
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

### Log Management
```bash
# Set up log rotation
sudo nano /etc/logrotate.d/hydration-app

# Add:
/home/ubuntu/app/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 ubuntu ubuntu
}
```

### Backup Strategy
```bash
# Database backup script
cat > /home/ubuntu/backup-db.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -h $DB_ENDPOINT -U hydration_user hydration_app > /home/ubuntu/backups/db_backup_$DATE.sql
aws s3 cp /home/ubuntu/backups/db_backup_$DATE.sql s3://your-backup-bucket/
EOF

chmod +x /home/ubuntu/backup-db.sh

# Schedule daily backups
echo "0 2 * * * /home/ubuntu/backup-db.sh" | crontab -u ubuntu -
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Application Won't Start
```bash
# Check Docker status
sudo systemctl status docker

# Check container logs
docker-compose logs backend
docker-compose logs frontend

# Restart services
docker-compose down
docker-compose up -d
```

#### 2. Database Connection Failed
```bash
# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# Test connection
telnet your-db-endpoint 5432

# Check database status
aws rds describe-db-instances --db-instance-identifier hydration-app-db
```

## 🎯 Success Metrics

### Technical Metrics
- **Uptime**: >99.5%
- **Response Time**: <2 seconds
- **Error Rate**: <1%
- **Database Performance**: <100ms queries

### User Experience Metrics
- **App Launch Time**: <3 seconds
- **Data Sync Success**: >95%
- **Feature Adoption**: Track AI coach usage
- **User Retention**: 7-day, 30-day rates

## 🚀 Ready for Participant Testing!

Your Hydration App is now deployed on AWS with:
- ✅ **Scalable infrastructure** (Auto Scaling Groups)
- ✅ **High availability** (Multi-AZ deployment)
- ✅ **Security** (VPC, Security Groups, SSL)
- ✅ **Monitoring** (CloudWatch, Prometheus, Grafana)
- ✅ **Backup** (Automated database backups)
- ✅ **Cost optimization** (Right-sized instances)

**Next Steps:**
1. **Test all endpoints** and functionality
2. **Deploy iOS app** to TestFlight
3. **Onboard participants** with clear instructions
4. **Monitor metrics** and user feedback
5. **Iterate** based on participant data

Good luck with your participant testing! 🎉
