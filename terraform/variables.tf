# Variables = Inputs to your Terraform configuration
# Think of these as function parameters

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
  default     = "cicd-portfolio"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  # No default = you MUST provide this when running Terraform
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"  # North Virginia (cheapest, most services)
}

variable "lambda_memory" {
  description = "Memory allocated to Lambda function (MB)"
  type        = number
  default     = 512  # More memory = faster CPU (Lambda scales CPU with memory)
}

variable "lambda_timeout" {
  description = "Maximum execution time for Lambda (seconds)"
  type        = number
  default     = 30
}

variable "enable_provisioned_concurrency" {
  description = "Enable provisioned concurrency (COSTS MONEY - see cost analysis)"
  type        = bool
  default     = false  # Keep false for free tier
}

variable "provisioned_concurrent_executions" {
  description = "Number of warm Lambda instances (only if enabled above)"
  type        = number
  default     = 1
}

variable "enable_warmup" {
  description = "Enable EventBridge warm-up pings (FREE)"
  type        = bool
  default     = true  # Recommended for production
}

variable "warmup_schedule" {
  description = "How often to ping Lambda (CloudWatch cron syntax)"
  type        = string
  default     = "rate(5 minutes)"  # Every 5 minutes
}

variable "log_retention_days" {
  description = "How long to keep CloudWatch logs"
  type        = number
  default     = 7  # 1 week (reduce for lower costs, but free tier is generous)
}