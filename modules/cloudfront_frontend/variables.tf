variable "project_name" {
  description = "The name of the project, used for naming the OAC and Distribution"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "The regional domain name of the S3 bucket acting as the origin"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all CloudFront resources"
  type        = map(string)
  default     = {}
}