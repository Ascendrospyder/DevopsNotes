# ==============================================================================
# 1. Public Route Table & Subnet Associations
# ==============================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt-${var.environment}-public"
  }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# 2. Private Route Tables (Routed to NAT Gateways)
# ==============================================================================
# Route Table 1A (Routes to NAT 1A)
resource "aws_route_table" "private_1a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }

  tags = {
    Name = "rt-${var.environment}-private-1a"
  }
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_app_1a.id
  route_table_id = aws_route_table.private_1a.id
}

# Route Table 1B (Routes to NAT 1B, or falls back to NAT 1A if single_nat_gateway is true)
resource "aws_route_table" "private_1b" {
  count  = var.single_nat_gateway ? 0 : 1
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b[0].id
  }

  tags = {
    Name = "rt-${var.environment}-private-1b"
  }
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_app_1b.id
  route_table_id = var.single_nat_gateway ? aws_route_table.private_1a.id : aws_route_table.private_1b[0].id
}

# ==============================================================================
# 3. Isolated DB Route Table (Local VPC Traffic Only - No Internet Route)
# ==============================================================================
resource "aws_route_table" "isolated_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "rt-${var.environment}-isolated-db"
  }
}

resource "aws_route_table_association" "isolated_db_1a" {
  subnet_id      = aws_subnet.isolated_db_1a.id
  route_table_id = aws_route_table.isolated_db.id
}

resource "aws_route_table_association" "isolated_db_1b" {
  subnet_id      = aws_subnet.isolated_db_1b.id
  route_table_id = aws_route_table.isolated_db.id
}
