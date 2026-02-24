# Storage module outputs

# Data Lake Bucket Outputs
output "data_lake_bucket_name" {
  description = "Name of the data lake S3 bucket"
  value       = aws_s3_bucket.data_lake.id
}

output "data_lake_bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  value       = aws_s3_bucket.data_lake.arn
}

output "raw_prefix" {
  description = "S3 prefix for raw data layer"
  value       = "raw/"
}

output "processed_prefix" {
  description = "S3 prefix for processed data layer"
  value       = "processed/"
}

output "curated_prefix" {
  description = "S3 prefix for curated data layer"
  value       = "curated/"
}

# MWAA DAGs Bucket Outputs
output "dags_bucket_name" {
  description = "Name of the MWAA DAGs S3 bucket"
  value       = aws_s3_bucket.mwaa_dags.id
}

output "dags_bucket_arn" {
  description = "ARN of the MWAA DAGs S3 bucket"
  value       = aws_s3_bucket.mwaa_dags.arn
}
