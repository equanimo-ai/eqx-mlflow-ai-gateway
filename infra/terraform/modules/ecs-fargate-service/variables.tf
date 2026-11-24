variable "name" {
  type        = string
  description = "Fully-qualified service name, e.g. apc-dev-dsl-compiler."
}

variable "cluster_arn" {
  type        = string
  description = "Shared cluster ARN from the deploy contract (deploy-contract output ecs_cluster_arn). One cluster per environment -- this module never creates one."
}

variable "vpc_id" {
  type        = string
  description = "From the deploy contract (ecs_cluster's Cloud Map namespace VPC)."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet ids the task ENI attaches to (deploy contract vpc_private_subnet_ids)."
}

variable "image" {
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:stable"
  description = "Placeholder image so the service can be created before CI ever pushes a real one. CI registers new task-def revisions and updates the service directly after that -- see the ignore_changes note on aws_ecs_service.this."
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 512
}

variable "cpu_architecture" {
  type    = string
  default = "X86_64"
}

variable "memory_mb" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "capacity_provider_strategy" {
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default     = []
  description = "Override the cluster's default capacity provider strategy for this service only, e.g. [{capacity_provider = \"FARGATE_SPOT\", weight = 100}] for an internal, retry-tolerant dev service. Empty = inherit the cluster default (on-demand FARGATE)."
}

variable "health_check_path" {
  type    = string
  default = "/healthz"
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Plain (non-secret) container env vars. Secrets are read at runtime from SSM under ssm_read_prefix."
}

variable "secrets" {
  type = list(object({
    name       = string
    value_from = string
  }))
  default     = []
  description = "Container-definition `secrets` entries for values that live in Secrets Manager rather than under ssm_read_prefix (e.g. a service's own DB URL/master key from its own stack, not the shared SSM namespace). The execution role gets secretsmanager:GetSecretValue scoped to each value_from ARN."
}

variable "ssm_read_prefix" {
  type        = string
  description = "SSM path prefix the task role may read at runtime, e.g. /apc/dev."
}

variable "kms_key_arn" {
  type        = string
  default     = ""
  description = "Optional CMK the task role may use (decrypt secrets published under ssm_read_prefix as SecureString)."
}

variable "additional_policy_json" {
  type        = string
  default     = ""
  description = "Optional extra IAM policy document (JSON) attached to the task role (not the execution role). Only attached when additional_policy_enabled is true."
}

variable "additional_policy_enabled" {
  type        = bool
  default     = false
  description = "Attach additional_policy_json. A separate known-at-plan flag because the JSON itself may be unknown at plan time (it can embed ARNs of resources created in the same apply), which a count cannot depend on."
}

variable "allowed_security_group_ids" {
  type        = list(string)
  default     = []
  description = "SGs allowed ingress on container_port, e.g. [gateway_sg_id]. Additive -- add a caller's SG here, never widen to a CIDR block for internal services."
}

variable "restrict_egress" {
  type        = bool
  default     = false
  description = "true = egress limited to egress_cidr_blocks/egress_security_group_ids only (e.g. LLM/GLiNER tasks that must never reach the internet at runtime). false = default open egress (image pulls via NAT, etc.)."
}

variable "egress_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "egress_security_group_ids" {
  type    = list(string)
  default = []
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "alb_target_group_arn" {
  type        = string
  default     = ""
  description = "Attach to an existing ALB target group. Empty = no load balancer (e.g. an internal service reached only via Cloud Map)."
}

variable "internal_target_group_arn" {
  type        = string
  default     = ""
  description = "Attach a second load_balancer block to an existing (internal NLB) target group, alongside alb_target_group_arn. Empty = no second load balancer registration."
}

variable "enable_service_discovery" {
  type    = bool
  default = true
}

variable "service_discovery_namespace_id" {
  type        = string
  default     = ""
  description = "From the deploy contract (ecs_service_discovery_namespace_id). Required when enable_service_discovery = true."
}

variable "efs_mounts" {
  type = list(object({
    file_system_id  = string
    container_path  = string
    access_point_id = optional(string, "")
    read_only       = optional(bool, true)
  }))
  default     = []
  description = "Shared EFS mounts (e.g. GLiNER checkpoint, compiled taxonomy). read_only = true unless the service writes back (the taxonomy compile job)."
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "enable_autoscaling" {
  type        = bool
  default     = false
  description = "Enable Application AutoScaling target tracking on the ECS service."
}

variable "min_capacity" {
  type        = number
  default     = 1
  description = "Minimum number of tasks when autoscaling is enabled."
}

variable "max_capacity" {
  type        = number
  default     = 10
  description = "Maximum number of tasks when autoscaling is enabled."
}

variable "cpu_target_tracking_percent" {
  type        = number
  default     = 70
  description = "Target average CPU utilization percentage (0 to disable CPU tracking)."
}

variable "memory_target_tracking_percent" {
  type        = number
  default     = 80
  description = "Target average Memory utilization percentage (0 to disable Memory tracking)."
}

variable "scale_in_cooldown" {
  type        = number
  default     = 300
  description = "Cooldown period in seconds before allowing another scale-in activity."
}

variable "scale_out_cooldown" {
  type        = number
  default     = 60
  description = "Cooldown period in seconds before allowing another scale-out activity."
}

variable "tags" {
  type    = map(string)
  default = {}
}


variable "additional_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Extra security groups attached to the task ENI alongside the service's own. For membership-style client SGs that another stack's resource grants ingress to (e.g. eqx-redis-client)."
}

variable "permissions_boundary" {
  type        = string
  default     = null
  description = "Permissions boundary ARN for the execution and task roles. null leaves them unbounded."
}

variable "enable_off_hours_schedule" {
  type        = bool
  default     = false
  description = "Scale the ECS service to zero between off_hours_stop_cron and off_hours_start_cron (default 00:00-09:00 America/New_York), daily. Requires enable_autoscaling = false."

  validation {
    condition     = !(var.enable_off_hours_schedule && var.enable_autoscaling)
    error_message = "enable_off_hours_schedule needs a fixed desired_count: with enable_autoscaling a desired count of 0 is scaled back up to min_capacity."
  }
}

variable "off_hours_stop_cron" {
  type        = string
  default     = "cron(0 0 * * ? *)"
  description = "EventBridge Scheduler cron that scales the service to zero, evaluated in off_hours_timezone."
}

variable "off_hours_start_cron" {
  type        = string
  default     = "cron(0 9 * * ? *)"
  description = "EventBridge Scheduler cron that restores desired_count, evaluated in off_hours_timezone."
}

variable "off_hours_timezone" {
  type        = string
  default     = "America/New_York"
  description = "IANA timezone for off_hours_stop_cron and off_hours_start_cron."
}
