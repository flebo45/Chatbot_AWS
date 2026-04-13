# Implementation Plan: Terraform Structure Refactor

## Overview

This plan refactors the Terraform project to eliminate configuration duplication across environments while maintaining three distinct deployment targets (production, development, test). The implementation follows a phased approach: create new structure, migrate configuration, refactor modules, test thoroughly, and clean up old directories.

## Tasks

- [x] 1. Create new directory structure and shared configuration foundation
  - [x] 1.1 Create environments/shared/ directory and subdirectories
    - Create environments/shared/ directory
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 9.3_

  - [x] 1.2 Create shared provider configuration (environments/shared/provider.tf)
    - Define terraform block with required_version >= 1.0
    - Define required_providers for aws (~> 5.0) and archive (~> 2.0)
    - Configure AWS provider with region variable and default_tags
    - _Requirements: 2.1, 6.1, 6.3, 10.2_

  - [x] 1.3 Create shared backend configuration (environments/shared/backend.tf)
    - Define terraform backend block with partial configuration support
    - Add comments explaining backend.hcl usage
    - _Requirements: 2.2, 5.1, 5.2, 5.3_

  - [x] 1.4 Create shared variables file (environments/shared/variables.tf)
    - Define environment variable with validation (production, development, test)
    - Define project_name variable with validation (lowercase alphanumeric with hyphens)
    - Define aws_region variable
    - Define lambda_runtime variable with default "python3.12"
    - Define bedrock_model_arn variable with ARN format validation
    - Add descriptions and type constraints for all variables
    - _Requirements: 2.4, 3.1, 4.4, 6.1, 7.4, 8.4, 10.4_

  - [x] 1.5 Create shared outputs file (environments/shared/outputs.tf)
    - Define placeholder outputs structure for root module
    - Add descriptions for all outputs
    - _Requirements: 4.2, 10.4_

- [x] 2. Create environment-specific configuration files
  - [x] 2.1 Create production environment directory and files
    - Create environments/production/ directory
    - Create environments/production/terraform.tfvars with production values
    - Create environments/production/backend.hcl with S3 backend configuration
    - _Requirements: 1.1, 1.2, 1.3, 5.2, 8.1, 8.2, 8.4_

  - [x] 2.2 Create development environment directory and files
    - Create environments/development/ directory
    - Create environments/development/terraform.tfvars with development values
    - Create environments/development/backend.hcl with local backend configuration
    - _Requirements: 1.1, 1.3, 5.3, 8.1, 8.2, 8.4_

  - [x] 2.3 Create test environment directory and files
    - Create environments/test/ directory (if not exists)
    - Create environments/test/terraform.tfvars with test values
    - Create environments/test/backend.hcl with S3 backend configuration
    - _Requirements: 1.1, 1.3, 5.2, 8.1, 8.2, 8.4_

- [x] 3. Refactor and enhance modules with proper outputs
  - [x] 3.1 Enhance chat_lambda module outputs
    - Add lambda_function_name output to modules/chat_lambda/output.tf
    - Add lambda_role_arn output to modules/chat_lambda/output.tf
    - Ensure all outputs have descriptions
    - _Requirements: 4.2, 7.3, 10.4_

  - [x] 3.2 Create dynamodb module with complete interface
    - Create modules/dynamodb/ directory
    - Create modules/dynamodb/main.tf with DynamoDB table resource
    - Create modules/dynamodb/variables.tf with table_name, billing_mode, read_capacity, write_capacity, tags
    - Create modules/dynamodb/outputs.tf with table_arn, table_name, table_id outputs
    - Create modules/dynamodb/versions.tf with provider version constraints
    - _Requirements: 4.2, 7.1, 7.3, 7.4, 9.1, 10.4_

  - [x] 3.3 Create api_gateway module with complete interface
    - Create modules/api_gateway/ directory
    - Create modules/api_gateway/main.tf with API Gateway resources
    - Create modules/api_gateway/variables.tf with api_name, lambda_function_arn, lambda_function_name, stage_name, tags
    - Create modules/api_gateway/outputs.tf with api_id, api_endpoint, api_execution_arn outputs
    - Create modules/api_gateway/versions.tf with provider version constraints
    - _Requirements: 4.2, 7.1, 7.3, 7.4, 9.1, 10.4_

  - [x] 3.4 Add tags variable to chat_lambda module
    - Add tags variable to modules/chat_lambda/variables.tf
    - Apply tags to Lambda function and IAM role resources
    - _Requirements: 7.1, 7.2, 7.4_

