# 🚀 Deployment Guide

## Current Status

✅ **Completed:**
- All code fixes and security improvements applied
- Secure secrets generated and configured in `terraform/terraform.tfvars`
- Terraform initialized successfully

⏳ **Next Steps:**
- Configure AWS credentials
- Deploy infrastructure with Terraform
- Set up CI/CD pipeline

---

## 📋 Prerequisites

Before deploying, you need:

1. **AWS Account** - Free tier eligible
2. **AWS Access Keys** - From IAM console
3. **AWS CLI** (optional but recommended)

---

## 🔐 Step 1: Get Your AWS Credentials

### Create IAM User (if you haven't already):

1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. Username: `terraform-deployment`
4. Attach policies:
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AWSLambda_FullAccess`
   - `IAMFullAccess`
   - `AmazonAPIGatewayAdministrator`
   - `CloudWatchLogsFullAccess`
   - `AmazonEventBridgeFullAccess`
   - `SecretsManagerReadWrite`
5. Click "Create access key" → "CLI"
6. **Download and save** your:
   - Access Key ID
   - Secret Access Key

---

## 🛠️ Step 2: Configure AWS Credentials

### Option A: Using AWS CLI (Recommended)

```bash
# Install AWS CLI v2 (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Configure credentials
aws configure
# Enter when prompted:
# AWS Access Key ID: [your-access-key-id]
# AWS Secret Access Key: [your-secret-access-key]
# Default region name: us-east-1
# Default output format: json
```

### Option B: Manual Configuration

```bash
mkdir -p ~/.aws

# Create credentials file
cat > ~/.aws/credentials << 'EOF'
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID_HERE
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY_HERE
EOF

# Create config file
cat > ~/.aws/config << 'EOF'
[default]
region = us-east-1
output = json
EOF

# Verify
aws sts get-caller-identity
```

### Option C: Environment Variables (Temporary)

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

---

## 🏗️ Step 3: Deploy Infrastructure with Terraform

```bash
# Navigate to terraform directory
cd /home/user/my-cicd-project/terraform

# Preview what will be created (optional)
terraform plan

# Deploy infrastructure
terraform apply

# When prompted, type: yes
```

### What Gets Created:

- **ECR Repository** - For Docker images
- **Lambda Function** - Your application
- **API Gateway** - HTTP API endpoint
- **IAM Roles** - Execution permissions
- **CloudWatch Logs** - For monitoring
- **Secrets Manager** - Secure credential storage
- **EventBridge Rule** - Lambda warm-up (optional)

### Expected Output:

```
Apply complete! Resources: 15+ added, 0 changed, 0 destroyed.

Outputs:

api_gateway_url = "https://abc123.execute-api.us-east-1.amazonaws.com/dev"
ecr_repository_url = "123456789.dkr.ecr.us-east-1.amazonaws.com/cicd-portfolio-dev-app"
lambda_function_name = "cicd-portfolio-dev-api"
```

---

## 🐳 Step 4: Build and Deploy Application

```bash
# Navigate to project root
cd /home/user/my-cicd-project

# Get ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(terraform -chdir=terraform output -raw ecr_repository_url | cut -d'/' -f1)

# Build Docker image
docker build --platform linux/amd64 -t cicd-portfolio-dev-app:latest .

# Tag image
docker tag cicd-portfolio-dev-app:latest \
  $(terraform -chdir=terraform output -raw ecr_repository_url):latest

# Push to ECR
docker push $(terraform -chdir=terraform output -raw ecr_repository_url):latest

# Update Lambda function
aws lambda update-function-code \
  --function-name $(terraform -chdir=terraform output -raw lambda_function_name) \
  --image-uri $(terraform -chdir=terraform output -raw ecr_repository_url):latest
```

---

## 🧪 Step 5: Test Your Deployment

```bash
# Get API endpoint
API_URL=$(terraform -chdir=terraform output -raw api_gateway_url)

# Test root endpoint
curl $API_URL/

