#!/bin/bash
set -e

# Deployment Validation Script
# Validates that all infrastructure and features are working correctly

ENVIRONMENT=${1:-dev}
API_URL=${2:-}

echo "=================================================="
echo "  DEPLOYMENT VALIDATION - $ENVIRONMENT Environment"
echo "=================================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name=$1
    local test_command=$2

    echo -n "Testing: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 1. Validate Terraform Configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. TERRAFORM VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd terraform

run_test "Terraform syntax validation" "terraform validate"
run_test "Terraform formatting check" "terraform fmt -check -recursive"

echo ""

# 2. Validate Python Code
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. PYTHON CODE VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd ..

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo -e "${YELLOW}⚠ pytest not installed, skipping tests${NC}"
else
    run_test "Unit tests" "pytest tests/test_*.py -v"
fi

# Check if flake8 is installed
if command -v flake8 &> /dev/null; then
    run_test "Flake8 linting" "flake8 app/ --max-line-length=120 --exclude=__pycache__"
else
    echo -e "${YELLOW}⚠ flake8 not installed, skipping linting${NC}"
fi

echo ""

# 3. Validate AWS Resources (if deployed)
if [ -n "$API_URL" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "3. AWS INFRASTRUCTURE VALIDATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    FUNCTION_NAME="cicd-portfolio-${ENVIRONMENT}-api"

    # Check Lambda function exists
    if aws lambda get-function --function-name $FUNCTION_NAME &> /dev/null; then
        echo -e "${GREEN}✓${NC} Lambda function exists: $FUNCTION_NAME"
        ((TESTS_PASSED++))

        # Check Lambda aliases exist
        for ALIAS in blue green live; do
            if aws lambda get-alias --function-name $FUNCTION_NAME --name $ALIAS &> /dev/null; then
                echo -e "${GREEN}✓${NC} Lambda alias exists: $ALIAS"
                ((TESTS_PASSED++))
            else
                echo -e "${RED}✗${NC} Lambda alias missing: $ALIAS"
                ((TESTS_FAILED++))
            fi
        done
    else
        echo -e "${RED}✗${NC} Lambda function not found: $FUNCTION_NAME"
        ((TESTS_FAILED++))
    fi

    # Check ECR repository
    REPO_NAME="cicd-portfolio-${ENVIRONMENT}-app"
    if aws ecr describe-repositories --repository-names $REPO_NAME &> /dev/null; then
        echo -e "${GREEN}✓${NC} ECR repository exists: $REPO_NAME"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} ECR repository not found: $REPO_NAME"
        ((TESTS_FAILED++))
    fi

    echo ""

    # 4. Validate API Endpoints
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "4. API ENDPOINT VALIDATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Test root endpoint
    run_test "Root endpoint (GET /)" "curl -sf -o /dev/null -w '%{http_code}' $API_URL | grep -q 200"

    # Test health endpoint
    run_test "Health endpoint (GET /$ENVIRONMENT/health)" "curl -sf -o /dev/null -w '%{http_code}' $API_URL/$ENVIRONMENT/health | grep -q 200"

    # Test home endpoint
    run_test "Home endpoint (GET /$ENVIRONMENT/)" "curl -sf -o /dev/null -w '%{http_code}' $API_URL/$ENVIRONMENT/ | grep -q 200"

    # Test items endpoint with pagination
    run_test "Items endpoint (GET /$ENVIRONMENT/items)" "curl -sf -o /dev/null -w '%{http_code}' '$API_URL/$ENVIRONMENT/items?page=1&limit=10' | grep -q 200"

    # Test validate endpoint with POST
    run_test "Validate endpoint (POST /$ENVIRONMENT/validate)" "curl -sf -X POST -H 'Content-Type: application/json' -d '{\"name\":\"Test\",\"email\":\"test@example.com\",\"age\":30,\"message\":\"test\"}' -o /dev/null -w '%{http_code}' $API_URL/$ENVIRONMENT/validate | grep -q 200"

    # Test protected endpoint without API key (should fail with 401)
    run_test "Protected endpoint without API key (should return 401)" "curl -sf -o /dev/null -w '%{http_code}' $API_URL/$ENVIRONMENT/protected | grep -q 401"

    echo ""

    # 5. Validate Security Features
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "5. SECURITY FEATURES VALIDATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Test security headers
    RESPONSE_HEADERS=$(curl -sI $API_URL/$ENVIRONMENT/)

    if echo "$RESPONSE_HEADERS" | grep -q "X-Frame-Options"; then
        echo -e "${GREEN}✓${NC} X-Frame-Options header present"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} X-Frame-Options header missing"
        ((TESTS_FAILED++))
    fi

    if echo "$RESPONSE_HEADERS" | grep -q "X-Content-Type-Options"; then
        echo -e "${GREEN}✓${NC} X-Content-Type-Options header present"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} X-Content-Type-Options header missing"
        ((TESTS_FAILED++))
    fi

    if echo "$RESPONSE_HEADERS" | grep -q "Content-Security-Policy"; then
        echo -e "${GREEN}✓${NC} Content-Security-Policy header present"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Content-Security-Policy header missing"
        ((TESTS_FAILED++))
    fi

    if echo "$RESPONSE_HEADERS" | grep -q "Strict-Transport-Security"; then
        echo -e "${GREEN}✓${NC} Strict-Transport-Security header present"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Strict-Transport-Security header missing"
        ((TESTS_FAILED++))
    fi

    # Check WAF Web ACL
    WAF_NAME="cicd-portfolio-${ENVIRONMENT}-waf"
    if aws wafv2 list-web-acls --scope REGIONAL --region us-east-1 | grep -q "$WAF_NAME"; then
        echo -e "${GREEN}✓${NC} WAF Web ACL exists"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} WAF Web ACL not found (may not be deployed yet)"
    fi

    echo ""

    # 6. Validate Monitoring
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "6. MONITORING & LOGGING VALIDATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check CloudWatch log group
    LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
    if aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP | grep -q $LOG_GROUP; then
        echo -e "${GREEN}✓${NC} CloudWatch log group exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} CloudWatch log group not found"
        ((TESTS_FAILED++))
    fi

    # Check CloudWatch alarms
    ALARM_PREFIX="cicd-portfolio-${ENVIRONMENT}"
    ALARM_COUNT=$(aws cloudwatch describe-alarms --alarm-name-prefix $ALARM_PREFIX --query 'length(MetricAlarms)' --output text)

    if [ "$ALARM_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} CloudWatch alarms configured ($ALARM_COUNT alarms)"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} No CloudWatch alarms found"
    fi

    # Check CloudWatch dashboard
    DASHBOARD_NAME="cicd-portfolio-${ENVIRONMENT}-dashboard"
    if aws cloudwatch list-dashboards | grep -q $DASHBOARD_NAME; then
        echo -e "${GREEN}✓${NC} CloudWatch dashboard exists"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} CloudWatch dashboard not found"
    fi

    echo ""
