# Off-hours scale-to-zero: stop/start crons and timezone come from
# off_hours_stop_cron / off_hours_start_cron / off_hours_timezone (default
# 00:00-09:00 America/New_York, daily). EventBridge Scheduler calls ecs:UpdateService directly, so no
# Lambda is needed. The other half of the mechanism is aws_ecs_service.this's
# `ignore_changes = [task_definition, desired_count]`: without it a routine
# `terraform apply` during off hours would fight the scheduler back up.
# Requires enable_autoscaling = false (fixed desired_count): with autoscaling a
# desired count of 0 is scaled straight back up to min_capacity.

resource "aws_iam_role" "scheduler" {
  count = var.enable_off_hours_schedule ? 1 : 0

  name                 = "${var.name}-scheduler"
  permissions_boundary = var.permissions_boundary
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "scheduler" {
  count = var.enable_off_hours_schedule ? 1 : 0

  name = "${var.name}-scheduler"
  role = aws_iam_role.scheduler[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ScaleService"
      Effect   = "Allow"
      Action   = ["ecs:UpdateService"]
      Resource = [aws_ecs_service.this.id]
    }]
  })
}

resource "aws_scheduler_schedule" "off_hours_start" {
  count = var.enable_off_hours_schedule ? 1 : 0

  name                         = "${var.name}-off-hours-start"
  schedule_expression          = var.off_hours_start_cron
  schedule_expression_timezone = var.off_hours_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.scheduler[0].arn
    input = jsonencode({
      Cluster = var.cluster_arn
      Service = var.name
      # var.desired_count, not a hardcoded 1: starting the service back at 1
      # when the caller asked for more would be a silent halving of capacity.
      DesiredCount = var.desired_count
    })
  }
}

resource "aws_scheduler_schedule" "off_hours_stop" {
  count = var.enable_off_hours_schedule ? 1 : 0

  name                         = "${var.name}-off-hours-stop"
  schedule_expression          = var.off_hours_stop_cron
  schedule_expression_timezone = var.off_hours_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.scheduler[0].arn
    input = jsonencode({
      Cluster      = var.cluster_arn
      Service      = var.name
      DesiredCount = 0
    })
  }
}
