# Read-only consumer of the Layer-1 → Layer-2 SSM contract.
#
# An L2 app root uses this to resolve the deploy targets Layer 1 publishes —
# WITHOUT re-implementing SSM lookups or (the anti-pattern this replaces)
# standing up its own networking. Layer 1 owns all of these values; Layer 2
# only reads them.
#
# Keys that Layer 1 publishes ONLY when a backing resource exists (dist_bucket,
# artifacts_bucket, cloudfront_distribution_id are gated by enable_s3_dist /
# enable_s3_artifacts / enable_cloudfront) are optional here: set the matching
# has_* flag to false to skip the lookup and receive "".

variable "environment" {
  type        = string
  description = "Environment slug (dev|prod) — selects the /apc/{env} prefix."
}

variable "has_dist_bucket" {
  type        = bool
  default     = true
  description = "Whether L1 published deploy/dist_bucket (enable_s3_dist)."
}

variable "has_artifacts_bucket" {
  type        = bool
  default     = true
  description = "Whether L1 published deploy/artifacts_bucket (enable_s3_artifacts)."
}

variable "has_cloudfront" {
  type        = bool
  default     = true
  description = "Whether L1 published deploy/cloudfront_distribution_id (enable_cloudfront)."
}

variable "has_dns" {
  type        = bool
  default     = false
  description = "Whether L1 published deploy/dns/* (enable_dns): shared api domain + wildcard certs."
}

variable "has_ecs_cluster" {
  type        = bool
  default     = false
  description = "Whether L1 published deploy/ecs/* (enable_ecs_shared_cluster): the shared ECS Fargate cluster + Cloud Map namespace every ecs-fargate-service instantiation deploys onto."
}

variable "has_cache" {
  type        = bool
  default     = false
  description = "Whether L1 published deploy/cache/* (enable_elasticache): Redis/Valkey host, port, and client security group."
}

locals {
  prefix = "/apc/${var.environment}"
}


# Always-present keys.
data "aws_ssm_parameter" "environment" {
  name = "${local.prefix}/deploy/environment"
}

# Optional deploy targets (present only when the backing resource is enabled).
data "aws_ssm_parameter" "dist_bucket" {
  count = var.has_dist_bucket ? 1 : 0
  name  = "${local.prefix}/deploy/dist_bucket"
}

data "aws_ssm_parameter" "artifacts_bucket" {
  count = var.has_artifacts_bucket ? 1 : 0
  name  = "${local.prefix}/deploy/artifacts_bucket"
}

data "aws_ssm_parameter" "cloudfront_distribution_id" {
  count = var.has_cloudfront ? 1 : 0
  name  = "${local.prefix}/deploy/cloudfront_distribution_id"
}

# DNS / edge (present only when L1's enable_dns is on). The dns-edge module in
# apc-platform-infra is the single owner of certs + the shared api domain; L2 only reads.
data "aws_ssm_parameter" "api_domain_name" {
  count = var.has_dns ? 1 : 0
  name  = "${local.prefix}/deploy/dns/api_domain_name"
}

data "aws_ssm_parameter" "cloudfront_certificate_arn" {
  count = var.has_dns ? 1 : 0
  name  = "${local.prefix}/deploy/dns/cloudfront_certificate_arn"
}

data "aws_ssm_parameter" "wildcard_certificate_arn" {
  count = var.has_dns ? 1 : 0
  name  = "${local.prefix}/deploy/dns/wildcard_certificate_arn"
}

data "aws_ssm_parameter" "dns_hosted_zone_id" {
  count = var.has_dns ? 1 : 0
  name  = "${local.prefix}/deploy/dns/hosted_zone_id"
}

# Shared ECS cluster (present only when L1's enable_ecs_shared_cluster is on).
data "aws_ssm_parameter" "ecs_cluster_arn" {
  count = var.has_ecs_cluster ? 1 : 0
  name  = "${local.prefix}/deploy/ecs/cluster_arn"
}

data "aws_ssm_parameter" "ecs_cluster_name" {
  count = var.has_ecs_cluster ? 1 : 0
  name  = "${local.prefix}/deploy/ecs/cluster_name"
}

data "aws_ssm_parameter" "ecs_service_discovery_namespace" {
  count = var.has_ecs_cluster ? 1 : 0
  name  = "${local.prefix}/deploy/ecs/service_discovery_namespace"
}

data "aws_ssm_parameter" "vpc_id" {
  count = var.has_ecs_cluster ? 1 : 0
  name  = "${local.prefix}/deploy/vpc/id"
}

data "aws_ssm_parameter" "vpc_private_subnet_ids" {
  count = var.has_ecs_cluster ? 1 : 0
  name  = "${local.prefix}/deploy/vpc/private_subnet_ids"
}

# Shared ElastiCache (Valkey) cache (present only when L1's enable_elasticache is on).
data "aws_ssm_parameter" "cache_host" {
  count = var.has_cache ? 1 : 0
  name  = "${local.prefix}/deploy/cache/host"
}

data "aws_ssm_parameter" "cache_port" {
  count = var.has_cache ? 1 : 0
  name  = "${local.prefix}/deploy/cache/port"
}

data "aws_ssm_parameter" "cache_security_group_id" {
  count = var.has_cache ? 1 : 0
  name  = "${local.prefix}/deploy/cache/security_group_id"
}

data "aws_ssm_parameter" "cache_client_security_group_id" {
  count = var.has_cache ? 1 : 0
  name  = "${local.prefix}/deploy/cache/client_security_group_id"
}

