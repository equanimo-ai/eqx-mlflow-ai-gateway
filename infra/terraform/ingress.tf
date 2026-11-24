data "aws_lb" "shared" {
  name = var.shared_alb_name
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

resource "aws_lb_target_group" "this" {
  name        = "eqx-mlflow-gw-${var.environment}"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = module.deploy.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_lb_listener_rule" "https" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = var.alb_listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header { values = [var.hostname] }
  }
}

resource "aws_route53_record" "this" {
  zone_id = module.deploy.dns_hosted_zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = false
  }
}
