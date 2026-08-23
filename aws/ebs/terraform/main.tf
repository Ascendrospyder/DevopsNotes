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
# 1. AWS KMS Customer Managed Key (CMK) for EBS Encryption
# ==============================================================================
resource "aws_kms_key" "ebs_cmk" {
  description             = "KMS Key for ${var.environment} EBS Volume Encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "kms-ebs-${var.environment}"
  }
}

resource "aws_kms_alias" "ebs_cmk_alias" {
  name          = "alias/ebs-${var.environment}-key"
  target_key_id = aws_kms_key.ebs_cmk.key_id
}

# ==============================================================================
# 2. Account/Region Level EBS Encryption Enforcement
# ==============================================================================
resource "aws_ebs_encryption_by_default" "enforce_encryption" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "default_kms" {
  key_arn = aws_kms_key.ebs_cmk.arn
}

# ==============================================================================
# 3. Dedicated Secondary EBS Volume (gp3)
# ==============================================================================
resource "aws_ebs_volume" "app_data" {
  availability_zone = var.availability_zone
  size              = var.ebs_volume_size
  type              = var.ebs_volume_type
  iops              = var.ebs_iops
  throughput        = var.ebs_throughput
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs_cmk.arn

  tags = {
    Name       = "vol-${var.environment}-app-data"
    BackupPlan = "daily-retained-${var.backup_retention_days}d"
  }

  lifecycle {
    # Prevent accidental destruction of production storage
    prevent_destroy = true

    # Prevent drift if volume size/IOPS are expanded dynamically in operations
    ignore_changes = [
      size,
      iops,
      throughput
    ]
  }
}

# ==============================================================================
# 4. Optional EC2 Instance Example & Attachment
# ==============================================================================
# Fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app_server" {
  ami               = data.aws_ami.amazon_linux_2023.id
  instance_type     = "t3.medium"
  availability_zone = var.availability_zone

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = aws_kms_key.ebs_cmk.arn

    tags = {
      Name = "root-vol-${var.environment}-app-server"
    }
  }

  tags = {
    Name = "ec2-${var.environment}-app-server"
  }
}

resource "aws_volume_attachment" "app_data_attachment" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.app_data.id
  instance_id = aws_instance.app_server.id

  stop_instance_before_detaching = true
}
