
# Environment Configuration

variable "environment" {
  description = "Deployment environment (dev | qa | prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod."
  }
}

variable "region" {
  description = "AWS region for deployment"
  type        = string

  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

# Networking

variable "vpc_id" {
  description = "VPC ID where ECS resources will be deployed"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must start with 'vpc-'."
  }
}

variable "public_subnets" {
  description = "Public subnet IDs for ALB (minimum 2 for Multi-AZ)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "At least two public subnets are required."
  }
}

variable "private_subnets" {
  description = "Private subnet IDs for ECS instances (minimum 2 for Multi-AZ)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "At least two private subnets are required."
  }
}

# ECS Configuration

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 1
    error_message = "Desired count must be at least 1."
  }
}

# EC2 / Auto Scaling Configuration

variable "instance_type" {
  description = "EC2 instance type used by ECS container instances"
  type        = string
  default     = "t3.medium"
}

variable "asg_min_size" {
  description = "Minimum Auto Scaling Group size"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum Auto Scaling Group size"
  type        = number
}

variable "on_demand_base_capacity" {
  description = "Baseline On-Demand capacity in mixed instances policy"
  type        = number
}

# Scaling Threshold Configuration

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for ECS service scaling"
  type        = number
  default     = 60
}

variable "memory_target_value" {
  description = "Target Memory utilization percentage for ECS service scaling"
  type        = number
  default     = 70
}

# AMI Configuration

variable "ecs_ami_id" {
  description = "ECS optimized AMI ID (dummy allowed for local plan, real required in production)"
  type        = string

  validation {
    condition     = can(regex("^ami-", var.ecs_ami_id))
    error_message = "AMI ID must start with 'ami-'."
  }
}

# Load Balancer Configuration

variable "alb_name" {
  description = "Application Load Balancer name"
  type        = string
}

variable "target_group_name" {
  description = "Target group name for ECS service"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "Must be a valid ACM certificate ARN."
  }
}

# DNS (Route53)

variable "route53_zone_id" {
  description = "Public Hosted Zone ID"
  type        = string
}

variable "domain_name" {
  description = "Public domain name (e.g., app.example.com)"
  type        = string
}

# Secrets Configuration (No Secret Values Stored)

variable "ssm_parameter_arn" {
  description = "ARN of existing SSM parameter (secret value never stored in Terraform)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^arn:aws:ssm:", var.ssm_parameter_arn))
    error_message = "Must be a valid SSM parameter ARN."
  }
}

variable "asm_secret_arn" {
  description = "ARN of existing AWS Secrets Manager secret"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:", var.asm_secret_arn))
    error_message = "Must be a valid Secrets Manager ARN."
  }
}

# Vault Integration (Optional)

variable "vault_role_name" {
  description = "Vault IAM auth role name (optional)"
  type        = string
  default     = null
}