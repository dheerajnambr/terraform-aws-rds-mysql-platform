# ─── SUBNETS ───────────────────────────────────────────────────────────────────

# Public subnet — Bastion host resides here.
# map_public_ip_on_launch ensures the Bastion gets a public IP for SSM connectivity.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet"
    Tier = "public"
  }
}

# Private subnet A — RDS instance in AZ-1.
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = var.availability_zone_a

  tags = {
    Name = "${local.name_prefix}-private-subnet-a"
    Tier = "private"
  }
}

# Private subnet B — AZ-2 required for RDS subnet group (2 AZ minimum).
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = var.availability_zone_b

  tags = {
    Name = "${local.name_prefix}-private-subnet-b"
    Tier = "private"
  }
}

# ─── ROUTE TABLES ──────────────────────────────────────────────────────────────

# Public route table — sends all internet traffic through the IGW.
# Only associated with the public subnet (Bastion).
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

# Private route table — no default route by design (no NAT Gateway).
# RDS instances are fully private with no outbound internet path.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

# ─── ROUTE TABLE ASSOCIATIONS ──────────────────────────────────────────────────

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
