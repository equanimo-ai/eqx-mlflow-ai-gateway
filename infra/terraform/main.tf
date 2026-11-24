module "deploy" {
  source      = "./modules/deploy-contract"
  environment = var.environment
}

# Resources are added in later tasks (service, ALB, DNS).
