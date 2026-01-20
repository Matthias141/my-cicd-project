# Production CI/CD Pipeline Architecture

> **Zero-touch deployment • Infrastructure as Code • Blue-Green Strategy**

---

## 🎨 Visual Architecture Diagram

```mermaid
graph TB
    subgraph "CI/CD PIPELINE"
        A1[📦 Build & Scan<br/>Docker • Trivy<br/>Bandit • Safety] --> A2[🔧 Terraform<br/>Init • Plan • Apply]
        A2 --> A3[🚀 Deploy<br/>Blue/Green<br/>Rollback]
        A3 --> A4[✅ Verify<br/>Health • Smoke]
        A4 --> A5[🎯 Promote<br/>Live → Green]
    end

    subgraph "AWS CLOUD"
        subgraph "Compute & API"
            B1[🌐 API Gateway<br/>HTTP API v2]
            B2[⚡ Lambda<br/>Container<br/>Python 3.11]
            B3[📦 ECR<br/>Immutable Tags]
        end

        subgraph "Security"
            C1[🛡️ WAF v2<br/>6 Rule Sets]
            C2[🔐 Secrets Mgr<br/>Encrypted]
            C3[👤 IAM<br/>Least Privilege]
        end

        subgraph "Observability"
            D1[📊 CloudWatch<br/>Logs & Metrics]
            D2[🔔 SNS<br/>Alerts]
            D3[📈 Dashboards<br/>Real-time]
        end

        subgraph "State Management"
            E1[📦 S3<br/>Terraform State]
            E2[🔒 DynamoDB<br/>State Locking]
        end
    end

    A5 --> B1
    B1 --> B2
    B2 -.pulls.-> B3
    C1 -.monitors.-> B1
    B2 -.reads.-> C2
    B2 --> D1
    D1 --> D2
    A2 -.stores.-> E1
    E1 -.locks.-> E2

    style A1 fill:#4CAF50,stroke:#2E7D32,color:#fff
    style A2 fill:#2196F3,stroke:#1565C0,color:#fff
    style A3 fill:#FF9800,stroke:#E65100,color:#fff
    style A4 fill:#9C27B0,stroke:#6A1B9A,color:#fff
    style A5 fill:#F44336,stroke:#C62828,color:#fff
    style B1 fill:#7C4DFF,stroke:#5E35B1,color:#fff
    style B2 fill:#FF6F00,stroke:#E65100,color:#fff
    style C1 fill:#D32F2F,stroke:#B71C1C,color:#fff
```

---

## 🏗️ Complete Infrastructure

```mermaid
flowchart LR
    subgraph Client
        U[👤 User]
    end

    subgraph "API Layer"
        AG[API Gateway<br/>HTTP API v2]
    end

    subgraph "Security Layer"
        WAF[WAF v2<br/>Rate Limit<br/>SQLi/XSS<br/>Geo-Block]
    end

    subgraph "Compute Layer"
        LA[Lambda Function<br/>cicd-portfolio-staging-api]
        subgraph "Aliases"
            BLUE[🔵 BLUE<br/>Stable v1]
            GREEN[🟢 GREEN<br/>New v2]
            LIVE[⭐ LIVE<br/>→ Production]
        end
    end

    subgraph "Storage"
        ECR[ECR<br/>Container<br/>Registry]
        SM[Secrets<br/>Manager]
    end

    subgraph "Monitoring"
        CW[CloudWatch<br/>Logs • Metrics<br/>Alarms]
        SNS[SNS<br/>Alerts]
    end

    U -->|HTTPS| AG
    AG -->|Invoke| LA
    WAF -.monitors.-> AG
    LA --> LIVE
    LIVE -.routes to.-> BLUE
    LIVE -.routes to.-> GREEN
    LA -.pulls image.-> ECR
    LA -.reads.-> SM
    LA -->|logs| CW
    CW -->|alert| SNS

    style U fill:#64B5F6,stroke:#1976D2,color:#fff
    style AG fill:#7C4DFF,stroke:#5E35B1,color:#fff
    style WAF fill:#EF5350,stroke:#C62828,color:#fff
    style LA fill:#FF9800,stroke:#E65100,color:#fff
    style BLUE fill:#42A5F5,stroke:#1565C0,color:#fff
    style GREEN fill:#66BB6A,stroke:#2E7D32,color:#fff
    style LIVE fill:#FFD54F,stroke:#F57C00,color:#000
    style CW fill:#AB47BC,stroke:#6A1B9A,color:#fff
```

---

## 🔄 Blue-Green Deployment Flow

