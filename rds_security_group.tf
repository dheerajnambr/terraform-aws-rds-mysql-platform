# --- RDS SECURITY GROUP ---
# No inline ingress/egress blocks - rules defined as separate resources below.
# This pattern avoids circular dependency: bastion SG references rds SG in its
# egress rule, and rds SG references bastion SG in its ingress rule.
# Splitting into separate rule resources means neither SG resource depends on the other.

resource "aws_security_group" "rds" {
  name        = "${local.rds_name}-sg"
  description = "RDS MySQL instance - inbound MySQL from Bastion only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.rds_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Inbound MySQL - only the Bastion security group can reach RDS on 3306.
# SG-to-SG reference is tighter than CIDR and survives IP changes.
resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_bastion" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "MySQL access from Bastion security group only"

  tags = {
    Name = "${local.rds_name}-mysql-from-bastion"
  }
}
