output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "lb_security_group_id" {
  value = aws_security_group.lb.id
}

output "node_security_group_id" {
  value = aws_security_group.node.id
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}
