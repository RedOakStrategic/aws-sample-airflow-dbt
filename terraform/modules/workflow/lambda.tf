# Lambda function for executing dbt SQL via Athena
# This replaces the need for dbt CLI in MWAA

# Archive the Lambda code
data "archive_file" "dbt_executor" {
  type        = "zip"
  source_file = "${path.module}/lambda/dbt_athena_executor.py"
  output_path = "${path.module}/lambda/dbt_athena_executor.zip"
}

# Lambda function
resource "aws_lambda_function" "dbt_executor" {
  filename         = data.archive_file.dbt_executor.output_path
  function_name    = "${local.name_prefix}-dbt-executor"
  role             = aws_iam_role.dbt_executor.arn
  handler          = "dbt_athena_executor.lambda_handler"
  source_code_hash = data.archive_file.dbt_executor.output_base64sha256
  runtime          = "python3.11"
  timeout          = 900  # 15 minutes max for Athena queries
  memory_size      = 256

  environment {
    variables = {
      ATHENA_WORKGROUP = var.athena_workgroup
      GLUE_DATABASE    = var.glue_database_name
      S3_BUCKET        = var.data_lake_bucket_name
    }
  }

  tags = local.default_tags
}

# IAM Role for Lambda
resource "aws_iam_role" "dbt_executor" {
  name = "${local.name_prefix}-dbt-executor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.default_tags
}

# Lambda basic execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "dbt_executor_basic" {
  role       = aws_iam_role.dbt_executor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Athena and Glue access for Lambda
resource "aws_iam_policy" "dbt_executor_athena" {
  name        = "${local.name_prefix}-dbt-executor-athena"
  description = "Allow Lambda to execute Athena queries and access Glue catalog"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetWorkGroup"
        ]
        Resource = [
          "arn:aws:athena:*:*:workgroup/${var.athena_workgroup}",
          "arn:aws:athena:*:*:workgroup/*"
        ]
      },
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition"
        ]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          "arn:aws:glue:*:*:database/*",
          "arn:aws:glue:*:*:table/*"
        ]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/*"
        ]
      },
      {
        Sid    = "LakeFormationAccess"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "dbt_executor_athena" {
  role       = aws_iam_role.dbt_executor.name
  policy_arn = aws_iam_policy.dbt_executor_athena.arn
}

# Allow Step Functions to invoke Lambda
resource "aws_iam_policy" "step_functions_lambda" {
  name        = "${local.name_prefix}-sfn-lambda-policy"
  description = "Allow Step Functions to invoke dbt executor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambda"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.dbt_executor.arn
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "step_functions_lambda" {
  role       = aws_iam_role.step_functions.name
  policy_arn = aws_iam_policy.step_functions_lambda.arn
}


# =============================================================================
# Test Executor Lambda - Runs dbt tests and records to Elementary
# =============================================================================

# Archive the test executor Lambda code
data "archive_file" "dbt_test_executor" {
  type        = "zip"
  source_file = "${path.module}/lambda/dbt_test_executor.py"
  output_path = "${path.module}/lambda/dbt_test_executor.zip"
}

# Test executor Lambda function
resource "aws_lambda_function" "dbt_test_executor" {
  filename         = data.archive_file.dbt_test_executor.output_path
  function_name    = "${local.name_prefix}-dbt-test-executor"
  role             = aws_iam_role.dbt_executor.arn  # Reuse same role
  handler          = "dbt_test_executor.lambda_handler"
  source_code_hash = data.archive_file.dbt_test_executor.output_base64sha256
  runtime          = "python3.11"
  timeout          = 900  # 15 minutes max for running all tests
  memory_size      = 256

  environment {
    variables = {
      ATHENA_WORKGROUP = var.athena_workgroup
      GLUE_DATABASE    = var.glue_database_name
      S3_BUCKET        = var.data_lake_bucket_name
    }
  }

  tags = local.default_tags
}

# Update Step Functions policy to also invoke test executor
resource "aws_iam_policy" "step_functions_test_lambda" {
  name        = "${local.name_prefix}-sfn-test-lambda-policy"
  description = "Allow Step Functions to invoke dbt test executor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeTestLambda"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.dbt_test_executor.arn
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "step_functions_test_lambda" {
  role       = aws_iam_role.step_functions.name
  policy_arn = aws_iam_policy.step_functions_test_lambda.arn
}
