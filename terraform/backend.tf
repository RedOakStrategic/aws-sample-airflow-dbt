# Backend configuration for remote state storage
# 
# IMPORTANT: Before enabling this backend, you must first create:
# 1. An S3 bucket for state storage
# 2. A DynamoDB table for state locking
#
# To create these resources manually:
#   aws s3api create-bucket --bucket <project>-<env>-terraform-state --region us-east-1
#   aws dynamodb create-table \
#     --table-name <project>-<env>-terraform-locks \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST
#
# Uncomment the backend block below after creating the resources.

# terraform {
#   backend "s3" {
#     bucket         = "lakehouse-mvp-sandbox-terraform-state"
#     key            = "aws-data-lakehouse-mvp/terraform.tfstate"
#     region         = "us-east-1"
#     profile        = "ros-sandbox"
#     encrypt        = true
#     dynamodb_table = "lakehouse-mvp-sandbox-terraform-locks"
#   }
# }
