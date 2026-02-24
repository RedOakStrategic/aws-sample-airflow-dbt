# MWAA Orchestration Module - Managed Airflow environment
# Creates AWS MWAA environment for pipeline orchestration
# Using new name to avoid conflict with stuck environment

locals {
  mwaa_name = "${var.project_name}-${var.environment}-airflow"
}

# Security group for MWAA environment
resource "aws_security_group" "mwaa" {
  name        = "${local.mwaa_name}-sg"
  description = "Security group for MWAA environment"
  vpc_id      = local.vpc_id

  # MWAA requires self-referencing ingress for worker communication
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.mwaa_name}-sg"
  })
}

# MWAA Execution Role
resource "aws_iam_role" "mwaa_execution" {
  name = "${local.mwaa_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "airflow.amazonaws.com",
            "airflow-env.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

# Base MWAA execution policy for environment operation
resource "aws_iam_role_policy" "mwaa_execution_base" {
  name = "${local.mwaa_name}-execution-base-policy"
  role = aws_iam_role.mwaa_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "airflow:PublishMetrics"
        ]
        Resource = "arn:aws:airflow:*:*:environment/${local.mwaa_name}"
      },
      {
        Effect = "Deny"
        Action = "s3:ListAllMyBuckets"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:List*"
        ]
        Resource = [
          var.dags_bucket_arn,
          "${var.dags_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults"
        ]
        Resource = "arn:aws:logs:*:*:log-group:airflow-${local.mwaa_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage"
        ]
        Resource = "arn:aws:sqs:*:*:airflow-celery-*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "sqs.*.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Pipeline execution policy for Step Functions and Glue integration
resource "aws_iam_role_policy" "mwaa_execution_pipeline" {
  name = "${local.mwaa_name}-execution-pipeline-policy"
  role = aws_iam_role.mwaa_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StepFunctionsStartExecution"
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = var.state_machine_arn
      },
      {
        Sid    = "StepFunctionsDescribeExecution"
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = "arn:aws:states:*:*:execution:*"
      },
      {
        Sid    = "GlueCrawlerManagement"
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3DagBucketRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.dags_bucket_arn,
          "${var.dags_bucket_arn}/*"
        ]
      }
    ]
  })
}

# dbt/Athena execution policy for data transformations
resource "aws_iam_role_policy" "mwaa_execution_dbt" {
  name = "${local.mwaa_name}-execution-dbt-policy"
  role = aws_iam_role.mwaa_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryExecution"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetWorkGroup",
          "athena:BatchGetQueryExecution"
        ]
        Resource = [
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
          "glue:BatchGetPartition",
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
        Sid    = "S3DataLakeAccess"
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
}

# S3 folder structure for MWAA
resource "aws_s3_object" "dags_folder" {
  bucket = var.dags_bucket_name
  key    = "dags/"
  source = "/dev/null"
}

resource "aws_s3_object" "requirements" {
  bucket  = var.dags_bucket_name
  key     = "requirements.txt"
  content = <<-EOF
    # Python requirements for MWAA
    apache-airflow-providers-amazon>=8.0.0
    dbt-athena-community>=1.7.0
  EOF
}

# MWAA Environment - Public access, standard class (serverless not yet in Terraform)
resource "aws_mwaa_environment" "main" {
  name = local.mwaa_name

  airflow_version    = var.airflow_version
  environment_class  = var.environment_class
  execution_role_arn = aws_iam_role.mwaa_execution.arn
  
  # DAG configuration
  dag_s3_path          = "dags/"
  source_bucket_arn    = var.dags_bucket_arn
  requirements_s3_path = "requirements.txt"

  # Worker configuration
  max_workers = var.max_workers
  min_workers = var.min_workers

  # Network configuration - required even for public access
  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = local.private_subnet_ids
  }

  # Logging configuration
  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }
    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  # PUBLIC access for easy browser access
  webserver_access_mode = "PUBLIC_ONLY"

  # Weekly maintenance window
  weekly_maintenance_window_start = "SUN:03:00"

  tags = merge(var.tags, {
    Name = local.mwaa_name
  })

  depends_on = [
    aws_s3_object.dags_folder,
    aws_s3_object.requirements
  ]
}
