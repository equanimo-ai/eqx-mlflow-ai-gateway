output "environment" {
  value       = data.aws_ssm_parameter.environment.value
  description = "Environment slug as published by L1."
}

output "dist_bucket" {
  value       = try(data.aws_ssm_parameter.dist_bucket[0].value, "")
  description = "Shared per-env web origin bucket, or \"\" when enable_s3_dist is off."
}

output "artifacts_bucket" {
  value       = try(data.aws_ssm_parameter.artifacts_bucket[0].value, "")
  description = "Build-artifacts bucket, or \"\" when enable_s3_artifacts is off."
}

output "cloudfront_distribution_id" {
  value       = try(data.aws_ssm_parameter.cloudfront_distribution_id[0].value, "")
  description = "Shared per-env CloudFront distribution id, or \"\" when enable_cloudfront is off."
}

output "api_domain_name" {
  value       = try(data.aws_ssm_parameter.api_domain_name[0].value, "")
  description = "Shared API hostname (api.{env-domain}) — pass to lambda-api's api_domain_name, or \"\" when has_dns is off."
}

output "cloudfront_certificate_arn" {
  value       = try(data.aws_ssm_parameter.cloudfront_certificate_arn[0].value, "")
  description = "us-east-1 wildcard cert for CloudFront viewer certificates (web-edge custom_domain), or \"\"."
}

output "wildcard_certificate_arn" {
  value       = try(data.aws_ssm_parameter.wildcard_certificate_arn[0].value, "")
  description = "Regional wildcard cert (API Gateway / ALB), or \"\"."
}

output "dns_hosted_zone_id" {
  value       = try(data.aws_ssm_parameter.dns_hosted_zone_id[0].value, "")
  description = "Route53 zone id owning the env's domain suffix, or \"\"."
}

output "ssm_prefix" {
  value       = local.prefix
  description = "The /apc/{env} prefix — pass as ssm_read_prefix to the lambda-api module."
}

output "ecs_cluster_arn" {
  value       = try(data.aws_ssm_parameter.ecs_cluster_arn[0].value, "")
  description = "Pass to ecs-fargate-service's cluster_arn, or \"\" when has_ecs_cluster is off."
}

output "ecs_cluster_name" {
  value = try(data.aws_ssm_parameter.ecs_cluster_name[0].value, "")
}

output "ecs_service_discovery_namespace_id" {
  value       = try(data.aws_ssm_parameter.ecs_service_discovery_namespace[0].value, "")
  description = "Pass to ecs-fargate-service's service_discovery_namespace_id, or \"\" to skip registration."
}

output "vpc_id" {
  value = try(data.aws_ssm_parameter.vpc_id[0].value, "")
}

output "vpc_private_subnet_ids" {
  value       = try(split(",", data.aws_ssm_parameter.vpc_private_subnet_ids[0].value), [])
  description = "Pass to ecs-fargate-service's subnet_ids."
}

output "cache_host" {
  value       = try(data.aws_ssm_parameter.cache_host[0].value, "")
  description = "ElastiCache (Valkey) cluster endpoint address, or \"\" when has_cache is off."
}

output "cache_port" {
  value       = try(data.aws_ssm_parameter.cache_port[0].value, "")
  description = "ElastiCache port (6379), or \"\" when has_cache is off."
}

output "cache_security_group_id" {
  value       = try(data.aws_ssm_parameter.cache_security_group_id[0].value, "")
  description = "ElastiCache security group ID, or \"\" when has_cache is off."
}

output "cache_client_security_group_id" {
  value       = try(data.aws_ssm_parameter.cache_client_security_group_id[0].value, "")
  description = "Security group for clients (policy-engine, policy-evaluator, gateway) to attach for Redis access."
}

output "redis_url" {
  value       = var.has_cache ? "redis://${try(data.aws_ssm_parameter.cache_host[0].value, "")}:${try(data.aws_ssm_parameter.cache_port[0].value, "6379")}" : ""
  description = "Full Redis connection URL (redis://host:6379)."
}

