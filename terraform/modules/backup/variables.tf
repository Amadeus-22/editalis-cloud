variable "name" {
  description = "Prefix for bucket names"
  type        = string
}

variable "backup_retention_days" {
  description = "Days a database dump is kept"
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets (lab only)"
  type        = bool
  default     = false
}
