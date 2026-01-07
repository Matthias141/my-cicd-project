# Outputs - Information displayed after Terraform creates resources
# Think of these as "return values" from your infrastructure

output "api_gateway_url" {
  value       = aws_apigatewayv2_stage.main.invoke_url
  description = "URL to access your API"
}

output "lambda_function_name" {
  value       = aws_lambda_function.app.function_name
  description = "Name of the Lambda function"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.app.arn
  description = "ARN of the Lambda function"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "URL of the ECR repository (for pushing Docker images)"
}

output "cloudwatch_dashboard_url" {
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
  description = "URL to CloudWatch dashboard"
}

output "cloudwatch_log_group" {
  value       = aws_cloudwatch_log_group.lambda.name
  description = "CloudWatch log group for Lambda"
}

output "environment" {
  value       = var.environment
  description = "Environment name"
}
```

**What Outputs Do:**

After running `terraform apply`, you'll see:
```
Outputs:

api_gateway_url = "https://abc123.execute-api.us-east-1.amazonaws.com/prod"
lambda_function_name = "cicd-portfolio-prod-api"
ecr_repository_url = "123456789.dkr.ecr.us-east-1.amazonaws.com/cicd-portfolio-prod-app"
cloudwatch_dashboard_url = "https://console.aws.amazon.com/cloudwatch/..."
```

You can use these values in scripts or documentation.

---

## ✅ COMPLETE TERRAFORM STRUCTURE

You now have all the Terraform files:
```
terraform/
├── main.tf           ✅ Provider config, naming conventions
├── variables.tf      ✅ Input parameters
├── outputs.tf        ✅ Display important info
├── lambda.tf         ✅ Lambda function + ECR
├── api_gateway.tf    ✅ HTTP API routing
├── iam.tf            ✅ Security permissions
├── cloudwatch.tf     ✅ Monitoring + alarms
├── eventbridge.tf    ✅ Lambda warm-up system
└── secrets.tf        ✅ Secure secret storage