output "load_balancer" {
  value = module.cluster.lb_dns_name
}

output "node_instance_id" {
  value = module.cluster.instance_id
}

output "database_address" {
  value = module.database.address
}

output "database_secret_arn" {
  value = module.database.master_secret_arn
}

output "backup_bucket" {
  value = module.backup.backup_bucket
}
