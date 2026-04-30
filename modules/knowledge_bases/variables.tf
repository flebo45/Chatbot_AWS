variable "s3vectors_bucket_name" {
  description = "The name of the S3 bucket for vector storage."
  type        = string
}

variable "s3vectors_index_name" {
  description = "The name of the S3Vectors index."
  type        = string
}

variable "s3vectors_data_type" {
  description = "The data type of the vectors stored in S3Vectors."
  type        = string
}

variable "embedding_dimensions" {
  description = "The number of dimensions for the embedding vectors."
  type        = number
}

variable "embedding_model_arn" {
  description = "The ARN of the embedding model to use for the knowledge base."
  type        = string
}

variable "knowledge_base_name" {
  description = "The name of the Bedrock Agent knowledge base."
  type        = string
}

variable "embedding_data_type" {
  description = "The data type of the embedding vectors used in the knowledge base."
  type        = string
}

variable "s3_documents_bucket_arn" {
  description = "The ARN of the S3 bucket where source documents are stored."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources in the knowledge base module"
  type        = map(string)
  default     = {}
}