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

variable "internal_hostname" {
  type        = string
  default     = ""
  description = "Cloud Map name in-VPC callers use, e.g. eqx-mlflow-gateway.shared-services-dev.internal. Empty disables the internal route."
}

variable "internal_client_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security groups allowed to reach the service directly on port 5000 (in-VPC callers such as the Policy Engine Lambda)."
}
