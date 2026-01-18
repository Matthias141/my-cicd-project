#!/bin/bash
# Quick cleanup of staging resources
# Run this locally to clean up orphaned resources, then deploy fresh

set -e

ENVIRONMENT="staging"
PROJECT_NAME="cicd-portfolio"
REGION="us-east-1"

echo "🧹 Quick cleanup of ${ENVIRONMENT} resources..."
echo ""

# Delete CloudWatch Log Groups
echo "Deleting CloudWatch Log Groups..."
aws logs delete-log-group --log-group-name "/aws/apigateway/${PROJECT_NAME}-${ENVIRONMENT}" --region ${REGION} 2>/dev/null || echo "  ⊘ Not found"
aws logs delete-log-group --log-group-name "/aws/lambda/${PROJECT_NAME}-${ENVIRONMENT}-api" --region ${REGION} 2>/dev/null || echo "  ⊘ Not found"
aws logs delete-log-group --log-group-name "/aws/waf/${PROJECT_NAME}-${ENVIRONMENT}" --region ${REGION} 2>/dev/null || echo "  ⊘ Not found"

# Delete Secrets (force delete)
echo "Deleting Secrets..."
aws secretsmanager delete-secret --secret-id "${PROJECT_NAME}-${ENVIRONMENT}-secrets" --force-delete-without-recovery --region ${REGION} 2>/dev/null || echo "  ⊘ Not found"

# Delete IAM Role (detach policies first)
echo "Deleting IAM Role..."
ROLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-lambda-execution"
for policy in $(aws iam list-attached-role-policies --role-name ${ROLE_NAME} --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
  aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn ${policy} 2>/dev/null
done
aws iam delete-role --role-name ${ROLE_NAME} --region ${REGION} 2>/dev/null || echo "  ⊘ Not found"

# Delete WAF
echo "Deleting WAF..."
WAF_ID=$(aws wafv2 list-web-acls --scope REGIONAL --region ${REGION} --query "WebACLs[?Name=='${PROJECT_NAME}-${ENVIRONMENT}-waf'].Id" --output text 2>/dev/null)
if [ -n "$WAF_ID" ]; then
  WAF_ARN=$(aws wafv2 list-web-acls --scope REGIONAL --region ${REGION} --query "WebACLs[?Name=='${PROJECT_NAME}-${ENVIRONMENT}-waf'].ARN" --output text)
  aws wafv2 delete-web-acl --id ${WAF_ID} --name "${PROJECT_NAME}-${ENVIRONMENT}-waf" --scope REGIONAL --lock-token $(aws wafv2 get-web-acl --id ${WAF_ID} --name "${PROJECT_NAME}-${ENVIRONMENT}-waf" --scope REGIONAL --query 'LockToken' --output text) --region ${REGION} 2>/dev/null || echo "  ⊘ Could not delete"
else
  echo "  ⊘ WAF not found"
fi

echo ""
echo "✅ Cleanup complete!"
echo "🚀 Now run: GitHub Actions → Terraform Deploy Infrastructure → staging → apply"
