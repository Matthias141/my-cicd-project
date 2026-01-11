output "api_gateway_url" {
  value       = aws_apigatewayv2_stage.main.invoke_url
  description = "API Gateway URL"
}

output "lambda_function_name" {
  value       = aws_lambda_function.app.function_name
  description = "Lambda function name"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.app.arn
  description = "Lambda function ARN"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "ECR repository URL"
}

output "cloudwatch_dashboard_url" {
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
  description = "CloudWatch dashboard URL"
}

output "cloudwatch_log_group" {
  value       = aws_cloudwatch_log_group.lambda.name
  description = "CloudWatch log group"
}

output "environment" {
  value       = var.environment
  description = "Environment name"
}

output "secrets_manager_arn" {
  value       = aws_secretsmanager_secret.app_secrets.arn
  description = "Secrets Manager ARN"
}
