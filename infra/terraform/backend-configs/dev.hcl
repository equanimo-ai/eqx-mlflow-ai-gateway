bucket       = "apc-tfstate-dev"
key          = "eqx-mlflow-ai-gateway/dev/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true # S3-native state locking
encrypt      = true
