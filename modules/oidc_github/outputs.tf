output "github_role_arn" {
  description = "The ARN of the IAM Role GitHub will assume"
  value       = aws_iam_role.github_actions.arn
}