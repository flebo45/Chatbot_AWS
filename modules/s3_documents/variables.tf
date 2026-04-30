variable "s3_documents_bucket_name" {
  description = "Name of the S3 bucket for RAG documents"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_origins" {
  description = "List of allowed CORS origins for presigned URL uploads. Should be your CloudFront domain(s) in production. e.g. [\"https://d1234abcd.cloudfront.net\"]"
  type        = list(string)
}

variable "project_name" {
  description = "The name of the project, used for tagging and naming resources"
  type        = string
}