# 🚀 GitHub Actions Deployment Guide

Since your AWS credentials are already configured in GitHub Secrets, you can deploy entirely through GitHub Actions!

---

## 📋 Required GitHub Secrets

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

You need to add these secrets:

### Already Configured ✓
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

### Need to Add (for Terraform):
1. **DATABASE_PASSWORD**
   - Value: `***REMOVED***`

2. **API_KEY**
   - Value: `***REMOVED***`

3. **JWT_SECRET**
   - Value: `***REMOVED***`

---

## 🏗️ Step 1: Deploy Infrastructure (One-Time)

### Option A: Using GitHub Actions (Recommended)

1. **Commit and push your changes:**
   ```bash
   git add .
   git commit -m "Add Terraform GitHub Actions workflow"
   git push origin claude/fix-errors-and-leaks-PekvX
   ```

2. **Go to GitHub:**
   - Navigate to: **Actions** tab
   - Select: **Terraform Deploy Infrastructure**
   - Click: **Run workflow**
   - Select branch: `claude/fix-errors-and-leaks-PekvX`
   - Choose action: **apply**
   - Click: **Run workflow**

3. **Wait for completion** (2-3 minutes)
   - Monitor the workflow execution
   - Check outputs for API Gateway URL and other details

### Option B: Using Local Terraform

If you prefer to deploy infrastructure locally:

```bash
# Set environment variables with secrets
export TF_VAR_database_password="***REMOVED***"
export TF_VAR_api_key="***REMOVED***"
export TF_VAR_jwt_secret="***REMOVED***"

# You still need AWS credentials locally
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

cd terraform
terraform plan
terraform apply
```

---

## 🐳 Step 2: Deploy Application Code

After infrastructure is created, deploy your application:

### Automatic Deployment (Recommended)

**Merge to main branch** - Automatically triggers deployment:

```bash
# Create pull request and merge, OR merge locally:
git checkout main
git merge claude/fix-errors-and-leaks-PekvX
git push origin main
```

The workflow will automatically:
1. ✅ Build Docker image
2. ✅ Push to ECR
3. ✅ Update Lambda function

### Manual Deployment

Trigger the workflow manually:
- Go to: **Actions → Deploy Dev**
- Click: **Run workflow**
- Select: **main** branch
- Click: **Run workflow**

---

## 🧪 Step 3: Test Your Deployment

After both workflows complete:

### Get API URL from Terraform Outputs

1. Go to **Actions → Terraform Deploy Infrastructure → Latest run**
2. Scroll to bottom to see outputs
3. Copy the `api_gateway_url`

### Test the API

```bash
# Replace with your actual API URL
API_URL="https://abc123.execute-api.us-east-1.amazonaws.com/dev"

# Test root endpoint
curl $API_URL/

# Test environment-specific endpoint
curl $API_URL/dev/

# Test health check
curl $API_URL/dev/health
```

Expected response:
```json
{
  "message": "AWS Lambda CI/CD Pipeline",
  "status": "Deployment Successful",
  "environment": "dev",
  "version": "terraform-managed"
}
```

---

## 📊 Workflow Overview

### 1. Terraform Deploy Infrastructure (`terraform-deploy.yml`)
- **Trigger**: Manual (workflow_dispatch)
- **Purpose**: Create/update/destroy AWS infrastructure
- **Creates**: ECR, Lambda, API Gateway, IAM roles, CloudWatch, Secrets Manager
- **Run**: Once initially, then only when infrastructure changes

### 2. Deploy Dev (`deploy-dev.yml`)
- **Trigger**: Push to main (paths: `app/**`, `Dockerfile`, etc.)
- **Purpose**: Deploy application code updates
- **Updates**: Docker image and Lambda function code
- **Run**: Every time you push code changes to main

---

## 🔄 Complete Deployment Workflow

