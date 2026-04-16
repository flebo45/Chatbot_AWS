output "api_endpoint" {
  description = "The URL of the API Gateway endpoint"
  value = aws_api_gateway_stage.production.invoke_url
}
output "execution_arn" {
  description = "The execution ARN for the API Gateway"
  value = aws_api_gateway_rest_api.this.execution_arn
}