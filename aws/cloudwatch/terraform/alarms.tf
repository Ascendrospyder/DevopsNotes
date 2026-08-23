# ==============================================================================
# CloudWatch Metric Alarms
# ==============================================================================

# 1. EC2 High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "alarm-${var.environment}-ec2-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Triggered when EC2 average CPU utilization is >= ${var.cpu_alarm_threshold}% for 3 consecutive minutes."

  dimensions = {
    InstanceId = var.monitored_instance_id
  }

  alarm_actions = [aws_sns_topic.ops_alerts.arn]
  ok_actions    = [aws_sns_topic.ops_alerts.arn]

  treat_missing_data = "notBreaching"
}

# 2. HTTP 500 Error Spike Alarm (Derived from Log Metric Filter)
resource "aws_cloudwatch_metric_alarm" "http_500_spike" {
  alarm_name          = "alarm-${var.environment}-http-500-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "Http500ErrorCount"
  namespace           = "CustomApp/${var.environment}API"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Triggered when HTTP 500 server errors exceed 10 in a minute."

  alarm_actions = [aws_sns_topic.ops_alerts.arn]
  ok_actions    = [aws_sns_topic.ops_alerts.arn]

  treat_missing_data = "notBreaching"
}

# 3. Automatic EC2 Hardware Failure Recovery Alarm
resource "aws_cloudwatch_metric_alarm" "auto_recovery" {
  alarm_name          = "alarm-${var.environment}-ec2-auto-recovery"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Automatically recovers instance upon AWS physical hardware failure."

  dimensions = {
    InstanceId = var.monitored_instance_id
  }

  alarm_actions = [
    "arn:aws:automate:${var.aws_region}:ec2:recover",
    aws_sns_topic.ops_alerts.arn
  ]
}

# ==============================================================================
# Composite Alarm: Multi-Condition Alerting
# ==============================================================================
resource "aws_cloudwatch_composite_alarm" "critical_app_outage" {
  alarm_name        = "composite-alarm-${var.environment}-critical-outage"
  alarm_description = "Pages on-call only if BOTH High CPU and 500 Error Spike occur simultaneously."

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.high_cpu.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.http_500_spike.alarm_name})"

  alarm_actions = [aws_sns_topic.ops_alerts.arn]
  ok_actions    = [aws_sns_topic.ops_alerts.arn]
}
