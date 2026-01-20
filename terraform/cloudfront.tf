# CloudFront Distribution for API Gateway
# This enables WAF enforcement, edge caching, and DDoS protection

# Origin Access Control for API Gateway
resource "aws_cloudfront_origin_access_control" "api_gateway" {
  name                              = "${local.name_prefix}-api-oac"
  description                       = "Origin Access Control for API Gateway"
  origin_access_control_origin_type = "apigateway"
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
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }

    # Custom headers for API Gateway
    custom_header {
      name  = "X-CloudFront-Distribution"
      value = var.environment
    }
  }

  # --------------------------------------------------------------------------
  # Default Cache Behavior (API Endpoints)
  # --------------------------------------------------------------------------
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "api-gateway"
    compress         = true

    # 1. Cache Policy: Managed-CachingDisabled 
    # (Do not cache dynamic API responses)
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # 2. Origin Request Policy: Managed-AllViewerExceptHostHeader
    # (Pass all query strings, headers, and cookies to the backend)
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    # REMOVED: forwarded_values block (Conflicted with cache_policy_id)
  }

  # --------------------------------------------------------------------------
  # Health Check Behavior (Static content)
  # --------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/health"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "api-gateway"
    compress         = true

    # 1. Cache Policy: Managed-CachingOptimized
    # (Cache this content efficiently)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    viewer_protocol_policy = "redirect-to-https"
    # TTLs are controlled by the Policy, but these overrides are allowed if compatible
    min_ttl                = 0
    default_ttl            = 5
    max_ttl                = 10

    # REMOVED: forwarded_values block (Conflicted with cache_policy_id)
  }

  # Custom error responses
  custom_error_response {
    error_code
