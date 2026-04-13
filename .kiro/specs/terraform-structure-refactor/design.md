# Design Document: Terraform Structure Refactor

## Overview

This design provides a technical solution for refactoring a multi-environment Terraform project to eliminate configuration duplication while maintaining three distinct deployment environments (production, development, test). The refactor implements a DRY (Don't Repeat Yourself) architecture where shared configuration files are defined once and environment-specific values are isolated in .tfvars files.

The current structure has duplicate configuration files (main.tf, provider.tf, variables.tf) in each environment directory, leading to maintenance overhead and potential inconsistencies. The refactored structure will centralize shared configuration in a common location while preserving environment-specific customization through variable files.

**Key Design Principles:**
- Single source of truth for infrastructure code
- Environment-specific values only in .tfvars files
- Explicit dependency management through outputs-as-inputs
- Clear separation between input variables and computed locals
- Flexible backend configuration (local/remote)
- Terraform best practices compliance

## Architecture

### Directory Structure

The refactored project will use the following directory structure:

```
terraform-project/
├── modules/                          # Reusable Terraform modules
│   ├── chat_lambda/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── api_gateway/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── dynamodb/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
├── environments/
│   ├── shared/                       # Shared configuration (DRY)
│   │   ├── main.tf                   # Root module logic
│   │   ├── variables.tf              # Variable declarations
│   │   ├── outputs.tf                # Root outputs
│   │   ├── provider.tf               # Provider configuration
│   │   └── backend.tf                # Backend configuration template
│   ├── production/
│   │   ├── terraform.tfvars          # Production-specific values
│   │   └── backend.hcl               # Production backend config
│   ├── development/
│   │   ├── terraform.tfvars          # Development-specific values
│   │   └── backend.hcl               # Development backend config
│   └── test/
│       ├── terraform.tfvars          # Test-specific values
│       └── backend.hcl               # Test backend config
└── src/                              # Application source code
    └── chat_handler.py
```

### Deployment Model

Each environment deployment follows this workflow:

1. **Initialize**: Navigate to `environments/shared/` directory
2. **Configure Backend**: Run `terraform init -backend-config=../production/backend.hcl`
3. **Plan**: Run `terraform plan -var-file=../production/terraform.tfvars`
4. **Apply**: Run `terraform apply -var-file=../production/terraform.tfvars`

This approach ensures:
- All environments use the same infrastructure code
- Only variable values differ between environments
- Backend configuration is flexible per environment
- No code duplication across environments

### State Management Strategy

**Development Environment:**
- Uses local backend for rapid iteration
- State file stored in `environments/development/terraform.tfstate`
- No state locking required

**Test Environment:**
- Uses remote backend (S3 + DynamoDB)
- Enables state sharing across team members
- State locking prevents concurrent modifications

**Production Environment:**
- Uses remote backend (S3 + DynamoDB)
- Encrypted state storage
- State locking with DynamoDB table
- Versioned S3 bucket for state history

## Components and Interfaces

### Shared Configuration Components

#### 1. Root Module (environments/shared/main.tf)

The root module orchestrates all infrastructure components and manages dependencies between modules.

**Responsibilities:**
- Instantiate child modules (chat_lambda, api_gateway, dynamodb)
- Pass environment-specific variables to modules
- Wire module outputs to module inputs (dependency management)
- Define local computed values

**Key Design Decisions:**
- Uses explicit output-as-input pattern for cross-module dependencies
- Computes derived values using locals block
- No hardcoded values (all parameterized through variables)

**Example Structure:**
```hcl
locals {
  resource_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

module "dynamodb" {
  source = "../../modules/dynamodb"
  
  table_name = "${local.resource_prefix}-chat-history"
  tags       = local.common_tags
}

module "chat_lambda" {
  source = "../../modules/chat_lambda"
  
  function_name       = "${local.resource_prefix}-chatbot"
  source_file         = "../../src/chat_handler.py"
  runtime             = var.lambda_runtime
  bedrock_model_arn   = var.bedrock_model_arn
  dynamodb_table_arn  = module.dynamodb.table_arn
  dynamodb_table_name = module.dynamodb.table_name
  tags                = local.common_tags
}
```

#### 2. Variable Declarations (environments/shared/variables.tf)

Declares all input variables accepted by the root module.

**Variable Categories:**
- **Environment Identifiers**: environment, project_name
- **AWS Configuration**: aws_region, aws_account_id (optional)
- **Resource ARNs**: bedrock_model_arn
- **Runtime Configuration**: lambda_runtime, lambda_timeout
- **Feature Flags**: enable_api_gateway, enable_monitoring

**Design Pattern:**
- All variables have descriptions
- All variables have type constraints
- Optional variables have default values
- No default values for environment-specific settings

#### 3. Provider Configuration (environments/shared/provider.tf)

Parameterized AWS provider configuration.

**Key Features:**
- Region specified via variable (not hardcoded)
- Support for assume_role (cross-account deployments)
- Default tags applied to all resources
- Provider version constraints

**Example:**
```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}
```

#### 4. Backend Configuration (environments/shared/backend.tf)

Template for backend configuration with partial configuration support.

**Design Approach:**
- Uses partial configuration (values provided via backend.hcl files)
- Supports both local and remote backends
- Remote backend uses S3 + DynamoDB for locking

**Example:**
```hcl
terraform {
  backend "s3" {
    # Configuration provided via -backend-config flag
    # See environments/{env}/backend.hcl for values
  }
}
```

### Environment-Specific Components

#### 1. Variable Files (terraform.tfvars)

Each environment has a terraform.tfvars file with environment-specific values.

**Production Example:**
```hcl
environment    = "production"
project_name   = "chatbot"
aws_region     = "us-east-1"
lambda_runtime = "python3.12"

bedrock_model_arn = "arn:aws:bedrock:us-east-1:123456789012:model/anthropic.claude-v2"
```

**Development Example:**
```hcl
environment    = "development"
project_name   = "chatbot"
aws_region     = "eu-central-1"
lambda_runtime = "python3.12"

bedrock_model_arn = "arn:aws:bedrock:eu-central-1:123456789012:model/anthropic.claude-v2"
```

#### 2. Backend Configuration Files (backend.hcl)

Each environment has a backend.hcl file specifying state storage configuration.

**Production Backend (Remote):**
```hcl
bucket         = "terraform-state-production"
key            = "chatbot/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

**Development Backend (Local):**
```hcl
path = "../development/terraform.tfstate"
```

### Module Interfaces

#### Chat Lambda Module

**Inputs:**
- `function_name` (string): Lambda function name
- `runtime` (string): Python runtime version
- `source_file` (string): Path to Lambda source code
- `dynamodb_table_arn` (string): DynamoDB table ARN for permissions
- `dynamodb_table_name` (string): DynamoDB table name for environment variables
- `bedrock_model_arn` (string): Bedrock model ARN for permissions
- `tags` (map): Resource tags

**Outputs:**
- `lambda_arn` (string): Lambda function ARN
- `lambda_function_name` (string): Lambda function name
- `lambda_role_arn` (string): IAM role ARN

**Design Notes:**
- Receives both table ARN (for IAM policy) and table name (for environment variable)
- Creates IAM role with least-privilege permissions
- Packages Lambda code using archive_file data source

#### DynamoDB Module

**Inputs:**
- `table_name` (string): DynamoDB table name
- `billing_mode` (string): PROVISIONED or PAY_PER_REQUEST
- `read_capacity` (number): Read capacity units (if PROVISIONED)
- `write_capacity` (number): Write capacity units (if PROVISIONED)
- `tags` (map): Resource tags

**Outputs:**
- `table_arn` (string): DynamoDB table ARN
- `table_name` (string): DynamoDB table name
- `table_id` (string): DynamoDB table ID

#### API Gateway Module

**Inputs:**
- `api_name` (string): API Gateway name
- `lambda_function_arn` (string): Lambda function ARN to integrate
- `lambda_function_name` (string): Lambda function name for permissions
- `stage_name` (string): Deployment stage name
- `tags` (map): Resource tags

**Outputs:**
- `api_id` (string): API Gateway ID
- `api_endpoint` (string): API Gateway invoke URL
- `api_execution_arn` (string): API Gateway execution ARN

## Data Models

### Variable Data Model

**Root Module Variables:**
```hcl
variable "environment" {
  description = "Deployment environment (production, development, test)"
  type        = string
  validation {
    condition     = contains(["production", "development", "test"], var.environment)
    error_message = "Environment must be production, development, or test"
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.12"
}

variable "bedrock_model_arn" {
  description = "ARN of the Bedrock model for Lambda function access"
  type        = string
}
```

### Local Values Data Model

**Computed Values:**
```hcl
locals {
  # Resource naming prefix
  resource_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Timestamp   = timestamp()
  }
  
  # Lambda configuration
  lambda_function_name = "${local.resource_prefix}-chatbot"
  lambda_timeout       = var.environment == "production" ? 30 : 60
  
  # DynamoDB configuration
  dynamodb_table_name = "${local.resource_prefix}-chat-history"
  dynamodb_billing    = var.environment == "production" ? "PROVISIONED" : "PAY_PER_REQUEST"
}
```

### Module Output Data Model

**Standard Output Pattern:**
Each module exports:
- Primary resource ARN (for IAM permissions)
- Primary resource name (for references)
- Primary resource ID (for dependencies)

**Example (DynamoDB Module):**
```hcl
output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.this.arn
}

