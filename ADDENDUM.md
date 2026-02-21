ADDENDUM.md
Production Stress Test & Failure Analysis

This document explains how the implemented Terraform design production failure scenarios.

The goal of this section is not just to describe what AWS does, but to demonstrate how the specific configuration in this repository prevents downtime, avoids deadlocks, and protects secrets.

All answers below reflects:

ECS EC2 launch type
Capacity Provider with managed scaling
Mixed On-Demand + Spot ASG
ALB with deregistration delay
Service-level auto scaling
Deployment circuit breaker
Least-privilege IAM

1) Spot Failure During Deployment
Scenario: During a rolling deployment, 60% of Spot instances are reclaimed.

What Actually Happens
1. Spot Interruption Notice
AWS sends a 2-minute interruption notice to affected Spot instances.
These instances are part of the ECS cluster backing the service.

2. ECS Capacity Provider & Termination Protection
In this design: managed_termination_protection = "ENABLED"
This ensures:
ASG does not abruptly terminate instances running tasks.
ECS first marks container instances as DRAINING.
Tasks are stopped gracefully.
without managed termination protection, traffic loss would be possible.

3. Task Draining
For affected instances:
ECS transitions tasks to DRAINING
ALB deregisters targets
deregistration_delay = 30
Existing connections complete
Because ALB only routes traffic to healthy targets, users are automatically routed to remaining healthy tasks.

4. Service-Level Protection
The number of healthy tasks never drops below desired_count.
ECS launches replacement tasks before stopping old ones.
Failed deployments automatically roll back.

The service configuration includes:
deployment_minimum_healthy_percent = 100
deployment_maximum_percent         = 200
deployment_circuit_breaker {
  enable   = true
  rollback = true
}

5. Replacement Capacity
If cluster capacity becomes insufficient:
Replacement tasks enter PENDING.
Capacity Provider detects insufficient capacity.
ASG scales out automatically.
New EC2 instances launch in private subnets.
ECS registers new container instances.
Pending tasks transition to RUNNING.


Where Does New Capacity Come From?
From the Auto Scaling Group:
On-Demand baseline ensures minimum availability.
Spot instances provide overflow capacity.
Mixed instance policy launches new Spot capacity.
If Spot is constrained, ASG can temporarily use On-Demand depending on availability.

Why There Is No Downtime

Because:
ALB routes only to healthy targets.
Minimum healthy percent prevents under-provisioning.
Managed termination ensures draining before instance termination.
Capacity provider scales cluster automatically.
On-Demand baseline prevents cluster collapse.
Users may observe slight latency increase — but not downtime.


2) Secrets Break at Runtime
Scenario: SSM permission is removed from the task execution role.

What Breaks?
In this design:
Secrets are injected via valueFrom = var.ssm_parameter_arn
ECS agent fetches secret at container startup
If IAM permission is removed:
ssm:GetParameter fails
Task fails to start
Task enters STOPPED state
ECS service retries
Repeated failures occur
CloudWatch logs show: AccessDeniedException: ssm:GetParameter

What Does NOT Happen?
Secret value is never exposed.
Terraform state is unaffected.
Secret is not stored in repo.
Secret is not logged.
Because only ARN references are stored in Terraform.

Detection
ECS Service events show task start failure.
CloudWatch logs show AccessDenied.
RunningTaskCount decreases.
Deployment may stall.

Recovery
Restore IAM permission.
Force new deployment optional.
ECS launches new tasks.
ALB registers healthy targets.
Because secrets are retrieved at runtime, fixing IAM resolves the issue immediately.

3) Pending Task Deadlock
Scenario: Service wants 10 tasks.
Cluster can run only 6.
4 tasks remain PENDING.

What Triggers Capacity Increase?
Capacity Provider managed scaling is enabled:
When tasks remain PENDING:
ECS signals insufficient cluster capacity.
Capacity provider increases ASG desired capacity.
ASG launches new EC2 instances.
Instances register automatically.
Pending tasks transition to RUNNING.

managed_scaling {
  status          = "ENABLED"
  target_capacity = 80
}


Why Deadlock Does Not Occur
Deadlock would occur if:
ASG max_size too low
Capacity provider disabled
All Spot unavailable AND no On-Demand baseline
In this design:
ASG max_size allows growth
Capacity provider is enabled
On-Demand baseline exists
Therefore scaling converges automatically.

