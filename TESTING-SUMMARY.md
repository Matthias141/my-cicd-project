# 🧪 Testing & Validation Summary

## Overview

This document summarizes the testing infrastructure and code standards for this
project. Numbers below were verified against current code on `main` on
2026-08-05 by running `pytest --collect-only` and the full suite directly —
not carried over from any prior version of this document.

---

## ✅ What We've Built & Tested

### 1. **Test Suite**

#### App Tests (`tests/test_app.py`) - 2 Test Cases
- ✅ Root endpoint (`test_home`)
- ✅ Health check endpoint (`test_health`)

#### Authentication Tests (`tests/test_auth.py`) - 8 Test Cases
- ✅ API key validation via `get_api_key_info()` (success, invalid key) - 2 cases
- ✅ HMAC signature validation via `validate_signature()` (valid, invalid signature, invalid API key) - 3 cases
- ✅ Rate limiting via `check_rate_limit()` (within limit, invalid key, exceeded limit) - 3 cases

**Coverage**: Core authentication and rate-limiting logic. Signature tests
compute real HMAC signatures rather than mocking the verification function.

#### Protected Endpoints Tests (`tests/test_protected_endpoints.py`) - 13 Test Cases
- ✅ Public endpoints accessible without auth - 1 case
- ✅ Protected endpoint access control (missing key, valid key, admin permission missing/present) - 4 cases
- ✅ Signed endpoint access control (missing signature, valid signature, invalid signature) - 3 cases
- ✅ Input validation via Pydantic (valid data, invalid email, invalid age boundary, missing field) - 4 cases
- ✅ Security headers present on responses - 1 case

**Coverage**: All current API endpoints, decorator-based auth, and input validation.

**Total: 23 test cases across 3 files.**

> Note: `tests/load_test.py` is a Locust load-testing script, not a pytest
> module - it fails pytest collection in this environment because `locust`
> isn't installed as a test dependency. This is expected; it's not part of
> the unit/integration suite and is excluded from the counts above.

### 2. **Code Standards Documentation**

Guidelines live in `STANDARDS.md` covering Python standards, Terraform
standards, API conventions, and testing requirements.

### 3. **Automated Validation Script**

`scripts/validate-deployment.sh` exists and covers Terraform syntax/formatting,
Python tests/linting, AWS resource checks (when deployed), API endpoint checks,
security header checks, and deployment infrastructure checks. Not re-verified
line-by-line as part of this update - scope here is the test suite itself.

---

## 🚀 How to Test

### Run Unit Tests

```bash
# Install test dependencies
pip install -r tests/requirements-test.txt

# Run all tests
pytest tests/test_app.py tests/test_auth.py tests/test_protected_endpoints.py -v

# Run specific test file
pytest tests/test_auth.py -v
```

> `tests/requirements-test.txt` lists `pytest-cov==4.1.0`, but it is **not
> currently installed** in the verified environment - `pytest --cov=app`
> fails with "unrecognized arguments: --cov=app" until it's installed. Run
> `pip install -r tests/requirements-test.txt` first if you want coverage
> output.

### Check Code Quality

```bash
# Format code
black app/ tests/

# Check linting
flake8 app/ --max-line-length=120

# Type checking
mypy app/
```

---

## 📊 Test Coverage Report

### Authentication Module (`app/auth.py`)

| Function | Test Cases |
|----------|-----------|
| `get_api_key_info()` | 2 |
| `validate_signature()` | 3 |
| `check_rate_limit()` | 3 |

### Protected Endpoints (`app/main.py`)

| Endpoint / Feature | Test Cases |
|----------|-----------|
| Public endpoints | 1 |
| `GET /protected` + `GET /admin/stats` (auth/permission checks) | 4 |
| `POST /signed` | 3 |
| `POST /validate` (Pydantic input validation) | 4 |
| Security headers | 1 |

**Coverage percentage**: Not stated. Coverage tooling (`pytest-cov`) is listed
as a dependency but not installed in this environment, so no line/branch
coverage percentage has actually been measured. Treat any coverage percentage
you see elsewhere for this project as unverified until `pytest --cov` is run
for real and a number is captured directly from that output.

**Test run result (verified 2026-08-05)**: `23 passed, 0 failed` running
`pytest tests/test_app.py tests/test_auth.py tests/test_protected_endpoints.py -v`.

---

## 🎯 Standards Compliance Checklist

Before merging to main, ensure:

### Code Quality
- [ ] All tests pass (`pytest tests/test_app.py tests/test_auth.py tests/test_protected_endpoints.py`)
- [ ] Code is formatted (`black . && flake8`)
- [ ] Type hints present on all functions
- [ ] No hardcoded secrets or credentials
- [ ] Error handling implemented

### Security
- [ ] Security headers set for all endpoints
- [ ] Input validation using Pydantic
- [ ] Authentication required for sensitive endpoints
- [ ] Secrets in AWS Secrets Manager (not code)
- [ ] Rate limiting configured

### Infrastructure
- [ ] Terraform validated (`terraform validate`)
- [ ] Terraform formatted (`terraform fmt -check`) - note: `main` currently
      has real, pre-existing formatting drift (`cloudfront.tf`,
      `environments/*.tfvars`, `lambda.tf`, `monitoring.tf`, `waf.tf`); this
      is why the PR-only `pr-terraform-validate.yml` workflow deliberately
      does not gate on `fmt -check` yet
- [ ] All resources tagged appropriately
- [ ] IAM policies follow least privilege - **currently not true**: see
      Known Gaps below

### Testing
- [ ] Unit tests for new features
- [ ] Integration tests for API endpoints
- [ ] Validation script passes
- [ ] Load tests successful (if applicable)

---

