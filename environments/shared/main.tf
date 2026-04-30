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

#  Post Lambda Module - Chat Handler Function
module "chat_lambda" {
  source = "../../modules/chat_lambda"

  function_name       = "${local.lambda_function_name}-post-message"
  source_dir         = "../../modules/chat_lambda/src"
  runtime             = var.lambda_runtime
  cloudfront_url = "https://${module.cloudfront_frontend.domain_name}"
  dynamodb_table_arn  = module.dynamodb.table_arn
  dynamodb_table_name = module.dynamodb.table_name
  bedrock_model_arn   = var.bedrock_model_arn
  guardrails_id       = module.guardrail.guardrail_id
  guardrail_arn      = module.guardrail.guardrail_arn
  s3_bucket_name     = module.s3_documents.s3_documents_bucket_name
  knowledge_base_id  = module.knowledge_bases.bedrock_agent_knowledge_base_id
  knowledge_base_arn = module.knowledge_bases.bedrock_agent_knowledge_base_arn
  tags                = local.common_tags
}

module "guardrail" {
  source = "../../modules/bedrock_guardrails"
  project_name = local.resource_prefix

  tags = local.common_tags
}

# Get Lambda Module - Chat History Handler Function
module "history_lambda" {
  source = "../../modules/history_lambda"
  function_name       = "${local.lambda_function_name}-get-history"
  source_dir         = "../../modules/history_lambda/src"
  runtime             = var.lambda_runtime
  dynamodb_table_arn  = module.dynamodb.table_arn
  dynamodb_table_name = module.dynamodb.table_name
  tags                = local.common_tags
}

# S3 Frontend Module - Static Assets for Frontend
module "frontend_bucket" {
  source = "../../modules/s3_frontend"
  bucket_name = "${local.resource_prefix}-frontend"
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


# API Gateway Module - WebSocket API for Chatbot
module "api_gateway" {
  source = "../../modules/api_gateway"
  project_name = local.resource_prefix

  # POST Connection (Chat Streaming)
  post_lambda_arn           = module.chat_lambda.response_streaming_invoke_arn
  post_lambda_function_name = module.chat_lambda.lambda_function_name

  # REST Connection (Chat History)
  get_lambda_arn           = module.history_lambda.invoke_arn
  get_lambda_function_name = module.history_lambda.lambda_function_name

  # Allowed origins for CORS (CloudFront URL)
  allowed_origins = [
    "https://${module.cloudfront_frontend.domain_name}", 
    "http://localhost:3000"
  ]
  tags = local.common_tags
}

module "s3_documents" {
  source = "../../modules/s3_documents"

  project_name = local.resource_prefix
  s3_documents_bucket_name = "${local.resource_prefix}-documents"

  allowed_origins = [
    "https://${module.cloudfront_frontend.domain_name}", 
    "http://localhost:3000"
  ]

  tags = local.common_tags
  
}

module "knowledge_bases" {
  source = "../../modules/knowledge_bases"

  knowledge_base_name = "${local.resource_prefix}-kb"
  s3vectors_bucket_name = "${local.resource_prefix}-vectors"
  s3vectors_index_name = "${local.resource_prefix}-vectors-index"

  s3vectors_data_type = var.s3vectors_data_type
  s3_documents_bucket_arn = module.s3_documents.s3_documents_bucket_arn


  embedding_model_arn = var.embedding_model_arn

  embedding_dimensions = var.embedding_dimensions
  embedding_data_type = var.embedding_data_type
  tags = local.common_tags
}

module "rag_lambda" {
  source = "../../modules/rag_trigger"

  function_name       = "${local.resource_prefix}-rag-trigger"
  source_dir         = "../../modules/rag_trigger/src"
  runtime             = var.lambda_runtime

  bedrock_agent_knowledge_base_id = module.knowledge_bases.bedrock_agent_knowledge_base_id
  bedrock_agent_data_source_id    = module.knowledge_bases.bedrock_agent_data_source_id
  sqs_queue_arn = module.s3_documents.sqs_queue_arn
  bedrock_agent_knowledge_base_arn = module.knowledge_bases.bedrock_agent_knowledge_base_arn

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
