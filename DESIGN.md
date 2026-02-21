# Production-Grade ECS on EC2 --- Architecture Design

## Overview

This design implements a production-grade ECS service (EC2 launch type)
deployed using Terraform and exposed via an Application Load Balancer.

The architecture is built to ensure:

-   Zero-downtime deployments
-   Secure runtime secret handling
-   Cost-optimized compute (On-Demand + Spot)
-   Multi-AZ high availability
-   Automatic scaling without deadlock
-   Least privilege IAM enforcement
-   Infrastructure drift detection and protection

Terraform is used as the single source of truth, with state stored
remotely (S3 + DynamoDB locking in production).

------------------------------------------------------------------------

# A) Zero-Downtime Deployment Strategy

Zero-downtime is enforced through coordinated configuration across ECS,
ALB, and the Capacity Provider.

## ECS Deployment Configuration

The service is configured with:

-   `deployment_minimum_healthy_percent = 100`
-   `deployment_maximum_percent = 200`
-   `health_check_grace_period_seconds = 60`
-   Deployment circuit breaker enabled (automatic rollback)

### Guarantees

-   Running tasks never drop below the desired count.
-   New tasks launch before old tasks are terminated.
-   Failed deployments automatically revert to the last stable revision.

## ALB Health Checks & Draining

-   ALB routes traffic only to healthy targets.
-   `deregistration_delay = 30` ensures graceful connection draining.
-   Old tasks stop receiving traffic before being stopped.

## Capacity Provider Termination Protection

`managed_termination_protection = ENABLED`

When instances (including Spot) are terminated:

-   ECS first drains running tasks.
-   ALB removes targets.
-   No abrupt termination of in-flight requests occurs.

This ensures traffic continuity during deployments and instance
interruptions.

------------------------------------------------------------------------

# B) Secrets Management Design

Secrets are never stored in Terraform.

Only ARN references are defined:

-   `valueFrom = var.ssm_parameter_arn`
-   `valueFrom = var.asm_secret_arn`

## Runtime Secret Flow

1.  ECS task starts.
2.  ECS agent assumes the task execution role.
3.  Agent retrieves secret from SSM / Secrets Manager.
4.  Secret is injected into container at runtime.

## Security Controls

Secret values never appear in:

-   Terraform code
-   terraform.tfvars
-   Terraform state
-   Git repository

IAM policy grants access only to specific secret ARNs.

No wildcard permissions are used.

This enforces strict least-privilege access and prevents secret leakage.

------------------------------------------------------------------------

# C) Spot + On-Demand Capacity Strategy

The compute layer uses:

-   Multi-AZ Auto Scaling Group
-   Mixed instances policy
-   On-Demand baseline capacity
-   Spot overflow capacity
-   ECS Capacity Provider with managed scaling enabled

## Why This Design

-   On-Demand ensures a minimum availability floor.
-   Spot provides cost-efficient scale-out.
-   Managed scaling aligns ASG capacity with ECS task demand.
-   Spot interruptions trigger draining and replacement automatically.

If Spot instances are reclaimed:

-   Tasks are drained gracefully.
-   ASG launches replacement instances.
-   On-Demand baseline prevents service collapse.

This balances cost efficiency with availability guarantees.

------------------------------------------------------------------------

# D) Scaling Architecture

Scaling is implemented at two coordinated levels.

## 1) Service-Level Auto Scaling

Implemented using:

-   `aws_appautoscaling_target`
-   Target tracking policies (CPU + Memory)

Metrics used:

-   ECSServiceAverageCPUUtilization
-   ECSServiceAverageMemoryUtilization

This adjusts the service desired task count dynamically.

## 2) Cluster-Level Capacity Scaling

ECS Capacity Provider with managed scaling:

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }

If tasks enter PENDING:

-   Capacity provider increases ASG desired capacity.
-   New EC2 instances launch.
-   Instances register to cluster.
-   Tasks transition to RUNNING.

This prevents scaling deadlock between service demand and instance
supply.

------------------------------------------------------------------------

# E) Network & Trust Boundary

Trust boundary:

Internet → ALB (public subnets, HTTPS)\
ALB → ECS tasks (private subnets)

Security design:

-   ECS instances have no public IP.
-   No SSH access.
-   ALB security group allows 80/443 from internet.
-   ECS security group allows inbound only from ALB security group.
-   IMDSv2 enforced.
-   EBS volumes encrypted.
-   VPC Interface Endpoint for SSM reduces dependency on public egress.

All compute remains private and protected behind the load balancer.

------------------------------------------------------------------------

# F) Infrastructure Governance & Drift Control

Terraform is the authoritative configuration source.

Production governance includes:

-   Remote backend (S3 + DynamoDB locking)
-   Encrypted state
-   Drift detection via `terraform plan`
-   `prevent_destroy` on critical resources
-   ALB deletion protection enabled
-   Strong variable validation

Manual console changes are detected during plan and reconciled through
Terraform.

This prevents configuration drift and accidental destruction.

------------------------------------------------------------------------

# G) Operational Readiness & Monitoring

## Observability

-   CloudWatch Log Group per service
-   Container Insights enabled
-   ALB health checks
-   ECS service metrics

## Critical Alerts (3AM Pager)

-   RunningTaskCount \< desired_count
-   ALB UnHealthyHostCount \> 0
-   ASG capacity below baseline
-   Deployment failure / rollback triggered
-   Spot interruption surge

These alarms ensure rapid detection of production degradation.

------------------------------------------------------------------------

# H) Cost Floor & Tradeoffs

Even with zero traffic, baseline costs remain:

-   On-Demand instances
-   ALB hourly cost
-   NAT Gateway
-   EBS volumes
-   CloudWatch logs
-   Route53 hosted zone

Spot reduces cost during burst scaling.

## Tradeoffs

-   Lower On-Demand baseline reduces cost but increases interruption
    risk.
-   Scheduled scaling can reduce off-hour costs.
-   Savings Plans can optimize long-term baseline cost.

The current design prioritizes availability over aggressive cost
minimization.

------------------------------------------------------------------------

# Design Principles

This architecture is designed to:

-   Avoid single points of failure
-   Survive Spot interruptions
-   Prevent deployment downtime
-   Prevent secret leakage
-   Scale safely without deadlock
-   Detect and correct drift
-   Enforce least privilege IAM
-   Protect infrastructure from accidental destruction