# Test environment-specific endpoint
curl $API_URL/dev/

# Test health check
curl $API_URL/dev/health
```

Expected responses:
```json
{
  "message": "AWS Lambda CI/CD Pipeline",
  "status": "Deployment Successful",
  "environment": "dev",
  "version": "terraform-managed"
}
```

---

## 🔄 Step 6: Set Up CI/CD (GitHub Actions)

### Configure GitHub Secrets:

Go to: Repository → Settings → Secrets and variables → Actions

Add these secrets:

1. **AWS_ACCESS_KEY_ID** - Your AWS access key
2. **AWS_SECRET_ACCESS_KEY** - Your AWS secret key

### Trigger Deployment:

```bash
# Merge your changes to main branch
git checkout main
git merge claude/fix-errors-and-leaks-PekvX
git push origin main
```

The GitHub Actions workflow will automatically:
1. Build Docker image
2. Push to ECR
3. Update Lambda function

---

## 📊 Monitoring

### CloudWatch Logs:
```bash
# View Lambda logs
aws logs tail /aws/lambda/cicd-portfolio-dev-api --follow

# View API Gateway logs
aws logs tail /aws/apigateway/cicd-portfolio-dev --follow
```

### AWS Console:
- Lambda: https://console.aws.amazon.com/lambda
- API Gateway: https://console.aws.amazon.com/apigateway
- CloudWatch: https://console.aws.amazon.com/cloudwatch
- ECR: https://console.aws.amazon.com/ecr

---

## 🧹 Cleanup (When Done Testing)

To avoid any charges:

```bash
cd /home/user/my-cicd-project/terraform

# Destroy all infrastructure
terraform destroy

# Type: yes when prompted
```

This will delete all AWS resources created by Terraform.

---

## 🆘 Troubleshooting

### Issue: "No valid credential sources"
- Solution: Configure AWS credentials (see Step 2)

### Issue: "Access Denied"
- Solution: Check IAM user has required permissions

### Issue: "Lambda execution failed"
- Solution: Check CloudWatch logs for detailed error messages

### Issue: "CORS errors in browser"
- Solution: Update `allowed_origins` in `terraform/terraform.tfvars`

### Issue: "Container image not found"
- Solution: Make sure to push Docker image to ECR before updating Lambda

---

## 📝 Important Files

- `terraform/terraform.tfvars` - **DO NOT COMMIT** (contains secrets)
- `terraform/terraform.tfvars.example` - Template for team members
- `.gitignore` - Ensures secrets aren't committed

---

## 💰 Cost Estimate

With AWS Free Tier:
- Lambda: 1M requests/month FREE
- API Gateway: 1M requests/month FREE (12 months)
- ECR: 500MB storage FREE
- CloudWatch: 5GB logs FREE
- **Total: $0/month** (within free tier limits)

---

## ✅ Deployment Checklist

- [ ] AWS account created
- [ ] IAM user with proper permissions created
- [ ] AWS credentials configured locally
- [ ] Terraform initialized
- [ ] Infrastructure deployed (`terraform apply`)
- [ ] Docker image built and pushed to ECR
- [ ] Lambda function updated with image
- [ ] API tested and working
- [ ] GitHub secrets configured
- [ ] CI/CD pipeline tested

---

## 🎯 Next Steps After Deployment

1. **Test the API** - Use curl or Postman
2. **Set up monitoring** - Configure CloudWatch alarms
3. **Update CORS** - Restrict to your domain for production
4. **Create staging environment** - Duplicate infrastructure with `environment = "staging"`
5. **Set up custom domain** - Use Route53 + API Gateway custom domain

---

## 📞 Support

If you encounter issues:
1. Check CloudWatch Logs for errors
2. Review Terraform output for resource details
3. Verify AWS credentials and permissions
4. Check the troubleshooting section above

---

**Generated**: 2026-01-16
**Terraform Version**: 1.7.0
**AWS Provider**: 5.100.0
