# Implementation Plan: AWS Data Lakehouse MVP

## Overview

This implementation plan creates an AWS Data Lakehouse MVP using Terraform for infrastructure, sample Airflow DAGs for orchestration, Step Functions for workflow execution, and dbt for data transformations with Iceberg tables. Tasks are organized to build foundational components first, then layer on orchestration and analytics.

## Tasks

- [x] 1. Set up project structure and Terraform foundation
  - [x] 1.1 Create directory structure for Terraform modules, Airflow DAGs, and dbt project
    - Create `terraform/`, `terraform/modules/`, `dags/`, `dbt_project/` directories
    - Create placeholder files for each module
    - _Requirements: 8.2_
  
  - [x] 1.2 Configure Terraform root module with AWS provider and backend
    - Create `terraform/main.tf` with AWS provider for ros-sandbox profile
    - Create `terraform/backend.tf` with S3 backend configuration
    - Create `terraform/variables.tf` with environment and project_name variables
    - Create `terraform/outputs.tf` for cross-module outputs
    - _Requirements: 8.1, 8.5_
  
  - [x] 1.3 Create shared locals and tagging configuration
    - Define naming convention in locals block
    - Configure default_tags for cost allocation
    - _Requirements: 8.6, 9.6_

- [x] 2. Implement S3 storage module
  - [x] 2.1 Create storage module with data lake bucket
    - Create `terraform/modules/storage/main.tf` with S3 bucket resource
    - Enable versioning, KMS encryption, and public access block
    - Configure lifecycle rules for storage tiering
    - _Requirements: 1.1, 1.3, 1.4, 1.5_
  
  - [x] 2.2 Create DAGs bucket for MWAA
    - Add S3 bucket for Airflow DAG storage
    - Configure versioning for DAG version control
    - _Requirements: 4.3_
  
  - [x] 2.3 Create storage module variables and outputs
    - Create `terraform/modules/storage/variables.tf`
    - Create `terraform/modules/storage/outputs.tf` with bucket names and ARNs
    - _Requirements: 8.3, 8.4_
  
  - [ ]* 2.4 Write property test for S3 bucket security configuration
    - **Property 2: S3 Bucket Security Configuration**
    - Validate versioning, encryption, public access block, lifecycle rules
    - **Validates: Requirements 1.1, 1.3, 1.4, 1.5**

- [x] 3. Implement Glue catalog module
  - [x] 3.1 Create catalog module with Glue database and crawlers
    - Create `terraform/modules/catalog/main.tf` with Glue database
    - Create three Glue crawlers for raw, processed, curated layers
    - Configure crawler schedules and S3 targets
    - _Requirements: 2.1, 2.2, 2.5_
  
  - [x] 3.2 Create IAM role for Glue crawlers
    - Create IAM role with S3 read and Glue catalog write permissions
    - Attach AWSGlueServiceRole managed policy
    - _Requirements: 2.4, 9.4_
  
  - [x] 3.3 Create catalog module variables and outputs
    - Create `terraform/modules/catalog/variables.tf`
    - Create `terraform/modules/catalog/outputs.tf` with database and crawler names
    - _Requirements: 8.3, 8.4_
  
  - [ ]* 3.4 Write property test for Glue crawler configuration
    - **Property 10: Glue Crawler Configuration**
    - Validate S3 targets, schedules, and database references
    - **Validates: Requirements 2.2, 2.5**

- [x] 4. Implement DynamoDB metadata module
  - [x] 4.1 Create metadata module with DynamoDB table
    - Create `terraform/modules/metadata/main.tf` with DynamoDB table
    - Configure partition key (pipeline_name) and sort key (execution_date)
    - Enable point-in-time recovery
    - Set PAY_PER_REQUEST billing mode
    - _Requirements: 3.1, 3.3, 3.4, 3.5_
  
  - [x] 4.2 Create GSI for status queries
    - Add global secondary index on status and start_time
    - _Requirements: 3.3_
  
  - [x] 4.3 Create metadata module variables and outputs
    - Create `terraform/modules/metadata/variables.tf`
    - Create `terraform/modules/metadata/outputs.tf` with table name and ARN
    - _Requirements: 8.3, 8.4_
  
  - [ ]* 4.4 Write property test for DynamoDB key schema
    - **Property 3: DynamoDB Key Schema Correctness**
    - Validate partition key and sort key configuration
    - **Validates: Requirements 3.1, 3.3**

