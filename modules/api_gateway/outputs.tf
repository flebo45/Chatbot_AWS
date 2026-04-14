output "api_endpoint" {
  description = "The base URL of the API Gateway"
  value       = aws_apigatewayv2_api.this.api_endpoint
}