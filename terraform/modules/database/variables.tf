variable "name" {
  description = "Identifier of the instance and its groups"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the instance"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group that only admits the node"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Database created on first boot"
  type        = string
  default     = "editalis"
}

variable "db_user" {
  description = "Master user name"
  type        = string
  default     = "editalis"
}

variable "backup_retention_days" {
  description = "Days of automated snapshots kept by RDS"
  type        = number
  default     = 7
}

variable "lab" {
  description = "Single-AZ, no deletion protection, no final snapshot"
  type        = bool
  default     = false
}
