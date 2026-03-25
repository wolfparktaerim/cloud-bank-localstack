# ─────────────────────────────────────────────
# Module: edge
# Creates: Route53 hosted zone, ALB, listener, lambda target group
# ─────────────────────────────────────────────

resource "aws_route53_zone" "main" {
  name = var.route53_zone_name

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-zone"
  })
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })
}

resource "aws_lb_target_group" "accounts_lambda" {
  name        = "${var.project_name}-acct-tg"
  target_type = "lambda"

  tags = merge(var.tags, {
    Name = "${var.project_name}-acct-tg"
  })
}

resource "aws_lambda_permission" "allow_alb_invoke" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_target_function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.accounts_lambda.arn
}

resource "aws_lb_target_group_attachment" "accounts_lambda" {
  target_group_arn = aws_lb_target_group.accounts_lambda.arn
  target_id        = var.lambda_target_function_arn

  depends_on = [aws_lambda_permission.allow_alb_invoke]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.accounts_lambda.arn
  }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.route53_record_name
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.main.dns_name]
}
