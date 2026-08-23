# ==============================================================================
# 1. Public ALB Security Group
# ==============================================================================
resource "aws_security_group" "alb_sg" {
  name        = "sg-${var.environment}-public-alb"
  description = "Allows inbound HTTPS from internet and all egress"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP from anywhere (for redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.environment}-public-alb"
  }
}

# ==============================================================================
# 2. Private App Server Security Group
# ==============================================================================
resource "aws_security_group" "app_sg" {
  name        = "sg-${var.environment}-private-app"
  description = "Allows HTTP strictly from the Public ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow port 8080 ONLY from ALB SG"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow outbound to internet via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.environment}-private-app"
  }
}

# ==============================================================================
# 3. Isolated Database Security Group
# ==============================================================================
resource "aws_security_group" "db_sg" {
  name        = "sg-${var.environment}-isolated-db"
  description = "Allows PostgreSQL strictly from App Servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow PostgreSQL (5432) ONLY from App Server SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    description = "Restricted outbound to VPC only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "sg-${var.environment}-isolated-db"
  }
}
