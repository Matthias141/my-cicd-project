#!/bin/bash
# Setup S3 backend for Terraform state storage
# Run this once to create the S3 bucket and DynamoDB table

set -e

BUCKET_NAME="cicd-portfolio-terraform-state"
DYNAMODB_TABLE="cicd-portfolio-terraform-locks"
REGION="us-east-1"

echo "🚀 Setting up Terraform S3 backend..."
echo ""

# Create S3 bucket for state storage
echo "📦 Creating S3 bucket: ${BUCKET_NAME}"
aws s3api create-bucket \
    --bucket ${BUCKET_NAME} \
    --region ${REGION} \
    2>/dev/null || echo "  ⚠️  Bucket already exists (OK)"

# Enable versioning on the bucket
echo "🔄 Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled \
    --region ${REGION}

# Enable encryption on the bucket
echo "🔒 Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket ${BUCKET_NAME} \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --region ${REGION}

# Block public access
echo "🚫 Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region ${REGION}

# Create DynamoDB table for state locking
echo "🔐 Creating DynamoDB table: ${DYNAMODB_TABLE}"
aws dynamodb create-table \
    --table-name ${DYNAMODB_TABLE} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ${REGION} \
    2>/dev/null || echo "  ⚠️  Table already exists (OK)"

# Wait for table to be active
echo "⏳ Waiting for DynamoDB table to be active..."
aws dynamodb wait table-exists \
    --table-name ${DYNAMODB_TABLE} \
    --region ${REGION}

echo ""
echo "✅ Terraform backend setup complete!"
echo ""
echo "Backend Configuration:"
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  Region: ${REGION}"
echo "  Encryption: Enabled"
echo "  Versioning: Enabled"
echo ""
echo "🎉 You can now run Terraform with persistent state storage!"
