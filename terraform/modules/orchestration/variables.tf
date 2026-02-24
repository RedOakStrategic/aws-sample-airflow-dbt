# Orchestration module input variables

variable "environment" {
  type        = string
  description = "Environment name (e.g., sandbox, dev, prod)"
}

variable "project_name" {
  type        = string
  description = "Project identifier for resource naming"
}

variable "dags_bucket_name" {
  type        = string
  description = "S3 bucket name for DAG storage"
}

variable "dags_bucket_arn" {
  type        = string
  description = "S3 bucket ARN for DAG storage"
}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------

variable "create_vpc" {
  type        = bool
  description = "Whether to create a new VPC for MWAA. If false, vpc_id and private_subnet_ids must be provided."
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for MWAA networking. Required if create_vpc is false."
  default     = null
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for MWAA (minimum 2 in different AZs). Required if create_vpc is false."
  default     = null
}

variable "state_machine_arn" {
  type        = string
  description = "Step Functions state machine ARN to invoke"
}

variable "data_lake_bucket_arn" {
  type        = string
  description = "S3 bucket ARN for data lake storage (used by dbt)"
}

variable "environment_class" {
  type        = string
  description = "MWAA environment class"
  default     = "mw1.small"
}

variable "airflow_version" {
  type        = string
  description = "Apache Airflow version"
  default     = "2.8.1"
}

variable "max_workers" {
  type        = number
  description = "Maximum number of workers for MWAA"
  default     = 2
}

variable "min_workers" {
  type        = number
  description = "Minimum number of workers for MWAA"
  default     = 1
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}
