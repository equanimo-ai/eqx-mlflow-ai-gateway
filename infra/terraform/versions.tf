terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "AI-Prompt-Collector"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "equanimo"
    }
  }
}
