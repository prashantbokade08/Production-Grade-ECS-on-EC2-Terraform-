# Production-Grade ECS on EC2 (Terraform)

## Overview

This repository implements a production-grade ECS (EC2 launch type)
workload on AWS using Terraform.

The design focuses on:

-   Zero-downtime deployments
-   Secure secret handling
-   Spot + On-Demand cost optimization
-   Capacity-aware scaling
-   Least privilege IAM
-   Multi-AZ resilience

This solution reflects real-world production patterns and operational
tradeoffs.

------------------------------------------------------------------------

# Architecture Summary

## Core Components

-   ECS Cluster (EC2 launch type)
-   Auto Scaling Group (Mixed Instances)
    -   On-Demand baseline
    -   Spot overflow (capacity-optimized)
-   ECS Capacity Provider (managed scaling enabled)
-   Application Load Balancer (HTTPS only)
-   Route53 public DNS (ALIAS to ALB)
-   SSM Parameter Store (secrets)
-   Secrets Manager (optional additional secret source)
-   CloudWatch Logs
-   ECS Service Auto Scaling (CPU + Memory target tracking)
-   IMDSv2 enforced
-   EBS encryption enabled

------------------------------------------------------------------------

# Design Principles

## 1️⃣ Zero-Downtime Deployments

ECS Service configuration:

-   `deployment_minimum_healthy_percent = 100`
-   `deployment_maximum_percent = 200`
-   ALB health checks + deregistration delay
-   Deployment circuit breaker with rollback enabled
-   Tasks spread across AZs
-   Capacity provider handles cluster scaling

Deployment behavior:

1.  New tasks start first.
2.  They pass ALB health checks.
3.  Traffic shifts gradually.
4.  Old tasks drain.
5.  Old tasks stop only after successful replacement.

Traffic never drops below healthy desired count.

------------------------------------------------------------------------

## 2️⃣ Secure Secrets Handling

Secrets are:

-   Stored in SSM Parameter Store / Secrets Manager
-   Referenced by ARN only
-   Injected at container runtime using ECS `secrets` block
-   Never stored in:
    -   Terraform variables
    -   terraform.tfvars
    -   Git repository
    -   Terraform state

IAM policy grants:

-   `ssm:GetParameter` (restricted to specific ARN)
-   `secretsmanager:GetSecretValue` (restricted to specific ARN)

Least privilege enforced.

------------------------------------------------------------------------

## 3️⃣ Cost-Optimized Capacity Strategy

Auto Scaling Group:

-   Mixed instances policy
-   On-Demand base capacity (guaranteed baseline)
-   Spot above baseline (cost optimization)
-   Spot allocation strategy: capacity-optimized

Why this works:

-   Baseline ensures service stability
-   Spot reduces cost during scale-out
-   Capacity provider managed scaling reacts to pending tasks
-   Spot interruptions do not cause downtime

------------------------------------------------------------------------

## 4️⃣ Scaling Strategy

### Cluster Scaling

-   ECS Capacity Provider
-   Managed scaling enabled
-   Target capacity = 80%
-   Scales EC2 instances based on pending tasks

### Service-Level Scaling

-   `aws_appautoscaling_target`
-   Target tracking policies:
    -   ECSServiceAverageCPUUtilization
    -   ECSServiceAverageMemoryUtilization

This ensures:

-   Reactive service scaling
-   No pending task deadlock
-   Proper cluster capacity expansion

------------------------------------------------------------------------

## 5️⃣ Networking

Assumptions:

-   Existing VPC
-   Minimum 2 public subnets (for ALB)
-   Minimum 2 private subnets (for ECS instances)
-   Private subnets have outbound egress via NAT Gateway

ECS instances:

-   No public IP
-   IMDSv2 required
-   Security groups restrict inbound traffic to ALB only

ALB:

-   Public
-   HTTPS only
-   TLS terminated at ALB
-   Route53 alias record configured

Trust boundary:

Internet → ALB → ECS Tasks (private subnets)

------------------------------------------------------------------------

# How to Run

## AWS Authentication (Production)

``` bash
aws configure sso
export AWS_PROFILE=prod
```

Or using temporary credentials:

``` bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```

------------------------------------------------------------------------

## Dummy Mode (Local Validation Only)

Linux / Mac:

``` bash
export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="ap-south-1"
```

Windows PowerShell:

