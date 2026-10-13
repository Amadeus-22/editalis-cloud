output "instance_id" {
  description = "Use with: aws ssm start-session --target <id>"
  value       = aws_instance.node.id
}

output "lb_dns_name" {
  value = aws_lb.this.dns_name
}