output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.this.name
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.this.id
}
```

## Error Handling

### Terraform Validation Errors

**Variable Validation:**
- Environment variable must be one of: production, development, test
- Project name must match pattern: lowercase alphanumeric with hyphens
- AWS region must be valid AWS region code
- ARNs must match AWS ARN format

**Implementation:**
```hcl
variable "bedrock_model_arn" {
  description = "ARN of the Bedrock model"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:bedrock:[a-z0-9-]+:[0-9]+:model/.+$", var.bedrock_model_arn))
    error_message = "Bedrock model ARN must be valid AWS ARN format"
  }
}
```

### State Management Errors

**Backend Initialization Failures:**
- Missing backend.hcl file: Provide clear error message with expected file location
- S3 bucket doesn't exist: Pre-create S3 bucket or use local backend for development
- DynamoDB table doesn't exist: Pre-create table or disable state locking

**State Lock Conflicts:**
- Concurrent terraform apply: Wait for lock release or force-unlock (with caution)
- Stale locks: Implement lock timeout and manual unlock procedure

### Module Dependency Errors

**Missing Required Outputs:**
- Module doesn't export required output: Add output to module
- Output referenced before module creation: Use depends_on for explicit ordering

**Circular Dependencies:**
- Module A depends on Module B which depends on Module A: Refactor to break cycle
- Use data sources for read-only dependencies

### Resource Creation Failures

**IAM Permission Errors:**
- Insufficient permissions to create resources: Document required IAM permissions
- Cross-account role assumption failures: Verify assume_role configuration

**Resource Naming Conflicts:**
- Resource name already exists: Use unique naming with environment prefix
- Global namespace conflicts (S3 buckets): Include account ID or random suffix

**Quota Limits:**
- AWS service quota exceeded: Request quota increase or use different resource type
- Lambda concurrent execution limit: Implement reserved concurrency

## Testing Strategy

Since this is an Infrastructure as Code (IaC) refactoring project, property-based testing is not applicable. Instead, the testing strategy focuses on validation, integration testing, and compliance checks appropriate for Terraform configurations.

### 1. Terraform Validation Tests

**Static Validation:**
- Run `terraform validate` to check syntax and configuration correctness
- Run `terraform fmt -check` to verify formatting compliance
- Use `tflint` for additional linting and best practices validation

**Variable Validation:**
- Test variable validation rules with valid and invalid inputs
- Verify validation error messages are clear and actionable

**Example Test Cases:**
- Valid environment values: "production", "development", "test"
- Invalid environment values: "prod", "dev", "staging" (should fail validation)
- Valid project names: "chatbot", "my-project-123"
- Invalid project names: "MyProject", "project_name" (should fail validation)

### 2. Terraform Plan Tests

**Plan Verification:**
- Run `terraform plan` for each environment with respective .tfvars files
- Verify plan output shows expected resources to be created
- Ensure no unexpected resource changes or deletions
- Verify resource counts match expectations

**Environment-Specific Plans:**
- Development: Verify local backend, PAY_PER_REQUEST billing
- Test: Verify remote backend, appropriate resource sizing
- Production: Verify remote backend, PROVISIONED billing, encryption enabled

**Example Test Workflow:**
```bash
# Test development environment
cd environments/shared
terraform init -backend-config=../development/backend.hcl
terraform plan -var-file=../development/terraform.tfvars -out=dev.tfplan

