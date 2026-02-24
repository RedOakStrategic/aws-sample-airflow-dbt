# Catalog module input variables
# Requirements: 2.1, 2.2, 2.5

variable "environment" {
  type        = string
  description = "Environment name (e.g., sandbox, dev, prod)"
}

variable "project_name" {
  type        = string
  description = "Project identifier for resource naming"
}

variable "data_lake_bucket_name" {
  type        = string
  description = "S3 bucket name containing data lake layers (raw, processed, curated)"
}

variable "crawler_schedule" {
  type        = string
  description = "Cron expression for crawler schedule (AWS Glue cron format)"
  default     = "cron(0 */6 * * ? *)" # Every 6 hours
}

variable "data_lake_bucket_arn" {
  type        = string
  description = "ARN of the S3 data lake bucket for IAM policy configuration"
}

variable "step_functions_role_arn" {
  type        = string
  description = "ARN of the Step Functions execution role for Lake Formation permissions"
  default     = ""
}
