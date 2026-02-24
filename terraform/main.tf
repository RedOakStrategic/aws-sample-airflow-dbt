# Root Terraform module for AWS Data Lakehouse MVP
# Configures AWS provider and required providers

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider configuration for ros-sandbox profile
provider "aws" {
  region  = var.aws_region
  profile = "ros-sandbox"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

#------------------------------------------------------------------------------
# Module 1: Storage - S3 buckets for data lake and DAGs
#------------------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  environment  = var.environment
  project_name = var.project_name
  kms_key_arn  = var.kms_key_arn
}

#------------------------------------------------------------------------------
# Module 2: Catalog - Glue database and crawlers (depends on storage, workflow)
#------------------------------------------------------------------------------
module "catalog" {
  source = "./modules/catalog"

  environment             = var.environment
  project_name            = var.project_name
  data_lake_bucket_name   = module.storage.data_lake_bucket_name
  data_lake_bucket_arn    = module.storage.data_lake_bucket_arn
  crawler_schedule        = var.crawler_schedule
  step_functions_role_arn = module.workflow.step_functions_role_arn
}

#------------------------------------------------------------------------------
# Module 3: Metadata - DynamoDB table for pipeline metadata
#------------------------------------------------------------------------------
module "metadata" {
  source = "./modules/metadata"

  environment  = var.environment
  project_name = var.project_name
  billing_mode = var.dynamodb_billing_mode
}

#------------------------------------------------------------------------------
# Module 4: Analytics - Athena workgroup (depends on storage, catalog)
#------------------------------------------------------------------------------
module "analytics" {
  source = "./modules/analytics"

  environment          = var.environment
  project_name         = var.project_name
  query_results_bucket = module.storage.data_lake_bucket_name
  glue_database_name   = module.catalog.glue_database_name
  bytes_scanned_cutoff = var.athena_bytes_scanned_cutoff
}

#------------------------------------------------------------------------------
# Module 5: Workflow - Step Functions (depends on catalog, metadata, analytics)
#------------------------------------------------------------------------------
module "workflow" {
  source = "./modules/workflow"

  environment          = var.environment
  project_name         = var.project_name
  glue_database_name   = module.catalog.glue_database_name
  raw_crawler_name     = module.catalog.raw_crawler_name
  curated_crawler_name = module.catalog.curated_crawler_name
  metadata_table_name  = module.metadata.table_name
  metadata_table_arn   = module.metadata.table_arn
  athena_workgroup     = module.analytics.workgroup_name
  data_lake_bucket_arn = module.storage.data_lake_bucket_arn
}

#------------------------------------------------------------------------------
# Module 6: Orchestration - MWAA (depends on storage, workflow)
#------------------------------------------------------------------------------
module "orchestration" {
  source = "./modules/orchestration"

  environment        = var.environment
  project_name       = var.project_name
  dags_bucket_name   = module.storage.dags_bucket_name
  dags_bucket_arn    = module.storage.dags_bucket_arn
  state_machine_arn  = module.workflow.state_machine_arn
  environment_class  = var.mwaa_environment_class
  airflow_version    = var.mwaa_airflow_version
  max_workers        = var.mwaa_max_workers
  min_workers        = var.mwaa_min_workers

  # VPC configuration - either create new or use existing
  create_vpc         = var.create_vpc
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
}
