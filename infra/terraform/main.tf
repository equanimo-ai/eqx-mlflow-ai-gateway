module "deploy" {
  source               = "./modules/deploy-contract"
  environment          = var.environment
  has_dist_bucket      = false
  has_artifacts_bucket = false
  has_cloudfront       = false
  has_dns              = true
  has_ecs_cluster      = true
}
