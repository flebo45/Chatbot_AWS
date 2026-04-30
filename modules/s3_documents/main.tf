resource "aws_s3_bucket" "documents" {
  bucket = var.s3_documents_bucket_name
  tags = var.tags
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CORS Configuration
resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

    cors_rule {
        allowed_headers = ["*"]
        allowed_methods = ["PUT", "POST", "GET"]
        allowed_origins = var.allowed_origins
        expose_headers = ["ETag"]
        max_age_seconds = 3600
    }
}

# Lifecycle Rules
# Documents can be large and accumulate quickly
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  # Move non-current (overwritten) versions to cheaper storage after 30 days
  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    filter {} # applies to all objects

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    # Permanently delete non-current versions after 90 days
    # Adjust to your data retention policy / compliance requirements
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  # Clean up incomplete multipart uploads (safety net for failed uploads)
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# S3 Event Notifications
resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id

  queue {
    queue_arn = aws_sqs_queue.rag_ingestion_queue.arn
    events = ["s3:ObjectCreated:*"]
  }
}

resource "aws_sqs_queue" "rag_ingestion_queue" {
  name                       = "${var.project_name}-rag-queue"
  visibility_timeout_seconds = 60 # Give the Lambda time to process
}

# Allow S3 to send messages to this specific Queue
resource "aws_sqs_queue_policy" "s3_to_sqs" {
  queue_url = aws_sqs_queue.rag_ingestion_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.rag_ingestion_queue.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_s3_bucket.documents.arn }
        }
      }
    ]
  })
}

# Bucket Policy
resource "aws_s3_bucket_policy" "documents" {
  bucket = aws_s3_bucket.documents.id
  depends_on = [aws_s3_bucket_public_access_block.documents]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- Deny any non-HTTPS request (encryption in transit) ---
      {
        Sid    = "DenyNonHttps"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}