#!/bin/bash
# Cleanup script for partial staging deployment resources
# Run this when Terraform reports "resource already exists" errors

set -e

ENVIRONMENT="staging"
PROJECT_NAME="cicd-portfolio"
REGION="us-east-1"

echo "🧹 Cleaning up partial ${ENVIRONMENT} deployment resources..."
echo "⚠️  This will delete resources that were partially created during failed deployments"
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Delete CloudWatch Log Groups
echo "Deleting CloudWatch Log Groups..."
aws logs delete-log-group \
    --log-group-name "/aws/apigateway/${PROJECT_NAME}-${ENVIRONMENT}" \
    --region ${REGION} 2>/dev/null || echo "  ⚠️  Log group /aws/apigateway/${PROJECT_NAME}-${ENVIRONMENT} not found (OK)"

aws logs delete-log-group \
    --log-group-name "/aws/lambda/${PROJECT_NAME}-${ENVIRONMENT}-api" \
    --region ${REGION} 2>/dev/null || echo "  ⚠️  Log group /aws/lambda/${PROJECT_NAME}-${ENVIRONMENT}-api not found (OK)"

aws logs delete-log-group \
    --log-group-name "/aws/waf/${PROJECT_NAME}-${ENVIRONMENT}" \
    --region ${REGION} 2>/dev/null || echo "  ⚠️  Log group /aws/waf/${PROJECT_NAME}-${ENVIRONMENT} not found (OK)"

# Delete Secrets Manager Secret (force delete)
echo "Deleting Secrets Manager Secret..."
aws secretsmanager delete-secret \
    --secret-id "${PROJECT_NAME}-${ENVIRONMENT}-secrets" \
    --force-delete-without-recovery \
    --region ${REGION} 2>/dev/null || echo "  ⚠️  Secret ${PROJECT_NAME}-${ENVIRONMENT}-secrets not found (OK)"

# Detach policies from IAM role before deletion
echo "Deleting IAM Role..."
ROLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-lambda-execution"
aws iam list-attached-role-policies --role-name ${ROLE_NAME} --region ${REGION} 2>/dev/null | \
    jq -r '.AttachedPolicies[].PolicyArn' | \
    while read policy_arn; do
        echo "  Detaching policy: ${policy_arn}"
        aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn ${policy_arn} --region ${REGION} 2>/dev/null || true
    done

aws iam delete-role \
    --role-name ${ROLE_NAME} \
    --region ${REGION} 2>/dev/null || echo "  ⚠️  IAM role ${ROLE_NAME} not found (OK)"

# Note: ECR repository is NOT deleted to preserve Docker images
echo ""
echo "✅ Cleanup complete!"
echo ""
echo "⚠️  NOTE: ECR repository '${PROJECT_NAME}-${ENVIRONMENT}-app' was NOT deleted"
echo "   This preserves your Docker images. If you want to delete it, run:"
echo "   aws ecr delete-repository --repository-name ${PROJECT_NAME}-${ENVIRONMENT}-app --force --region ${REGION}"
echo ""
echo "🚀 You can now re-run: Terraform Deploy Infrastructure → environment=${ENVIRONMENT}, action=apply"
