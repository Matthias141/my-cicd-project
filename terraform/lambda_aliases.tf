# Lambda Aliases for Blue-Green Deployment and Canary Releases
# Note: Lambda function versioning is enabled in lambda.tf with publish = true

# BLUE Alias - Current stable version
resource "aws_lambda_alias" "blue" {
  name             = "blue"
  description      = "Stable production version (blue)"
  function_name    = aws_lambda_function.app.function_name
  function_version = "$LATEST"  # Will be updated by deployment script

  lifecycle {
    ignore_changes = [function_version]
  }
}

# GREEN Alias - New version being deployed
resource "aws_lambda_alias" "green" {
  name             = "green"
  description      = "New version being deployed (green)"
  function_name    = aws_lambda_function.app.function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

# LIVE Alias - Production traffic (points to blue or uses weighted routing)
resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Production traffic endpoint"
  function_name    = aws_lambda_function.app.function_name
  function_version = aws_lambda_alias.blue.function_version

  # Routing configuration for canary deployments
  # This allows gradual traffic shifting from blue to green
  routing_config {
    additional_version_weights = {
      # Initially, green gets 0% traffic
      # Deployment script will update this to 10%, 25%, 50%, 100%
      (aws_lambda_alias.green.function_version) = 0.0
    }
  }

  lifecycle {
    ignore_changes = [function_version, routing_config]
  }
}

# CloudWatch Alarm for Green Version Health Check
resource "aws_cloudwatch_metric_alarm" "green_version_errors" {
  alarm_name          = "${local.name_prefix}-green-version-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"  # 1 minute
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Errors in green version - trigger rollback"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName    = aws_lambda_function.app.function_name
    ExecutedVersion = aws_lambda_alias.green.function_version
  }

  tags = local.common_tags
}

# Outputs for deployment scripts
output "blue_alias_name" {
  description = "Blue alias name"
  value       = aws_lambda_alias.blue.name
}

output "green_alias_name" {
  description = "Green alias name"
  value       = aws_lambda_alias.green.name
}

output "live_alias_name" {
  description = "Live alias name"
  value       = aws_lambda_alias.live.name
}
