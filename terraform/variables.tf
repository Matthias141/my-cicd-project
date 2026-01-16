variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cicd-portfolio"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_memory" {
  description = "Memory for Lambda function in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "enable_provisioned_concurrency" {
  description = "Enable provisioned concurrency"
  type        = bool
  default     = false
}

variable "provisioned_concurrent_executions" {
  description = "Number of provisioned concurrent executions"
  type        = number
  default     = 1
}

variable "enable_warmup" {
  description = "Enable EventBridge warmup"
  type        = bool
  default     = true
}

variable "warmup_schedule" {
  description = "EventBridge schedule expression"
  type        = string
  default     = "rate(5 minutes)"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "database_password" {
  description = "Database password - must be provided via terraform.tfvars or environment variable"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "API key - must be provided via terraform.tfvars or environment variable"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret - must be provided via terraform.tfvars or environment variable"
  type        = string
  sensitive   = true
}

variable "allowed_origins" {
  description = "List of allowed CORS origins (e.g., ['https://yourdomain.com']). For development only, you can use ['*']"
  type        = list(string)
  default     = []
}

variable "api_gateway_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 100
}

variable "api_gateway_rate_limit" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 50
}
