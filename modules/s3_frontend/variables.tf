variable "bucket_name" {
  description = "The globally unique name of the S3 bucket"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to the bucket"
  type        = map(string)
  default     = {}
}

variable "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution allowed to read the bucket"
  type        = string
}