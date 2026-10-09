variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name used in resource names."
  type        = string
  default     = "tflab"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "offline" {
  description = "When true, the AWS provider skips every call that needs real credentials. Used for plan-only runs on laptops, EC2 without a role, and CI."
  type        = bool
  default     = false
}

variable "emulator_endpoint" {
  description = "Optional URL of an AWS emulator, for example http://localhost:4566. Null means real AWS."
  type        = string
  default     = null
}
