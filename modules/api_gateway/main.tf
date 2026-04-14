resource "aws_apigatewayv2_api" "this" {
  name = "${var.project_name}-api"
  protocol_type = "HTTP"

  # CORS Configuration
  cors_configuration {
    allow_origins = var.allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age = 300
  }

  tags = var.tags
}

# Deployment Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.this.id
  name   = "$default"
  auto_deploy = true
  tags = var.tags
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.this.id
  integration_type = "AWS_PROXY"
  integration_uri = var.lambda_arn

  payload_format_version = "2.0"
}

# Route for Lambda Integration
resource "aws_apigatewayv2_route" "post_chat" {
  api_id = aws_apigatewayv2_api.this.id
  route_key = "POST /chat"
  target = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Security
resource "aws_lambda_permission" "api_gw" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
  
}