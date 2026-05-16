# --- PROJECT IDENTITY ---

variable "project_name" {
  description = "Project name used as a prefix for all resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment label (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-south-1"
}

# --- NETWORKING ---

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet. Hosts the Bastion host."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for private subnet A (AZ-1). Hosts RDS instance."
  type        = string
  default     = "10.0.10.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for private subnet B (AZ-2). Required for RDS subnet group (2 AZ minimum)."
  type        = string
  default     = "10.0.11.0/24"
}

variable "availability_zone_a" {
  description = "Primary availability zone for public subnet and RDS instance."
  type        = string
  default     = "ap-south-1a"
}

variable "availability_zone_b" {
  description = "Secondary availability zone for RDS subnet group (2 AZ minimum required)."
  type        = string
  default     = "ap-south-1b"
}

# --- RDS INSTANCE ---

variable "db_engine_version" {
  description = "MySQL engine version for the RDS instance."
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class. db.t4g.micro is Free Tier eligible for RDS MySQL."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_master_username" {
  description = "Master username for the RDS instance. Stored in SSM Parameter Store."
  type        = string
  default     = "dbadmin"
}

variable "db_backup_retention_days" {
  description = "Days to retain automated RDS backups. 0 disables automated backups."
  type        = number
  default     = 0

  validation {
    condition     = var.db_backup_retention_days >= 0 && var.db_backup_retention_days <= 35
    error_message = "db_backup_retention_days must be between 0 and 35."
  }
}

# --- BASTION HOST ---

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion host. t3.micro is Free Tier eligible."
  type        = string
  default     = "t3.micro"
}
