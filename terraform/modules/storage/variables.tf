# Storage module input variables
# Requirements: 8.3 (define variables for environment-specific configuration)

variable "environment" {
  type        = string
  description = "Environment name (e.g., sandbox, dev, prod)"
}

variable "project_name" {
  type        = string
  description = "Project identifier for resource naming"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for S3 encryption. Uses aws/s3 managed key if not provided."
  default     = null
}
