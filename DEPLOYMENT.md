# 🚀 Deployment & Operations Guide

Comprehensive guide for deploying, testing, and operating the AWS Lambda CI/CD Pipeline.

## Table of Contents
- [Blue-Green Deployments](#blue-green-deployments)
- [Load Testing](#load-testing)
- [API Authentication](#api-authentication)
- [Performance Monitoring](#performance-monitoring)
- [Troubleshooting](#troubleshooting)

---

## Blue-Green Deployments

### Overview

This project implements **canary releases** using Lambda aliases with automatic rollback on errors.

**Architecture:**
- **Blue Alias**: Current stable production version
- **Green Alias**: New version being deployed
- **Live Alias**: Production traffic endpoint (weighted routing between blue/green)

### Deployment Process

The deployment follows a gradual traffic shift pattern:
1. **10%** of traffic → Green version (wait 60s, health check)
2. **25%** of traffic → Green version (wait 60s, health check)
3. **50%** of traffic → Green version (wait 60s, health check)
4. **100%** of traffic → Green version (promote to blue)

**Automatic Rollback:**
- If error rate > 5 in any 1-minute window
- Immediately reverts all traffic to blue version
- No manual intervention required

### Running a Blue-Green Deployment

#### Prerequisites
```bash
# AWS CLI configured with appropriate credentials
aws configure

# Ensure Lambda function is deployed
cd terraform
terraform apply
```

#### Deploy New Version

```bash
# Get the latest Lambda version number
LATEST_VERSION=$(aws lambda publish-version \
  --function-name cicd-portfolio-dev-api \
  --query 'Version' \
  --output text)

# Run canary deployment
./scripts/blue-green-deploy.sh cicd-portfolio-dev-api $LATEST_VERSION
```

#### Monitor Deployment

```bash
# Watch CloudWatch logs during deployment
aws logs tail /aws/lambda/cicd-portfolio-dev-api --follow

# Check current alias routing
aws lambda get-alias \
  --function-name cicd-portfolio-dev-api \
  --name live
```

#### Manual Rollback

```bash
# If you need to manually rollback
BLUE_VERSION=$(aws lambda get-alias \
  --function-name cicd-portfolio-dev-api \
  --name blue \
  --query 'FunctionVersion' \
  --output text)

aws lambda update-alias \
  --function-name cicd-portfolio-dev-api \
  --name live \
  --function-version $BLUE_VERSION
```

---

## Load Testing

### Overview

Load testing uses **Locust**, an open-source load testing framework written in Python.

**Test Types:**
- **Baseline**: Normal traffic patterns (10 users, 2/sec spawn rate)
- **Stress**: High sustained load (50 users, 5/sec spawn rate)
- **Spike**: Sudden traffic spike (100 users, 20/sec spawn rate)
- **Endurance**: Long-duration test (25 users, 10 minutes)

### Running Load Tests Locally

#### Install Dependencies

```bash
cd tests
pip install -r requirements-loadtest.txt
```

#### Run Load Test

```bash
# Basic load test
locust -f tests/load_test.py \
  --host https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com \
  --users 10 \
  --spawn-rate 2 \
  --run-time 2m \
  --headless

# With CSV output
locust -f tests/load_test.py \
  --host https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com \
  --users 50 \
  --spawn-rate 5 \
  --run-time 5m \
  --headless \
  --csv results/loadtest
```

#### Analyze Results

```bash
# Analyze Locust CSV output
python scripts/analyze-performance.py results/loadtest_stats.csv
```

**Performance Thresholds:**
- ✅ Average response time: < 500ms
- ✅ P95 response time: < 1000ms
- ✅ Failure rate: < 1%
- ✅ Availability: > 99.9%

### Running Load Tests via GitHub Actions

#### Trigger Workflow

```bash
# Via GitHub CLI
gh workflow run load-test.yml \
  -f test_type=stress \
  -f users=50 \
  -f spawn_rate=5 \
  -f duration=5m

# Via GitHub UI
# Navigate to Actions → Load Testing → Run workflow
```

#### Download Results

```bash
# List recent workflow runs
gh run list --workflow=load-test.yml

# Download artifacts from latest run
gh run download <run-id>
```

---

## API Authentication

### Overview

The API supports two authentication methods:
1. **API Key Authentication**: Simple key-based auth for standard endpoints
2. **HMAC Signature**: Request signing for sensitive operations

### API Key Authentication

#### Endpoints

**Unprotected (Public):**
- `GET /dev/` - API info
- `GET /dev/health` - Health check

**Protected (Requires API Key):**
- `GET /dev/protected` - Protected resource
- `GET /dev/admin/stats` - Admin statistics (requires 'admin' permission)

#### Example Request

```bash
# Get protected resource
curl -H "X-API-Key: your-api-key-here" \
  https://your-api-url/dev/protected
```

**Response:**
```json
{
  "status": "success",
  "message": "Access granted to protected resource",
  "api_key_id": "key-123",
  "permissions": ["read", "write"],
  "rate_limit_remaining": 995
}
```

### HMAC Signature Authentication

For sensitive operations, requests must be signed with HMAC-SHA256.

#### Requirements

**Headers:**
- `X-API-Key`: Your API key
- `X-Signature`: HMAC-SHA256 signature of request body
- `X-Timestamp`: Unix timestamp (must be within 5 minutes)

#### Example (Python)

```python
import hmac
import hashlib
import time
import json
import requests

# Configuration
API_URL = "https://your-api-url/dev/signed"
API_KEY = "your-api-key-here"
API_SECRET = "your-api-secret-here"

# Request payload
payload = {
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30,
    "message": "Signed request"
}

# Create signature
timestamp = str(int(time.time()))
body = json.dumps(payload)
message = f"{timestamp}{body}"
signature = hmac.new(
    API_SECRET.encode(),
    message.encode(),
    hashlib.sha256
).hexdigest()

# Make request
response = requests.post(
    API_URL,
    json=payload,
    headers={
        "X-API-Key": API_KEY,
        "X-Signature": signature,
        "X-Timestamp": timestamp,
        "Content-Type": "application/json"
    }
)

print(response.json())
```

#### Example (Bash)

```bash
#!/bin/bash

API_URL="https://your-api-url/dev/signed"
API_KEY="your-api-key-here"
API_SECRET="your-api-secret-here"

# Request body
BODY='{"name":"John Doe","email":"john@example.com","age":30,"message":"Signed request"}'

# Generate timestamp and signature
TIMESTAMP=$(date +%s)
MESSAGE="${TIMESTAMP}${BODY}"
SIGNATURE=$(echo -n "$MESSAGE" | openssl dgst -sha256 -hmac "$API_SECRET" | awk '{print $2}')

# Make request
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -H "X-Signature: $SIGNATURE" \
  -H "X-Timestamp: $TIMESTAMP" \
  -d "$BODY"
```

### Rate Limiting

**Per API Key:**
- Default: 1000 requests per hour
- Configurable in AWS Secrets Manager

**Response Headers:**
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 995
X-RateLimit-Reset: 1640000000
```

**Rate Limit Exceeded:**
```json
{
  "error": "Rate limit exceeded",
  "retry_after": 3600
}
```

---

## Performance Monitoring

### CloudWatch Dashboard

**Access:**
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=cicd-portfolio-dev-dashboard
```

**Metrics:**
- Lambda invocations, errors, duration, throttles
- API Gateway requests, 4XX/5XX errors, latency
- WAF allowed/blocked requests
- Recent error logs (last 20)

### CloudWatch Alarms

**Critical Alarms (SNS notifications):**
- ✅ Lambda errors > 5 in 5 minutes
- ✅ Lambda throttles > 10 in 5 minutes
- ✅ Lambda duration > 1000ms avg (prod) / 2000ms (dev)
- ✅ API Gateway 4XX errors > 50 in 5 minutes
- ✅ API Gateway 5XX errors > 5 in 5 minutes
- ✅ API Gateway latency > 500ms avg (prod) / 1000ms (dev)
- ✅ WAF blocked requests > 100 in 5 minutes
- ✅ Application-level errors > 10 in 5 minutes

### Viewing Logs

```bash
# Tail Lambda logs in real-time
aws logs tail /aws/lambda/cicd-portfolio-dev-api --follow

# Filter for errors
aws logs tail /aws/lambda/cicd-portfolio-dev-api \
  --follow \
  --filter-pattern "ERROR"

# Get logs for specific time range
aws logs filter-log-events \
  --log-group-name /aws/lambda/cicd-portfolio-dev-api \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"
```

---

## Troubleshooting

### Deployment Issues

#### Issue: Deployment Stuck at Canary Stage

**Symptoms:**
- Deployment pauses at 10%, 25%, or 50%
- Health checks failing

**Solution:**
```bash
# Check CloudWatch logs for errors
aws logs tail /aws/lambda/cicd-portfolio-dev-api --follow

# Check alarm state
aws cloudwatch describe-alarms \
  --alarm-names cicd-portfolio-dev-green-version-errors

# If needed, manually rollback
./scripts/blue-green-deploy.sh cicd-portfolio-dev-api <blue-version>
```

#### Issue: Lambda Version Not Created

**Symptoms:**
- `publish-version` fails
- "No updates to publish" error

**Solution:**
```bash
# Force update by changing environment variable
aws lambda update-function-configuration \
  --function-name cicd-portfolio-dev-api \
  --environment Variables={ENVIRONMENT=dev,APP_VERSION=new-version}

# Wait for update to complete
aws lambda wait function-updated \
  --function-name cicd-portfolio-dev-api

# Publish new version
aws lambda publish-version \
  --function-name cicd-portfolio-dev-api
```

### Load Testing Issues

#### Issue: High Error Rate During Load Test

**Symptoms:**
- Many 5XX errors
- Lambda throttling

**Solution:**
```bash
# Check Lambda concurrency limits
aws lambda get-function-concurrency \
  --function-name cicd-portfolio-dev-api

# Increase reserved concurrency (if needed)
# Uncomment in terraform/lambda.tf:
# reserved_concurrent_executions = 10

# Check API Gateway throttling
# Increase limits in terraform/environments/*.tfvars
```

#### Issue: Slow Response Times

**Symptoms:**
- Average response time > 1000ms
- P95 > 2000ms

**Investigation:**
```bash
# Check Lambda duration metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=cicd-portfolio-dev-api \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Check for cold starts
aws logs filter-log-events \
  --log-group-name /aws/lambda/cicd-portfolio-dev-api \
  --filter-pattern "INIT_START"
```

**Solutions:**
- Enable provisioned concurrency (terraform/variables.tf)
- Optimize Lambda memory (increases CPU)
- Enable Lambda warmup (EventBridge scheduled invocations)

### Authentication Issues

#### Issue: API Key Not Working

**Symptoms:**
- 401 Unauthorized
- "Invalid API key" error

**Solution:**
```bash
# Verify API key in Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id cicd-portfolio-dev-api-key

# Test with curl
curl -v -H "X-API-Key: your-key" \
  https://your-api-url/dev/protected
```

#### Issue: HMAC Signature Verification Failed

**Symptoms:**
- 401 Unauthorized
- "Invalid signature" error

**Checklist:**
- ✅ Timestamp is within 5 minutes
- ✅ Message format is `{timestamp}{body}` (no spaces)
- ✅ Body is exact JSON string (no extra whitespace)
- ✅ Using correct API secret
- ✅ HMAC algorithm is SHA256

**Debug:**
```python
# Print signature components
print(f"Timestamp: {timestamp}")
print(f"Body: {body}")
print(f"Message: {message}")
print(f"Signature: {signature}")
```

---

## Best Practices

### Deployment

1. **Always test in dev first**
   ```bash
   # Deploy to dev
   terraform workspace select dev
   terraform apply

   # Run load tests
   ./run-load-test.sh dev

   # If successful, promote to staging
   terraform workspace select staging
   terraform apply
   ```

2. **Use blue-green for production**
   - Never deploy directly to prod
   - Always use canary releases
   - Monitor for 5+ minutes at 100% before promoting

3. **Tag releases**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

### Load Testing

1. **Run baseline tests regularly**
   - Weekly baseline tests
   - Compare results over time
   - Detect performance regressions early

2. **Test before major releases**
   - Run stress test before prod deployment
   - Validate performance thresholds
   - Document results

3. **Monitor during tests**
   - Watch CloudWatch dashboards
   - Check for throttling
   - Monitor costs

### Security

1. **Rotate API keys regularly**
   - Every 90 days minimum
   - Update in Secrets Manager
   - Update client applications

2. **Use HMAC signatures for sensitive operations**
   - Money transfers
   - User data modifications
   - Admin operations

3. **Monitor failed authentication attempts**
   - Review CloudWatch logs
   - Look for brute force attempts
   - Update WAF rules if needed

---

## Additional Resources

- [AWS Lambda Aliases](https://docs.aws.amazon.com/lambda/latest/dg/configuration-aliases.html)
- [Locust Documentation](https://docs.locust.io/)
- [HMAC Authentication Best Practices](https://tools.ietf.org/html/rfc2104)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)

---

**Last Updated**: 2026-01-17
**Version**: 2.0
**Maintained By**: DevOps Team
