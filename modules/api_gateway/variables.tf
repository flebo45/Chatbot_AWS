variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to integrate with API Gateway"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function for permission configuration"
  type        = string
}

variable "stage_name" {
  description = "Deployment stage name for the API Gateway"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags to apply to API Gateway resources"
  type        = map(string)
  default     = {}
}
