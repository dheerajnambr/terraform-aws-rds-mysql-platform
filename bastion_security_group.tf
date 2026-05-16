# ─── BASTION SECURITY GROUP ────────────────────────────────────────────────────
# Zero inbound rules — access is exclusively via AWS SSM Session Manager.
# SSM agent on the instance initiates outbound HTTPS to AWS SSM endpoints;
# no inbound port is required from the public internet.

resource "aws_security_group" "bastion" {
  name        = "${local.bastion_name}-sg"
  description = "Bastion host - SSM Session Manager only, zero inbound rules"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.bastion_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Outbound HTTPS — required for:
#   - SSM agent communication with ssm.*, ssmmessages.*, ec2messages.* endpoints
#   - dnf package manager downloading MySQL community client RPM
resource "aws_vpc_security_group_egress_rule" "bastion_https_out" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS egress for SSM agent and package installations"

  tags = {
    Name = "${local.bastion_name}-https-out"
  }
}

# Outbound HTTP — some MySQL community repo mirrors serve metadata over HTTP.
resource "aws_vpc_security_group_egress_rule" "bastion_http_out" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP egress for dnf package repo metadata"

  tags = {
    Name = "${local.bastion_name}-http-out"
  }
}

# Outbound MySQL - bastion to RDS instance (SG-to-SG, no CIDR needed).
# This rule references aws_security_group.rds defined in rds_security_group.tf.
resource "aws_vpc_security_group_egress_rule" "bastion_mysql_out" {
  security_group_id            = aws_security_group.bastion.id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "MySQL egress to RDS instance security group"

  tags = {
    Name = "${local.bastion_name}-mysql-out"
  }
}
