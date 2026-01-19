# CI/CD Portfolio Project - Architecture Diagram

## Overview
Production-grade CI/CD pipeline with blue-green deployment, automated security scanning, and comprehensive monitoring on AWS.

---

## 🔄 CI/CD Pipeline (GitHub Actions)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB ACTIONS WORKFLOW                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ STAGE 0: INFRASTRUCTURE (Terraform)                                   │  │
│  │ ─────────────────────────────────────────────────────────────────────│  │
│  │  • Setup S3 Backend + DynamoDB Locking                                │  │
│  │  • Clear Stale Locks                                                  │  │
│  │  • Terraform Plan & Apply                                             │  │
│  │  • Verify Lambda Function Exists                                      │  │
│  │                                                                         │  │
│  │  Creates: Lambda, API Gateway, ECR, WAF, CloudWatch, Secrets, SNS,   │  │
│  │           IAM Roles, EventBridge                                      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ STAGE 1: BUILD & SECURITY SCAN                                        │  │
│  │ ─────────────────────────────────────────────────────────────────────│  │
│  │  • Docker Build (Multi-stage)                                         │  │
│  │  • Trivy Container Scan (CVE Detection)                               │  │
│  │  • Safety Check (Python Dependencies)                                 │  │
│  │  • Bandit Scan (Python Security)                                      │  │
│  │  • Push to ECR (Immutable Tags)                                       │  │
│  │  • Upload SARIF to GitHub Security                                    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ STAGE 2: DEPLOY (Blue-Green)                                          │  │
│  │ ─────────────────────────────────────────────────────────────────────│  │
│  │  • Update Lambda Function Code (New Container Image)                  │  │
│  │  • Wait for Function Update                                           │  │
│  │  • Publish New Lambda Version                                         │  │
│  │  • Update GREEN Alias → New Version                                   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ STAGE 3: VERIFY                                                        │  │
│  │ ─────────────────────────────────────────────────────────────────────│  │
│  │  • Health Check (GREEN Alias)                                         │  │
│  │  • Smoke Tests (API Endpoints)                                        │  │
│  │  • Check Error Metrics (Last 5 Minutes)                               │  │
│  │  • CloudWatch Alarm Status Check                                      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ STAGE 4: PROMOTE                                                       │  │
│  │ ─────────────────────────────────────────────────────────────────────│  │
│  │  • Get GREEN Version Number                                           │  │
│  │  • Switch LIVE Alias → GREEN Version                                  │  │
│  │  • Update BLUE Alias → Previous LIVE Version (Backup)                │  │
│  │  • Tag Deployment in GitHub                                           │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    ↓                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ STAGE 5: MONITOR (Production Only)                                    │  │
│  │ ─────────────────────────────────────────────────────────────────────│  │
│  │  • Monitor Error Rates (10 Minutes)                                   │  │
│  │  • Check CloudWatch Alarms                                            │  │
│  │  • Trigger Rollback if Error Rate > Threshold                         │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## ☁️ AWS Infrastructure Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD (us-east-1)                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                          🌐 API GATEWAY (HTTP API v2)                   │ │
│  │                     https://xyz.execute-api.us-east-1...                │ │
│  └────────────────────────────┬────────────────────────────────────────────┘ │
│                                │                                               │
│                                │ Invokes                                       │
│                                ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    ⚡ LAMBDA FUNCTION (Containerized)                   │ │
│  │                     cicd-portfolio-{env}-api                             │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  ALIASES (Blue-Green Deployment)                                   │  │ │
│  │  │  ───────────────────────────────────────────────────────────────  │  │ │
│  │  │                                                                     │  │ │
│  │  │   ┌──────────┐      ┌──────────┐      ┌──────────┐               │  │ │
│  │  │   │  BLUE    │      │  GREEN   │      │  LIVE    │               │  │ │
│  │  │   │ (Stable) │      │ (New Ver)│      │(Production)              │  │ │
│  │  │   │ Version N│      │Version N+1      │Points to │               │  │ │
│  │  │   │          │      │          │      │BLUE/GREEN│               │  │ │
│  │  │   └────┬─────┘      └────┬─────┘      └────┬─────┘               │  │ │
│  │  │        │                 │                  │                      │  │ │
│  │  │        └─────────────────┴──────────────────┘                      │  │ │
│  │  │                           │                                         │  │ │
│  │  │                           │ Weighted Traffic (Canary Support)      │  │ │
│  │  └───────────────────────────┼─────────────────────────────────────┘  │ │
│  │                               │                                         │ │
│  │  Runtime: Python 3.11         │                                         │ │
│  │  Memory: 512 MB               │                                         │ │
│  │  Timeout: 30s                 │                                         │ │
│  │  Image: ECR → Container       │                                         │ │
│  │                               │                                         │ │
│  │  ┌────────────────────────────▼──────────────────────────────────────┐ │ │
│  │  │ Flask Application (Mangum ASGI Handler)                            │ │ │
│  │  │  • API Key Authentication                                          │ │ │
│  │  │  • HMAC Signature Validation                                       │ │ │
│  │  │  • Rate Limiting (In-Memory)                                       │ │ │
│  │  │  • Health Check Endpoint (/health)                                 │ │ │
│  │  │  • Protected Endpoints (/api/*)                                    │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────┬────────────────────────────────────────────────────────┘ │
│                   │                                                           │
│                   │ Pulls Image From                                          │
│                   ↓                                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │           📦 ELASTIC CONTAINER REGISTRY (ECR)                           │ │
│  │                cicd-portfolio-{env}-app                                  │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Images:                                                            │  │ │
│  │  │   • {git-sha} (Immutable Tags)                                     │  │ │
│  │  │   • latest                                                          │  │ │
│  │  │                                                                     │  │ │
│  │  │  Scan on Push: Enabled                                             │  │ │
│  │  │  Encryption: AES-256                                               │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    🛡️ AWS WAF (Web Application Firewall)               │ │
│  │                     cicd-portfolio-{env}-waf                             │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  RULES:                                                             │  │ │
│  │  │   1. Rate Limiting: 2000 req / 5 min per IP → Block (429)         │  │ │
│  │  │   2. SQL Injection: Query String + Body + URI → Block              │  │ │
│  │  │   3. XSS Protection: Query String + Body + Cookie → Block          │  │ │
│  │  │   4. Geo-Blocking: CN, RU, KP → Count (Monitor Mode)               │  │ │
│  │  │   5. AWS Managed Rules: Common Rule Set                            │  │ │
│  │  │   6. AWS Managed Rules: Known Bad Inputs                           │  │ │
│  │  │                                                                     │  │ │
│  │  │  Logging: CloudWatch Logs (aws-waf-logs-*)                         │  │ │
│  │  │  Metrics: CloudWatch Metrics                                       │  │ │
│  │  │                                                                     │  │ │
│  │  │  NOTE: Not enforced on API Gateway (HTTP API v2 limitation)        │  │ │
│  │  │        WAF created for monitoring only                             │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    🔐 AWS SECRETS MANAGER                                │ │
│  │                cicd-portfolio-{env}-secrets                              │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Secrets:                                                           │  │ │
│  │  │   • database_password                                              │  │ │
│  │  │   • api_key                                                         │  │ │
│  │  │   • jwt_secret                                                      │  │ │
│  │  │                                                                     │  │ │
│  │  │  Encryption: AWS KMS                                               │  │ │
│  │  │  Rotation: Disabled (Manual)                                       │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                     📊 CLOUDWATCH (Monitoring & Logging)                 │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  LOG GROUPS:                                                        │  │ │
│  │  │   • /aws/lambda/cicd-portfolio-{env}-api                           │  │ │
│  │  │   • /aws/apigateway/cicd-portfolio-{env}                           │  │ │
│  │  │   • aws-waf-logs-cicd-portfolio-{env}                              │  │ │
│  │  │                                                                     │  │ │
│  │  │  METRICS:                                                           │  │ │
│  │  │   • Lambda: Invocations, Errors, Duration, Throttles               │  │ │
│  │  │   • API Gateway: Count, 4XXError, 5XXError, Latency                │  │ │
│  │  │   • WAF: AllowedRequests, BlockedRequests, CountedRequests         │  │ │
│  │  │                                                                     │  │ │
│  │  │  ALARMS:                                                            │  │ │
│  │  │   • Green Version Errors > 3 in 1 min → Trigger Rollback           │  │ │
│  │  │   • Lambda Error Rate > Threshold → SNS Alert                      │  │ │
│  │  │   • API Gateway 5XX > Threshold → SNS Alert                        │  │ │
│  │  │                                                                     │  │ │
│  │  │  DASHBOARD:                                                         │  │ │
│  │  │   • Lambda Performance Metrics                                     │  │ │
│  │  │   • API Gateway Request Metrics                                    │  │ │
│  │  │   • WAF Rule Metrics                                               │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         📧 SNS (Alerting)                                │ │
│  │                cicd-portfolio-{env}-alerts                               │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Subscriptions:                                                     │  │ │
│  │  │   • Email: {alert_email} (if configured)                           │  │ │
│  │  │                                                                     │  │ │
│  │  │  Triggered By:                                                      │  │ │
│  │  │   • CloudWatch Alarms                                              │  │ │
│  │  │   • Lambda Errors                                                   │  │ │
│  │  │   • Deployment Failures                                            │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    ⏰ EVENTBRIDGE (Lambda Warmup)                        │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Schedule: rate(5 minutes)                                          │  │ │
│  │  │  Target: Lambda Function (LIVE Alias)                              │  │ │
│  │  │  Payload: {"httpMethod":"GET","path":"/health"}                    │  │ │
│  │  │                                                                     │  │ │
│  │  │  Purpose: Keep Lambda warm, reduce cold starts                     │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         👤 IAM ROLES & POLICIES                          │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Lambda Execution Role:                                             │  │ │
│  │  │   • AWSLambdaBasicExecutionRole (CloudWatch Logs)                  │  │ │
│  │  │   • Custom Policy: Secrets Manager Read                            │  │ │
│  │  │   • Custom Policy: ECR Image Pull                                  │  │ │
│  │  │                                                                     │  │ │
│  │  │  GitHub Actions User:                                              │  │ │
│  │  │   • Lambda, ECR, API Gateway, CloudWatch, Logs                     │  │ │
│  │  │   • IAM (CreateRole, CreatePolicy, etc.)                           │  │ │
│  │  │   • Secrets Manager, SNS, EventBridge, WAF                         │  │ │
│  │  │   • S3 (Terraform State), DynamoDB (State Locking)                 │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Terraform State Management

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          TERRAFORM STATE BACKEND                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    📦 S3 BUCKET (State Storage)                       │  │
│  │                 cicd-portfolio-terraform-state                         │  │
│  │  ┌───────────────────────────────────────────────────────────────────┐│  │
│  │  │  State Files:                                                      ││  │
│  │  │   • env/dev/terraform.tfstate                                     ││  │
│  │  │   • env/staging/terraform.tfstate                                 ││  │
│  │  │   • env/prod/terraform.tfstate                                    ││  │
│  │  │                                                                    ││  │
│  │  │  Features:                                                         ││  │
│  │  │   • Versioning: Enabled                                           ││  │
│  │  │   • Encryption: AES-256                                           ││  │
│  │  │   • Lifecycle: Retain previous versions                           ││  │
│  │  └───────────────────────────────────────────────────────────────────┘│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                          │
│                                    │ Lock Coordination                        │
│                                    ↓                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │               🔒 DYNAMODB TABLE (State Locking)                       │  │
│  │                cicd-portfolio-terraform-locks                          │  │
│  │  ┌───────────────────────────────────────────────────────────────────┐│  │
│  │  │  Primary Key: LockID (String)                                      ││  │
│  │  │  Billing Mode: PAY_PER_REQUEST                                    ││  │
│  │  │                                                                    ││  │
│  │  │  Purpose: Prevent concurrent Terraform operations                 ││  │
│  │  └───────────────────────────────────────────────────────────────────┘│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           5 LAYERS OF SECURITY                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  Layer 1: NETWORK SECURITY                                                   │
│  ────────────────────────────────────────────────────────────────────────   │
│  • AWS WAF with 6 Rule Sets                                                  │
│    - Rate Limiting (2000 req/5min per IP)                                    │
│    - SQL Injection Protection (Query String + Body + URI)                    │
│    - XSS Protection (Query String + Body + Cookie)                           │
│    - Geo-Blocking (CN, RU, KP - Count Mode)                                  │
│    - AWS Managed Rules: Common Rule Set                                      │
│    - AWS Managed Rules: Known Bad Inputs                                     │
│                                                                               │
│  Layer 2: APPLICATION SECURITY                                               │
│  ────────────────────────────────────────────────────────────────────────   │
│  • API Key Authentication (X-API-Key Header)                                 │
│  • HMAC Signature Validation (X-Signature + X-Timestamp)                     │
│  • Rate Limiting (100 req/min per API key)                                   │
│  • Request Validation (Pydantic Models)                                      │
│                                                                               │
│  Layer 3: CONTAINER SECURITY                                                 │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Trivy Scan (HIGH & CRITICAL CVEs)                                         │
│  • ECR Scan on Push                                                          │
│  • Immutable Image Tags                                                      │
│  • Minimal Base Image (AWS Lambda Python 3.11)                               │
│  • No Root User in Container                                                 │
│                                                                               │
│  Layer 4: DEPENDENCY SECURITY                                                │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Safety Check (Python Package Vulnerabilities)                             │
│  • Bandit Scan (Python Code Security Issues)                                 │
│  • pip-audit (Dependency Audit)                                              │
│  • Automated Dependency Updates                                              │
│                                                                               │
│  Layer 5: INFRASTRUCTURE SECURITY                                            │
│  ────────────────────────────────────────────────────────────────────────   │
│  • IAM Least Privilege (Role-based Access)                                   │
│  • Secrets Manager (No Hardcoded Credentials)                                │
│  • Encrypted S3 (Terraform State)                                            │
│  • Encrypted ECR (Container Images)                                          │
│  • VPC Endpoints (Private Access to AWS Services)                            │
│  • CloudWatch Logs Encryption                                                │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Observability Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MONITORING & OBSERVABILITY                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  LOGS (CloudWatch Logs)                                                      │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Lambda Execution Logs                                                     │
│  • API Gateway Access Logs                                                   │
│  • WAF Logs (Blocked/Allowed Requests)                                       │
│  • Retention: 7 days (configurable)                                          │
│                                                                               │
│  METRICS (CloudWatch Metrics)                                                │
│  ────────────────────────────────────────────────────────────────────────   │
│  Lambda:                                                                     │
│   • Invocations, Errors, Duration, Throttles, ConcurrentExecutions          │
│   • Metrics per Alias (blue, green, live)                                    │
│                                                                               │
│  API Gateway:                                                                │
│   • Count, 4XXError, 5XXError, IntegrationLatency, Latency                  │
│                                                                               │
│  WAF:                                                                        │
│   • AllowedRequests, BlockedRequests, CountedRequests                        │
│   • Per-Rule Metrics (Rate Limit, SQLi, XSS, Geo, Managed Rules)            │
│                                                                               │
│  DASHBOARDS (CloudWatch Dashboard)                                           │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Lambda Performance (Invocations, Errors, Duration)                        │
│  • API Gateway Overview (Requests, Errors, Latency)                          │
│  • WAF Security (Blocked Requests by Rule)                                   │
│  • Blue-Green Deployment Status                                              │
│                                                                               │
│  ALARMS (CloudWatch Alarms)                                                  │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Green Version Errors > 3 in 1 min → Rollback                             │
│  • Lambda Error Rate > 5% → SNS Alert                                        │
│  • API Gateway 5XX > 10 in 5 min → SNS Alert                                │
│  • Lambda Duration > 25s (80% of timeout) → SNS Alert                        │
│                                                                               │
│  TRACING (AWS X-Ray) - Optional                                              │
│  ────────────────────────────────────────────────────────────────────────   │
│  • End-to-End Request Tracing                                                │
│  • Service Map Visualization                                                 │
│  • Performance Bottleneck Identification                                     │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Blue-Green Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        BLUE-GREEN DEPLOYMENT FLOW                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  INITIAL STATE:                                                              │
│  ───────────────────────────────────────────────────────────────────────    │
│    BLUE (v1)  ◄────┐                                                         │
│                     │                                                         │
│    LIVE (v1)  ──────┘  ◄─── 100% Production Traffic                          │
│                                                                               │
│    GREEN (v1)                                                                │
│                                                                               │
│                                                                               │
│  AFTER DEPLOYMENT (Stage 2 - Deploy):                                        │
│  ───────────────────────────────────────────────────────────────────────    │
│    BLUE (v1)  ◄────┐                                                         │
│                     │                                                         │
│    LIVE (v1)  ──────┘  ◄─── 100% Production Traffic                          │
│                                                                               │
│    GREEN (v2) ◄─────────── NEW VERSION DEPLOYED (No Traffic Yet)             │
│                                                                               │
│                                                                               │
│  AFTER VERIFICATION (Stage 3 - Verify):                                      │
│  ───────────────────────────────────────────────────────────────────────    │
│    BLUE (v1)  ◄────┐                                                         │
│                     │                                                         │
│    LIVE (v1)  ──────┘  ◄─── 100% Production Traffic                          │
│                                                                               │
│    GREEN (v2) ◄─────────── ✅ HEALTH CHECKS PASSED                           │
│                                                                               │
│                                                                               │
│  AFTER PROMOTION (Stage 4 - Promote):                                        │
│  ───────────────────────────────────────────────────────────────────────    │
│    BLUE (v1)  ◄─────────── BACKUP VERSION (Rollback Target)                 │
│                                                                               │
│    LIVE (v2)  ──────┐  ◄─── 100% Production Traffic                          │
│                      │                                                        │
│    GREEN (v2) ◄──────┘                                                       │
│                                                                               │
│                                                                               │
│  IF ERRORS DETECTED (Stage 5 - Monitor):                                     │
│  ───────────────────────────────────────────────────────────────────────    │
│    BLUE (v1)  ◄────┐  ◄─── ROLLBACK TARGET                                  │
│                     │                                                         │
│    LIVE (v1)  ──────┘  ◄─── 🔄 ROLLED BACK (100% Traffic)                   │
│                                                                               │
│    GREEN (v2) ◄─────────── ❌ FAILED MONITORING                              │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🌍 Multi-Environment Setup

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ENVIRONMENT ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  DEV (Development)                                                           │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Purpose: Feature development and testing                                  │
│  • Lambda: 256 MB, 30s timeout                                               │
│  • WAF: Geo-blocking in COUNT mode                                           │
│  • Monitoring: Basic CloudWatch Logs                                         │
│  • Terraform State: env/dev/terraform.tfstate                                │
│                                                                               │
│  STAGING (Pre-Production)                                                    │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Purpose: Integration testing and validation                               │
│  • Lambda: 512 MB, 30s timeout                                               │
│  • WAF: All rules enabled, geo-blocking in COUNT mode                        │
│  • Monitoring: Full CloudWatch (Logs, Metrics, Alarms)                       │
│  • Blue-Green: Enabled                                                       │
│  • Terraform State: env/staging/terraform.tfstate                            │
│                                                                               │
│  PROD (Production)                                                           │
│  ────────────────────────────────────────────────────────────────────────   │
│  • Purpose: Live customer traffic                                            │
│  • Lambda: 1024 MB, 30s timeout, Provisioned Concurrency                     │
│  • WAF: All rules enabled, geo-blocking in BLOCK mode                        │
│  • Monitoring: Full observability + 10-minute error monitoring               │
│  • Blue-Green: Enabled with automated rollback                               │
│  • Alerts: SNS to on-call team                                               │
│  • Terraform State: env/prod/terraform.tfstate                               │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📈 Traffic Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            END-TO-END REQUEST FLOW                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  1. CLIENT REQUEST                                                           │
│     │                                                                         │
│     │  GET /api/users                                                        │
│     │  Headers:                                                               │
│     │    X-API-Key: test-api-key-12345                                      │
│     │    X-Signature: hmac-sha256-signature                                  │
│     │    X-Timestamp: 1234567890                                            │
│     ↓                                                                         │
│                                                                               │
│  2. API GATEWAY (HTTP API)                                                   │
│     │                                                                         │
│     │  • Receives request                                                    │
│     │  • Logs to CloudWatch                                                  │
│     │  • Applies throttling (if configured)                                  │
│     ↓                                                                         │
│                                                                               │
│  3. WAF INSPECTION (if enforced via CloudFront/ALB)                          │
│     │                                                                         │
│     │  • Rate limiting check (2000/5min per IP)                              │
│     │  • SQL injection check                                                 │
│     │  • XSS check                                                           │
│     │  • Geo-blocking check                                                  │
│     │  • Managed rules evaluation                                            │
│     │                                                                         │
│     │  ✅ ALLOWED → Continue                                                 │
│     │  ❌ BLOCKED → Return 403                                               │
│     ↓                                                                         │
│                                                                               │
│  4. LAMBDA INVOCATION (LIVE Alias)                                           │
│     │                                                                         │
│     │  • Routes to current version (blue or green)                           │
│     │  • Cold start (if needed) or warm instance                             │
│     ↓                                                                         │
│                                                                               │
│  5. FLASK APPLICATION                                                        │
│     │                                                                         │
│     │  a. API Key Validation                                                 │
│     │     • Check X-API-Key exists                                           │
│     │     • Lookup in in-memory store                                        │
│     │     • Return 401 if invalid                                            │
│     │                                                                         │
│     │  b. HMAC Signature Validation                                          │
│     │     • Get X-Signature and X-Timestamp                                  │
│     │     • Check timestamp is within 5 minutes                              │
│     │     • Recompute HMAC with secret                                       │
│     │     • Compare signatures                                               │
│     │     • Return 401 if mismatch                                           │
│     │                                                                         │
│     │  c. Rate Limiting Check                                                │
│     │     • Check request count for API key                                  │
│     │     • Return 429 if exceeded (100 req/min)                             │
│     │                                                                         │
│     │  d. Request Processing                                                 │
│     │     • Route to endpoint handler                                        │
│     │     • Process business logic                                           │
│     │     • Generate response                                                │
│     ↓                                                                         │
│                                                                               │
│  6. RESPONSE                                                                 │
│     │                                                                         │
│     │  200 OK                                                                │
│     │  {                                                                     │
│     │    "data": [...],                                                      │
│     │    "status": "success"                                                 │
│     │  }                                                                     │
│     ↓                                                                         │
│                                                                               │
│  7. LOGGING & METRICS                                                        │
│     │                                                                         │
│     │  • Lambda logs to CloudWatch                                           │
│     │  • API Gateway logs request/response                                   │
│     │  • Metrics updated (invocations, duration, errors)                     │
│     │  • X-Ray trace (if enabled)                                            │
│     ↓                                                                         │
│                                                                               │
│  8. RETURN TO CLIENT                                                         │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Technology Stack

### Infrastructure
- **IaC**: Terraform 1.6
- **State**: S3 + DynamoDB
- **Cloud**: AWS (us-east-1)

### Compute & API
- **Runtime**: AWS Lambda (Python 3.11)
- **API Gateway**: HTTP API (v2)
- **Container**: Docker + ECR

### CI/CD
- **Pipeline**: GitHub Actions
- **Security Scans**: Trivy, Safety, Bandit
- **Testing**: pytest, Locust

### Security
- **WAF**: AWS WAF v2
- **Secrets**: AWS Secrets Manager
- **Auth**: API Key + HMAC

### Monitoring
- **Logs**: CloudWatch Logs
- **Metrics**: CloudWatch Metrics
- **Alerts**: SNS
- **Tracing**: X-Ray (optional)

### Python Frameworks
- **Web**: Flask 3.0
- **ASGI**: Mangum (for Lambda)
- **Validation**: Pydantic 2.5

---

## 📝 Key Design Decisions

### 1. HTTP API vs REST API
- **Choice**: HTTP API (v2)
- **Rationale**: Lower cost, better performance, simpler configuration
- **Trade-off**: No WAF association (WAF in monitoring mode only)
- **Future**: Add CloudFront for WAF enforcement

### 2. Blue-Green vs Canary
- **Choice**: Blue-Green with canary capability
- **Rationale**:
  - Blue-Green: Instant rollback, simple traffic switching
  - Canary: Gradual rollout with weighted routing (10% → 25% → 50% → 100%)
- **Implementation**: Lambda aliases with routing configuration

### 3. Container vs Zip Deployment
- **Choice**: Container deployment via ECR
- **Rationale**:
  - Better dependency management
  - Consistent dev/prod environments
  - Easy to scan with Trivy
- **Trade-off**: Slightly slower cold starts

### 4. S3 Backend vs Terraform Cloud
- **Choice**: S3 + DynamoDB backend
- **Rationale**:
  - Full control over state
  - No third-party dependencies
  - Cost-effective
  - Supports locking

### 5. In-Memory Rate Limiting vs DynamoDB
- **Choice**: In-memory rate limiting
- **Rationale**:
  - Simple implementation
  - No additional AWS costs
  - Sufficient for per-instance rate limiting
- **Limitation**: Doesn't work across multiple Lambda instances
- **Future**: Migrate to DynamoDB for distributed rate limiting

---

## 🚀 Deployment Commands

### Deploy Infrastructure
```bash
# Via GitHub Actions (Recommended)
GitHub Actions → Build and Deploy → Run workflow → staging

# Via Terraform CLI (Manual)
cd terraform
terraform init -backend-config="key=env/staging/terraform.tfstate"
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

### Rollback Deployment
```bash
# Via GitHub Actions
GitHub Actions → Rollback Deployment → Run workflow → staging

# Via AWS CLI (Manual)
aws lambda update-alias \
  --function-name cicd-portfolio-staging-api \
  --name live \
  --function-version <blue-version>
```

### View Logs
```bash
# Lambda logs
aws logs tail /aws/lambda/cicd-portfolio-staging-api --follow

# API Gateway logs
aws logs tail /aws/apigateway/cicd-portfolio-staging --follow

# WAF logs
aws logs tail aws-waf-logs-cicd-portfolio-staging --follow
```

---

## 📚 Related Documentation

- [Error Log & Solutions](./ERROR-LOG.md)
- [Alignment with Architecture](./ALIGNMENT-WITH-ARCHITECTURE.md)
- [Testing Summary](./TESTING-SUMMARY.md)
- [Standards Guide](./STANDARDS.md)
- [IAM Policy](./iam-policy-github-actions.json)

---

**Last Updated**: 2026-01-19
**Project**: CI/CD Portfolio
**Status**: ✅ Infrastructure Deployed, 🔄 Completing Pipeline Testing
