# Athena Analytics Module - Workgroup and Named Queries
# Requirements: 6.1 (workgroup with query result location), 6.2 (cost controls)

# -----------------------------------------------------------------------------
# Athena Workgroup (Requirements 6.1, 6.2)
# Provides query execution environment with cost controls and CloudWatch metrics
# -----------------------------------------------------------------------------
resource "aws_athena_workgroup" "main" {
  name = "${var.project_name}-${var.environment}-workgroup"

  configuration {
    # Enforce workgroup configuration - users cannot override these settings
    enforce_workgroup_configuration = true

    # Cost control: limit bytes scanned per query (Requirement 6.2)
    bytes_scanned_cutoff_per_query = var.bytes_scanned_cutoff

    # Enable CloudWatch metrics for monitoring
    publish_cloudwatch_metrics_enabled = true

    # Query result configuration (Requirement 6.1)
    result_configuration {
      output_location = "s3://${var.query_results_bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  # Prevent accidental deletion of workgroup with queries
  force_destroy = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-workgroup"
    Environment = var.environment
    Module      = "analytics"
    Purpose     = "athena-queries"
  }
}

# -----------------------------------------------------------------------------
# Sample Named Queries (Requirement 6.4)
# Demonstrates Iceberg table operations for data lakehouse patterns
# -----------------------------------------------------------------------------

# Named query: Iceberg table creation example
resource "aws_athena_named_query" "iceberg_table_example" {
  name        = "${var.project_name}-${var.environment}-iceberg-table-example"
  workgroup   = aws_athena_workgroup.main.name
  database    = var.glue_database_name
  description = "Example query showing how to create an Iceberg table in the data lakehouse"

  query = <<-EOT
    CREATE TABLE IF NOT EXISTS ${var.glue_database_name}.example_iceberg_table (
      id STRING,
      name STRING,
      created_at TIMESTAMP
    )
    LOCATION 's3://${var.query_results_bucket}/curated/example_iceberg_table/'
    TBLPROPERTIES (
      'table_type' = 'ICEBERG',
      'format' = 'parquet',
      'write_compression' = 'snappy'
    )
  EOT
}

# Named query: Iceberg time travel example
resource "aws_athena_named_query" "iceberg_time_travel_example" {
  name        = "${var.project_name}-${var.environment}-iceberg-time-travel-example"
  workgroup   = aws_athena_workgroup.main.name
  database    = var.glue_database_name
  description = "Example query demonstrating Iceberg time travel capabilities"

  query = <<-EOT
    SELECT * FROM ${var.glue_database_name}.example_iceberg_table
    FOR TIMESTAMP AS OF TIMESTAMP '2024-01-01 00:00:00'
  EOT
}
