output "sns_topic_arn" {
  description = "ARN of the SNS alert topic"
  value       = aws_sns_topic.ops_alerts.arn
}

output "log_group_name" {
  description = "Name of the created CloudWatch log group"
  value       = aws_cloudwatch_log_group.application_logs.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.ops_dashboard.dashboard_name
}

output "cpu_alarm_arn" {
  description = "ARN of the CPU metric alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "composite_alarm_arn" {
  description = "ARN of the composite outage alarm"
  value       = aws_cloudwatch_composite_alarm.critical_app_outage.arn
}
