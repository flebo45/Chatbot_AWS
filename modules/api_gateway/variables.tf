variable "project_name" {
  type = string
}

variable "post_lambda_arn" {
  description = "The ARN of the Lambda function for POST requests"
  type        = string
}

variable "get_lambda_arn" {
  description = "The ARN of the Lambda function for GET requests"
  type        = string
}

variable "post_lambda_function_name" {
  description = "The name of the Lambda function for POST requests"
  type        = string
}

variable "get_lambda_function_name" {
  description = "The name of the Lambda function for GET requests"
  type        = string
}

variable "allowed_origins" {
  description = "A list of allowed origins for CORS (Your CloudFront URL)"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}