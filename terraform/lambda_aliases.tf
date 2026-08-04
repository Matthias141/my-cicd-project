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
  function_version = "$LATEST"

  # NOTE: routing_config is omitted initially because it requires actual version numbers (1, 2, 3...)
  # $LATEST cannot be used in routing_config.additional_version_weights
  # The deployment workflow will add routing configuration dynamically via AWS CLI
  # when performing canary deployments with real version numbers

  lifecycle {
    ignore_changes = [function_version, routing_config]
  }
}

# -----------------------------------------------------------------------------
# Provisioned Concurrency (cold-start mitigation)
# -----------------------------------------------------------------------------
# Gated on enable_provisioned_concurrency (variables.tf) - not forced on for
# every environment; prod.tfvars/staging.tfvars set it true, dev does not.
#
# Targets the "live" alias specifically, not blue/green: live is the only
# alias api_gateway.tf's Lambda integration actually routes real traffic to
# (see integration_uri = aws_lambda_alias.live.invoke_arn). blue/green exist
# purely as deployment-process bookkeeping for the canary script; there's no
# traffic hitting them directly to warm.
#
# NOTE: AWS requires the target alias to point at a real published version
# number, not $LATEST. live.function_version starts as "$LATEST" above and
# is deliberately left unmanaged by Terraform after that (lifecycle.
# ignore_changes) - the blue-green deployment workflow is what actually
# pins it to a numbered version out-of-band via the AWS CLI. This resource
# is therefore only apply-able once that first deployment has run and "live"
# is pointing at a real version; it cannot be applied against a freshly
# created Lambda function that's still on $LATEST. Not tested against live
# AWS here (account pending) - validated for HCL correctness only.
resource "aws_lambda_provisioned_concurrency_config" "live" {
  count = var.enable_provisioned_concurrency ? 1 : 0

  function_name                     = aws_lambda_function.app.function_name
  qualifier                         = aws_lambda_alias.live.name
  provisioned_concurrent_executions = var.provisioned_concurrent_executions
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