``` powershell
setx AWS_ACCESS_KEY_ID dummy
setx AWS_SECRET_ACCESS_KEY dummy
setx AWS_DEFAULT_REGION ap-south-1
```

------------------------------------------------------------------------

## Terraform Commands (Common Production Usage)

``` bash
terraform fmt
terraform validate
terraform init
terraform init -reconfigure
terraform init -upgrade
terraform plan
terraform plan -out=tfplan
terraform apply tfplan
terraform apply -auto-approve
terraform output
terraform state list
terraform state show
terraform workspace list
terraform workspace new prod
terraform import
terraform state mv
terraform force-unlock
terraform destroy
terraform plan -refresh-only
terraform graph | dot -Tpng > graph.png
TF_LOG=DEBUG terraform apply
```

------------------------------------------------------------------------

# Least-Privilege IAM for Terraform

Terraform should not use full admin permissions.

Create a role:

**TerraformExecutionRole**

Required permissions scope:

-   `ecs:*`
-   `autoscaling:*`
-   `elasticloadbalancing:*`
-   `iam:PassRole` (restricted to ECS roles only)
-   `logs:*`
-   `route53:*`
-   `ssm:GetParameter`
-   `secretsmanager:GetSecretValue`
-   `ec2:Describe*`

Production best practice:

-   Use IAM Role assumption (OIDC / CI/CD)
-   Store state in encrypted S3
-   Enable DynamoDB state locking
-   Avoid static credentials

------------------------------------------------------------------------

# Governance

-   Terraform is single source of truth
-   Remote backend (S3 + DynamoDB)
-   Drift detected via `terraform plan`
-   Critical resources protected with `prevent_destroy`
-   ALB deletion protection enabled

------------------------------------------------------------------------

# Summary

This repository demonstrates:

-   Deployment safety
-   Secure secret handling
-   Spot-aware scaling
-   Multi-AZ resilience
-   Drift detection and infra protection
-   Production-grade Terraform governance


## Terraform follows

``` bash

aws configure sso
export AWS_PROFILE=prod
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

terraform init
terraform init -reconfigure
terraform init -upgrade
terraform plan
terraform fmt
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve
git add .
git commit -m "feat: implemented ALB with autoscaling"
git push
terraform apply

terraform init
terraform plan -var-file=environments/dev.tfvars

terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars


Set dummy credentials:

$env:AWS_ACCESS_KEY_ID="dummy"
$env:AWS_SECRET_ACCESS_KEY="dummy"
$env:AWS_SESSION_TOKEN="dummy"
$env:AWS_DEFAULT_REGION="ap-south-1"

versions.tf


# Terraform & Provider Version Constraints

# version.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# provider.tf
provider "aws" {
  region = var.region
  access_key = "dummy"
  secret_key = "dummy"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = "ECS-Assessment"
    }
  }
}

Linux / Mac
export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="ap-south-1"
Windows PowerShell


setx AWS_ACCESS_KEY_ID dummy
setx AWS_SECRET_ACCESS_KEY dummy
setx AWS_DEFAULT_REGION ap-south-1
setx AWS_ACCESS_KEY_ID "dummy"
setx AWS_SECRET_ACCESS_KEY "dummy"
setx AWS_DEFAULT_REGION "ap-south-1"


TF COMMANDS 
terraform fmt
terraform validate
terraform init
terraform init -migrate-state
terraform init -reconfigure
terraform plan -out=tfplan
terraform apply tfplan
terraform output
terraform state list
terraform state show
terraform workspace select
terraform import
terraform state mv
terraform force-unlock
terraform destroy
terraform providers lock
terraform plan -refresh-only
terraform apply -lock-timeout=5m
terraform state push backup.tfstate
terraform state pull > backup.tfstate
terraform init -input=false
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform output -json
terraform output alb_dns_name
terraform graph | dot -Tpng > graph.png
TF_LOG=DEBUG terraform apply
TF_LOG=TRACE terraform plan
terraform init -reconfigure
terraform workspace list
terraform workspace new prod
terraform apply -target=aws_ecs_service.service
terraform destroy -target=aws_lb.alb
terraform destroy -target=aws_lb.alb
terraform state mv aws_lb.old aws_lb.new
terraform state rm aws_lb.alb
terraform import aws_lb.alb arn:aws:elasticloadbalancing:...
terraform import aws_lb.alb arn:aws:elasticloadbalancing:...
terraform show
terraform state show aws_ecs_service.service

```