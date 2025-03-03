output "load_balancer_dns" {
  description = "The DNS name of the ALB"
  value       = aws_alb.ecs_alb.dns_name
}
