# Catalog module outputs
# Requirements: 8.3, 8.4

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.lakehouse.name
}

output "raw_crawler_name" {
  description = "Name of the raw layer Glue crawler"
  value       = aws_glue_crawler.raw.name
}

output "processed_crawler_name" {
  description = "Name of the processed layer Glue crawler"
  value       = aws_glue_crawler.processed.name
}

output "curated_crawler_name" {
  description = "Name of the curated layer Glue crawler"
  value       = aws_glue_crawler.curated.name
}

output "crawler_role_arn" {
  description = "ARN of the IAM role used by Glue crawlers"
  value       = aws_iam_role.glue_crawler.arn
}

output "crawler_role_name" {
  description = "Name of the IAM role used by Glue crawlers"
  value       = aws_iam_role.glue_crawler.name
}
