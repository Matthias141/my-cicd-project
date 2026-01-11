resource "aws_cloudwatch_event_rule" "keep_lambda_warm" {
  count = var.enable_warmup ? 1 : 0

  name                = "${local.name_prefix}-keep-warm"
  description         = "Ping Lambda every 5 minutes to prevent cold starts"
  schedule_expression = var.warmup_schedule
}

resource "aws_cloudwatch_event_target" "lambda" {
  count = var.enable_warmup ? 1 : 0

  rule      = aws_cloudwatch_event_rule.keep_lambda_warm[0].name
  target_id = "KeepLambdaWarm"
  arn       = aws_lambda_function.app.arn

  input = jsonencode({
    warmup = true
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.enable_warmup ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.keep_lambda_warm[0].arn
}
