variable "region" { type = string }
variable "environment" { type = string }

variable "hostname" {
  type        = string
  description = "Public hostname, e.g. mlflow.dev.equanimo.io."
}

variable "shell_origin" {
  type        = string
  description = "Shell origin allowed to iframe the UI, e.g. https://app.dev.equanimo.io."
}

variable "shared_alb_name" { type = string }
variable "alb_listener_rule_priority" { type = number }
variable "image" { type = string }
variable "cpu" {
  type    = number
  default = 1024
}
variable "memory_mb" {
  type    = number
  default = 2048
}
variable "desired_count" {
  type    = number
  default = 1
}
variable "capacity_provider_strategy" { type = any }
variable "log_retention_days" {
  type    = number
  default = 7
}
