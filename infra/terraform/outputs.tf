# Outputs are added in later tasks.

output "db_client_security_group_id" {
  value = nonsensitive(data.aws_ssm_parameter.db_client_sg.value)
}

output "db_bootstrap_run_task" {
  description = "Run once, and again after any DB change, before the first deploy; the deploy workflow also runs it."
  value = join(" ", [
    "aws ecs run-task --cluster", module.deploy.ecs_cluster_arn,
    "--launch-type FARGATE --task-definition", aws_ecs_task_definition.db_bootstrap.family,
    "--network-configuration 'awsvpcConfiguration={subnets=[${join(",", module.deploy.vpc_private_subnet_ids)}],securityGroups=[${nonsensitive(data.aws_ssm_parameter.db_client_sg.value)}],assignPublicIp=DISABLED}'",
  ])
}

output "ecr_repository_url" {
  value = aws_ecr_repository.gateway.repository_url
}
