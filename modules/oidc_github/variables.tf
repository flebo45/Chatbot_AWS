variable "project_name" {
  type = string
}

variable "github_org" {
  description = "Your GitHub Username or Organization Name"
  type        = string
}

variable "github_repo" {
  description = "The name of your GitHub repository"
  type        = string
}

variable "s3_bucket_arn" {
  description = "The ARN of the frontend S3 bucket"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  type        = string
}