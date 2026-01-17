# Staging Environment Configuration
environment = "staging"

# Lambda Configuration
lambda_memory = 512
lambda_timeout = 30
enable_provisioned_concurrency = true
provisioned_concurrent_executions = 2

# API Gateway Rate Limiting
api_gateway_burst_limit = 200
api_gateway_rate_limit = 100

# Logging
log_retention_days = 14

# Monitoring
enable_warmup = true
warmup_schedule = "rate(5 minutes)"

# CORS - Allow all origins for testing (update with your actual staging domain later)
allowed_origins = ["*"]
