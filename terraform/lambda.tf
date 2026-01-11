resource "aws_lambda_function" "app" {
  function_name = "${local.name_prefix}-api"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.app.repository_url}:latest"
  
  # UPDATED: Matches the "linux/amd64" docker build we did earlier
  architectures = ["x86_64"]
  
  memory_size   = var.lambda_memory
  timeout       = var.lambda_timeout

  environment {
    variables = {
      ENVIRONMENT = var.environment
      APP_VERSION = "terraform-managed"
      # AWS_REGION removed - Lambda sets this automatically
      LOG_LEVEL = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }

  tracing_config {
    mode = "Active"
  }

  # UPDATED: Commented out to prevent the "UnreservedConcurrentExecution" error
  # reserved_concurrent_executions = var.environment == "prod" ? 10 : 5

  lifecycle {
    ignore_changes = [image_uri]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs
  ]
}
