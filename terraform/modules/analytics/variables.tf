# Analytics Module Input Variables
# Requirements: 6.1, 6.2

variable "environment" {
  type        = string
  description = "Environment name (e.g., sandbox, dev, prod)"
}

variable "project_name" {
  type        = string
  description = "Project identifier for resource naming"
}

variable "query_results_bucket" {
  type        = string
  description = "S3 bucket for Athena query results"
}

variable "glue_database_name" {
  type        = string
  description = "Glue database name for Athena queries"
}

variable "bytes_scanned_cutoff" {
  type        = number
  description = "Maximum bytes scanned per query for cost control"
  default     = 10737418240 # 10 GB
}