# Verify plan output
terraform show -json dev.tfplan | jq '.resource_changes | length'
```

### 3. Module Integration Tests

**Module Isolation Testing:**
- Test each module independently with mock inputs
- Verify module outputs are correctly exported
- Test module with various input combinations

**Cross-Module Dependency Testing:**
- Verify DynamoDB module outputs are correctly consumed by Lambda module
- Verify Lambda module outputs are correctly consumed by API Gateway module
- Test dependency chain: DynamoDB → Lambda → API Gateway

**Example Test:**
```hcl
# Test Lambda module with mock DynamoDB outputs
module "chat_lambda_test" {
  source = "../../modules/chat_lambda"
  
  function_name       = "test-function"
  source_file         = "../../src/chat_handler.py"
  runtime             = "python3.12"
  dynamodb_table_arn  = "arn:aws:dynamodb:us-east-1:123456789012:table/test-table"
  dynamodb_table_name = "test-table"
  bedrock_model_arn   = "arn:aws:bedrock:us-east-1:123456789012:model/test-model"
  tags                = {}
}
```

### 4. State Migration Testing

**Environment Rename Testing:**
- Test renaming "release" environment to "production"
- Verify state continuity using `terraform state mv`
- Ensure no resource recreation during rename

**Migration Procedure:**
```bash
# 1. Backup existing state
terraform state pull > backup.tfstate

