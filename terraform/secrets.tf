resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.name_prefix}-secrets"
  description = "Application secrets for ${var.project_name} ${var.environment}"
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    database_password = var.database_password
    api_key           = var.api_key
    jwt_secret        = var.jwt_secret
  })
}
