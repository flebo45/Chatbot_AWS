resource "aws_s3vectors_vector_bucket" "chatbot_vectors" {
  vector_bucket_name = var.s3vectors_bucket_name
}

resource "aws_s3vectors_index" "chatbot_index" {
  index_name         = var.s3vectors_index_name
  vector_bucket_name = aws_s3vectors_vector_bucket.chatbot_vectors.vector_bucket_name

  data_type       = var.s3vectors_data_type
  dimension       = var.embedding_dimensions
  distance_metric = "euclidean"

  metadata_configuration {
    non_filterable_metadata_keys = [
      "AMAZON_BEDROCK_TEXT",
      "AMAZON_BEDROCK_METADATA",
      "x-amz-bedrock-kb-document-metadata"
    ]
  }
}

# IAM Role for Bedrock
data "aws_iam_policy_document" "kb_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "kb_chatbot" {
    name = "${var.knowledge_base_name}_role"
    assume_role_policy = data.aws_iam_policy_document.kb_assume_role.json
}

# Execution Policy for Bedrock Agent to access S3Vectors
data "aws_iam_policy_document" "kb_s3vectors_permissions" {
  statement {
    effect    = "Allow"
    actions   = [
      "s3vectors:PutVectors",
      "s3vectors:QueryVectors",
      "s3vectors:DeleteVectors",
      "s3vectors:ListVectors",
      "s3vectors:GetVectors"
    ]
    resources = [
      aws_s3vectors_vector_bucket.chatbot_vectors.vector_bucket_arn,
      aws_s3vectors_index.chatbot_index.index_arn
    ]
  }
}

resource "aws_iam_role_policy" "kb_s3vectors_policy" {
  name   = "${var.knowledge_base_name}_s3vectors_policy"
  role   = aws_iam_role.kb_chatbot.id
  policy = data.aws_iam_policy_document.kb_s3vectors_permissions.json
}

# Execution Policy for Bedrock Agent to access S3 
data "aws_iam_policy_document" "kb_s3_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      var.s3_documents_bucket_arn,
      "${var.s3_documents_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "kb_s3_policy" {
  name   = "${var.knowledge_base_name}_s3_policy"
  role   = aws_iam_role.kb_chatbot.id
  policy = data.aws_iam_policy_document.kb_s3_permissions.json
}

# Execution Policy for Bedrock Agent to access Models
data "aws_iam_policy_document" "kb_models_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [var.embedding_model_arn]
  }
}

resource "aws_iam_role_policy" "kb_models_policy" {
  name   = "${var.knowledge_base_name}_models_policy"
  role   = aws_iam_role.kb_chatbot.id
  policy = data.aws_iam_policy_document.kb_models_permissions.json
}


resource "aws_bedrockagent_knowledge_base" "chatbot_kb" {
  name     = var.knowledge_base_name
  role_arn = aws_iam_role.kb_chatbot.arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = var.embedding_data_type
        }
      }
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.chatbot_index.index_arn
    }
  }
}

# Knowledge Base  Data Source - S3
resource "aws_bedrockagent_data_source" "s3_data_source" {
    name     = "${var.knowledge_base_name}_s3_data_source"
    knowledge_base_id = aws_bedrockagent_knowledge_base.chatbot_kb.id

    data_source_configuration {
      type = "S3"
      s3_configuration {
        bucket_arn = var.s3_documents_bucket_arn
      }
    }
  
}