```mermaid
stateDiagram-v2
    [*] --> Initial

    state Initial {
        [*] --> Blue_v1
        Blue_v1 --> Live_v1
        Live_v1: LIVE → v1<br/>100% Traffic
        Green_v1: GREEN → v1<br/>No Traffic
    }

    Initial --> Deploying: Stage 2: Deploy

    state Deploying {
        [*] --> Blue_v1_dep
        Blue_v1_dep: BLUE → v1<br/>Stable
        Live_v1_dep: LIVE → v1<br/>100% Traffic
        Green_v2_new: GREEN → v2<br/>NEW VERSION
        Green_v2_new: 0% Traffic
    }

    Deploying --> Verifying: Stage 3: Verify

    state Verifying {
        [*] --> HealthCheck
        HealthCheck: ✅ Health Check<br/>GREEN v2
        HealthCheck --> SmokeTests
        SmokeTests: ✅ Smoke Tests<br/>Passed
    }

    Verifying --> Promoted: Stage 4: Promote

    state Promoted {
        [*] --> Blue_v1_backup
        Blue_v1_backup: BLUE → v1<br/>Backup
        Live_v2_new: LIVE → v2<br/>100% Traffic
        Green_v2_live: GREEN → v2<br/>Active
    }

    Promoted --> Monitoring: Stage 5: Monitor

    state Monitoring {
        [*] --> CheckErrors
        CheckErrors: Monitor Errors<br/>10 minutes
        CheckErrors --> Success: Error Rate OK
        CheckErrors --> Rollback: Errors > Threshold
    }

    state Rollback {
        [*] --> Reverted
        Reverted: LIVE → v1<br/>🔄 Rolled Back<br/>BLUE Restored
    }

    Success --> [*]
    Rollback --> [*]
```

---

## 🛡️ Security Layers

```mermaid
graph TD
    subgraph "5 Security Layers"
        L1[Layer 1: Network<br/>WAF • Rate Limiting<br/>SQLi/XSS • Geo-Block]
        L2[Layer 2: Application<br/>API Keys • HMAC<br/>Validation]
        L3[Layer 3: Container<br/>Trivy Scan<br/>Immutable Tags]
        L4[Layer 4: Dependencies<br/>Safety • Bandit<br/>pip-audit]
        L5[Layer 5: Infrastructure<br/>IAM • Encryption<br/>Secrets Manager]
    end

    L1 --> L2 --> L3 --> L4 --> L5

    style L1 fill:#F44336,stroke:#C62828,color:#fff
    style L2 fill:#FF9800,stroke:#E65100,color:#fff
    style L3 fill:#FFC107,stroke:#F57C00,color:#000
    style L4 fill:#4CAF50,stroke:#2E7D32,color:#fff
    style L5 fill:#2196F3,stroke:#1565C0,color:#fff
```

---

## 📊 Multi-Environment Architecture

```mermaid
graph LR
    subgraph DEV
        D1[Lambda: 256MB<br/>WAF: Count Mode<br/>Logs: Basic]
    end

    subgraph STAGING
        S1[Lambda: 512MB<br/>WAF: Monitor<br/>Logs: Full<br/>Blue-Green: ✅]
    end

    subgraph PROD
        P1[Lambda: 1024MB<br/>WAF: Enforce<br/>Logs: Full<br/>Blue-Green: ✅<br/>Auto-Rollback: ✅]
    end

    DEV -->|Promote| STAGING
    STAGING -->|Promote| PROD

    style DEV fill:#4CAF50,stroke:#2E7D32,color:#fff
    style STAGING fill:#FF9800,stroke:#E65100,color:#fff
    style PROD fill:#F44336,stroke:#C62828,color:#fff
```

---

## 📈 Key Metrics

| Metric | Value | Description |
|--------|-------|-------------|
| **Deploy Time** | <2m | Infrastructure + Code Deployment |
| **Monthly Cost** | $0 | Free tier (Lambda, API GW, CloudWatch) |
| **Manual Steps** | 0 | Fully automated pipeline |
| **Test Coverage** | 85% | Authentication & Core Logic |
| **Security Layers** | 5 | Network → Infrastructure |
| **Environments** | 3 | Dev, Staging, Production |
| **AWS Services** | 12 | Lambda, API GW, ECR, WAF, etc. |
| **Zero-Downtime** | ✅ | Blue-Green Deployment |

---

## 🎯 Quick Reference

### AWS Services Used
- **Compute**: Lambda (Python 3.11, Containerized)
- **API**: API Gateway HTTP API (v2)
- **Storage**: ECR (Container Registry), S3 (State)
- **Security**: WAF v2, Secrets Manager, IAM
- **Monitoring**: CloudWatch Logs/Metrics, SNS, X-Ray
- **Orchestration**: EventBridge
- **State**: DynamoDB (Locking)

### CI/CD Pipeline
- **Source**: GitHub
- **CI/CD**: GitHub Actions (6 stages)
- **Security**: Trivy, Safety, Bandit
- **Testing**: pytest (85% coverage), Locust
- **IaC**: Terraform 1.6

### Security Features
- ✅ WAF with 6 rule sets (2000 req/5min per IP)
- ✅ API Key + HMAC authentication
- ✅ Container scanning (Trivy)
- ✅ Dependency scanning (Safety, Bandit)
- ✅ Immutable container tags
- ✅ Encrypted secrets (Secrets Manager)
- ✅ IAM least privilege

### Deployment Features
- ✅ Blue-Green deployment
- ✅ Automated rollback (on errors)
- ✅ Health checks + smoke tests
- ✅ Zero-downtime deployments
- ✅ Multi-environment (dev/staging/prod)
- ✅ Terraform state management (S3 + DynamoDB)

---

## 🔗 Related Documentation

- [Complete Architecture Details](./ARCHITECTURE-DIAGRAM.md)
- [Error Log & Solutions](./ERROR-LOG.md)
- [Alignment Analysis](./ALIGNMENT-WITH-ARCHITECTURE.md)
- [Testing Summary](./TESTING-SUMMARY.md)

---

**Status**: ✅ Infrastructure Deployed | 🔄 Pipeline Testing
**Last Updated**: 2026-01-19
**Author**: Your Name
**Project**: Production CI/CD Portfolio
