# CODE STANDARDS

## Python Code Standards

### Code Quality
- Always use type hints for function parameters and return values
- Follow PEP 8 style guide strictly
- Keep functions under 50 lines, break into smaller units if longer
- Use named imports, not wildcard imports (`from module import *`)
- Never commit without running linters and formatters first

### Testing Requirements
- Write tests for every new feature before marking task complete
- Run `pytest` after any changes to verify nothing breaks
- Never skip error handling, always wrap risky operations in try/except
- Minimum 80% code coverage for production code
- Test both success and failure paths

### Security
- Never hardcode secrets, credentials, or API keys in code
- Always validate user input using Pydantic models
- Use parameterized queries for database operations (prevent SQL injection)
- Implement rate limiting for all public endpoints
- Log security-relevant events (auth failures, suspicious activity)

### Git Workflow
- Branch names must follow pattern: `feature/description` or `fix/description`
- Commit messages must be descriptive, not generic ("fix bug" is not acceptable)
- Always run linter/formatter before committing: `black . && flake8`
- Never commit directly to `main` branch
- All changes must go through pull requests

### Common Mistakes to Avoid
- Do NOT use `any` type in type hints, use proper types or `Union`
- Do NOT modify production code without corresponding tests
- Do NOT install new dependencies without discussing alternatives first
- Do NOT expose stack traces in API responses (security risk)
- Do NOT use print() for logging, use proper logging module

## Terraform Standards

### Infrastructure as Code
- Always use variables for configurable values, never hardcode
- Each resource must have meaningful tags (environment, project, managed-by)
- Use `locals` for computed values and DRY principles
- Name resources using consistent pattern: `${var.project_name}-${var.environment}-${resource_type}`
- Always include descriptions for variables and outputs

### Security Best Practices
- Never commit terraform.tfstate files (add to .gitignore)
- Use AWS Secrets Manager for sensitive data, not variables
- Enable encryption for all data at rest (S3, RDS, EBS)
- Implement least-privilege IAM policies
- Use security groups with minimal required access

### Deployment
- Always run `terraform plan` before `terraform apply`
- Review plan output carefully before applying changes
- Use `-var-file` for environment-specific configurations
- Tag infrastructure releases with git tags
- Document infrastructure changes in PR descriptions

### Testing
- Validate Terraform code: `terraform validate`
- Format code: `terraform fmt -recursive`
- Check for security issues: `tfsec .`
- Run `terraform plan` in CI/CD before merge

## API Conventions

### REST Endpoints
- Use proper HTTP methods (GET for reads, POST for creates, PUT/PATCH for updates, DELETE for deletes)
- Return appropriate status codes (200, 201, 400, 401, 403, 404, 500)
- Always include error messages in responses: `{"error": "description", "code": "ERROR_CODE"}`
- Use versioning for breaking changes (e.g., `/api/v1/`, `/api/v2/`)

### Request/Response Format
- All requests and responses must be JSON
- Use camelCase for JSON keys (for consistency with frontend)
- Include metadata in paginated responses (total, page, per_page)
- Validate all request bodies using Pydantic models

### Authentication
- Use API keys in headers: `X-API-Key: <key>`
- Implement HMAC signatures for sensitive operations
- Return 401 for authentication failures
- Return 403 for authorization failures (authenticated but no permission)

## Documentation

### Code Documentation
- Add docstrings to all public functions and classes
- Use Google-style docstrings format
- Document parameters, return values, and exceptions
- Include usage examples for complex functions

```python
def calculate_total(items: list[dict], tax_rate: float) -> float:
    """
    Calculate total cost including tax.

    Args:
        items: List of item dictionaries with 'price' and 'quantity' keys
        tax_rate: Tax rate as decimal (e.g., 0.08 for 8%)

    Returns:
        Total cost including tax

    Raises:
        ValueError: If tax_rate is negative

    Example:
        >>> items = [{'price': 10.00, 'quantity': 2}]
        >>> calculate_total(items, 0.08)
        21.60
    """
    if tax_rate < 0:
        raise ValueError("Tax rate cannot be negative")

    subtotal = sum(item['price'] * item['quantity'] for item in items)
    return subtotal * (1 + tax_rate)
```

