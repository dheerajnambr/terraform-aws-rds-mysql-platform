locals {
  # Consistent naming prefix used across all resource names and tags.
  name_prefix = "${var.project_name}-${var.environment}"

  # Derived logical component names - single source of truth for naming.
  vpc_name     = "${local.name_prefix}-vpc"
  igw_name     = "${local.name_prefix}-igw"
  rds_name     = "${local.name_prefix}-rds"
  bastion_name = "${local.name_prefix}-bastion"
}
