# 🚀 Multi-Environment CI/CD Pipeline with AWS Lambda

A production-grade CI/CD pipeline demonstrating modern DevOps practices with serverless architecture.

## 🎯 Overview

This project showcases:
- **Serverless Architecture**: AWS Lambda + API Gateway
- **Infrastructure as Code**: Terraform for all AWS resources
- **CI/CD Pipeline**: GitHub Actions with multi-environment deployment
- **Containerization**: Docker with multi-stage builds
- **Security**: IAM least privilege, Secrets Manager, vulnerability scanning
- **Observability**: CloudWatch logs, metrics, alarms, and X-Ray tracing
- **Cost Optimization**: 100% free tier usage with cold start mitigation

## 🏗️ Architecture
```
GitHub → GitHub Actions → ECR → Lambda → API Gateway → User
                    ↓
            [DEV] → [STAGING] → [PRODUCTION]
```

## 🛠️ Tech Stack

- **Application**: Python 3.11, Flask
- **Container**: Docker (ARM64 optimized)
- **Cloud**: AWS (Lambda, API Gateway, ECR, CloudWatch, Secrets Manager)
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Testing**: pytest
- **Security**: Trivy vulnerability scanning

## 📦 Project Structure
```
my-cicd-project/
├── app/                  # Flask application
├── tests/                # Automated tests
├── terraform/            # Infrastructure as Code
├── .github/workflows/    # CI/CD pipeline
└── Dockerfile           # Container definition
```

## 🚀 Deployment Environments

- **DEV**: Automatic deployment on every commit
- **STAGING**: Manual approval required
- **PRODUCTION**: Manual approval + comprehensive testing

## 📊 Features

- ✅ Automated testing with pytest
- ✅ Docker containerization
- ✅ Multi-environment deployment (dev/staging/prod)
- ✅ Security vulnerability scanning
- ✅ CloudWatch monitoring and alarms
- ✅ Lambda warm-up system (eliminates cold starts)
- ✅ Blue/green deployments for zero downtime
- ✅ Cost: $0/month (within AWS free tier)

## 🔐 Security

- IAM roles with least privilege principle
- Secrets managed via AWS Secrets Manager
- Container vulnerability scanning with Trivy
- No hardcoded credentials
- GitHub Actions OIDC authentication

## 📈 Monitoring

- CloudWatch Logs for all Lambda executions
- CloudWatch Alarms for errors, throttling, and latency
- X-Ray distributed tracing
- Custom CloudWatch dashboard

## 💰 Cost Analysis

**Monthly Cost**: $0

- Lambda: 1M requests/month free tier
- API Gateway: 1M requests/month free tier (first 12 months)
- ECR: 500MB storage free tier
- CloudWatch: 5GB logs free tier
- EventBridge: Free for scheduled rules

## 🎓 Learning Outcomes

This project demonstrates:
- Modern serverless architecture patterns
- Infrastructure as Code best practices
- CI/CD pipeline design and implementation
- AWS cloud services integration
- Container optimization techniques
- Security and observability patterns
- Cost optimization strategies

## 👤 Author

**Your Name**
- GitHub: [@Matthias141](https://github.com/Matthias141)
- LinkedIn: [Your LinkedIn](https://linkedin.com/in/ifedayo-idowu)

---

⭐ Star this repo if you find it helpful!
'@ | Out-File -FilePath README.md -Encoding UTF8