```
┌─────────────────────────────────────────────────┐
│ 1. Add GitHub Secrets                           │
│    (DATABASE_PASSWORD, API_KEY, JWT_SECRET)     │
└─────────────────────────┬───────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────┐
│ 2. Deploy Infrastructure (One-time)             │
│    Actions → Terraform Deploy → Run → Apply     │
└─────────────────────────┬───────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────┐
│ 3. Deploy Application                           │
│    Merge to main → Auto-deploy                  │
└─────────────────────────┬───────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────┐
│ 4. Test API                                     │
│    curl API_URL/dev/health                      │
└─────────────────────────────────────────────────┘
```

---

## 🔐 Security Best Practices

### ✅ What's Secure:
- AWS credentials stored in GitHub Secrets ✓
- Secrets passed as environment variables ✓
- `terraform.tfvars` in `.gitignore` ✓
- No secrets in code or logs ✓

### ⚠️ Important:
- Never commit AWS credentials to Git
- Rotate secrets regularly
- Use least-privilege IAM policies
- Monitor CloudWatch for unauthorized access

---

## 🆘 Troubleshooting

### "Resource already exists" error
- **Cause**: Infrastructure was partially created
- **Solution**: Run `terraform destroy` then `terraform apply` again

### "No such repository" error
- **Cause**: ECR repository doesn't exist yet
- **Solution**: Run Terraform workflow first to create infrastructure

### "Access Denied" error
- **Cause**: IAM permissions insufficient
- **Solution**: Add required policies to IAM user (see Prerequisites)

### GitHub Actions workflow fails
- **Cause**: Missing GitHub Secrets
- **Solution**: Verify all 5 secrets are configured correctly

### Lambda function not updating
- **Cause**: Workflow only triggers on certain path changes
- **Solution**: Ensure you're modifying files in `app/**` directory

---

## 📝 GitHub Secrets Summary

| Secret Name | Value | Used For |
|------------|-------|----------|
| `AWS_ACCESS_KEY_ID` | Your AWS key | ✅ Already configured |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret | ✅ Already configured |
| `DATABASE_PASSWORD` | `***REMOVED***` | ⚠️ Need to add |
| `API_KEY` | `***REMOVED***` | ⚠️ Need to add |
| `JWT_SECRET` | `***REMOVED***` | ⚠️ Need to add |

---

## ✅ Deployment Checklist

- [x] AWS credentials configured in GitHub Secrets
- [ ] Add DATABASE_PASSWORD secret
- [ ] Add API_KEY secret
- [ ] Add JWT_SECRET secret
- [ ] Commit and push Terraform workflow
- [ ] Run Terraform workflow (apply)
- [ ] Merge to main branch
- [ ] Verify application deployment
- [ ] Test API endpoints
- [ ] Monitor CloudWatch logs

---

## 🎯 Next Steps After Deployment

1. **Monitor your application**
   - CloudWatch Logs: `/aws/lambda/cicd-portfolio-dev-api`
   - API Gateway Logs: `/aws/apigateway/cicd-portfolio-dev`

2. **Update CORS for production**
   - Edit `terraform/terraform.tfvars`
   - Change `allowed_origins` to your domain
   - Run Terraform workflow again

3. **Set up staging environment**
   - Create new workflow for staging
   - Duplicate infrastructure with `environment = "staging"`

4. **Enable monitoring alerts**
   - Configure CloudWatch alarms
   - Set up SNS notifications

---

## 💰 Cost Monitoring

All resources are within AWS Free Tier:
- Lambda: 1M requests/month FREE
- API Gateway: 1M requests/month FREE (12 months)
- ECR: 500MB storage FREE
- CloudWatch: 5GB logs FREE

**Estimated cost: $0/month** (within free tier)

---

## 🧹 Cleanup

To destroy all infrastructure and avoid any future charges:

1. Go to **Actions → Terraform Deploy Infrastructure**
2. Click **Run workflow**
3. Select action: **destroy**
4. Click **Run workflow**
5. Wait for completion

This will delete all AWS resources created by Terraform.

---

**Last Updated**: 2026-01-16
**Terraform Version**: 1.7.0
**AWS Provider**: 5.100.0
