# AWS Provider Configuration
provider "aws" {
region = var.region
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = "ECS-Assessment"
    }
  }
}
 

# dummy local test
# provider "aws" {
#   region                      = var.region
#   access_key                  = "dummy"
#   secret_key                  = "dummy"
#   skip_credentials_validation = true
#   skip_metadata_api_check     = true
#   skip_requesting_account_id  = true
#   skip_region_validation      = true
#   default_tags {
#     tags = {
#       ManagedBy   = "Terraform"
#       Environment = var.environment
#       Project     = "ECS-Assessment"
#     }
#   }
# }