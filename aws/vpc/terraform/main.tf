terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Team        = "CloudOperations"
    }
  }
}

# ==============================================================================
# 1. Virtual Private Cloud (VPC)
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${var.environment}"
  }
}

# ==============================================================================
# 2. Public Subnets (AZ A and AZ B)
# ==============================================================================
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-${var.environment}-public-${var.aws_region}a"
    Tier = "Public"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-${var.environment}-public-${var.aws_region}b"
    Tier = "Public"
  }
}

# ==============================================================================
# 3. Private App Subnets (AZ A and AZ B)
# ==============================================================================
resource "aws_subnet" "private_app_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_cidrs[0]
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-${var.environment}-private-app-${var.aws_region}a"
    Tier = "PrivateApp"
  }
}

resource "aws_subnet" "private_app_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_cidrs[1]
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-${var.environment}-private-app-${var.aws_region}b"
    Tier = "PrivateApp"
  }
}

# ==============================================================================
# 4. Isolated Database Subnets (AZ A and AZ B)
# ==============================================================================
resource "aws_subnet" "isolated_db_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.isolated_db_subnet_cidrs[0]
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-${var.environment}-isolated-db-${var.aws_region}a"
    Tier = "IsolatedDB"
  }
}

resource "aws_subnet" "isolated_db_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.isolated_db_subnet_cidrs[1]
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-${var.environment}-isolated-db-${var.aws_region}b"
    Tier = "IsolatedDB"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "dbsng-${var.environment}"
  subnet_ids = [aws_subnet.isolated_db_1a.id, aws_subnet.isolated_db_1b.id]

  tags = {
    Name = "dbsng-${var.environment}"
  }
}
