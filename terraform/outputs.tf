# Output values for AWS Data Lakehouse MVP
# Exposes key resource identifiers for service integration
# Requirements: 8.4

#------------------------------------------------------------------------------
# Storage Module Outputs
#------------------------------------------------------------------------------

output "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket"
  value       = module.storage.data_lake_bucket_name
}

output "data_lake_bucket_arn" {
  description = "ARN of the S3 data lake bucket"
  value       = module.storage.data_lake_bucket_arn
}

output "dags_bucket_name" {
  description = "Name of the S3 bucket for MWAA DAGs"
  value       = module.storage.dags_bucket_name
}

output "raw_prefix" {
  description = "S3 prefix for raw data layer"
  value       = module.storage.raw_prefix
}

output "processed_prefix" {
  description = "S3 prefix for processed data layer"
  value       = module.storage.processed_prefix
}

output "curated_prefix" {
  description = "S3 prefix for curated data layer"
  value       = module.storage.curated_prefix
}

#------------------------------------------------------------------------------
# Catalog Module Outputs
#------------------------------------------------------------------------------

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = module.catalog.glue_database_name
}

output "raw_crawler_name" {
  description = "Name of the raw layer Glue crawler"
  value       = module.catalog.raw_crawler_name
}

output "processed_crawler_name" {
  description = "Name of the processed layer Glue crawler"
  value       = module.catalog.processed_crawler_name
}

output "curated_crawler_name" {
  description = "Name of the curated layer Glue crawler"
  value       = module.catalog.curated_crawler_name
}

#------------------------------------------------------------------------------
# Metadata Module Outputs
#------------------------------------------------------------------------------

output "metadata_table_name" {
  description = "Name of the DynamoDB metadata table"
  value       = module.metadata.table_name
}

output "metadata_table_arn" {
  description = "ARN of the DynamoDB metadata table"
  value       = module.metadata.table_arn
}

#------------------------------------------------------------------------------
# Workflow Module Outputs
#------------------------------------------------------------------------------

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = module.workflow.state_machine_arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = module.workflow.state_machine_name
}

#------------------------------------------------------------------------------
# Analytics Module Outputs
#------------------------------------------------------------------------------

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = module.analytics.workgroup_name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = module.analytics.workgroup_arn
}

#------------------------------------------------------------------------------
# Orchestration Module Outputs
#------------------------------------------------------------------------------

output "mwaa_environment_name" {
  description = "Name of the MWAA environment"
  value       = module.orchestration.mwaa_environment_name
}

output "mwaa_webserver_url" {
  description = "URL of the MWAA Airflow webserver"
  value       = module.orchestration.mwaa_webserver_url
}

output "mwaa_execution_role_arn" {
  description = "ARN of the MWAA execution IAM role"
  value       = module.orchestration.mwaa_execution_role_arn
}

#------------------------------------------------------------------------------
# VPC Outputs (from orchestration module)
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC used by MWAA"
  value       = module.orchestration.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets used by MWAA"
  value       = module.orchestration.private_subnet_ids
}
