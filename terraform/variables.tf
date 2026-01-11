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
