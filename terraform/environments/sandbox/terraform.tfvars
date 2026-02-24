# Environment-specific variables for sandbox deployment
# Use with: terraform plan -var-file=environments/sandbox/terraform.tfvars

environment  = "sandbox"
project_name = "lakehouse-mvp"
aws_region   = "us-east-1"

# VPC Configuration - create new VPC for sandbox
create_vpc = true

# MWAA Configuration - minimal for sandbox
mwaa_environment_class = "mw1.small"
mwaa_max_workers       = 2
mwaa_min_workers       = 1

# Athena cost control - 10 GB limit for sandbox
athena_bytes_scanned_cutoff = 10737418240

# Glue crawler schedule - every 6 hours
crawler_schedule = "cron(0 */6 * * ? *)"
