# IAM Role for the RAG Trigger Lambda
data "aws_iam_policy_document" "rag_lambda_assume" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rag_trigger_role" {
  name               = "${var.function_name}_rag_trigger_role"
  assume_role_policy = data.aws_iam_policy_document.rag_lambda_assume.json
}

# Allow Lambda to read SQS, start Bedrock jobs, and write logs
resource "aws_iam_role_policy" "rag_trigger_policy" {
  name   = "rag_trigger_permissions"
  role   = aws_iam_role.rag_trigger_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      },
      {
        Effect = "Allow"
        Action = ["bedrock:StartIngestionJob"]
        Resource = [
          var.bedrock_agent_knowledge_base_arn,
        ]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "zip" {
  type        = "zip"
  source_dir = var.source_dir
  output_path = "${path.module}/rag_trigger.zip"
}


# The Lambda Function
resource "aws_lambda_function" "rag_trigger" {
  filename         = data.archive_file.zip.output_path
  function_name    = "${var.function_name}"
  role             = aws_iam_role.rag_trigger_role.arn
  handler          = "index.handler"
  runtime          = var.runtime
  timeout          = 30

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.bedrock_agent_knowledge_base_id
      DATA_SOURCE_ID    = var.bedrock_agent_data_source_id
    }
       
  }
  tags = var.tags
}

# The Event Source Mapping (Wiring SQS to Lambda)
resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.rag_trigger.arn
  batch_size       = 10
}