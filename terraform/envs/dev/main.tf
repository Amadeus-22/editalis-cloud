locals {
  name = "editalis-${var.environment}"
}

# Cost guard first: an alert at 80% of a small monthly budget.
resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

module "backup" {
  source        = "../../modules/backup"
  name          = local.name
  force_destroy = true
}

module "network" {
  source              = "../../modules/network"
  name                = local.name
  flow_log_bucket_arn = module.backup.logs_bucket_arn
  azs                 = ["${var.region}a", "${var.region}b"]
}

module "database" {
  source            = "../../modules/database"
  name              = local.name
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.db_security_group_id
  lab               = true
}

module "cluster" {
  source                 = "../../modules/cluster"
  name                   = local.name
  vpc_id                 = module.network.vpc_id
  subnet_id              = module.network.public_subnet_ids[0]
  public_subnet_ids      = module.network.public_subnet_ids
  node_security_group_id = module.network.node_security_group_id
  lb_security_group_id   = module.network.lb_security_group_id
  certificate_arn        = var.certificate_arn
  backup_bucket_arn      = module.backup.backup_bucket_arn
  logs_bucket            = module.backup.logs_bucket
  db_secret_arn          = module.database.master_secret_arn
  lab                    = true
}
