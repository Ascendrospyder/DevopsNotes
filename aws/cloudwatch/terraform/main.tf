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
# Amazon SNS Topic for Alert Notifications
# ==============================================================================
resource "aws_sns_topic" "ops_alerts" {
  name = "sns-${var.environment}-cloudops-alerts"

  tags = {
    Name = "sns-${var.environment}-cloudops-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.ops_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ==============================================================================
# CloudWatch Visual Dashboard
# ==============================================================================
resource "aws_cloudwatch_dashboard" "ops_dashboard" {
  dashboard_name = "Dashboard-${var.environment}-Operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.monitored_instance_id, { "label" : "CPU %", "color" : "#ff7f0e" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 CPU Utilization"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["CustomApp/${var.environment}API", "Http500ErrorCount", { "label" : "500 Errors", "color" : "#d62728" }]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "Application 500 Error Count"
        }
      }
    ]
  })
}
