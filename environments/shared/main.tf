# Root Module - Main Configuration
# This file orchestrates all infrastructure components and manages dependencies between modules

locals {
  # Resource naming prefix combining project name and environment
  resource_prefix = "${var.project_name}-${var.environment}"

  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  # Computed values for resource naming
  lambda_function_name = "${local.resource_prefix}-chatbot"
  dynamodb_table_name  = "${local.resource_prefix}-chat-history"
  api_gateway_name     = "${local.resource_prefix}-api"
}
# DynamoDB Module - Chat History Table
module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name = local.dynamodb_table_name
  tags       = local.common_tags
}

# Lambda Module - Chat Handler Function
module "chat_lambda" {
  source = "../../modules/chat_lambda"

  function_name       = local.lambda_function_name
  source_file         = "../../modules/chat_lambda/index.py"
  runtime             = var.lambda_runtime
  dynamodb_table_arn  = module.dynamodb.table_arn
  dynamodb_table_name = module.dynamodb.table_name
  bedrock_model_arn   = var.bedrock_model_arn
  tags                = local.common_tags
}

# API Gateway Module - REST API for Lambda Function
module "api_gateway" {
  source = "../../modules/api_gateway"

  api_name             = local.api_gateway_name
  lambda_function_arn  = module.chat_lambda.lambda_arn
  lambda_function_name = module.chat_lambda.lambda_function_name
  tags                 = local.common_tags
}
