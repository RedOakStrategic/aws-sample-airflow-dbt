# DynamoDB Metadata Module - Pipeline metadata store
# Requirements: 3.1, 3.3, 3.4, 3.5

locals {
  table_name = "${var.project_name}-${var.environment}-pipeline-metadata"

  common_tags = {
    Module      = "metadata"
    Environment = var.environment
    Project     = var.project_name
  }
}

# -----------------------------------------------------------------------------
# DynamoDB Table for Pipeline Metadata
# Requirement 3.1: Create a DynamoDB table for pipeline metadata with partition key and sort key
# Requirement 3.3: Support querying by pipeline name and execution date
# Requirement 3.4: Configure point-in-time recovery for the metadata table
# Requirement 3.5: Set appropriate read and write capacity settings (PAY_PER_REQUEST)
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "pipeline_metadata" {
  name         = local.table_name
  billing_mode = var.billing_mode

  # Partition key: pipeline_name (String)
  # Requirement 3.1, 3.3: Enable querying by pipeline name
  hash_key = "pipeline_name"

  # Sort key: execution_date (String, ISO 8601 format)
  # Requirement 3.1, 3.3: Enable querying by execution date within a pipeline
  range_key = "execution_date"

  # Key attribute definitions
  attribute {
    name = "pipeline_name"
    type = "S"
  }

  attribute {
    name = "execution_date"
    type = "S"
  }

  # GSI attribute definitions for status-index
  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "start_time"
    type = "S"
  }

  # -----------------------------------------------------------------------------
  # Global Secondary Index: status-index
  # Requirement 3.3: Support querying pipelines by status for monitoring
  # Partition Key: status - Query all pipelines with a specific status
  # Sort Key: start_time - Order results by when the pipeline started
  # -----------------------------------------------------------------------------
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "start_time"
    projection_type = "ALL"
  }

  # Requirement 3.4: Configure point-in-time recovery for the metadata table
  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}
