# ─── VPC ───────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.vpc_name
  }
}

# ─── INTERNET GATEWAY ──────────────────────────────────────────────────────────
# Required for Bastion outbound internet access (SSM agent, dnf package installs).
# Aurora private subnets have no route to this gateway — they are fully isolated.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.igw_name
  }
}
