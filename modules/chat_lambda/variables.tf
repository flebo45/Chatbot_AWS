variable "function_name" {
  description = "The name of the lambda function"
  type        = string
}

variable "runtime" {
  description = "The runtime environment for the lambda function"
  type        = string
  default     = "python3.12"
}

variable "source_dir" {
  description = "The path to the directory containing the Python code for the lambda function"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table to be used by the Lambda function"
  type        = string
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table to be used by the Lambda function"
  type        = string
}

variable "bedrock_model_arn" {
  description = "The ARN of the Bedrock model to be used by the Lambda function"
  type        = string
}

variable "guardrails_id" {
  description = "The ID of the Bedrock Guardrails to be used by the Lambda function"
  type        = string
}

variable "tags" {
  description = "Tags to apply to Lambda function and IAM role resources"
  type        = map(string)
  default     = {}
}

variable "guardrail_arn" {
  description = "The ARN of the Bedrock Guardrail"
  type        = string
}

variable "cloudfront_url" {
  description = "The URL of the CloudFront distribution for CORS configuration"
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket for document storage, used by the Lambda function"
  type        = string
}

variable "knowledge_base_id" {
  description = "The ID of the Bedrock Agent Knowledge Base to be used by the Lambda function"
  type        = string
}

variable "knowledge_base_arn" {
  description = "The ARN of the Bedrock Agent Knowledge Base to be used by the Lambda function"
  type        = string
}