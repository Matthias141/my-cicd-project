resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.name_prefix}-secrets"
  description = "Application secrets for ${var.project_name} ${var.environment}"
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    database_password = "changeme-in-production"
    api_key           = "changeme-in-production"
    jwt_secret        = "changeme-in-production"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
