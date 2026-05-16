# --- NETWORK OUTPUTS ---

output "vpc_id" {
  description = "ID of the dedicated VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet hosting the Bastion."
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets used by the RDS subnet group."
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# --- RDS OUTPUTS ---

output "rds_instance_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.main.identifier
}

output "rds_endpoint" {
  description = "RDS MySQL instance endpoint - use for all connections."
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS MySQL instance port."
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "Default database name created in the RDS instance."
  value       = aws_db_instance.main.db_name
}

# --- CREDENTIALS - SSM PATHS ---

output "ssm_path_master_username" {
  description = "SSM Parameter Store path for RDS master username."
  value       = aws_ssm_parameter.rds_master_username.name
}

output "ssm_path_master_password" {
  description = "SSM Parameter Store path for RDS master password (SecureString)."
  value       = aws_ssm_parameter.rds_master_password.name
}

output "ssm_path_rds_endpoint" {
  description = "SSM Parameter Store path for RDS endpoint."
  value       = aws_ssm_parameter.rds_endpoint.name
}

# --- BASTION OUTPUTS ---

output "bastion_instance_id" {
  description = "Bastion EC2 instance ID - pass to aws ssm start-session."
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion public IP address."
  value       = aws_instance.bastion.public_ip
}

output "ssm_connect_command" {
  description = "Ready-to-run AWS CLI command to open a Session Manager shell on the Bastion."
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}

output "mysql_connect_command" {
  description = "MySQL command to connect to RDS from inside the Bastion shell."
  value       = "mysql -h ${aws_db_instance.main.address} -P ${aws_db_instance.main.port} -u ${var.db_master_username} -p"
}