- [x] 5. Checkpoint - Validate storage and metadata modules
  - Run `terraform validate` on all modules
  - Run `terraform plan` to verify resource creation
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement Step Functions workflow module
  - [x] 6.1 Create workflow module with state machine
    - Create `terraform/modules/workflow/main.tf` with Step Functions resource
    - Create `terraform/modules/workflow/state_machine.json` with state definition
    - _Requirements: 5.1_
  
  - [x] 6.2 Implement state machine definition
    - Add RecordPipelineStart state (DynamoDB PutItem)
    - Add StartRawCrawler and WaitForRawCrawler states
    - Add RunDbtTransformations state (Athena query placeholder)
    - Add StartCuratedCrawler and WaitForCuratedCrawler states
    - Add RecordPipelineSuccess and RecordPipelineFailure states
    - Configure retry policies and catch blocks on all task states
    - _Requirements: 5.2, 5.3, 5.4_
  
  - [x] 6.3 Create IAM role for Step Functions
    - Create IAM role with DynamoDB, Glue, and Athena permissions
    - Add trust policy for states.amazonaws.com
    - _Requirements: 5.6, 9.3_
  
  - [x] 6.4 Create workflow module variables and outputs
    - Create `terraform/modules/workflow/variables.tf`
    - Create `terraform/modules/workflow/outputs.tf` with state machine ARN
    - _Requirements: 8.3, 8.4_
  
  - [ ]* 6.5 Write property test for state machine structure
    - **Property 5: Step Functions State Machine Structure**
    - Validate required states, retry policies, and catch blocks
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5**

- [x] 7. Implement Athena analytics module
  - [x] 7.1 Create analytics module with Athena workgroup
    - Create `terraform/modules/analytics/main.tf` with Athena workgroup
    - Configure query result location in S3
    - Set bytes_scanned_cutoff for cost control
    - _Requirements: 6.1, 6.2_
  
  - [x] 7.2 Create sample named queries
    - Add named query for Iceberg table creation example
    - Add named query for time travel query example
    - _Requirements: 6.4_
  
  - [x] 7.3 Create analytics module variables and outputs
    - Create `terraform/modules/analytics/variables.tf`
    - Create `terraform/modules/analytics/outputs.tf` with workgroup name
    - _Requirements: 8.3, 8.4_

- [x] 8. Implement MWAA orchestration module
  - [x] 8.1 Create orchestration module with MWAA environment
    - Create `terraform/modules/orchestration/main.tf` with MWAA environment
    - Configure mw1.small environment class
    - Reference DAGs bucket from storage module
    - _Requirements: 4.1, 4.3_
  
  - [x] 8.2 Configure MWAA VPC networking
    - Create VPC, private subnets, and security groups (or reference existing)
    - Configure MWAA network configuration
    - _Requirements: 4.2_
  
  - [x] 8.3 Create IAM role for MWAA execution
    - Create IAM role with Step Functions invoke permissions
    - Add Glue crawler start permissions
    - Add S3 DAG bucket read permissions
    - _Requirements: 9.1, 9.2_
  
  - [x] 8.4 Create orchestration module variables and outputs
    - Create `terraform/modules/orchestration/variables.tf`
    - Create `terraform/modules/orchestration/outputs.tf` with MWAA URL
    - _Requirements: 8.3, 8.4_

- [x] 9. Checkpoint - Validate all Terraform modules
  - Run `terraform validate` on complete configuration
  - Run `terraform plan` to verify all resources
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement sample Airflow DAG
  - [x] 10.1 Create lakehouse pipeline DAG
    - Create `dags/lakehouse_pipeline.py`
    - Use StepFunctionStartExecutionOperator to trigger workflow
    - Use StepFunctionExecutionSensor to monitor completion
    - Set retries=0 in default_args
    - _Requirements: 4.4, 4.6, 4.7_
  
  - [x] 10.2 Configure DAG scheduling and dependencies
    - Set daily schedule interval
    - Configure task dependencies
    - Add DAG documentation
    - _Requirements: 4.5_
  
  - [ ]* 10.3 Write property test for DAG delegation pattern
    - **Property 6: Airflow DAG Delegation Pattern**
    - Validate Step Functions operators and retries=0
    - **Validates: Requirements 4.4, 4.6, 4.7**

