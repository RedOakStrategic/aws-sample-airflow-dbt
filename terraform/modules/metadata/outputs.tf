# Metadata module outputs
# Requirements: 8.3, 8.4

output "table_name" {
  description = "Name of the DynamoDB pipeline metadata table"
  value       = aws_dynamodb_table.pipeline_metadata.name
}

output "table_arn" {
  description = "ARN of the DynamoDB pipeline metadata table"
  value       = aws_dynamodb_table.pipeline_metadata.arn
}
