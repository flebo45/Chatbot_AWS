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

variable "bedrock_agent_knowledge_base_id" {
  description = "The ID of the Bedrock Agent knowledge base to be used by the Lambda function"
  type        = string
}

variable "bedrock_agent_data_source_id" {
  description = "The ID of the Bedrock Agent data source to be used by the Lambda function"
  type        = string
}

variable "bedrock_agent_knowledge_base_arn" {
  description = "The ARN of the Bedrock Agent knowledge base to be used by the Lambda function"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue that triggers the RAG ingestion Lambda on ObjectCreated events"
  type        = string
}

variable "tags" {
  description = "Tags to apply to Lambda function and IAM role resources"
  type        = map(string)
  default     = {}
}