### Infrastructure Documentation
- Update README.md if you add new environment variables
- Document all Terraform modules with usage examples
- Update architecture diagrams for significant structural changes
- Maintain DEPLOYMENT.md with deployment procedures

## Performance Rules

### Application Performance
- Cache expensive computations (use Redis or in-memory cache)
- Use database indexes for frequently queried fields
- Implement pagination for large data sets
- Lazy load resources that aren't immediately needed
- Monitor Lambda cold starts and optimize package size

### Cost Optimization
- Use appropriate Lambda memory settings (don't over-provision)
- Implement CloudWatch log retention policies
- Clean up unused ECR images periodically
- Use reserved capacity for predictable workloads
- Monitor AWS costs with billing alarms

## CI/CD Standards

### Pipeline Requirements
- All tests must pass before merge
- Security scans must complete (no CRITICAL vulnerabilities)
- Terraform plan must succeed before infrastructure changes
- Docker images must be scanned with Trivy
- Deployment must be reversible (support rollback)

### Environment Promotion
- Dev → Automatic deployment on merge to main
- Staging → Automatic with security scans and smoke tests
- Prod → Manual approval + blue-green deployment + monitoring

## Monitoring and Logging

### Logging Standards
- Use structured logging (JSON format)
- Include correlation IDs for request tracing
- Log levels: DEBUG (dev only), INFO, WARNING, ERROR, CRITICAL
- Never log sensitive data (passwords, API keys, PII)
- Include context (user_id, request_id, timestamp)

```python
import logging
import json

logger = logging.getLogger(__name__)

def process_payment(user_id: str, amount: float):
    logger.info(json.dumps({
        'event': 'payment_processing',
        'user_id': user_id,
        'amount': amount,
        'timestamp': time.time()
    }))
```

### Monitoring
- Set up CloudWatch alarms for critical metrics
- Monitor Lambda errors, throttles, and duration
- Track API Gateway 4xx and 5xx errors
- Alert on WAF blocked requests spike
- Dashboard for real-time system health

## When Stuck

### Troubleshooting Steps
1. Check CloudWatch logs first (most issues show up in logs)
2. Search existing closed issues in GitHub before asking
3. Run tests in isolation to identify the failing component
4. Use `terraform plan` to see what infrastructure changes will occur
5. If adding a workaround, document why with a TODO comment

### Getting Help
- Include full error messages and stack traces
- Provide steps to reproduce the issue
- Share relevant code snippets (sanitize secrets first!)
- Mention what you've already tried
- Check DEPLOYMENT.md troubleshooting section

## Code Review Checklist

Before submitting a PR, verify:
- [ ] All tests pass (`pytest`)
- [ ] Code is formatted (`black . && flake8`)
- [ ] Type hints are present
- [ ] Security headers are set for new endpoints
- [ ] Documentation is updated (README, DEPLOYMENT, etc.)
- [ ] Terraform is validated (`terraform validate && terraform fmt`)
- [ ] No secrets or credentials in code
- [ ] Error handling is implemented
- [ ] Logging is added for important operations
- [ ] Performance impact is considered

## Example: Good vs Bad

### ❌ Bad Code
```python
def get_user(id):  # No type hints
    # No error handling
    data = requests.get(f"https://api.example.com/users/{id}")  # Vulnerable to injection
    return data.json()  # No validation
```

### ✅ Good Code
```python
from typing import Optional
import requests
from pydantic import BaseModel

class User(BaseModel):
    id: int
    name: str
    email: str

def get_user(user_id: int) -> Optional[User]:
    """
    Fetch user by ID from external API.

    Args:
        user_id: Unique user identifier

    Returns:
        User object if found, None otherwise

    Raises:
        requests.RequestException: If API request fails
    """
    try:
        response = requests.get(
            "https://api.example.com/users",
            params={"id": user_id},  # Parameterized, prevents injection
            timeout=5
        )
        response.raise_for_status()

        # Validate response with Pydantic
        user_data = response.json()
        return User(**user_data)

    except requests.RequestException as e:
        logger.error(f"Failed to fetch user {user_id}: {e}")
        return None
    except ValidationError as e:
        logger.error(f"Invalid user data for {user_id}: {e}")
        return None
```

---

**Last Updated**: 2026-01-18
**Version**: 1.0
**Maintained By**: DevOps Team
