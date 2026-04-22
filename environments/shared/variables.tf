variable "environment" {
  description = "Deployment environment (production, development, test)"
  type        = string

  validation {
    condition     = contains(["production", "development", "test"], var.environment)
    error_message = "Environment must be one of: production, development, test"
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda function runtime version"
  type        = string
  default     = "python3.12"
}

variable "bedrock_model_arn" {
  description = "ARN of the Bedrock model for Lambda function access"
  type        = string
}
