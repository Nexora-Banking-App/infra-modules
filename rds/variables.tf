variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Private Subnet IDs for the RDS Subnet Group"
  type        = list(string)
}

variable "eks_security_group_id" {
  description = "Security group ID of the EKS cluster permitted to connect to MySQL"
  type        = string
}

variable "instance_class" {
  description = "RDS instance size"
  type        = string
  default     = "db.t3.micro" # Staging default. Use db.t3.medium or larger for Prod
}

variable "multi_az" {
  description = "Enable synchronous Multi-AZ standby replica (Set true for Prod, false for Staging)"
  type        = bool
  default     = false
}

variable "allocated_storage" {
  description = "Initial storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling limit in GB"
  type        = number
  default     = 50
}

variable "database_name" {
  description = "Name of the default MySQL schema"
  type        = string
  default     = "nexora_bank"
}
variable "backup_retention_period" {
  description = "Days to retain backups (Use 1 for Free Tier/Staging, 7 for Prod)"
  type        = number
  default     = 1
}