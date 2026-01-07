# AWS Secrets Manager - Secure Storage for API Keys, Passwords, etc.

resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.name_prefix}-secrets"
  description = "Application secrets for ${var.project_name} ${var.environment}"
  
  # Automatically rotate secrets every 30 days (optional)
  # rotation_lambda_arn = aws_lambda_function.rotate_secret.arn
  # rotation_rules {
  #   automatically_after_days = 30
  # }
  
  tags = {
    Name = "${local.name_prefix}-secrets"
  }
}

# Secret Version - The actual secret values
resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  
  # Secret values in JSON format
  secret_string = jsonencode({
    database_password = "changeme-in-production"
    api_key          = "changeme-in-production"
    jwt_secret       = "changeme-in-production"
  })
  
  # Lifecycle - ignore changes (we'll update secrets manually in AWS Console)
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Output the secret ARN (not the actual values!)
output "secrets_manager_arn" {
  value       = aws_secretsmanager_secret.app_secrets.arn
  description = "ARN of Secrets Manager secret"
}