fi

# 7. Validate Blue-Green Deployment Setup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. BLUE-GREEN DEPLOYMENT VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "scripts/blue-green-deploy.sh" ]; then
    echo -e "${GREEN}✓${NC} Blue-green deployment script exists"
    ((TESTS_PASSED++))

    if [ -x "scripts/blue-green-deploy.sh" ]; then
        echo -e "${GREEN}✓${NC} Deployment script is executable"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Deployment script is not executable"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${RED}✗${NC} Blue-green deployment script not found"
    ((TESTS_FAILED++))
fi

if [ -f "terraform/lambda_aliases.tf" ]; then
    echo -e "${GREEN}✓${NC} Lambda aliases Terraform config exists"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Lambda aliases config not found"
    ((TESTS_FAILED++))
fi

echo ""

# 8. Validate Load Testing Setup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. LOAD TESTING VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "tests/load_test.py" ]; then
    echo -e "${GREEN}✓${NC} Locust load test script exists"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Load test script not found"
    ((TESTS_FAILED++))
fi

if [ -f ".github/workflows/load-test.yml" ]; then
    echo -e "${GREEN}✓${NC} Load test GitHub Actions workflow exists"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Load test workflow not found"
    ((TESTS_FAILED++))
fi

if [ -f "scripts/analyze-performance.py" ]; then
    echo -e "${GREEN}✓${NC} Performance analysis script exists"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Performance analysis script not found"
    ((TESTS_FAILED++))
fi

echo ""

# 9. Validate Documentation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. DOCUMENTATION VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

REQUIRED_DOCS=("README.md" "DEPLOYMENT.md" "SECURITY.md" "README_ADVANCED.md" "STANDARDS.md")

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}✓${NC} $doc exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $doc not found"
        ((TESTS_FAILED++))
    fi
done

echo ""

# Summary
echo "=================================================="
echo "  VALIDATION SUMMARY"
echo "=================================================="
echo ""
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
SUCCESS_RATE=$((TESTS_PASSED * 100 / TOTAL_TESTS))

echo "Success Rate: $SUCCESS_RATE%"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some validations failed. Please review the errors above.${NC}"
    exit 1
fi
