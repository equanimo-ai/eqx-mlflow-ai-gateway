resource "aws_s3_bucket" "artifacts" {
  bucket = "eqx-mlflow-gateway-artifacts-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

module "service" {
  source = "./modules/ecs-fargate-service"

  name                       = "eqx-mlflow-gateway"
  cluster_arn                = module.deploy.ecs_cluster_arn
  vpc_id                     = module.deploy.vpc_id
  subnet_ids                 = module.deploy.vpc_private_subnet_ids
  image                      = var.image
  container_port             = 5000
  cpu                        = var.cpu
  memory_mb                  = var.memory_mb
  desired_count              = var.desired_count
  capacity_provider_strategy = var.capacity_provider_strategy
  health_check_path          = "/health"
  alb_target_group_arn       = aws_lb_target_group.this.arn
  log_retention_days         = var.log_retention_days
  # The module requires a prefix but this service reads no SSM; point it at an
  # app-private, empty path so the task role cannot read other apps' /apc/dev/* params.
  ssm_read_prefix = "${module.deploy.ssm_prefix}/modules/mlflow-gateway"

  # Reached only through the ALB; no Cloud Map registration.
  enable_service_discovery      = false
  allowed_security_group_ids    = data.aws_lb.shared.security_groups
  additional_security_group_ids = [nonsensitive(data.aws_ssm_parameter.db_client_sg.value)]

  environment_variables = {
    MLFLOW_ARTIFACT_ROOT               = "s3://${aws_s3_bucket.artifacts.bucket}"
    MLFLOW_UI_GATEWAY_ONLY             = "true"
    MLFLOW_SERVER_FRAME_ANCESTORS      = var.shell_origin
    MLFLOW_SERVER_ALLOWED_HOSTS        = var.hostname
    MLFLOW_SERVER_CORS_ALLOWED_ORIGINS = "https://${var.hostname},${var.shell_origin}"
  }

  secrets = [
    { name = "MLFLOW_CRYPTO_KEK_PASSPHRASE", value_from = aws_secretsmanager_secret.kek.arn },
    { name = "MLFLOW_BACKEND_STORE_URI", value_from = aws_secretsmanager_secret.db_url.arn },
  ]

  additional_policy_enabled = true
  additional_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
    }]
  })

  enable_off_hours_schedule = true
  off_hours_stop_cron       = "cron(0 22 * * ? *)"
  off_hours_start_cron      = "cron(30 7 * * ? *)"
  off_hours_timezone        = "America/Chicago"
}
