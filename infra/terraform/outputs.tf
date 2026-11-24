output "db_client_security_group_id" {
  value = nonsensitive(data.aws_ssm_parameter.db_client_sg.value)
}

output "db_bootstrap_run_task" {
  description = "Run the DB bootstrap by hand. It needs the service security group (egress to Secrets Manager and ECR) plus the DB client group."
  value = join(" ", [
    "aws ecs run-task --cluster", nonsensitive(module.deploy.ecs_cluster_arn),
    "--launch-type FARGATE --task-definition", aws_ecs_task_definition.db_bootstrap.family,
    "--network-configuration 'awsvpcConfiguration={subnets=[${join(",", nonsensitive(module.deploy.vpc_private_subnet_ids))}],securityGroups=[${module.service.security_group_id},${nonsensitive(data.aws_ssm_parameter.db_client_sg.value)}],assignPublicIp=DISABLED}'",
  ])
}

output "ecr_repository_url" {
  description = "ECR repository the deploy workflow pushes images to."
  value       = aws_ecr_repository.gateway.repository_url
}

output "ecs_cluster_name" {
  description = "Shared ECS cluster name."
  value       = nonsensitive(module.deploy.ecs_cluster_name)
}

output "service_name" {
  description = "ECS service name."
  value       = module.service.service_name
}

output "task_definition_family" {
  description = "Task definition family (the module uses its name input); CI registers revisions under it."
  value       = "eqx-mlflow-gateway"
}

output "service_security_group_id" {
  description = "Service security group, for one-off tasks such as migrate."
  value       = module.service.security_group_id
}

output "private_subnet_ids" {
  description = "Private subnets for one-off tasks."
  value       = nonsensitive(module.deploy.vpc_private_subnet_ids)
}
