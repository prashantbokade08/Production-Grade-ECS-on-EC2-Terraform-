

# ECS Cluster & Service
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "ecs_service_id" {
  description = "ID of the ECS service (cluster/service format)"
  value       = aws_ecs_service.service.id
}

output "ecs_task_definition_arn" {
  description = "ARN of the active task definition"
  value       = aws_ecs_task_definition.nginx.arn
}

output "ecs_desired_count" {
  description = "Configured desired task count"
  value       = aws_ecs_service.service.desired_count
}

# Logging & Observability
output "ecs_log_group_name" {
  description = "CloudWatch Log Group used by ECS tasks"
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

output "ecs_log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.ecs_logs.arn
}

# Load Balancer
output "alb_name" {
  description = "Application Load Balancer name"
  value       = aws_lb.alb.name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.alb.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.alb.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the ALB"
  value       = aws_lb.alb.zone_id
}

output "alb_https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "target_group_arn" {
  description = "Target Group ARN attached to ECS service"
  value       = aws_lb_target_group.tg.arn
}

output "target_group_name" {
  description = "Target Group name"
  value       = aws_lb_target_group.tg.name
}

# Route53
output "route53_record_fqdn" {
  description = "Fully qualified domain name created in Route53"
  value       = aws_route53_record.public_dns.fqdn
}

# Auto Scaling & Capacity Provider
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group backing ECS"
  value       = aws_autoscaling_group.ecs_asg.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.ecs_asg.arn
}

output "capacity_provider_name" {
  description = "ECS Capacity Provider name"
  value       = aws_ecs_capacity_provider.ecs_cp.name
}

output "capacity_provider_managed_scaling_status" {
  description = "Managed scaling status of capacity provider"
  value = try(
    aws_ecs_capacity_provider.ecs_cp.auto_scaling_group_provider[0].managed_scaling[0].status,
    "UNKNOWN"
  )
}

# IAM Roles
output "ecs_instance_role_arn" {
  description = "IAM Role ARN used by ECS EC2 instances"
  value       = aws_iam_role.ecs_instance_role.arn
}

output "task_execution_role_arn" {
  description = "IAM Role ARN used by ECS tasks"
  value       = aws_iam_role.task_execution_role.arn
}

# Security Groups
output "alb_security_group_id" {
  description = "Security Group ID associated with the ALB"
  value       = aws_security_group.alb_sg.id
}

output "ecs_security_group_id" {
  description = "Security Group ID associated with ECS instances"
  value       = aws_security_group.ecs_sg.id
}

# Scaling Configuration Visibility
output "cpu_scaling_target_value" {
  description = "Configured CPU utilization scaling target"
  value       = var.cpu_target_value
}

output "memory_scaling_target_value" {
  description = "Configured Memory utilization scaling target"
  value       = var.memory_target_value
}

# Secrets (Reference Only – No Values)
output "ssm_parameter_reference" {
  description = "SSM parameter ARN used for secret injection (value not exposed)"
  value       = var.ssm_parameter_arn
  sensitive   = true
}

output "asm_secret_reference" {
  description = "Secrets Manager ARN used for secret injection (value not exposed)"
  value       = var.asm_secret_arn
  sensitive   = true
}