4) Deployment Safety
During Rolling Deployment

When Do New Tasks Start?
Immediately after a new task definition revision is deployed.
Because maximum_percent = 200, ECS can temporarily exceed desired_count.

When Do Old Tasks Stop Receiving Traffic?
Only after:
New tasks pass ALB health checks
ALB marks them healthy
ALB health check acts as safety gate.

When Are Old Tasks Killed?
After:
Deregistration delay (30 seconds)
Active connections drain
Replacement tasks confirmed healthy

What If New Tasks Fail Health Checks?
Deployment circuit breaker triggers:
Deployment marked failed
New tasks stopped
Previous stable revision restored
Service continues running
This prevents partial rollout scenarios.

5) TLS, Trust Boundary & Identity
Where Is TLS Terminated?
At the Application Load Balancer:
HTTPS listener
ACM certificate attached
Backend traffic ALB → ECS is HTTP inside private VPC
Trust boundary:
Public subnet: Internet → ALB
Private subnets: ECS + EC2
No public IP on compute

What AWS Identity Does the Container Run As?
Tasks assume the ECS task execution role.
Permissions are limited to:
Specific SSM parameter
Specific Secrets Manager secret
CloudWatch Logs
No wildcard policies.
No broad IAM access.

6) Cost Floor (Traffic = 0 for 12 Hours)
Even with zero traffic, costs remain:
On-Demand baseline EC2 instances
ALB hourly cost
NAT Gateway
EBS volumes
CloudWatch Logs
Route53 hosted zone
Spot instances scale down automatically if service scales down.

How To Reduce Cost Without Reducing Safety
Options:
Scheduled scaling during off-hours
Reduce instance size
Purchase Savings Plans
Lower On-Demand baseline (carefully)
Consider Fargate for very low steady-state traffic
Current design prioritizes availability over absolute minimum cost.

7) Real Production Failure Modes
Failure 1 — AZ Outage
Detection:
ALB shows unhealthy targets in one AZ.
Blast Radius:
Only affected AZ.
Mitigation:
Tasks spread across AZs.
ASG launches replacement in healthy AZ.
ALB routes traffic automatically.

Failure 2 — Spot Capacity Collapse
Detection:
Multiple instance termination events.
Blast Radius:
Temporary capacity reduction.
Mitigation:
On-Demand baseline remains active.
Capacity provider replaces instances.
Service-level scaling ensures recovery.

Failure 3 — Bad Deployment
Detection:
ALB health checks fail.
ECS deployment failure event.
Blast Radius:
New revision only.
Mitigation:
Circuit breaker rollback.
Previous tasks continue serving.
No user-facing downtime.

Final Reflection
This architecture was designed with real production behavior in mind:
No public compute
Managed draining before termination
On-Demand baseline for resilience
Capacity provider prevents deadlocks
Service auto scaling handles load
Circuit breaker prevents broken rollouts
Secrets injected at runtime with least privilege
Encrypted state and infrastructure protection
The system is not optimized for theoretical perfection — it is optimized
for safe, predictable production behavior under failure conditions.


It balances:
Availability
Cost efficiency
Security
Operational simplicity

SECURE Terraform + IAM + governance
Role of IAM Policy in This Architecture
A) Terraform Execution Role
This is the role Terraform assumes when running plan/apply.

It needs permission to:
Create ECS
Create ASG
Create ALB
Attach IAM roles
Create Route53 records
Pass IAM roles (iam:PassRole limited to specific ARNs)
It should NOT have:
AdministratorAccess
Wildcard *:*
This enforces least privilege at infrastructure provisioning level.

B) ECS Instance Role (EC2 Container Instance Role)
Used by:
EC2 instances running ECS agent.

Allows:
Registering to ECS cluster
Pulling from ECR
Sending logs
It does NOT allow:
Reading secrets
Accessing S3
Accessing unrelated services


C) Task Execution Role Most Important
This is the identity the container runs as.
In your code: That means:
Container can only read exactly defined secret
Cannot list all secrets
Cannot access other AWS services
This is strict least privilege enforcement.


D) Terraform is the single source of truth for infrastructure.
That means:
Infra must be changed via Terraform
No manual console changes allowed
State file reflects real infrastructure
Git history tracks infra changes



