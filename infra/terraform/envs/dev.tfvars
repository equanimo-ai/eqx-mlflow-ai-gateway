region                     = "us-east-1"
environment                = "dev"
hostname                   = "ai-gateway.dev.equanimo.io"
shell_origin               = "https://app.dev.equanimo.io"
shared_alb_name            = "eqx-alb"
capacity_provider_strategy = [{ capacity_provider = "FARGATE_SPOT", weight = 1, base = 0 }]

# Pass at apply time with -var (not set here, needs live AWS):
#   alb_listener_rule_priority: unused priority on the :443 listener of eqx-alb
#     (aws elbv2 describe-rules --listener-arn <443 listener> --query 'Rules[].Priority')
#   image: ECR image URI from the Task 4 container build, pinned tag/digest
