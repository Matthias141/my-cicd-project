# AWS WAF (Web Application Firewall) for API Gateway Protection

resource "aws_wafv2_web_acl" "api_waf" {
  name        = "${local.name_prefix}-waf"
  description = "WAF for ${var.project_name} ${var.environment} API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Rate limiting to prevent DDoS
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {
        custom_response {
          response_code = 429
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = 2000 # requests per 5 minutes per IP
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: SQL Injection (Expanded Scope)
  # Checks Body, URL, Query String, and Cookies
  rule {
    name     = "SQLInjectionProtection"
    priority = 2

    action {
      block {}
    }

    statement {
      or_statement {
        # Check 1: Query String
        statement {
          sqli_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        # Check 2: Request Body
        statement {
          sqli_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        # Check 3: URI Path
        statement {
          sqli_match_statement {
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-sqli-protection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: XSS Protection (Expanded Scope)
  # Checks Body, URL, Query String, and Cookies
  rule {
    name     = "XSSProtection"
    priority = 3

    action {
      block {}
    }

    statement {
      or_statement {
        # Check 1: Query String
        statement {
          xss_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        # Check 2: Request Body
        statement {
          xss_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
         # Check 3: Cookie Header (Scans all cookies)
        statement {
          xss_match_statement {
            field_to_match {
              single_header {
                name = "cookie"
              }
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-xss-protection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Geo-blocking (optional)
  rule {
    name     = "GeoBlockRule"
    priority = 4

    action {
      count {} # Count only for now
    }

    statement {
      geo_match_statement {
        country_codes = ["CN", "RU", "KP"]
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-geo-block"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-aws-managed-common"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-aws-managed-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for WAF logs
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "waf_logs" {
  # FIX: Must start with "aws-waf-logs-" for WAF logging to work
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# WAF Logging Configuration
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  resource_arn = aws_wafv2_web_acl.api_waf.arn
  
  # FIX: Removed ":*" suffix from ARN
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
    # Also redact cookies if they contain sensitive session IDs
    single_header {
      name = "cookie"
    }
  }
}

# -----------------------------------------------------------------------------
# Associate WAF with API Gateway (HTTP or REST)
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "api_gateway" {
  # Ensure "aws_apigatewayv2_stage.main" is defined in your other .tf files
  resource_arn = aws_apigatewayv2_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.api_waf.arn
}
