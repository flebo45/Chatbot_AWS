# Root Module Outputs
#
# These outputs export key values from instantiated modules for external consumption
# All three modules (dynamodb, chat_lambda, api_gateway) are instantiated in main.tf

output "lambda_function_arn" {
  description = "ARN of the Lambda function for chat handling"
  value       = module.chat_lambda.lambda_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for chat history storage"
  value       = module.dynamodb.table_name
}

output "api_gateway_endpoint" {
  description = "API Gateway invoke URL endpoint for accessing the chat API"
  value       = module.api_gateway.api_endpoint
}
