output "sqs_queue_arn" {
  description = "The ARN of the SQS queue that triggers the RAG ingestion Lambda on ObjectCreated events"
  value       = aws_sqs_queue.rag_ingestion_queue.arn
}

output "s3_documents_bucket_name" {
    description = "The name of the S3 bucket used for RAG ingestion"
    value       = aws_s3_bucket.documents.bucket
}

output "s3_documents_bucket_arn" {
    description = "The ARN of the S3 bucket used for RAG ingestion"
    value       = aws_s3_bucket.documents.arn
}