# ECR Repository - Where we store Docker images
# ECR = Elastic Container Registry (like Docker Hub, but private and AWS-native)

resource "aws_ecr_repository" "app" {
  name                 = "${local.name_prefix}-app"
  image_tag_mutability = "MUTABLE"  # Allow overwriting tags (useful for 'latest')
  
  # Scan images for security vulnerabilities
  image_scanning_configuration {
    scan_on_push = true  # Automatic scan when you push an image
  }
  
  # Delete old images to save storage costs
  # Keep only last 5 images
  lifecycle {
    prevent_destroy = false  # Allow deletion (set true in production)
  }
}

# ECR Lifecycle Policy - Automatically delete old images
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lambda Function - The serverless compute
resource "aws_lambda_function" "app" {
  function_name = "${local.name_prefix}-api"
  role          = aws_iam_role.lambda_execution.arn
  
  # Package type - we're using container images (not zip files)
  package_type = "Image"
  
  # Docker image location
  # This will be updated by CI/CD pipeline with actual image
  image_uri = "${aws_ecr_repository.app.repository_url}:latest"
  
  # ARM64 = AWS Graviton2 processors (20% faster, 20% cheaper)
  architectures = ["arm64"]
  
  # Memory allocation (more memory = more CPU)
  memory_size = var.lambda_memory
  
  # Maximum execution time
  timeout = var.lambda_timeout
  
  # Environment variables passed to your application
  environment {
    variables = {
      ENVIRONMENT  = var.environment
      APP_VERSION  = "terraform-managed"
      AWS_REGION   = var.aws_region
      LOG_LEVEL    = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }
  
  # Enable AWS X-Ray tracing (distributed tracing for debugging)
  tracing_config {
    mode = "Active"
  }
  
  # Reserved concurrent executions (limits max instances)
  # Prevents runaway costs if something goes wrong
  reserved_concurrent_executions = var.environment == "prod" ? 10 : 5
  
  # Lifecycle rule - ignore image changes (CI/CD will update this)
  lifecycle {
    ignore_changes = [image_uri]
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

# Lambda Alias - Points to a specific version
# Used for blue/green deployments
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.app.function_name
  function_version = aws_lambda_function.app.version
  
  lifecycle {
    ignore_changes = [function_version]
  }
}

# Provisioned Concurrency - Keep Lambda warm (COSTS MONEY)
# Only created if var.enable_provisioned_concurrency = true
resource "aws_lambda_provisioned_concurrency_config" "app" {
  count = var.enable_provisioned_concurrency ? 1 : 0
  
  function_name                     = aws_lambda_function.app.function_name
  provisioned_concurrent_executions = var.provisioned_concurrent_executions
  qualifier                         = aws_lambda_alias.live.name
}

# Lambda Permission - Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}