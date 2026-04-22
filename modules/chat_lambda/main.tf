# Fetch AWS Account for Docker login
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
    actions   = ["bedrock:InvokeModel",
                 "bedrock:InvokeModelWithResponseStream",
                 "bedrock:ApplyGuardrail",
                ]
    resources = [
                "arn:aws:bedrock:*::foundation-model/*",  # Allow access to the base models
                "arn:aws:bedrock:*:*:inference-profile/*", # Allow access to the routing profiles
                 var.guardrail_arn
                  ]
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

# ECR Repository for Lambda Docker Image
resource "aws_ecr_repository" "chatbot_repo" {
  name                 = "${var.function_name}-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Allows Terraform to destroy the repo even if it contains images
  tags                 = var.tags
}

# Docker image build and push to ECR
resource "null_resource" "docker_build_push" {
  triggers = {
    # This forces a rebuild ONLY if your python code, requirements, or Dockerfile changes
    src_hash = sha256(join("", [
      filesha256("${var.source_dir}/index.py"),
      filesha256("${var.source_dir}/ai_service.py"),
      filesha256("${var.source_dir}/Dockerfile"),
      filesha256("${var.source_dir}/requirements.txt")
    ]))
  }

  provisioner "local-exec" {
    # Logs into AWS Docker, builds the image (WITHOUT provenance), and pushes it to your ECR repo
    command = <<EOF
      aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com
      
      docker build --platform linux/amd64 --provenance=false -t ${aws_ecr_repository.chatbot_repo.repository_url}:latest ${var.source_dir}
      
      docker push ${aws_ecr_repository.chatbot_repo.repository_url}:latest
    EOF
  }
}

resource "aws_lambda_function" "this" {
  depends_on       = [null_resource.docker_build_push] # Ensures image is pushed BEFORE Lambda is created
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
 package_type     = "Image"
  image_uri        = "${aws_ecr_repository.chatbot_repo.repository_url}:latest"
  timeout          = 60

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      BEDROCK_MODEL_ID = var.bedrock_model_arn
      GUARDRAILS_ID = var.guardrails_id

      AWS_LWA_INVOKE_MODE     = "RESPONSE_STREAM"
    }
  }

  tags = var.tags
}
