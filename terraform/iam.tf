# IAM Role for Lambda Execution
# IAM = Identity and Access Management (who can do what in AWS)

resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-execution"
  
  # Trust policy - WHO can assume this role
  # This says "Lambda service can use this role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name = "${local.name_prefix}-lambda-execution-role"
  }
}

# Policy: Basic Lambda Execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# This AWS-managed policy allows Lambda to:
# - Create CloudWatch log groups
# - Create CloudWatch log streams
# - Write logs to CloudWatch

# Policy: X-Ray Tracing (Distributed Tracing)
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
# This allows Lambda to send trace data to X-Ray for debugging

# Policy: VPC Access (if you later add VPC networking)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
# This allows Lambda to create network interfaces in a VPC

# Custom Policy: Access Secrets Manager
resource "aws_iam_policy" "lambda_secrets" {
  name        = "${local.name_prefix}-lambda-secrets"
  description = "Allow Lambda to read secrets from Secrets Manager"
  
  # WHAT this role can do
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.app_secrets.arn
      }
    ]
  })
}

# Attach the custom secrets policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_secrets.arn
}

# Custom Policy: Read from ECR (pull Docker images)
resource "aws_iam_policy" "lambda_ecr" {
  name        = "${local.name_prefix}-lambda-ecr"
  description = "Allow Lambda to pull images from ECR"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach ECR policy
resource "aws_iam_role_policy_attachment" "lambda_ecr" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_ecr.arn
}