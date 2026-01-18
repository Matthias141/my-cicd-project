# S3 Backend for Terraform State
# This stores Terraform state remotely in S3 with DynamoDB locking
# State persists between workflow runs, preventing "already exists" errors
# Each environment (dev/staging/prod) has its own state file
# The 'key' is set dynamically in the workflow using -backend-config

terraform {
  backend "s3" {
    bucket         = "cicd-portfolio-terraform-state"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cicd-portfolio-terraform-locks"
  }
}
