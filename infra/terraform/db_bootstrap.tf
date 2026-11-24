data "aws_ssm_parameter" "db_host" {
  name = "/apc/${var.environment}/deploy/db/host"
}

data "aws_ssm_parameter" "db_master_secret_arn" {
  name = "/apc/${var.environment}/deploy/db/master_secret_arn"
}

data "aws_ssm_parameter" "db_client_sg" {
  name = "/apc/${var.environment}/deploy/db/client_security_group_id"
}

resource "random_password" "db_app" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "db_url" {
  name = "eqx-mlflow-gateway-${var.environment}-db-url"
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql+psycopg2://mlflow_app:${random_password.db_app.result}@${nonsensitive(data.aws_ssm_parameter.db_host.value)}:5432/mlflow?sslmode=require"
}

resource "aws_secretsmanager_secret" "db_app_password" {
  name = "eqx-mlflow-gateway-${var.environment}-db-app-password"
}

resource "aws_secretsmanager_secret_version" "db_app_password" {
  secret_id     = aws_secretsmanager_secret.db_app_password.id
  secret_string = random_password.db_app.result
}

resource "aws_cloudwatch_log_group" "db_bootstrap" {
  name              = "/ecs/eqx-mlflow-gateway-${var.environment}-db-bootstrap"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "db_bootstrap_execution" {
  name = "eqx-mlflow-gateway-${var.environment}-db-bootstrap-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "db_bootstrap_execution" {
  role       = aws_iam_role.db_bootstrap_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "db_bootstrap_secrets" {
  name = "read-bootstrap-secrets"
  role = aws_iam_role.db_bootstrap_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        nonsensitive(data.aws_ssm_parameter.db_master_secret_arn.value),
        aws_secretsmanager_secret.db_app_password.arn,
      ]
    }]
  })
}

resource "aws_ecs_task_definition" "db_bootstrap" {
  family                   = "eqx-mlflow-gateway-${var.environment}-db-bootstrap"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.db_bootstrap_execution.arn

  container_definitions = jsonencode([{
    name      = "bootstrap"
    image     = "public.ecr.aws/docker/library/postgres:16-alpine"
    essential = true
    command   = ["sh", "-c", "printf '%s\n' \"$SQL\" | psql -v ON_ERROR_STOP=1 -v app_password=\"$APP_PASSWORD\" -d postgres"]
    environment = [
      { name = "PGHOST", value = nonsensitive(data.aws_ssm_parameter.db_host.value) },
      { name = "PGSSLMODE", value = "require" },
      { name = "SQL", value = file("${path.module}/db_bootstrap.sql") },
    ]
    secrets = [
      { name = "PGUSER", valueFrom = "${nonsensitive(data.aws_ssm_parameter.db_master_secret_arn.value)}:username::" },
      { name = "PGPASSWORD", valueFrom = "${nonsensitive(data.aws_ssm_parameter.db_master_secret_arn.value)}:password::" },
      { name = "APP_PASSWORD", valueFrom = aws_secretsmanager_secret.db_app_password.arn },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.db_bootstrap.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "bootstrap"
      }
    }
  }])
}
