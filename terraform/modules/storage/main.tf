# S3 Storage Module - Data Lake Bucket
# Requirements: 1.1 (versioning), 1.3 (KMS encryption), 1.4 (lifecycle), 1.5 (public access block)

# -----------------------------------------------------------------------------
# Data Lake S3 Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project_name}-${var.environment}-data-lake"

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-lake"
    Environment = var.environment
    Module      = "storage"
    Purpose     = "data-lake"
  }
}

# -----------------------------------------------------------------------------
# Versioning Configuration (Requirement 1.1)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# Server-Side Encryption with KMS (Requirement 1.3)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn # Uses aws/s3 managed key if null
    }
    bucket_key_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Public Access Block (Requirement 1.5)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Lifecycle Configuration for Storage Tiering (Requirement 1.4)
# Transition to IA after 90 days, Glacier after 365 days
# Three prefix layers: raw/, processed/, curated/
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  # Depends on versioning being enabled first
  depends_on = [aws_s3_bucket_versioning.data_lake]

  # Raw layer tiering
  rule {
    id     = "raw-layer-tiering"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  # Processed layer tiering
  rule {
    id     = "processed-layer-tiering"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  # Curated layer tiering
  rule {
    id     = "curated-layer-tiering"
    status = "Enabled"

    filter {
      prefix = "curated/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  # Abort incomplete multipart uploads to save costs
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# MWAA DAGs S3 Bucket (Requirement 4.3)
# Stores Airflow DAG files for MWAA environment
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "mwaa_dags" {
  bucket = "${var.project_name}-${var.environment}-mwaa-dags"

  tags = {
    Name        = "${var.project_name}-${var.environment}-mwaa-dags"
    Environment = var.environment
    Module      = "storage"
    Purpose     = "mwaa-dags"
  }
}

# -----------------------------------------------------------------------------
# Versioning for DAG Version Control (Requirement 4.3)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "mwaa_dags" {
  bucket = aws_s3_bucket.mwaa_dags.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# Server-Side Encryption for MWAA DAGs
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "mwaa_dags" {
  bucket = aws_s3_bucket.mwaa_dags.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Public Access Block for MWAA DAGs
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "mwaa_dags" {
  bucket = aws_s3_bucket.mwaa_dags.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
