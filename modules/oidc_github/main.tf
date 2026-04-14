# Register GitHub as an OIDC Identity Provider in AWS IAM
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM Role with Trust Condition
resource "aws_iam_role" "github_actions" {
    name = "${var.project_name}-github-oidc-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
            Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
            StringLike = {
            # CRITICAL SECURITY: Only YOUR repository can assume this role!
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
            }
            StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
        }
        }]
    })
}

# Role permission to allow update S3 and CloudFront
resource "aws_iam_role_policy" "frontend_deploy_policy" {
    name = "${var.project_name}-github-oidc-policy"
    role = aws_iam_role.github_actions.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
      {
        Sid      = "AllowS3Sync"
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Sid      = "AllowCloudFrontInvalidation"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = [var.cloudfront_distribution_arn]
      }
    ]
  }) 
}