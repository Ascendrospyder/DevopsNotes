# ==============================================================================
# 1. Internet Gateway (IGW)
# ==============================================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.environment}"
  }
}

# ==============================================================================
# 2. Elastic IPs & NAT Gateways
# ==============================================================================
# NAT EIP 1A (Always created)
resource "aws_eip" "nat_1a" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "eip-${var.environment}-nat-1a"
  }
}

resource "aws_nat_gateway" "nat_1a" {
  allocation_id = aws_eip.nat_1a.id
  subnet_id     = aws_subnet.public_1a.id

  tags = {
    Name = "nat-${var.environment}-1a"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT EIP 1B (Created only in Multi-AZ mode when single_nat_gateway is false)
resource "aws_eip" "nat_1b" {
  count      = var.single_nat_gateway ? 0 : 1
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "eip-${var.environment}-nat-1b"
  }
}

resource "aws_nat_gateway" "nat_1b" {
  count         = var.single_nat_gateway ? 0 : 1
  allocation_id = aws_eip.nat_1b[0].id
  subnet_id     = aws_subnet.public_1b.id

  tags = {
    Name = "nat-${var.environment}-1b"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ==============================================================================
# 3. S3 Gateway Endpoint (Zero Cost - Direct Private Route to S3)
# ==============================================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = compact([
    aws_route_table.public.id,
    aws_route_table.private_1a.id,
    var.single_nat_gateway ? null : aws_route_table.private_1b[0].id
  ])

  tags = {
    Name = "vpce-${var.environment}-s3-gateway"
  }
}
