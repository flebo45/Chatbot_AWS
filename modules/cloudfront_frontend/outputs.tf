output "distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "The ARN of the CloudFront distribution (needed for S3 Bucket Policy)"
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "The public URL of your application (e.g., d123456abcdef8.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}