output "service_name" {
  value = aws_ecs_service.this.name
}

output "service_id" {
  value = aws_ecs_service.this.id
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.this.arn
  description = "Terraform's own revision -- CI registers newer ones directly; see the ignore_changes note on aws_ecs_service.this."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Pass to another service's allowed_security_group_ids to grant it ingress here."
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "task_role_name" {
  value       = aws_iam_role.task.name
  description = "Role name, for consumers that build an assumed-role prefix (arn:aws:sts::<acct>:assumed-role/<name>/) rather than an IAM role ARN."
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "service_discovery_arn" {
  value = try(aws_service_discovery_service.this[0].arn, "")
}

output "internal_dns_name" {
  value       = local.has_sd ? "${var.name}.${data.aws_region.current.name}" : ""
  description = "Informational only -- actual resolvable name depends on the shared namespace's domain, published separately by ecs-cluster."
}

output "autoscaling_target_arn" {
  value       = try(aws_appautoscaling_target.ecs[0].arn, "")
  description = "ARN of the scalable target if autoscaling is enabled."
}

output "autoscaling_cpu_policy_arn" {
  value       = try(aws_appautoscaling_policy.cpu[0].arn, "")
  description = "ARN of the CPU scaling policy if enabled."
}

output "autoscaling_memory_policy_arn" {
  value       = try(aws_appautoscaling_policy.memory[0].arn, "")
  description = "ARN of the Memory scaling policy if enabled."
}

