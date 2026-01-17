# Production Environment Configuration
environment = "prod"

# Lambda Configuration - Higher resources for production
lambda_memory = 1024
lambda_timeout = 30
enable_provisioned_concurrency = true
provisioned_concurrent_executions = 5

# API Gateway Rate Limiting - Higher limits for production
api_gateway_burst_limit = 500
api_gateway_rate_limit = 250

# Logging - Longer retention for compliance
log_retention_days = 30

# Monitoring
enable_warmup = true
warmup_schedule = "rate(3 minutes)"

# CORS - Strict domain restriction for production
# Update this with your actual production domain
allowed_origins = ["https://yourdomain.com", "https://www.yourdomain.com"]
