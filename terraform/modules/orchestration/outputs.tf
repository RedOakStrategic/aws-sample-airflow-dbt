# Orchestration module outputs

output "mwaa_environment_name" {
  description = "Name of the MWAA environment"
  value       = aws_mwaa_environment.main.name
}

output "mwaa_environment_arn" {
  description = "ARN of the MWAA environment"
  value       = aws_mwaa_environment.main.arn
}

output "mwaa_webserver_url" {
  description = "URL of the MWAA Airflow webserver"
  value       = aws_mwaa_environment.main.webserver_url
}

output "mwaa_execution_role_arn" {
  description = "ARN of the MWAA execution IAM role"
  value       = aws_iam_role.mwaa_execution.arn
}

output "mwaa_execution_role_name" {
  description = "Name of the MWAA execution IAM role"
  value       = aws_iam_role.mwaa_execution.name
}

output "mwaa_security_group_id" {
  description = "ID of the MWAA security group"
  value       = aws_security_group.mwaa.id
}

#------------------------------------------------------------------------------
# VPC Outputs (only populated when create_vpc = true)
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC (created or provided)"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (created or provided)"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (only when create_vpc = true)"
  value       = var.create_vpc ? aws_subnet.public[*].id : []
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (only when create_vpc = true)"
  value       = var.create_vpc ? aws_nat_gateway.mwaa[0].id : null
}
