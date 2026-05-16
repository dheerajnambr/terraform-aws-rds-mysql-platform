# --- MASTER PASSWORD ---
# Generates a strong random password for the RDS master user.
# Written to SSM Parameter Store as SecureString. Never in tfvars or CI/CD vars.

resource "random_password" "rds_master" {
  length           = 20
  special          = true
  override_special = "!#%&*()-_=+[]<>:?"
  min_special      = 2
  min_numeric      = 2
  min_upper        = 2
  min_lower        = 2
}

# --- SSM PARAMETER STORE - CREDENTIALS ---

resource "aws_ssm_parameter" "rds_master_password" {
  name        = "/${var.project_name}/${var.environment}/rds/master_password"
  description = "RDS MySQL instance master password - managed by Terraform"
  type        = "SecureString"
  value       = random_password.rds_master.result

  tags = {
    Name = "${local.rds_name}-master-password"
  }
}

resource "aws_ssm_parameter" "rds_master_username" {
  name        = "/${var.project_name}/${var.environment}/rds/master_username"
  description = "RDS MySQL instance master username - managed by Terraform"
  type        = "String"
  value       = var.db_master_username

  tags = {
    Name = "${local.rds_name}-master-username"
  }
}

resource "aws_ssm_parameter" "rds_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/endpoint"
  description = "RDS MySQL instance endpoint - managed by Terraform"
  type        = "String"
  value       = aws_db_instance.main.address

  tags = {
    Name = "${local.rds_name}-endpoint"
  }
}

# --- DB SUBNET GROUP ---
# aws_db_subnet_group requires at least 2 subnets in different AZs even for single-AZ instance.

resource "aws_db_subnet_group" "rds" {
  name        = "${local.rds_name}-subnet-group"
  description = "RDS MySQL subnet group spanning private subnets in 2 AZs"
  subnet_ids  = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${local.rds_name}-subnet-group"
  }
}

# --- PARAMETER GROUP ---

resource "aws_db_parameter_group" "rds" {
  name        = "${local.rds_name}-pg"
  family      = "mysql8.0"
  description = "RDS MySQL 8.0 parameter group"

  tags = {
    Name = "${local.rds_name}-pg"
  }
}

# --- RDS MYSQL INSTANCE ---

resource "aws_db_instance" "main" {
  identifier = local.rds_name

  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # 20 GB gp2 is the free-tier allocation limit
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "rdsdb"
  username = var.db_master_username
  password = random_password.rds_master.result

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.rds.name

  port                = 3306
  multi_az            = false
  publicly_accessible = false

  backup_retention_period = var.db_backup_retention_days
  skip_final_snapshot     = true
  deletion_protection     = false

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = {
    Name = local.rds_name
  }

  # Prevent Terraform from rotating password on every plan after initial apply.
  # To rotate: taint random_password.rds_master and apply.
  lifecycle {
    ignore_changes = [password]
  }
}
