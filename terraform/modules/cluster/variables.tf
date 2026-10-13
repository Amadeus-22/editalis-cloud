variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet for the node"
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets for the load balancer (two availability zones)"
  type        = list(string)
}

variable "node_security_group_id" {
  type = string
}

variable "lb_security_group_id" {
  type = string
}

variable "instance_type" {
  description = "Instance type of the k3s node (arm64)"
  type        = string
  default     = "t4g.small"
}

variable "k3s_version" {
  description = "Pinned k3s release"
  type        = string
  default     = "v1.31.4+k3s1"
}

variable "ingress_node_port" {
  type    = number
  default = 30080
}

variable "certificate_arn" {
  description = "ACM certificate for the HTTPS listener"
  type        = string
}

variable "backup_bucket_arn" {
  type = string
}

variable "logs_bucket" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "lab" {
  description = "Disable load balancer deletion protection so the lab can be destroyed"
  type        = bool
  default     = false
}