# 2. Rename state resources if needed
terraform state mv 'module.old_name' 'module.new_name'

# 3. Verify plan shows no changes
terraform plan -var-file=../production/terraform.tfvars
```

### 5. Backend Configuration Testing

**Local Backend Testing:**
- Verify local backend stores state in correct location
- Test state file is created and updated correctly
- Verify no state locking conflicts in single-user scenario

**Remote Backend Testing:**
- Verify S3 backend initialization succeeds
- Test state locking with DynamoDB table
- Verify state encryption is enabled
- Test concurrent access scenarios (should block with lock)

**Backend Migration Testing:**
- Test migrating from local to remote backend
- Test migrating between different S3 buckets
- Verify state integrity after migration

### 6. Compliance and Security Testing

**Security Scanning:**
- Use `tfsec` to scan for security issues
- Use `checkov` for policy compliance checks
- Verify IAM policies follow least-privilege principle

**Best Practices Validation:**
- Verify all resources have tags
- Verify all variables have descriptions
- Verify all outputs have descriptions
- Verify provider versions are pinned

**Example Security Checks:**
- DynamoDB encryption at rest enabled
- S3 state bucket encryption enabled
- Lambda functions have appropriate IAM roles
- No hardcoded credentials or secrets

### 7. Deployment Testing

**Smoke Tests:**
- Deploy to development environment
- Verify all resources created successfully
- Test basic functionality (Lambda invocation, DynamoDB access)
- Destroy resources and verify clean teardown

**End-to-End Testing:**
- Deploy complete infrastructure to test environment
- Invoke Lambda function with test payload
- Verify DynamoDB records are created
- Verify API Gateway integration (if enabled)
- Monitor CloudWatch logs for errors

**Rollback Testing:**
- Test reverting to previous Terraform state
- Verify rollback doesn't cause resource deletion
- Test disaster recovery scenarios

### 8. Documentation Testing

**README Validation:**
- Verify deployment instructions are accurate
- Test all documented commands execute successfully
- Verify prerequisites are clearly stated

**Variable Documentation:**
- Verify all variables are documented in README
- Verify example .tfvars files are provided
- Test example values work correctly

### Testing Checklist

Before merging refactored code:
- [ ] `terraform validate` passes for all environments
- [ ] `terraform fmt -check` passes
- [ ] `tflint` passes with no errors
- [ ] `tfsec` passes with no critical issues
- [ ] `terraform plan` succeeds for all environments
- [ ] Module integration tests pass
- [ ] State migration tested successfully
- [ ] Backend configuration tested for all environments
- [ ] Deployment smoke test passes in development
- [ ] Documentation reviewed and tested

### Continuous Integration

**Automated Testing Pipeline:**
```yaml
# Example GitHub Actions workflow
name: Terraform Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        
      - name: Terraform Validate
        run: |
          cd environments/shared
          terraform init -backend=false
          terraform validate
          
      - name: TFLint
        run: |
          tflint --init
          tflint --recursive
          
      - name: TFSec
        run: tfsec .
