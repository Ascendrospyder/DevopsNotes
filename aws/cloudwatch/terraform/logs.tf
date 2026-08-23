# ==============================================================================
# CloudWatch Log Group with Automated Retention Policy
# ==============================================================================
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/${var.environment}/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "logs-${var.environment}-application"
  }
}

# ==============================================================================
# Log Metric Filter (Transforms Log Text into a Numeric Metric)
# ==============================================================================
resource "aws_cloudwatch_log_metric_filter" "http_500_filter" {
  name           = "filter-${var.environment}-500-errors"
  log_group_name = aws_cloudwatch_log_group.application_logs.name
  pattern        = "[timestamp, request_id, status_code = 5*, message]"

  metric_transformation {
    name          = "Http500ErrorCount"
    namespace     = "CustomApp/${var.environment}API"
    value         = "1"
    default_value = "0"
  }
}
