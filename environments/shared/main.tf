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
  source_dir         = "../../modules/chat_lambda/src"
  runtime             = var.lambda_runtime
  dynamodb_table_arn  = module.dynamodb.table_arn
  dynamodb_table_name = module.dynamodb.table_name
  bedrock_model_arn   = var.bedrock_model_arn
  tags                = local.common_tags
}

# S3 Frontend Module - Static Assets for Frontend
module "frontend_bucket" {
  source = "../../modules/s3_frontend"
  bucket_name = "${local.resource_prefix}-frontend-assets"
  cloudfront_distribution_arn = module.cloudfront_frontend.distribution_arn
  tags = local.common_tags
}

# CloudFront Module - CDN for Frontend Assets
module "cloudfront_frontend" {
  source = "../../modules/cloudfront_frontend"

  project_name = local.resource_prefix
  s3_bucket_regional_domain_name = module.frontend_bucket.bucket_regional_domain_name
  tags = local.common_tags
}

# API Gateway Module - HTTP API for Chatbot
module "api_gateway" {
  source = "../../modules/api_gateway"
  project_name = local.resource_prefix

  # Lambda connection
  lambda_arn = module.chat_lambda.lambda_arn
  lambda_function_name = module.chat_lambda.lambda_function_name

  # Secure CORS by allowing only ClodFront
  allowed_origins = ["https://${module.cloudfront_frontend.domain_name}"]
  tags = local.common_tags
}

module "github_oidc" {
  source = "../../modules/oidc_github"

  project_name = local.resource_prefix

  github_org = "flebo45"
  github_repo = "Chatbot_AWS"

  s3_bucket_arn = module.frontend_bucket.bucket_arn
  cloudfront_distribution_arn = module.cloudfront_frontend.distribution_arn
}
