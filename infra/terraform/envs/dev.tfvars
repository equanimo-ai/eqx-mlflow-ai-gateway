region                             = "us-east-1"
environment                        = "dev"
hostname                           = "mlflow.dev.equanimo.io"
alb_listener_rule_priority         = 400
shell_origin                       = "https://app.dev.equanimo.io"
internal_hostname                  = "eqx-mlflow-gateway.shared-services-dev.internal"
internal_client_security_group_ids = ["sg-0ecbdd9a86a142851"] # eqx-policy-engine-lambda
shared_alb_name                    = "eqx-alb"
memory_mb                          = 4096
capacity_provider_strategy         = [{ capacity_provider = "FARGATE_SPOT", weight = 1, base = 0 }]

# Pass at apply time with -var (not set here, needs live AWS):
#   image: ECR image URI from the Task 4 container build, pinned tag/digest
