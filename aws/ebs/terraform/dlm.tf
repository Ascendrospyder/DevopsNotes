# ==============================================================================
# AWS Data Lifecycle Manager (DLM) Snapshot Automation
# ==============================================================================

# IAM Role for DLM Service
resource "aws_iam_role" "dlm_service_role" {
  name = "dlm-${var.environment}-snapshot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "role-dlm-${var.environment}"
  }
}

# IAM Policy with minimum required permissions for DLM snapshot management
resource "aws_iam_role_policy" "dlm_service_policy" {
  name = "dlm-${var.environment}-snapshot-policy"
  role = aws_iam_role.dlm_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*::snapshot/*"
      }
    ]
  })
}

# DLM Automated Lifecycle Policy
resource "aws_dlm_lifecycle_policy" "daily_snapshot_policy" {
  description        = "Daily automated snapshots for ${var.environment} volumes"
  execution_role_arn = aws_iam_role.dlm_service_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      BackupPlan = "daily-retained-${var.backup_retention_days}d"
    }

    schedule {
      name = "DailySnapshotSchedule"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["02:00"] # 02:00 UTC
      }

      retain_rule {
        count = var.backup_retention_days
      }

      tags_to_add = {
        SnapshotCreator = "DLM-Policy"
        ManagedBy       = "Terraform"
      }

      copy_tags = true
    }
  }

  tags = {
    Name = "dlm-policy-${var.environment}-daily-snapshots"
  }
}
