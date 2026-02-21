# Terraform & Provider Version Constraints (Production)
terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.33.0"
    }
  }

  # REMOTE BACKEND — PRODUCTION ENABLED
  backend "s3" {
    bucket         = "terraform-state-bucket"   # add bucket name
    key            = "ecs/${var.environment}/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
    # kms_key_id = "arn:aws:kms:ap-south-1:123456789012:key/123"
  }
}


# terraform {
#   required_version = "~> 1.14.0"
#   required_providers {
#     aws = {
#       source = "hashicorp/aws"
#       version = "~> 6.33.0"
#     }
#   }
# }