# Glue Catalog Module - Database and Crawlers
# Requirements: 2.1, 2.2, 2.5

locals {
  database_name = "${var.project_name}_${var.environment}_lakehouse"
  
  common_tags = {
    Module      = "catalog"
    Environment = var.environment
    Project     = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Glue Catalog Database
# Requirement 2.1: Create a Glue database for the data lakehouse catalog
# -----------------------------------------------------------------------------
resource "aws_glue_catalog_database" "lakehouse" {
  name        = local.database_name
  description = "Data lakehouse catalog for ${var.project_name} ${var.environment} environment"

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM Role for Glue Crawlers (placeholder - will be fully implemented in task 3.2)
# Requirement 2.4: Configure appropriate IAM roles for Glue_Crawler S3 access
# -----------------------------------------------------------------------------
resource "aws_iam_role" "glue_crawler" {
  name = "${var.project_name}-${var.environment}-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Attach AWSGlueServiceRole managed policy
# Requirement 2.4: Configure appropriate IAM roles for Glue_Crawler S3 access
# Requirement 9.4: Glue_Crawler SHALL have IAM permissions to read S3 and write to Glue catalog
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# -----------------------------------------------------------------------------
# Custom policy for S3 read access to data lake bucket
# Requirement 2.4: Configure appropriate IAM roles for Glue_Crawler S3 access
# Requirement 9.4: Glue_Crawler SHALL have IAM permissions to read S3
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "glue_crawler_s3_access" {
  name        = "${var.project_name}-${var.environment}-glue-crawler-s3-policy"
  description = "Policy for Glue crawlers to read from data lake S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.data_lake_bucket_arn
      },
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.data_lake_bucket_arn}/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "glue_crawler_s3_access" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = aws_iam_policy.glue_crawler_s3_access.arn
}

# -----------------------------------------------------------------------------
# Custom policy for Glue catalog write permissions
# Requirement 9.4: Glue_Crawler SHALL have IAM permissions to write to Glue catalog
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "glue_crawler_catalog_access" {
  name        = "${var.project_name}-${var.environment}-glue-crawler-catalog-policy"
  description = "Policy for Glue crawlers to write to Glue Data Catalog"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:BatchGetPartition",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          "arn:aws:glue:*:*:database/${local.database_name}",
          "arn:aws:glue:*:*:table/${local.database_name}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "glue_crawler_catalog_access" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = aws_iam_policy.glue_crawler_catalog_access.arn
}

# -----------------------------------------------------------------------------
# Glue Crawler for Raw Layer
# Requirement 2.2: Configure Glue_Crawler resources for each data layer
# Requirement 2.5: Set crawler schedules for periodic schema updates
# -----------------------------------------------------------------------------
resource "aws_glue_crawler" "raw" {
  name          = "${var.project_name}-${var.environment}-raw-crawler"
  database_name = aws_glue_catalog_database.lakehouse.name
  role          = aws_iam_role.glue_crawler.arn
  description   = "Crawler for raw data layer - discovers schemas from landing zone"

  schedule = var.crawler_schedule

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/raw/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Glue Crawler for Processed Layer
# Requirement 2.2: Configure Glue_Crawler resources for each data layer
# Requirement 2.5: Set crawler schedules for periodic schema updates
# -----------------------------------------------------------------------------
resource "aws_glue_crawler" "processed" {
  name          = "${var.project_name}-${var.environment}-processed-crawler"
  database_name = aws_glue_catalog_database.lakehouse.name
  role          = aws_iam_role.glue_crawler.arn
  description   = "Crawler for processed data layer - discovers schemas from cleaned/validated data"

  schedule = var.crawler_schedule

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/processed/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Glue Crawler for Curated Layer
# Requirement 2.2: Configure Glue_Crawler resources for each data layer
# Requirement 2.5: Set crawler schedules for periodic schema updates
# -----------------------------------------------------------------------------
resource "aws_glue_crawler" "curated" {
  name          = "${var.project_name}-${var.environment}-curated-crawler"
  database_name = aws_glue_catalog_database.lakehouse.name
  role          = aws_iam_role.glue_crawler.arn
  description   = "Crawler for curated data layer - discovers Iceberg tables for business-ready data"

  schedule = var.crawler_schedule

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/curated/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Lake Formation Permissions for Glue Crawler
# Grant database and table permissions to the Glue crawler role
# -----------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "glue_crawler_database" {
  principal   = aws_iam_role.glue_crawler.arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP"]

  database {
    name = aws_glue_catalog_database.lakehouse.name
  }
}

resource "aws_lakeformation_permissions" "glue_crawler_tables" {
  principal   = aws_iam_role.glue_crawler.arn
  permissions = ["ALL"]

  table {
    database_name = aws_glue_catalog_database.lakehouse.name
    wildcard      = true
  }
}

# -----------------------------------------------------------------------------
# Lake Formation Permissions for Step Functions Role
# Grant SELECT permissions for Athena queries
# -----------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "step_functions_tables" {
  principal   = var.step_functions_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.lakehouse.name
    wildcard      = true
  }
}
