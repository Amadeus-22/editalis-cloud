# PostgreSQL on RDS, in the private subnets, reachable from the node only.
# The master password is generated and stored by RDS in Secrets Manager, so it
# never appears in Terraform variables or state.

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "500" # log statements slower than 500 ms
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }
}

# Role that lets RDS publish OS-level metrics (enhanced monitoring).
data "aws_iam_policy_document" "assume_monitoring" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.assume_monitoring.json
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  db_name                     = var.db_name
  username                    = var.db_user
  manage_master_user_password = true

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  # Automated snapshots with point-in-time recovery, on top of the logical
  # dumps the cluster sends to S3.
  backup_retention_period  = var.backup_retention_days
  backup_window            = "06:00-07:00"
  maintenance_window       = "sun:07:30-sun:08:30"
  copy_tags_to_snapshot    = true
  delete_automated_backups = var.lab

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.monitoring.arn

  auto_minor_version_upgrade            = true
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  iam_database_authentication_enabled   = true

  # A lab is single-AZ and destroyable; production flips these three.
  multi_az                  = !var.lab
  deletion_protection       = !var.lab
  skip_final_snapshot       = var.lab
  final_snapshot_identifier = var.lab ? null : "${var.name}-final"
}
