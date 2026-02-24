# Shared locals for AWS Data Lakehouse MVP
# Defines naming conventions and common tags for cost allocation and resource identification

locals {
  # Resource naming prefix following pattern: {project_name}-{environment}
  # Used for consistent naming across all resources (Requirement 9.6)
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags for resource-specific tagging beyond default_tags
  # Useful when resources need additional tags or when referencing in modules
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
