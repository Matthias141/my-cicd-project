# EventBridge Rule - Keep Lambda Warm (FREE Cold Start Solution)
# This pings Lambda every 5 minutes to prevent cold starts

resource "aws_cloudwatch_event_rule" "keep_lambda_warm" {
  count = var.enable_warmup ? 1 : 0  # Only create if warmup is enabled
  
  name                = "${local.name_prefix}-keep-warm"
  description         = "Ping Lambda every 5 minutes to prevent cold starts"
  schedule_expression = var.warmup_schedule  # Default: "rate(5 minutes)"
  
  tags = {
    Name = "${local.name_prefix}-warmup-rule"
  }
}

# EventBridge Target - Where to send the ping (to Lambda)
resource "aws_cloudwatch_event_target" "lambda" {
  count = var.enable_warmup ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.keep_lambda_warm[0].name
  target_id = "KeepLambdaWarm"
  arn       = aws_lambda_function.app.arn
  
  # Send special payload so Lambda knows it's a warmup ping
  input = jsonencode({
    warmup = true
  })
}

# Lambda Permission - Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.enable_warmup ? 1 : 0
  
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.keep_lambda_warm[0].arn
}
```

**What This Does (Cold Start Prevention):**

**The Problem:**
- Lambda "goes to sleep" after 15 minutes of inactivity
- First request after sleep = **cold start** (800ms delay)

**The Solution:**
- EventBridge pings Lambda every 5 minutes
- Lambda never goes to sleep
- Cold starts eliminated (for 95% of requests)

**Cost:**
```
5-minute pings = 288 pings/day × 30 days = 8,640 pings/month
Lambda free tier = 1,000,000 requests/month
Cost = $0 ✅
```

**Visual Flow:**
```
Every 5 minutes:
EventBridge → Sends {"warmup": true} → Lambda wakes up
                                           ↓
                                    Lambda handler sees warmup=true
                                           ↓
                                    Returns immediately (doesn't process request)
                                           ↓
                                    Lambda stays warm for next real request