#!/bin/bash
# Import existing AWS resources into Terraform state
# This makes the deployment idempotent - it won't fail if resources already exist

set +e  # Don't exit on errors

ENVIRONMENT="$1"
PROJECT_NAME="cicd-portfolio"
REGION="${AWS_REGION:-us-east-1}"
NAME_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"

echo "🔍 Checking for existing resources in AWS for environment: ${ENVIRONMENT}"
echo ""

# Function to import a resource if it exists
import_if_exists() {
    local resource_type=$1
    local resource_name=$2
    local resource_id=$3

    echo -n "  Checking ${resource_type}.${resource_name}... "

    # Check if already in state
    terraform state show "${resource_type}.${resource_name}" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Already in state"
        return 0
    fi

    # Try to import
    terraform import "${resource_type}.${resource_name}" "${resource_id}" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Imported"
        return 0
    else
        echo "⊘ Not found (will be created)"
        return 1
    fi
}

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📦 Attempting to import existing resources..."
echo ""

# Import CloudWatch Log Groups
import_if_exists "aws_cloudwatch_log_group" "api_gateway" "/aws/apigateway/${NAME_PREFIX}"
import_if_exists "aws_cloudwatch_log_group" "lambda_logs" "/aws/lambda/${NAME_PREFIX}-api"
import_if_exists "aws_cloudwatch_log_group" "waf_logs" "/aws/waf/${NAME_PREFIX}"

# Import ECR Repository
import_if_exists "aws_ecr_repository" "app" "${NAME_PREFIX}-app"

# Import IAM Role
import_if_exists "aws_iam_role" "lambda_execution" "${NAME_PREFIX}-lambda-execution"

# Import Secrets Manager Secret
import_if_exists "aws_secretsmanager_secret" "app_secrets" "${NAME_PREFIX}-secrets"

# Import SNS Topic (need to get ARN first)
SNS_TOPIC_ARN=$(aws sns list-topics --region ${REGION} --query "Topics[?contains(TopicArn, '${NAME_PREFIX}-alerts')].TopicArn" --output text 2>/dev/null)
if [ -n "$SNS_TOPIC_ARN" ]; then
    import_if_exists "aws_sns_topic" "alerts" "${SNS_TOPIC_ARN}"
fi

# Import EventBridge Rule
import_if_exists "aws_cloudwatch_event_rule" "keep_lambda_warm[0]" "${NAME_PREFIX}-keep-warm"

# Import WAF WebACL (need to get ID and ARN)
WAF_ID=$(aws wafv2 list-web-acls --scope REGIONAL --region ${REGION} --query "WebACLs[?Name=='${NAME_PREFIX}-waf'].Id" --output text 2>/dev/null)
if [ -n "$WAF_ID" ]; then
    WAF_ARN="arn:aws:wafv2:${REGION}:${ACCOUNT_ID}:regional/webacl/${NAME_PREFIX}-waf/${WAF_ID}"
    import_if_exists "aws_wafv2_web_acl" "api_waf" "${WAF_ARN}"
fi

# Import API Gateway (need to get ID first)
API_ID=$(aws apigatewayv2 get-apis --region ${REGION} --query "Items[?Name=='${NAME_PREFIX}-api'].ApiId" --output text 2>/dev/null)
if [ -n "$API_ID" ]; then
    import_if_exists "aws_apigatewayv2_api" "main" "${API_ID}"

    # Import API Gateway Stage
    import_if_exists "aws_apigatewayv2_stage" "main" "${API_ID}/${ENVIRONMENT}"

    # Import API Gateway Integration
    INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id ${API_ID} --region ${REGION} --query "Items[0].IntegrationId" --output text 2>/dev/null)
    if [ -n "$INTEGRATION_ID" ]; then
        import_if_exists "aws_apigatewayv2_integration" "lambda" "${API_ID}/${INTEGRATION_ID}"
    fi

    # Import API Gateway Route
    ROUTE_ID=$(aws apigatewayv2 get-routes --api-id ${API_ID} --region ${REGION} --query "Items[0].RouteId" --output text 2>/dev/null)
    if [ -n "$ROUTE_ID" ]; then
        import_if_exists "aws_apigatewayv2_route" "lambda" "${API_ID}/${ROUTE_ID}"
    fi
fi

# Import Lambda Function
LAMBDA_NAME="${NAME_PREFIX}-api"
import_if_exists "aws_lambda_function" "main" "${LAMBDA_NAME}"

# Import Lambda Aliases
import_if_exists "aws_lambda_alias" "blue[0]" "${LAMBDA_NAME}:blue"
import_if_exists "aws_lambda_alias" "green[0]" "${LAMBDA_NAME}:green"
import_if_exists "aws_lambda_alias" "live[0]" "${LAMBDA_NAME}:live"

echo ""
echo "✅ Import complete! Terraform will now manage existing resources."
echo ""
