# ── Application Load Balancer ─────────────────
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids

  tags = var.tags
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-api-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "lambda"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# Attach Lambda to the target group
resource "aws_lb_target_group_attachment" "accounts_lambda" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = var.accounts_lambda_arn
}

module "load_balancer" {
  source             = "./modules/load_balancer"
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  accounts_lambda_arn = module.compute.lambda_function_names["accounts"]
  tags               = local.common_tags
}

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"

  default_action { allow {} }

  rule {
    name     = "RateLimitRule"
    priority = 1
    action   { block {} }
    statement {
      rate_based_statement {
        limit              = 2000   # requests per 5 min per IP
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "RateLimit"
      sampled_requests_enabled   = false
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = false
  }
}