# Dedicated `mlflow` database, schema `public`, via the platform's apc-schema module.
# PREREQUISITE (platform change, not in this repo): the `mlflow` database and its
# mlflow_db_reader/mlflow_db_writer group roles must be created by apc-platform-infra's
# bootstrap (PLATFORM_DATABASES in databases.ts, roles.ts, locals.tf schema_database,
# platform_bootstrap_version bump). apc-schema cannot create the database itself.
data "aws_ssm_parameter" "db_proxy_endpoint" {
  name = var.db_proxy_endpoint_ssm_path
}

data "aws_ssm_parameter" "db_master_secret_arn" {
  name = "${module.deploy.ssm_prefix}/deploy/db/master_secret_arn"
}

module "db" {
  source = "git::https://github.com/equanimo-ai/apc-platform-infra.git//modules/apc-schema?ref=d92d2ace6d63"

  environment          = var.environment
  module_slug          = "mlflow-gateway"
  db_name              = "mlflow"
  schema_name          = "public"
  db_proxy_endpoint    = nonsensitive(data.aws_ssm_parameter.db_proxy_endpoint.value)
  db_master_secret_arn = nonsensitive(data.aws_ssm_parameter.db_master_secret_arn.value)
  migrations_path      = "${path.module}/migrations"

  # The migrator is a zip whose src/index.handler provisions the role (apc-schema runs
  # whatever the zip contains). It must be built before plan/apply; see the Task 6 report.
  migrations_lambda_package = "${path.module}/migrator/dist/mlflow-migrator.zip"

  vpc_attached       = true
  subnet_ids         = module.deploy.vpc_private_subnet_ids
  security_group_ids = [var.aurora_sg_id]

  common_tags = { Project = "AI-Prompt-Collector", Environment = var.environment }
}
