# 🔒 Security Features

This document outlines the comprehensive security measures implemented in this project.

## Table of Contents
- [Infrastructure Security](#infrastructure-security)
- [Application Security](#application-security)
- [CI/CD Security](#cicd-security)
- [Monitoring & Alerting](#monitoring--alerting)
- [Best Practices](#best-practices)

---

## Infrastructure Security

### AWS WAF (Web Application Firewall)

**Protection Against:**
- ✅ **DDoS Attacks**: Rate limiting (2000 requests per 5 minutes per IP)
- ✅ **SQL Injection**: Automatic detection and blocking
- ✅ **XSS Attacks**: Cross-site scripting protection
- ✅ **Geo-blocking**: Optional country-based blocking
- ✅ **Known Bad Inputs**: AWS Managed Rules for common attack patterns

**Features:**
- Real-time monitoring with CloudWatch metrics
- Detailed logging of blocked requests
- Configurable per environment

### Network Security

- **API Gateway**: Managed TLS/SSL termination (HTTPS only)
- **CORS Configuration**: Strict origin restrictions (configurable per environment)
- **VPC Integration**: Optional (can be enabled for additional isolation)

### IAM & Access Control

- **Least Privilege**: Lambda execution role with minimal required permissions
- **Secrets Management**: AWS Secrets Manager for sensitive data
- **No Hardcoded Credentials**: All secrets externalized
- **Encryption at Rest**: KMS encryption for sensitive resources

---

## Application Security

### Input Validation (Pydantic)

All API inputs are validated using Pydantic models before processing.

**Example Endpoint:**
```python
POST /dev/validate
{
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30,
    "message": "Hello world"
}
```

**Validation Rules:**
- ✅ Email format validation
- ✅ String length constraints
- ✅ Numeric range validation
- ✅ Special character filtering
- ✅ XSS prevention in text fields

**Error Response:**
```json
{
    "error": "Validation failed",
    "details": "Name contains invalid characters",
    "status": "error"
}
```

### Security Headers

All responses include comprehensive security headers:

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-XSS-Protection` | `1; mode=block` | Enable XSS filter |
| `Content-Security-Policy` | `default-src 'self'` | Restrict content sources |
| `Cache-Control` | `no-store` | Prevent sensitive data caching |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer information |
| `Permissions-Policy` | Restrictive | Disable dangerous features |

### Rate Limiting

**API Gateway Throttling:**
- **Dev**: 100 burst, 50 req/s
- **Staging**: 200 burst, 100 req/s
- **Production**: 500 burst, 250 req/s

**WAF Rate Limiting:**
- 2000 requests per 5 minutes per IP
- Automatic blocking with 429 response

---

## CI/CD Security

### Dependency Scanning

**Tools:**
- **pip-audit**: Scan Python dependencies for known vulnerabilities
- **Safety**: Additional CVE database checks

**Integration:**
- Runs on every deployment
- Fails build on critical vulnerabilities (production)
- Reports uploaded to GitHub Security tab

### Container Scanning

**Tool:** Trivy (Aqua Security)

**Features:**
- Scans Docker images for OS and library vulnerabilities
- Checks for misconfigurations
- SARIF format output for GitHub Security

**Thresholds:**
- Dev/Staging: Warning only
- Production: Fails on CRITICAL or HIGH vulnerabilities

**Example:**
```bash
docker run --rm \
  aquasec/trivy image \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  your-image:tag
```

### Secrets Management

**GitHub Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DATABASE_PASSWORD`
- `API_KEY`
- `JWT_SECRET`

**Terraform Variables:**
- Marked as `sensitive = true`
- Never logged or displayed
- Stored in `terraform.tfvars` (gitignored)

---

## Monitoring & Alerting

### CloudWatch Alarms

**Lambda Function:**
- ✅ Error rate > 5 in 5 minutes
- ✅ Throttles > 10 in 5 minutes
- ✅ Duration > 1000ms average (prod) / 2000ms (dev)

**API Gateway:**
- ✅ 4XX errors > 50 in 5 minutes
- ✅ 5XX errors > 5 in 5 minutes
- ✅ Latency > 500ms average (prod) / 1000ms (dev)

**WAF:**
- ✅ Blocked requests > 100 in 5 minutes (potential attack)

### SNS Notifications

**Alert Channels:**
- Email notifications (configurable)
- Can be extended to Slack, PagerDuty, etc.

**Alert Levels:**
- 🔴 **Critical**: 5XX errors, Lambda failures
- 🟠 **Warning**: High latency, throttles
- 🟡 **Info**: Deployment notifications

### CloudWatch Dashboards

**Metrics Displayed:**
- Lambda invocations, errors, duration
- API Gateway requests, errors, latency
- WAF allowed/blocked requests
- Recent error logs (last 20)

**Access:**
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=cicd-portfolio-{env}-dashboard
```

---

## Best Practices

### 1. Regular Updates

```bash
# Check for dependency updates
pip list --outdated

# Update with caution
pip install --upgrade package-name

# Re-run security scans
pip-audit
safety check
```

### 2. Secret Rotation

**Recommended Schedule:**
- Database passwords: Every 90 days
- API keys: Every 90 days
- JWT secrets: Every 180 days

**Rotation Process:**
1. Generate new secret in Secrets Manager
2. Update application configuration
3. Test thoroughly
4. Remove old secret

### 3. Log Review

**What to Monitor:**
- Unusual spike in 4XX/5XX errors
- High WAF block rate (potential attack)
- Lambda throttles (capacity issues)
- Error patterns in CloudWatch Logs

### 4. Penetration Testing

**Tools:**
- OWASP ZAP
- Burp Suite
- AWS Inspector

**Frequency:**
- Before major releases
- Quarterly for production
- After significant security updates

### 5. Incident Response

**In Case of Security Incident:**

1. **Contain**
   - Disable compromised API keys
   - Update WAF rules to block attacker
   - Scale down if under DDoS

2. **Investigate**
   - Check CloudWatch logs
   - Review WAF logs
   - Analyze access patterns

3. **Remediate**
   - Patch vulnerabilities
   - Rotate affected credentials
   - Update security groups

4. **Document**
   - Record timeline
   - Document root cause
   - Update runbooks

---

## Security Checklist

### Before Deployment

- [ ] All dependencies scanned (pip-audit, safety)
- [ ] Container scanned (Trivy)
- [ ] Secrets rotated if needed
- [ ] CORS origins restricted
- [ ] Rate limits configured
- [ ] CloudWatch alarms enabled
- [ ] SNS notifications tested

### After Deployment

- [ ] Smoke tests passed
- [ ] No critical errors in logs
- [ ] Security headers verified
- [ ] WAF rules active
- [ ] Monitoring dashboard checked

---

## Compliance

This implementation follows:

- **OWASP Top 10**: Protection against common vulnerabilities
- **AWS Well-Architected**: Security pillar best practices
- **CIS Benchmarks**: AWS security configuration
- **NIST Guidelines**: General security framework

---

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Email: security@yourdomain.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

**Response Time:** Within 48 hours

---

## Additional Resources

- [AWS WAF Developer Guide](https://docs.aws.amazon.com/waf/)
- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/)
- [Flask Security Best Practices](https://flask.palletsprojects.com/en/latest/security/)
- [Pydantic Documentation](https://docs.pydantic.dev/)

---

**Last Updated**: 2026-01-17
**Security Version**: 1.0
**Reviewed By**: DevOps Team
