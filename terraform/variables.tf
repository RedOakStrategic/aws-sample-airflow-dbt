# Input variables for AWS Data Lakehouse MVP

#------------------------------------------------------------------------------
# Core Configuration
#------------------------------------------------------------------------------

variable "environment" {
  type        = string
  description = "Environment name (e.g., sandbox, dev, prod)"

  validation {
    condition     = contains(["sandbox", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: sandbox, dev, staging, prod."
  }
}

variable "project_name" {
  type        = string
  description = "Project identifier for resource naming"
  default     = "lakehouse-mvp"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

#------------------------------------------------------------------------------
# Storage Module Variables
#------------------------------------------------------------------------------

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for S3 encryption. Uses aws/s3 managed key if not provided."
  default     = null
}

#------------------------------------------------------------------------------
# Catalog Module Variables
#------------------------------------------------------------------------------

variable "crawler_schedule" {
  type        = string
  description = "Cron expression for Glue crawler schedule (AWS Glue cron format)"
  default     = "cron(0 */6 * * ? *)" # Every 6 hours
}

#------------------------------------------------------------------------------
# Metadata Module Variables
#------------------------------------------------------------------------------

variable "dynamodb_billing_mode" {
  type        = string
  description = "DynamoDB billing mode (PAY_PER_REQUEST for serverless, PROVISIONED for fixed capacity)"
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "dynamodb_billing_mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

#------------------------------------------------------------------------------
# Analytics Module Variables
#------------------------------------------------------------------------------

variable "athena_bytes_scanned_cutoff" {
  type        = number
  description = "Maximum bytes scanned per Athena query for cost control"
  default     = 10737418240 # 10 GB
}

#------------------------------------------------------------------------------
# MWAA Orchestration Module Variables
#------------------------------------------------------------------------------

variable "mwaa_environment_class" {
  type        = string
  description = "MWAA environment class"
  default     = "mw1.small"
}

variable "mwaa_airflow_version" {
  type        = string
  description = "Apache Airflow version for MWAA"
  default     = "2.8.1"
}

variable "mwaa_max_workers" {
  type        = number
  description = "Maximum number of workers for MWAA"
  default     = 2
}

variable "mwaa_min_workers" {
  type        = number
  description = "Minimum number of workers for MWAA"
  default     = 1
}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------

variable "create_vpc" {
  type        = bool
  description = "Whether to create a new VPC for MWAA. If false, vpc_id and private_subnet_ids must be provided."
  default     = true
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