- [x] 4. Implement root module with output-as-input pattern
  - [x] 4.1 Create locals block in environments/shared/main.tf
    - Define resource_prefix local combining project_name and environment
    - Define common_tags local with Environment, Project, ManagedBy
    - Define computed values for resource naming
    - _Requirements: 3.2, 3.3_

  - [x] 4.2 Instantiate dynamodb module in environments/shared/main.tf
    - Call dynamodb module with computed table name
    - Pass common_tags to module
    - _Requirements: 4.1, 4.2, 10.5_

  - [x] 4.3 Instantiate chat_lambda module with explicit dependencies
    - Call chat_lambda module with computed function name
    - Pass module.dynamodb.table_arn as dynamodb_table_arn input
    - Pass module.dynamodb.table_name as dynamodb_table_name input
    - Pass bedrock_model_arn variable as input
    - Pass common_tags to module
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 7.2, 10.5_

  - [x] 4.4 Instantiate api_gateway module with Lambda outputs
    - Call api_gateway module with computed API name
    - Pass module.chat_lambda.lambda_arn as lambda_function_arn input
    - Pass module.chat_lambda.lambda_function_name as lambda_function_name input
    - Pass common_tags to module
    - _Requirements: 4.1, 4.2, 4.5, 10.5_

  - [x] 4.5 Define root module outputs in environments/shared/outputs.tf
    - Export Lambda function ARN from chat_lambda module
    - Export DynamoDB table name from dynamodb module
    - Export API Gateway endpoint from api_gateway module
    - Add descriptions for all outputs
    - _Requirements: 4.2, 10.4_

- [x] 5. Checkpoint - Validate new structure
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Test and validate the refactored structure
  - [x] 6.1 Run terraform validate for shared configuration
    - Navigate to environments/shared/
    - Run terraform init -backend=false
    - Run terraform validate
    - Run terraform fmt -check
    - _Requirements: 2.5, 10.1, 10.2, 10.3_

  - [x] 6.2 Test development environment plan
    - Initialize with development backend: terraform init -backend-config=../development/backend.hcl
    - Run terraform plan with development variables: terraform plan -var-file=../development/terraform.tfvars
    - Verify plan output shows expected resources
    - _Requirements: 1.1, 5.4, 8.2_

  - [x] 6.3 Test production environment plan
    - Reconfigure backend: terraform init -reconfigure -backend-config=../production/backend.hcl
    - Run terraform plan with production variables: terraform plan -var-file=../production/terraform.tfvars
    - Verify plan output shows expected resources
    - _Requirements: 1.1, 1.2, 5.4, 8.2_

  - [ ]* 6.4 Test test environment plan
    - Reconfigure backend: terraform init -reconfigure -backend-config=../test/backend.hcl
    - Run terraform plan with test variables: terraform plan -var-file=../test/terraform.tfvars
    - Verify plan output shows expected resources
    - _Requirements: 1.1, 5.4, 8.2_

- [x] 7. Checkpoint - Ensure validation passes
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Create migration documentation and cleanup plan
  - [x] 8.1 Create migration guide document
    - Document state backup procedure
    - Document environment rename steps (release → production)
    - Document state migration commands
    - Document rollback procedure
    - _Requirements: 1.2, 2.5_

  - [x] 8.2 Create deployment instructions document
    - Document prerequisites (Terraform version, AWS CLI, credentials)
    - Document deployment commands for each environment
    - Document environment switching procedure
    - Document backend configuration details
    - _Requirements: 5.4, 6.4, 8.2, 9.5_

  - [x] 8.3 Update project README
    - Document new directory structure
    - Add quick start guide for each environment
    - Add troubleshooting section
    - Add requirements and prerequisites
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 9. Final checkpoint - Review and user approval
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation and user feedback
- This is an IaC refactoring project - no property-based tests are applicable
- State migration and cleanup of old directories should be done manually by the user after validation
- The implementation does NOT include actual deployment or state migration - only artifact creation
