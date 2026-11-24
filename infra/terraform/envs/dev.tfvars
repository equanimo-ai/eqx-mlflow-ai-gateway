region      = "us-east-1"
environment = "dev"
# Temporary: LiteLLM still owns ai-gateway.dev.equanimo.io (ALB rules, CloudFront,
# Route53 in another stack). Switch to it at the LiteLLM cutover (Task 12).
hostname                   = "ai-gateway-new.dev.equanimo.io"
alb_listener_rule_priority = 400
shell_origin               = "https://app.dev.equanimo.io"
shared_alb_name            = "eqx-alb"
capacity_provider_strategy = [{ capacity_provider = "FARGATE_SPOT", weight = 1, base = 0 }]

# Pass at apply time with -var (not set here, needs live AWS):
#   image: ECR image URI from the Task 4 container build, pinned tag/digest
