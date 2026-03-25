output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.main.name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_listener_arn" {
  description = "ALB HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}

output "lambda_target_group_arn" {
  description = "Lambda target group ARN"
  value       = aws_lb_target_group.accounts_lambda.arn
}

output "api_record_fqdn" {
  description = "Route53 API record FQDN"
  value       = aws_route53_record.api.fqdn
}