- [x] 11. Implement dbt project
  - [x] 11.1 Create dbt project structure
    - Create `dbt_project/dbt_project.yml` with Athena adapter config
    - Create `dbt_project/profiles.yml.example`
    - Create `dbt_project/packages.yml` for dbt-athena
    - _Requirements: 7.1_
  
  - [x] 11.2 Create staging models
    - Create `dbt_project/models/staging/` directory
    - Create `stg_raw_events.sql` staging model
    - Create `stg_raw_users.sql` staging model
    - Create `_staging__models.yml` with schema tests
    - _Requirements: 7.3, 7.6_
  
  - [x] 11.3 Create mart models with Iceberg configuration
    - Create `dbt_project/models/marts/` directory
    - Create `fct_events.sql` with Iceberg table config
    - Create `dim_users.sql` with Iceberg table config
    - Configure partitioning, format, and s3_data_dir
    - Create `_marts__models.yml` with schema tests
    - _Requirements: 7.2, 7.4, 7.5, 7.7_
  
  - [x] 11.4 Create Iceberg configuration macro
    - Create `dbt_project/macros/iceberg_config.sql`
    - Define reusable Iceberg table properties
    - _Requirements: 7.5_
  
  - [ ]* 11.5 Write property test for dbt Iceberg configuration
    - **Property 7: dbt Iceberg Model Configuration**
    - Validate table_type, format, and s3_data_dir settings
    - **Validates: Requirements 7.1, 7.2, 7.5, 7.7**

- [x] 12. Wire Terraform modules together
  - [x] 12.1 Update root module to instantiate all modules
    - Add module blocks for storage, catalog, metadata, workflow, analytics, orchestration
    - Pass outputs between modules as inputs
    - _Requirements: 8.2_
  
  - [x] 12.2 Create environment-specific tfvars
    - Create `terraform/environments/sandbox/terraform.tfvars`
    - Set ros-sandbox specific values
    - _Requirements: 8.3_
  
  - [ ]* 12.3 Write property test for IAM policy completeness
    - **Property 4: IAM Policy Completeness**
    - Validate all required actions in IAM policies
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4**
  
  - [ ]* 12.4 Write property test for module structure
    - **Property 8: Terraform Module Structure**
    - Validate main.tf, variables.tf, outputs.tf in each module
    - **Validates: Requirements 8.2, 8.3, 8.4**
  
  - [ ]* 12.5 Write property test for resource naming
    - **Property 9: Resource Naming Consistency**
    - Validate naming pattern across all resources
    - **Validates: Requirements 9.6**

- [x] 13. Create documentation
  - [x] 13.1 Create main README with architecture overview
    - Add architecture diagram
    - Document data flow from ingestion to consumption
    - Include deployment instructions
    - _Requirements: 10.1, 10.2_
  
  - [x] 13.2 Document best practices for each service
    - Add S3 best practices (encryption, lifecycle, versioning)
    - Add Glue best practices (crawler scheduling, partitioning)
    - Add Step Functions best practices (error handling, timeouts)
    - Add MWAA best practices (DAG design, monitoring)
    - Add Athena best practices (partitioning, compression)
    - Add dbt best practices (model organization, testing)
    - _Requirements: 10.3_
  
  - [x] 13.3 Create operational runbooks
    - Document common operational tasks
    - Include troubleshooting guides
    - _Requirements: 10.4_
  
  - [x] 13.4 Document cost optimization and security
    - Add cost optimization recommendations
    - Document security considerations and IAM best practices
    - _Requirements: 10.5, 10.6_

- [x] 14. Final checkpoint - Complete validation
  - Run `terraform validate` and `terraform plan`
  - Validate all DAGs load correctly
  - Run dbt compile to validate models
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 15. Write property test for Terraform configuration validity
  - **Property 1: Terraform Configuration Validity**
  - Validate terraform validate succeeds
  - Validate terraform plan contains expected resources
  - **Validates: Requirements 1.1, 1.3, 1.4, 1.5, 2.1, 2.2, 2.4, 2.5, 3.1, 3.4, 3.5, 4.1, 4.2, 4.3, 5.1, 5.6, 6.1, 6.2, 8.1, 8.5, 8.6**

## Notes

- Tasks marked with `*` are optional property tests that can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints at tasks 5, 9, and 14 ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Terraform modules are built in dependency order: storage → catalog → metadata → workflow → analytics → orchestration
