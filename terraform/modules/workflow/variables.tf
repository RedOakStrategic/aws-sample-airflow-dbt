# Workflow module input variables
# Requirements: 8.3

variable "environment" {
  type        = string
  description = "Environment name (e.g., sandbox, dev, prod)"
}

variable "project_name" {
  type        = string
  description = "Project identifier for resource naming"
}

variable "glue_database_name" {
  type        = string
  description = "Name of the Glue database for the lakehouse catalog"
}

variable "raw_crawler_name" {
  type        = string
  description = "Name of the Glue crawler for raw layer"
}

variable "curated_crawler_name" {
  type        = string
  description = "Name of the Glue crawler for curated layer"
}

variable "metadata_table_name" {
  type        = string
  description = "Name of the DynamoDB metadata table"
}

variable "metadata_table_arn" {
  type        = string
  description = "ARN of the DynamoDB metadata table for IAM policy"
}

variable "athena_workgroup" {
  type        = string
  description = "Name of the Athena workgroup for query execution"
}

variable "data_lake_bucket_arn" {
  type        = string
  description = "ARN of the S3 data lake bucket for Athena query results"
}
