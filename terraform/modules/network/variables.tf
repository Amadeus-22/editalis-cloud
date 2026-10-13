variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "ingress_node_port" {
  description = "NodePort the ingress controller listens on"
  type        = number
  default     = 30080
}

variable "flow_log_bucket_arn" {
  description = "Bucket that receives rejected-traffic flow logs"
  type        = string
}

variable "azs" {
  description = "Two availability zones, named explicitly so the plan never changes when AWS adds a zone"
  type        = list(string)
  validation {
    condition     = length(var.azs) == 2
    error_message = "Exactly two availability zones are required."
  }
}
