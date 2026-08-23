variable "aws_region" {
  description = "The AWS Region to deploy CloudWatch resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "alert_email" {
  description = "Email address to receive SNS CloudWatch alert notifications"
  type        = string
  default     = "cloudops-oncall@example.com"
}

variable "log_retention_days" {
  description = "Days to retain CloudWatch logs before automatic purging"
  type        = number
  default     = 30
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization percentage threshold for alarm"
  type        = number
  default     = 80
}

variable "monitored_instance_id" {
  description = "The EC2 Instance ID to attach CloudWatch alarms to"
  type        = string
  default     = "i-0123456789abcdef0"
}
