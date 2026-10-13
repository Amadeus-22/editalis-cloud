variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the load balancer's HTTPS listener"
  type        = string
}

variable "budget_email" {
  description = "Address that receives the cost alert"
  type        = string
}

variable "monthly_budget_usd" {
  type    = number
  default = 10
}
