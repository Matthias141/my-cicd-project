# CloudFront Distribution for API Gateway
# This enables WAF enforcement, edge caching, and DDoS protection

# Origin Access Control for API Gateway
resource "aws_cloudfront_origin_access_control" "api_gateway" {
  name                              = "${local.name_prefix}-api-oac"
  description                       = "Origin Access Control for API Gateway"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "api" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} API distribution"
  price_class         = "PriceClass_100" # Use only North America and Europe
  http_version        = "http2and3"
  wait_for_deployment = false

  # Origin: API Gateway
  origin {
    domain_name = replace(aws_apigatewayv2_api.main.api_endpoint, "https://", "")
    origin_id   = "api-gateway"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 5
    }

    # Custom headers for API Gateway
    custom_header {
      name  = "X-CloudFront-Distribution"
      value = var.environment
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "api-gateway"
    compress         = true

    # Use Managed-CachingDisabled policy (no caching for API)
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # Use Managed-AllViewerExceptHostHeader origin request policy
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    # Forward all headers to API Gateway (needed for API functionality)
    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }
  }

  # Health check endpoint with shorter cache
  ordered_cache_behavior {
    path_pattern     = "/health"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "api-gateway"
    compress         = true

    # Use Managed-CachingOptimized policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 5   # Cache health checks for 5 seconds
    max_ttl                = 10

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }
  }

  # Custom error responses
  custom_error_response {
    error_code            = 403
    response_code         = 403
    response_page_path    = "/error"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 500
    response_code         = 500
    response_page_path    = "/error"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 502
    response_code         = 502
    response_page_path    = "/error"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 503
    response_code         = 503
    response_page_path    = "/error"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 504
    response_code         = 504
    response_page_path    = "/error"
    error_caching_min_ttl = 0
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
      # Can be changed to "whitelist" or "blacklist" for geo-restrictions
    }
  }

  # SSL Certificate (using default CloudFront certificate)
  # For custom domain, replace with ACM certificate
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  # Logging configuration (optional)
  # logging_config {
  #   include_cookies = false
  #   bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
  #   prefix          = "cloudfront-logs/"
  # }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cloudfront"
    }
  )
}

# Associate WAF with CloudFront
resource "aws_wafv2_web_acl_association" "cloudfront" {
  resource_arn = aws_cloudfront_distribution.api.arn
  web_acl_arn  = aws_wafv2_web_acl.api_waf.arn
}

# CloudWatch Log Group for CloudFront access logs (optional, for detailed logging)
resource "aws_cloudwatch_log_group" "cloudfront_logs" {
  name              = "/aws/cloudfront/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# Outputs
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.api.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.api.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (use this for API access)"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "cloudfront_distribution_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}
