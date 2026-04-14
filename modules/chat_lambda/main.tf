# Trust Policy for Lambda Execution Role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_role" {
  name               = "${var.function_name}_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# Amazon Bedrock permissions
data "aws_iam_policy_document" "bedrock_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [var.bedrock_model_arn]
  }
}

resource "aws_iam_role_policy" "bedrock_policy" {
  name   = "${var.function_name}_bedrock_policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.bedrock_permissions.json
}

# Amazon DynamoDB permissions
data "aws_iam_policy_document" "dynamodb_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query"
    ]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "dynamodb_policy" {
  name   = "${var.function_name}_dynamodb_policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.dynamodb_permissions.json
}

# Attch standard AWS CloudWatch Logs permissions to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "zip" {
  type        = "zip"
  source_dir = var.source_dir
  output_path = "${path.module}/chat_handler.zip"
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = var.runtime
  source_code_hash = data.archive_file.zip.output_base64sha256

  timeout = 30

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      BEDROCK_MODEL_ID = var.bedrock_model_arn
    }
  }

  tags = var.tags
}
