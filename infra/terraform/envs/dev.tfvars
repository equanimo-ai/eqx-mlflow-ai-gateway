region                     = "us-east-1"
environment                = "dev"
hostname                   = "ai-gateway.dev.equanimo.io"
shell_origin               = "https://app.dev.equanimo.io"
shared_alb_name            = "equanimo-alb"
capacity_provider_strategy = [{ capacity_provider = "FARGATE_SPOT", weight = 1, base = 0 }]
# Platform deploy-contract key for the Aurora host (platform-infra main.tf publishes
# "db/host" under /apc/<env>/deploy/; apc-schema's "db/proxy_endpoint" wording is stale).
db_proxy_endpoint_ssm_path = "/apc/dev/deploy/db/host"

# Pass at apply time with -var (not set here, needs live AWS):
#   alb_listener_rule_priority: unused priority on the :443 listener of equanimo-alb
#     (aws elbv2 describe-rules --listener-arn <443 listener> --query 'Rules[].Priority')
#   image: ECR image URI from the Task 4 container build, pinned tag/digest
#   aurora_sg_id: Aurora client SG id, SSM /apc/dev/deploy/db/client_security_group_id