Terraform state terraform.tfstate stores:
Resource IDs
Current configuration mapping
Dependency graph
When you run:
terraform plan
Terraform compares:
Desired state
Actual AWS infrastructure
Stored state
Then it generates a diff.

How Resources Stay Protected
You implemented multiple protection layers.
Layer 1 — prevent_destroy
Example:
lifecycle {
  prevent_destroy = true
}

If someone runs:
terraform destroy
Terraform will FAIL instead of deleting critical resources like:
ECS Cluster
ALB
ASG

Layer 2 — ALB Deletion Protection
enable_deletion_protection = true

Even if someone deletes from AWS console → deletion fails.

Layer 3 — Encrypted Volumes
ebs {
  encrypted = true
}
Prevents plaintext disk data.

Layer 4 — Private Compute
associate_public_ip_address = false

No public IP.
No SSH.
No direct internet access.

Layer 5 — IMDSv2
metadata_options {
  http_tokens = "required"
}

Prevents SSRF credential theft.

What Is Drift?
Drift happens when someone changes AWS manually.
Example:
Someone changes ASG desired capacity via console.
Someone edits ALB health check manually.
Someone modifies security group rules manually.
Now:
AWS ≠ Terraform state
That is drift.

How Drift Detection Works
When you run:
terraform plan
Terraform:
Reads state file
Queries real AWS
Compares configuration
If drift exists:
You’ll see:
~ update in-place
or
-/+ destroy and recreate
That is drift detection.

Accepting Drift vs Rejecting Drift

Case 1 — Reject Drift (Enforce Terraform Truth)
If someone changed something manually and it’s wrong:
You run:
terraform apply
Terraform reverts infrastructure to match code.
This restores single source of truth.

Case 2 — Accept Drift (Update Terraform to Match Reality)
If manual change was intentional:
Example:
Console change increased ASG max_size.
Then you:
Update .tf file
Run terraform plan
Confirm no change
Commit updated config
Now Terraform matches real state.

Case 3 — Import Resource & If Created Outside Terraform
If someone created resource manually:
Use:
terraform import
Then add config block in .tf.
Now Terraform owns it.

ignore_changes Controlled Drift Acceptance
Sometimes we intentionally allow certain attributes to drift.
Example:
lifecycle {
  ignore_changes = [desired_capacity]
}

Use case:
Let ASG autoscaling manage desired capacity,
but prevent Terraform from resetting it every apply.
This is controlled drift.

How Terraform Prevents Accidental Infra Creation
In your assessment version:
You used dummy provider mode.
That:
Skips AWS authentication
Prevents real infra creation
Allows structural validation
In production:
You remove dummy credentials and use IAM role.
This prevents:
Accidental infra creation in wrong account
Credential leakage
Hardcoded keys
Terraform State Security
Production setup:
S3 backend with:
Encryption enabled
KMS key
Versioning enabled
DynamoDB locking
This prevents:
Concurrent apply corruption
State tampering
Secret exposure
Even if state is accessed,
secret values are NOT stored because:
Only ARN references are used.


“How do you protect infrastructure from drift?”
Terraform acts as the single source of truth. We store state in encrypted S3 with DynamoDB locking. Any manual console change is detected during terraform plan. Drift can either be rejected or accepted. Critical resources use prevent_destroy and deletion protection to avoid accidental removal.

“How do you protect infrastructure from accidental destruction?”
prevent_destroy
ALB deletion protection
Encrypted volumes
Private-only compute
IMDSv2 enforced
Least privilege IAM
No static credentials
Remote backend with locking

“How does single source of truth work?”
Terraform configuration defines desired state. State file tracks actual deployed resources. During plan, Terraform compares desired vs actual and shows drift. Apply enforces convergence to declared state.

Trust Boundary & Network Isolation Clarification
11) Trust Boundary & Network Isolation
Public entry point: ALB only
ECS instances: private subnets
No public IP on compute
Security group chaining:
ALB SG → ECS SG
No 0.0.0.0/0 access to ECS
Secrets accessed via IAM, not network exposure
VPC Interface Endpoint for SSM reduces internet dependency
This enforces layered security.

12) Terraform Execution Security
Terraform runs using IAM role-based authentication.
No static credentials in code
No credentials stored in repository
Remote state encrypted with KMS
DynamoDB locking prevents concurrent corruption
IAM policy scoped to required services only
