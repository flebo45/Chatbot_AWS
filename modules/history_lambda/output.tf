output "lambda_arn" {
  description = "The ARN of the created Lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "lambda_role_arn" {
  description = "The ARN of the Lambda execution IAM role"
  value       = aws_iam_role.lambda_role.arn
}

output "invoke_arn" {
  description = "The ARN to invoke the Lambda function"
  value = aws_lambda_function.this.invoke_arn
}