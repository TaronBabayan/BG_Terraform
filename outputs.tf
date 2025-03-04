# DNS name of load_balancer 
output "load_balancer_dns" {
  description = "The DNS name of the ALB"
  value       = aws_alb.ecs_alb.dns_name
}

# Bastiontosts Public IP 
output "bastion_ip" {
  description = "Bastion Host public IP"
  value       = aws_instance.web.public_ip
}


# Output RDS Endpoint
output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.postgresql.endpoint
}
