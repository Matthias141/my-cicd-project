# CloudWatch Log Group for Lambda Logs
# Every Lambda execution writes logs here

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.app.function_name}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name = "${local.name_prefix}-lambda-logs"
  }
}

# CloudWatch Metric Alarm - Cold Start Monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300  # 5 minutes
  statistic           = "Sum"
  threshold           = 5    # Alert if more than 5 errors in 5 minutes
  alarm_description   = "Alert when Lambda has multiple errors"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }
}

# CloudWatch Metric Alarm - Throttling
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name_prefix}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when Lambda is throttled (rate limited)"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }
}

# CloudWatch Metric Alarm - Duration (Slow Responses)
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.name_prefix}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2  # Must breach 2 times in a row
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 5000  # Alert if average duration > 5 seconds
  alarm_description   = "Alert when Lambda is running slow"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }
}

# CloudWatch Dashboard - Visual Monitoring
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: Lambda Invocations (How many requests)
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Invocations" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Invocations"
          dimensions = {
            FunctionName = aws_lambda_function.app.function_name
          }
        }
      },
      # Widget 2: Lambda Errors
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", { stat = "Sum", label = "Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Errors"
          dimensions = {
            FunctionName = aws_lambda_function.app.function_name
          }
        }
      },
      # Widget 3: Lambda Duration (Response time)
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { stat = "Average", label = "Avg Duration" }],
            ["...", { stat = "Maximum", label = "Max Duration" }]
          ]
          period = 300
          region = var.aws_region
          title  = "Lambda Duration (ms)"
          dimensions = {
            FunctionName = aws_lambda_function.app.function_name
          }
        }
      },
      # Widget 4: API Gateway Requests
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum", label = "API Requests" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "API Gateway Requests"
          dimensions = {
            ApiId = aws_apigatewayv2_api.main.id
          }
        }
      }
    ]
  })
}
```

**What This Does (Monitoring Explained):**

1. **Log Group**: Stores all Lambda execution logs (like a logbook)
2. **Alarms**: Automatic alerts when things go wrong
   - **Error Alarm**: Triggers if Lambda has 5+ errors in 5 minutes
   - **Throttle Alarm**: Triggers if requests are being rate-limited
   - **Duration Alarm**: Triggers if responses are slow (>5 seconds)
3. **Dashboard**: Visual graphs showing your app's health

**Real-World Example:**
```
Lambda executes → Writes to CloudWatch Logs
                     ↓
            If errors > 5 in 5 min
                     ↓
            Alarm triggers (could send email/SMS)
                     ↓
            You get notified and can debug