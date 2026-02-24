# Step Functions Workflow Module - State machine for pipeline execution
# Requirements: 5.1

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  default_tags = {
    Module      = "workflow"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Step Functions State Machine for data pipeline orchestration
resource "aws_sfn_state_machine" "data_pipeline" {
  name     = "${local.name_prefix}-data-pipeline"
  role_arn = aws_iam_role.step_functions.arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/state_machine.json", {
    MetadataTableName          = var.metadata_table_name
    RawCrawlerName             = var.raw_crawler_name
    CuratedCrawlerName         = var.curated_crawler_name
    GlueDatabaseName           = var.glue_database_name
    AthenaWorkgroup            = var.athena_workgroup
    DbtExecutorLambdaArn       = aws_lambda_function.dbt_executor.arn
    DbtTestExecutorLambdaArn   = aws_lambda_function.dbt_test_executor.arn
    DataLakeBucket             = var.data_lake_bucket_name
  })

  tags = local.default_tags

  depends_on = [aws_lambda_function.dbt_executor, aws_lambda_function.dbt_test_executor]
}

# IAM Role for Step Functions
# Requirements: 5.6, 9.3
resource "aws_iam_role" "step_functions" {
  name = "${local.name_prefix}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = local.default_tags
}

# IAM Policy for DynamoDB access - PutItem, UpdateItem, GetItem on metadata table
# Requirements: 9.3
resource "aws_iam_policy" "step_functions_dynamodb" {
  name        = "${local.name_prefix}-sfn-dynamodb-policy"
  description = "Allow Step Functions to read/write pipeline metadata in DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = var.metadata_table_arn
      }
    ]
  })

  tags = local.default_tags
}

# IAM Policy for Glue access - StartCrawler, GetCrawler on crawlers
# Requirements: 9.3
resource "aws_iam_policy" "step_functions_glue" {
  name        = "${local.name_prefix}-sfn-glue-policy"
  description = "Allow Step Functions to start and monitor Glue crawlers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueCrawlerAccess"
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.default_tags
}

# IAM Policy for Athena access - StartQueryExecution, GetQueryExecution, GetQueryResults
# Requirements: 9.3
resource "aws_iam_policy" "step_functions_athena" {
  name        = "${local.name_prefix}-sfn-athena-policy"
  description = "Allow Step Functions to execute and monitor Athena queries"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3QueryResultsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = local.default_tags
}

# Attach DynamoDB policy to Step Functions role
resource "aws_iam_role_policy_attachment" "step_functions_dynamodb" {
  role       = aws_iam_role.step_functions.name
  policy_arn = aws_iam_policy.step_functions_dynamodb.arn
}

# Attach Glue policy to Step Functions role
resource "aws_iam_role_policy_attachment" "step_functions_glue" {
  role       = aws_iam_role.step_functions.name
  policy_arn = aws_iam_policy.step_functions_glue.arn
}

# Attach Athena policy to Step Functions role
resource "aws_iam_role_policy_attachment" "step_functions_athena" {
  role       = aws_iam_role.step_functions.name
  policy_arn = aws_iam_policy.step_functions_athena.arn
}
