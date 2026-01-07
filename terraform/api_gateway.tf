# API Gateway HTTP API (v2) - Routes HTTP requests to Lambda
# Why HTTP API instead of REST API? It's 70% cheaper and simpler

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  
  # CORS configuration - allows frontend apps to call your API
  cors_configuration {
    allow_origins = ["*"]  # In production, specify exact domains
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300  # Browser caches CORS preflight for 5 minutes
  }
  
  description = "API Gateway for ${var.project_name} ${var.environment}"
}

# API Gateway Stage - Represents an environment (dev/staging/prod)
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true  # Automatically deploy changes
  
  # Access logs - record every request
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    
    # Log format - what information to capture
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
      integrationError = "$context.integrationErrorMessage"
    })
  }
  
  # Default route settings
  default_route_settings {
    throttling_burst_limit = 100   # Max concurrent requests
    throttling_rate_limit  = 50    # Max requests per second
  }
  
  tags = {
    Name = "${local.name_prefix}-stage"
  }
}

# API Gateway Integration - Connects API Gateway to Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"  # Pass everything to Lambda
  integration_method = "POST"
  integration_uri    = aws_lambda_function.app.invoke_arn
  
  # How long to wait for Lambda response
  timeout_milliseconds = 30000  # 30 seconds (Lambda max timeout)
  
  # Payload format version
  payload_format_version = "2.0"
}

# API Gateway Route - Catch-all route (forwards ALL requests to Lambda)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"  # Special key meaning "match everything"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name = "${local.name_prefix}-api-gateway-logs"
  }
}
```

**What This Does (Simple Explanation):**

1. **API Gateway**: Acts as the "front door" to your Lambda function
2. **Stage**: Represents your environment (dev/staging/prod)
3. **Integration**: Connects API Gateway → Lambda
4. **Route**: `$default` means "send ALL requests to Lambda" (Lambda handles routing)
5. **CORS**: Allows web browsers to call your API from different domains
6. **Throttling**: Protects your API from being overwhelmed (rate limiting)
7. **Access Logs**: Records every request for debugging and analytics

**Real-World Example:**
```
User visits: https://abc123.execute-api.us-east-1.amazonaws.com/prod/
                    ↓
            API Gateway receives request
                    ↓
            Forwards to Lambda function
                    ↓
            Lambda runs your Flask app
                    ↓
            Returns JSON response
                    ↓
            API Gateway sends response to user