## 🔍 What Can Be Tested Now vs. Needs Deployment

### ✅ Can Test Locally (No AWS Required)

```bash
pytest tests/test_app.py tests/test_auth.py tests/test_protected_endpoints.py -v
black --check app/ tests/
flake8 app/ --max-line-length=120
cd terraform && terraform init -backend=false && terraform validate
```

### 🚀 Requires AWS Deployment

**Currently blocked**: the AWS account backing this project is suspended
(see `CLAUDE.md`), so none of the below can actually be exercised right now
- treat this section as a description of the intended checks, not something
you can run today.

1. **Live API Testing** - endpoint accessibility, response times, security headers, auth flows
2. **Infrastructure Validation** - Lambda functions/aliases, ECR, CloudWatch alarms, WAF
3. **Blue-Green Deployment** - the staged rollout script
   (`scripts/blue-green-deploy.sh`) exists and works standalone, but is not
   invoked by any workflow, and `lambda_aliases.tf`'s alias tracks `$LATEST`
   rather than a published version - real weighted traffic shifting isn't
   wired up yet regardless of AWS account status
4. **Load Testing** - performance, stress, endurance testing

---

## 📝 Running Tests in CI/CD

**Verified 2026-08-05: no GitHub Actions workflow in this repository runs
`pytest` at all** - not on push, not on pull request, not in dev/staging/prod
deploy. The 23 tests above currently only run when someone runs `pytest`
manually. This is a real gap, not a hypothetical one - it was previously
undocumented.

What CI *does* run today, confirmed by grepping `.github/workflows/`:

- `deploy-staging.yml`: `pip-audit` and `safety check` (both non-blocking, `|| true`), plus a Trivy container scan
- `deploy-prod.yml`: `pip-audit`, `safety check` (blocking), and `bandit` (non-blocking)
- `build-and-deploy.yml`: `bandit` (non-blocking) and a Trivy container scan
- `pr-python-security.yml`, `pr-terraform-validate.yml`, `pr-docker-scan.yml` (new this session): the same dependency/container/Terraform scans, now also on pull requests - see Known Gaps for the Trivy/Security-tab caveat

None of these run the unit test suite. `deploy-dev.yml` in particular has no
test, lint, or security-scan step of any kind - it builds, pushes to ECR, and
updates the Lambda function directly.

---

## 🚦 Known Gaps (as of 2026-08-05)

Listed honestly rather than omitted, per `CLAUDE.md`'s "Current known state"
and this session's logged follow-ups:

- **No CI enforcement of the test suite at all** (see above) - passing tests
  locally does not currently gate any deploy.
- **AWS account is suspended** - nothing in this document's "Requires AWS
  Deployment" section can actually be run against live infrastructure right now.
- **`docs/iam-policy-github-actions.json` grants wildcard `Resource: "*"`**
  for every service except IAM - unfixed, critical.
- **"Canary releases" is not an accurate description of the deploy pipeline**:
  the staged rollout script exists standalone but isn't wired into any
  workflow, and the Lambda alias tracks `$LATEST` rather than a published
  version, which blocks real weighted routing at the AWS API level regardless.
- **CloudWatch alarms have zero confirmed SNS subscribers** (`alert_email`
  unset in every `.tfvars`) - alarms fire into a void.
- **Possible latent `actions: read` permission gap** in `deploy-staging.yml`'s
  and `build-and-deploy.yml`'s existing Trivy + `upload-sarif` steps -
  flagged during this session's `pr-docker-scan.yml` live-PR testing, not
  yet verified for these two pre-existing workflows.
- **This repo has no GitHub Advanced Security "Code scanning" feature
  available** (only Dependency graph / Dependabot) - the new
  `pr-docker-scan.yml` workflow uploads Trivy results as a plain build
  artifact instead of to the Security tab because of this; the same
  limitation likely affects any pre-existing SARIF uploads too.
- **`terraform fmt` drift** exists on `main` in `cloudfront.tf`,
  `environments/*.tfvars`, `lambda.tf`, `monitoring.tf`, and `waf.tf`.
- **`pytest-cov` is not installed**, so no real code coverage percentage
  currently exists for this project - don't cite one until it's actually run.

## What's Actually Covered

- Authentication: API key lookup, HMAC signature validation (real
  computation, not mocked), rate limiting
- Authorization: protected/admin endpoint permission checks
- Input validation: Pydantic model validation including the age boundary
  (`lt=150`, exclusive)
- Security headers presence on responses
- Cross-file test isolation (the shared `rate_limit_store` is now reset
  between tests via `conftest.py`, fixing a real cross-file pollution bug
  found during this session's verification work)

This is real, verified coverage of the application's auth and validation
logic. It is not a "production ready" claim - see Known Gaps above for what
that would still require (CI enforcement of these tests being the most
direct gap; the AWS/infrastructure items being separate, larger blockers).

---

## 🎓 Next Steps

1. **Wire the test suite into CI** - none of the existing workflows run it
2. **Install and run `pytest-cov`** to get a real coverage number
3. **Address the Known Gaps above**, roughly in order of severity: CI test
   enforcement, IAM wildcard policy, then the deploy/infrastructure items
4. Re-run `./scripts/validate-deployment.sh` once AWS access is restored

---

## 📚 Additional Resources

- **Code Standards**: `STANDARDS.md`
- **Deployment Guide**: `DEPLOYMENT.md`
- **Security Guide**: `SECURITY.md`

---

**Last Updated**: 2026-08-05
**Test Results**: 23/23 passing (verified directly, not assumed)
**Coverage**: Not currently measured (`pytest-cov` not installed)
**Production Ready**: Not a blanket claim - see "What's Actually Covered" and
"Known Gaps" above
