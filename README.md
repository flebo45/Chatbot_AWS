# Terraform Chatbot Infrastructure

A multi-environment Terraform project for deploying a serverless chatbot on AWS using Lambda, DynamoDB, API Gateway, and AWS Bedrock.

## Overview

This project uses a DRY (Don't Repeat Yourself) structure. All shared Terraform code lives in `environments/shared/`. Environment-specific values are isolated in `.tfvars` and `backend.hcl` files — no code duplication across environments.

**Architecture:**

```
┌─────────────────┐
│   API Gateway   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│  Lambda Function│─────▶│    DynamoDB      │
│  (Chat Handler) │      │  (Chat History)  │
└────────┬────────┘      └──────────────────┘
         │
         ▼
┌─────────────────┐
│   AWS Bedrock   │
│   (AI Model)    │
└─────────────────┘
```

## Directory Structure

```
.
├── environments/
│   ├── shared/                  # Shared Terraform configuration (single source of truth)
│   │   ├── main.tf              # Module instantiation and locals
│   │   ├── variables.tf         # Variable declarations
│   │   ├── outputs.tf           # Root outputs
│   │   ├── provider.tf          # AWS provider configuration
│   │   └── backend.tf           # Backend configuration template
│   ├── development/
│   │   ├── terraform.tfvars     # Development variable values
│   │   └── backend.hcl          # Development backend config
│   ├── test/
│   │   ├── terraform.tfvars     # Test variable values
│   │   └── backend.hcl          # Test backend config
│   └── production/
│       ├── terraform.tfvars     # Production variable values
│       └── backend.hcl          # Production backend config
├── modules/
│   ├── chat_lambda/             # Lambda function + IAM role
│   ├── api_gateway/             # API Gateway REST API
│   └── dynamodb/                # DynamoDB table
├── src/
│   └── chat_handler.py          # Lambda function source code
└── docs/
    ├── DEPLOYMENT.md            # Full deployment guide
    └── MIGRATION.md             # Migration guide from old structure
```

## Prerequisites

- **Terraform** >= 1.0 — `terraform version`
- **AWS CLI** 2.x — `aws --version`
- AWS credentials configured — `aws sts get-caller-identity`
- S3 buckets and DynamoDB lock tables for each environment (see [Backend Setup](#backend-setup))

**Required IAM permissions:** Lambda, DynamoDB, API Gateway, IAM, S3, CloudWatch Logs.

## Quick Start

All deployments run from `environments/shared/`. Select the environment by passing the appropriate `backend.hcl` and `terraform.tfvars`.

### Development

```bash
cd environments/shared
terraform init -backend-config=../development/backend.hcl
terraform plan -var-file=../development/terraform.tfvars
terraform apply -var-file=../development/terraform.tfvars
```

### Test

```bash
cd environments/shared
terraform init -reconfigure -backend-config=../test/backend.hcl
terraform plan -var-file=../test/terraform.tfvars
terraform apply -var-file=../test/terraform.tfvars
```

### Production

```bash
cd environments/shared
terraform init -reconfigure -backend-config=../production/backend.hcl
terraform plan -var-file=../production/terraform.tfvars -out=production.tfplan
terraform show production.tfplan   # review before applying
terraform apply production.tfplan
```

## Configuration

Each environment's `terraform.tfvars` sets these variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `environment` | Environment name | `"production"` |
| `project_name` | Project identifier (lowercase, hyphens ok) | `"chatbot"` |
| `aws_region` | AWS region | `"us-east-1"` |
| `lambda_runtime` | Python runtime | `"python3.12"` |
| `bedrock_model_arn` | Bedrock model ARN | `"arn:aws:bedrock:..."` |

Update `bedrock_model_arn` in each `terraform.tfvars` with your actual Bedrock model ARN before deploying.

## Backend Setup

Each environment requires an S3 bucket (and DynamoDB lock table for test/production).

### Development

```bash
aws s3 mb s3://terraform-state-development --region us-east-1
aws s3api put-bucket-versioning \
  --bucket terraform-state-development \
  --versioning-configuration Status=Enabled
```

### Test

```bash
aws s3 mb s3://terraform-state-test --region us-east-1
aws s3api put-bucket-versioning \
  --bucket terraform-state-test \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock-test \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Production

```bash
aws s3 mb s3://terraform-state-production --region us-east-1
aws s3api put-bucket-versioning \
  --bucket terraform-state-production \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket terraform-state-production \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Switching Environments

Always use `-reconfigure` when switching between environments:

```bash
cd environments/shared

# → development
terraform init -reconfigure -backend-config=../development/backend.hcl

# → test
terraform init -reconfigure -backend-config=../test/backend.hcl

# → production
terraform init -reconfigure -backend-config=../production/backend.hcl
```

## Modules

### chat_lambda

Deploys a Lambda function with an IAM execution role.

| Input | Description |
|-------|-------------|
| `function_name` | Lambda function name |
| `runtime` | Python runtime version |
| `source_file` | Path to Lambda source code |
| `dynamodb_table_arn` | DynamoDB table ARN (for IAM policy) |
| `dynamodb_table_name` | DynamoDB table name (for env var) |
| `bedrock_model_arn` | Bedrock model ARN (for IAM policy) |
| `tags` | Resource tags |

Outputs: `lambda_arn`, `lambda_function_name`, `lambda_role_arn`

### dynamodb

Deploys a DynamoDB table for chat history.

| Input | Description |
|-------|-------------|
| `table_name` | Table name |
| `billing_mode` | `PROVISIONED` or `PAY_PER_REQUEST` |
| `read_capacity` | Read capacity units (if PROVISIONED) |
| `write_capacity` | Write capacity units (if PROVISIONED) |
| `tags` | Resource tags |

Outputs: `table_arn`, `table_name`, `table_id`

### api_gateway

Deploys a REST API Gateway with Lambda integration.

| Input | Description |
|-------|-------------|
| `api_name` | API name |
| `lambda_function_arn` | Lambda ARN to integrate |
| `lambda_function_name` | Lambda name (for invoke permission) |
| `stage_name` | Deployment stage name |
| `tags` | Resource tags |

Outputs: `api_id`, `api_endpoint`, `api_execution_arn`

## Troubleshooting

### "Backend configuration changed"

```bash
terraform init -reconfigure -backend-config=../production/backend.hcl
```

### "Error acquiring the state lock"

```bash
# Force unlock only when certain no other process is running
terraform force-unlock <lock-id>
```

### "No valid credential sources found"

```bash
aws configure
# or set environment variables:
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

### "Backend bucket does not exist"

See [Backend Setup](#backend-setup) above.

### Plan shows unexpected changes

```bash
terraform refresh -var-file=../production/terraform.tfvars
terraform plan -var-file=../production/terraform.tfvars
```

### Lambda function errors

```bash
# Check Lambda logs
aws logs tail /aws/lambda/chatbot-production-chatbot --follow

# Test Lambda invocation
aws lambda invoke \
  --function-name chatbot-production-chatbot \
  --payload '{"message":"Hello"}' \
  response.json
```

## Validation Commands

```bash
# Validate configuration syntax
terraform validate

# Check formatting
terraform fmt -check

# List all resources in state
terraform state list

# Show specific resource
terraform state show 'module.chat_lambda.aws_lambda_function.this'
```

## Additional Documentation

- [Deployment Instructions](docs/DEPLOYMENT.md) — full deployment guide with CI/CD examples
- [Migration Guide](docs/MIGRATION.md) — migrating from the old per-environment structure
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Changelog

### v2.0.0 (current)
- Refactored to DRY structure with `environments/shared/`
- Eliminated duplicate configuration files across environments
- Renamed `release` → `production`, `dev` → `development`
- Implemented output-as-input pattern for module dependencies
- Added comprehensive documentation

### v1.0.0
- Initial multi-environment structure with per-environment configuration files
