output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.this.id
}

output "api_endpoint" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_deployment.this.invoke_url
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.this.execution_arn
}
