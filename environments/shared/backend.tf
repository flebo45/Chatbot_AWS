# Backend Configuration
#
# This backend configuration uses partial configuration to support multiple environments.
# Backend-specific values are provided via backend.hcl files in each environment directory.
#
# Usage:
#   terraform init -backend-config=../production/backend.hcl
#   terraform init -backend-config=../development/backend.hcl
#   terraform init -backend-config=../test/backend.hcl
#
# For remote backends (production, test):
#   - S3 bucket for state storage
#   - DynamoDB table for state locking
#   - Encryption enabled
#
# For local backends (development):
#   - Local file path for state storage
#   - No state locking required

terraform {
  backend "s3" {
    # Configuration provided via -backend-config flag
    # See environments/{env}/backend.hcl for environment-specific values
  }
}
