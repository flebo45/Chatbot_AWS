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

# output URL for frontend assets served via CloudFront
output "website_url" {
  value = "https://${module.cloudfront_frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "The ID needed for the deploy.sh script"
  value       = module.cloudfront_frontend.distribution_id
}

output "api_chat_url" {
  value = "${module.api_gateway.api_endpoint}/chat"
}