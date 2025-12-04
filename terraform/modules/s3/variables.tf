# ======
# S3 Module - Variables
# ======

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "logs_retention_days" {
  description = "Number of days to retain logs before deletion"
  type        = number
  default     = 180
}

variable "backups_retention_days" {
  description = "Number of days to retain backups before deletion"
  type        = number
  default     = 365
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}