```

## Migration Plan

### Phase 1: Preparation

1. **Backup Current State:**
   - Export current state files: `terraform state pull > backup-{env}.tfstate`
   - Document current resource names and configurations
   - Create git branch for refactoring work

2. **Create New Directory Structure:**
   - Create `environments/shared/` directory
   - Create environment-specific directories with .tfvars files
   - Keep existing environment directories temporarily for comparison

### Phase 2: Shared Configuration Migration

1. **Move Configuration Files:**
   - Copy `main.tf` from one environment to `environments/shared/main.tf`
   - Copy `variables.tf` to `environments/shared/variables.tf`
   - Copy `provider.tf` to `environments/shared/provider.tf`
   - Create `backend.tf` in `environments/shared/`

2. **Parameterize Hardcoded Values:**
   - Replace hardcoded region in provider.tf with variable
   - Replace hardcoded resource names with computed locals
   - Extract environment-specific values to variables

3. **Create Variable Files:**
   - Create `production/terraform.tfvars` with production values
   - Create `development/terraform.tfvars` with development values
   - Create `test/terraform.tfvars` with test values

### Phase 3: Environment Rename

1. **Rename Release to Production:**
   - Create `environments/production/` directory
   - Copy `release/terraform.tfvars` to `production/terraform.tfvars`
   - Update environment variable value to "production"

2. **State Migration:**
   - Initialize with production backend config
   - Verify plan shows no changes (resource names unchanged)
   - Apply if needed to update state metadata

### Phase 4: Testing and Validation

1. **Test Each Environment:**
   - Run `terraform plan` for development (should show no changes)
   - Run `terraform plan` for test (should show no changes)
   - Run `terraform plan` for production (should show no changes)

2. **Verify Outputs:**
   - Confirm all module outputs are accessible
   - Verify cross-module dependencies work correctly

### Phase 5: Cleanup

1. **Remove Old Directories:**
   - Delete `environments/dev/` (replaced by shared + development)
   - Delete `environments/test/` (replaced by shared + test)
   - Delete `environments/release/` (replaced by shared + production)

2. **Update Documentation:**
   - Update README with new deployment instructions
   - Document new directory structure
   - Provide examples for each environment

## Deployment Instructions

### Initial Setup

1. **Prerequisites:**
   - Terraform >= 1.0 installed
   - AWS CLI configured with appropriate credentials
   - Access to S3 bucket and DynamoDB table for remote backend (production/test)

2. **Clone Repository:**
   ```bash
   git clone <repository-url>
   cd terraform-project
   ```

### Deploying to Development

```bash
# Navigate to shared configuration
cd environments/shared

# Initialize with development backend (local)
terraform init -backend-config=../development/backend.hcl

# Plan deployment
terraform plan -var-file=../development/terraform.tfvars

# Apply changes
terraform apply -var-file=../development/terraform.tfvars
```

### Deploying to Test

```bash
# Navigate to shared configuration
cd environments/shared

# Initialize with test backend (remote S3)
terraform init -backend-config=../test/backend.hcl

# Plan deployment
terraform plan -var-file=../test/terraform.tfvars

# Apply changes
terraform apply -var-file=../test/terraform.tfvars
```

### Deploying to Production

```bash
# Navigate to shared configuration
cd environments/shared

# Initialize with production backend (remote S3)
terraform init -backend-config=../production/backend.hcl

# Plan deployment
terraform plan -var-file=../production/terraform.tfvars

# Review plan carefully before applying
terraform apply -var-file=../production/terraform.tfvars
```

### Switching Between Environments

When switching between environments, re-run `terraform init` with the appropriate backend configuration:

```bash
# Switch from development to production
terraform init -reconfigure -backend-config=../production/backend.hcl
```

## Conclusion

This design provides a comprehensive solution for refactoring the Terraform project to eliminate duplication while maintaining flexibility for multi-environment deployments. The key architectural decisions—centralized shared configuration, environment-specific variable files, explicit dependency management, and flexible backend configuration—align with Terraform best practices and enable maintainable infrastructure as code.

The refactored structure reduces maintenance overhead by ensuring infrastructure changes are made in a single location, while preserving the ability to customize deployments per environment through variable files. The output-as-input pattern makes dependencies explicit and modules properly decoupled, improving code clarity and reusability.
