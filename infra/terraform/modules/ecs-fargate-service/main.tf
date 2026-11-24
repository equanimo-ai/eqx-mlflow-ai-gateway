# Reusable ECS Fargate service, deployed onto the ONE shared cluster the
# deploy contract publishes (ecs_cluster_arn) -- this module never creates a
# cluster. One instantiation per app service (apc-embedding-service, dsl-compiler,
# litellm, ...); each gets its own task def, SG, IAM roles, and scaling here,
# even though all three share the same cluster's capacity-provider pool.
#
# Terraform owns configuration only; CI registers new task-definition
# revisions and calls `aws ecs update-service` directly after a real image is
# pushed -- see the ignore_changes note on aws_ecs_service.this below, which
# mirrors lambda-api's "Terraform owns config, CI owns code" split.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # NOTE: switch to data.aws_region.current.region when this module's
  # provider constraint moves to aws ~> 6.0 -- confirmed by direct testing
  # that .region doesn't exist yet under the ~> 5.30 this repo currently
  # pins (only .name does), so changing it now would break validate/plan
  # against the actual pinned provider, not just silence a warning.
  region          = data.aws_region.current.name
  has_efs         = length(var.efs_mounts) > 0
  has_alb         = var.alb_target_group_arn != ""
  has_internal_lb = var.internal_target_group_arn != ""
  has_sd          = var.enable_service_discovery && var.service_discovery_namespace_id != ""
  cluster_name    = element(split("/", var.cluster_arn), length(split("/", var.cluster_arn)) - 1)
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { Name = "/ecs/${var.name}" })
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "execution" {
  name                 = "${var.name}-execution"
  permissions_boundary = var.permissions_boundary
  tags                 = merge(var.tags, { Name = "${var.name}-execution" })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS resolves container-definition `secrets` entries (var.secrets) at task
# launch using the EXECUTION role, not the task role -- distinct from the ssm
# policy below, which is the task role's own runtime access.
resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.secrets) == 0 ? 0 : 1
  name  = "${var.name}-secrets"
  role  = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [for s in var.secrets : s.value_from]
    }]
  })
}

resource "aws_iam_role" "task" {
  name                 = "${var.name}-task"
  permissions_boundary = var.permissions_boundary
  tags                 = merge(var.tags, { Name = "${var.name}-task" })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Runtime can always read its own SSM namespace (secrets + config) -- same
# shape as lambda-api's ssm policy.
resource "aws_iam_role_policy" "ssm" {
  name = "${var.name}-ssm"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter${var.ssm_read_prefix}/*"
      }],
      var.kms_key_arn == "" ? [] : [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }]
    )
  })
}

resource "aws_iam_role_policy" "additional" {
  # A known flag, not the JSON: the document embeds ARNs of resources created in
  # the same apply, so in a fresh account the whole string is unknown at plan
  # time and a count derived from it fails ("Invalid count argument").
  count  = var.additional_policy_enabled ? 1 : 0
  name   = "${var.name}-extra"
  role   = aws_iam_role.task.id
  policy = var.additional_policy_json
}

# ── Networking ────────────────────────────────────────────────────────────────

resource "aws_security_group" "this" {
  name        = "${var.name}-svc"
  description = "${var.name} ECS service -- ingress from allowed_security_group_ids only, never a CIDR block"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-svc" })

  dynamic "egress" {
    for_each = var.restrict_egress ? [] : [1]
    content {
      description = "Default open egress (image pulls via NAT, etc.)"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = var.restrict_egress && length(var.egress_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = var.egress_cidr_blocks
    }
  }

  # A name change forces replacement; without this the old SG deletes first
  # and blocks on the ECS task ENI still attached to it.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "egress_to_sg" {
  for_each                 = var.restrict_egress ? toset(var.egress_security_group_ids) : toset([])
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = each.value
}

resource "aws_service_discovery_service" "this" {
  count = local.has_sd ? 1 : 0
  name  = var.name

  dns_config {
    namespace_id = var.service_discovery_namespace_id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

# ── Task definition + service ────────────────────────────────────────────────

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory_mb)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  tags                     = merge(var.tags, { Name = var.name })

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = var.name
    image     = var.image
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    environment = [for k, v in var.environment_variables : { name = k, value = v }]
    secrets     = [for s in var.secrets : { name = s.name, valueFrom = s.value_from }]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
      interval    = 30
      timeout     = 10
      retries     = 3
      startPeriod = 60
    }
    mountPoints = [for m in var.efs_mounts : {
      sourceVolume  = md5(m.file_system_id)
      containerPath = m.container_path
      readOnly      = m.read_only
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = var.name
      }
    }
  }])

  dynamic "volume" {
    for_each = var.efs_mounts
    content {
      name = md5(volume.value.file_system_id)
      efs_volume_configuration {
        file_system_id     = volume.value.file_system_id
        transit_encryption = "ENABLED"
        dynamic "authorization_config" {
          for_each = volume.value.access_point_id == "" ? [] : [1]
          content {
            access_point_id = volume.value.access_point_id
            iam             = "ENABLED"
          }
        }
      }
    }
  }
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  tags            = merge(var.tags, { Name = var.name })

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = concat([aws_security_group.this.id], var.additional_security_group_ids)
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = local.has_alb ? [1] : []
    content {
      target_group_arn = var.alb_target_group_arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  # Second load_balancer block, for the internal NLB target group (API
  # Gateway's VPC Link) -- ECS supports registering one service with more
  # than one target group, each as its own load_balancer block.
  dynamic "load_balancer" {
    for_each = local.has_internal_lb ? [1] : []
    content {
      target_group_arn = var.internal_target_group_arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = local.has_sd ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.this[0].arn
    }
  }

  # Model/app load can take real time on a fresh task (BGE-M3, GLiNER, vLLM
  # weights) -- give ECS room before treating a not-yet-healthy container as a
  # failed deployment, same rationale as apc-embedding-service.
  health_check_grace_period_seconds = local.has_alb || local.has_sd ? 60 : null

  # Without this, a bad task-def revision (bad image, bad config) retries
  # indefinitely -- each failed task start re-pulls the image, which is
  # exactly the mechanism behind the July 2026 dsl-compiler incident (a
  # crash-loop's repeated image pulls routed through NAT before the missing
  # S3 gateway endpoint was fixed, running up a large data-processing bill).
  # This caps it: after enough consecutive failures, ECS stops retrying and
  # rolls the service back to the last known-good task definition.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    # CI registers a new task-definition revision and updates the service
    # directly once a real image ships (see the image variable's default
    # comment) -- without this, the next `terraform apply` would force the
    # service back to whatever revision Terraform itself last created,
    # undoing CI's deploy. Terraform still owns everything else (cpu/memory,
    # env vars, scaling, networking) via aws_ecs_task_definition.this above.
    #
    # desired_count is also always ignored -- same reasoning as
    # apc-embedding-service's identical, long-standing ignore_changes: an external
    # EventBridge business-hours schedule flips this 0<->N outside Terraform
    # for every current caller, and this attribute can't be conditionally
    # ignored based on schedule_managed_desired_count -- Terraform's
    # ignore_changes list must be a static literal, not an expression.
    ignore_changes = [task_definition, desired_count]
  }
}

# ── Application AutoScaling ───────────────────────────────────────────────────

resource "aws_appautoscaling_target" "ecs" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${local.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.enable_autoscaling && var.cpu_target_tracking_percent > 0 ? 1 : 0
  name               = "${var.name}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_tracking_percent
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count              = var.enable_autoscaling && var.memory_target_tracking_percent > 0 ? 1 : 0
  name               = "${var.name}-memory-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_tracking_percent
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

