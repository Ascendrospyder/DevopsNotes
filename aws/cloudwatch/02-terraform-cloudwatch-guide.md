# Managing Amazon CloudWatch with Terraform — Beginner to CloudOps Guide

---

## 1. Technical Definition: Observability as Code (OaC)

> **Formal Technical Definition:**
> **Observability as Code (OaC)** is the programmatic specification, provisioning, and automated lifecycle management of telemetry collectors, log streaming groups, metric filters, statistical anomaly alarms, composite state machines, and visual operational dashboards using Infrastructure as Code (IaC) tooling like Terraform. Managing Amazon CloudWatch via Terraform guarantees deterministic alarm thresholds across multi-account enterprise environments, enforces automated log retention policies to prevent unbounded storage costs, and binds incident remediation actions directly to AWS SNS topics and Auto-Recovery automation targets.

### 1.1 The Conceptual Analogy (For Intuition)

*   **Standardized Assembly Line vs Hand-Crafted Alarms**:
    *   *ClickOps (The Manual Way)*: Manually creating 400 separate alarms across 80 microservices in the AWS Console leads to missing servers, inconsistent thresholds, forgotten email subscribers, and human error.
    *   *Terraform (The Code Blueprint)*: You define reusable alarm templates in code. When a new service is provisioned, Terraform automatically builds the log group with a 30-day retention policy, configures standard CPU/Memory alarms, wires them to PagerDuty/SNS, and adds them to the master NOC dashboard in 10 seconds.

```
+---------------------------------------------------------------------------------------------------+
|                            TERRAFORM OBSERVABILITY ARCHITECTURE                                   |
|                                                                                                   |
|  [ aws_cloudwatch_log_group ]                                                                     |
|    (retention_in_days = 30)                                                                       |
|             |                                                                                     |
|             v                                                                                     |
|  [ aws_cloudwatch_log_metric_filter ]                                                             |
|    (Extracts "500 Error" count from text logs)                                                    |
|             |                                                                                     |
|             v (Creates Custom Metric)                                                             |
|  [ aws_cloudwatch_metric_alarm ] <------- [ aws_cloudwatch_metric_alarm ]                         |
|    (Alarm 1: High 500 Errors)                (Alarm 2: High CPU Utilization)                      |
|             \                                       /                                             |
|              +------------------+------------------+                                              |
|                                 |                                                                 |
|                                 v (Combines both rules)                                           |
|                   [ aws_cloudwatch_composite_alarm ]                                              |
|                     "Only page on-call if BOTH fire!"                                             |
|                                 |                                                                 |
|                                 v                                                                 |
|                        [ aws_sns_topic ]                                                          |
|                     (PagerDuty / Slack / Email)                                                   |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Core Terraform Resources for CloudWatch

| Terraform Resource | Technical Purpose | CloudOps Production Role |
| :--- | :--- | :--- |
| `aws_cloudwatch_log_group` | Ingestion container for timestamped application/system logs. | **Must set `retention_in_days`** to eliminate runaway storage expenses. |
| `aws_cloudwatch_log_metric_filter` | Regular expression/pattern parser converting log events into time-series metrics. | Creates custom operational metrics from application text outputs. |
| `aws_cloudwatch_metric_alarm` | Threshold evaluation state machine on numeric time-series metrics. | Paginates on-call engineers via SNS or triggers EC2 auto-recovery. |
| `aws_cloudwatch_composite_alarm` | Multi-condition rule evaluator combining multiple alarms via boolean logic. | Reduces alarm fatigue and false positives. |
| `aws_cloudwatch_dashboard` | Declarative JSON layout rendering metric widgets and log query tables. | Establishes uniform operational dashboards across environments. |

---

## 3. Production Terraform Code: Line-by-Line Breakdown

```hcl
# ==============================================================================
# 1. Amazon SNS Topic for Alert Notifications
# ==============================================================================
resource "aws_sns_topic" "ops_critical_alerts" {
  name = "sns-cloudops-critical-alerts-production"

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "ops_email_alert" {
  topic_arn = aws_sns_topic.ops_critical_alerts.arn
  protocol  = "email"
  endpoint  = "cloudops-oncall@example.com"
}

# ==============================================================================
# 2. CloudWatch Log Group with Strict Cost-Saving Retention Policy
# ==============================================================================
resource "aws_cloudwatch_log_group" "api_server_logs" {
  name              = "/aws/production/ecommerce-api"
  retention_in_days = 30 # CRITICAL: Automatically purges logs after 30 days!

  tags = {
    Environment = "production"
    Application = "ecommerce-api"
  }
}

# ==============================================================================
# 3. Log Metric Filter: Turn Log Errors into a Numeric Metric
# ==============================================================================
resource "aws_cloudwatch_log_metric_filter" "http_500_errors" {
  name           = "filter-http-500-errors"
  log_group_name = aws_cloudwatch_log_group.api_server_logs.name
  pattern        = "[timestamp, request_id, status_code = 5*, message]"

  metric_transformation {
    name          = "Http500ErrorCount"
    namespace     = "CustomApp/EcommerceAPI"
    value         = "1"
    default_value = "0"
  }
}

# ==============================================================================
# 4. Standard EC2 CPU Alarm (With 3-Period Noise Suppression)
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "alarm-ec2-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3   # Must breach 3 consecutive periods before paging
  datapoints_to_alarm = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers when EC2 average CPU utilization is >= 80% for 3 minutes."

  dimensions = {
    InstanceId = "i-0123456789abcdef0"
  }

  alarm_actions      = [aws_sns_topic.ops_critical_alerts.arn]
  ok_actions         = [aws_sns_topic.ops_critical_alerts.arn]
  treat_missing_data = "notBreaching"
}

# ==============================================================================
# 5. Application 500 Error Spike Alarm
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "http_500_spike_alarm" {
  alarm_name          = "alarm-api-500-error-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Http500ErrorCount"
  namespace           = "CustomApp/EcommerceAPI"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "High volume of HTTP 500 server errors detected in API logs."

  alarm_actions      = [aws_sns_topic.ops_critical_alerts.arn]
  ok_actions         = [aws_sns_topic.ops_critical_alerts.arn]
  treat_missing_data = "notBreaching" # Prevents false alarms during low-traffic periods
}

# ==============================================================================
# 6. Automatic EC2 Hardware Recovery Alarm
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "ec2_hardware_auto_recovery" {
  alarm_name          = "alarm-ec2-hardware-auto-recovery"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Automatically recovers the EC2 instance upon underlying AWS hardware failure."

  dimensions = {
    InstanceId = "i-0123456789abcdef0"
  }

  alarm_actions = [
    "arn:aws:automate:us-east-1:ec2:recover",
    aws_sns_topic.ops_critical_alerts.arn
  ]
}
```

---

## 4. Real-World Disasters & CloudOps Safeguards in Terraform

### 💥 Disaster 1: The "False Alarm Storm" (`treat_missing_data`)
*   **The Problem**: Setting `treat_missing_data = "breaching"` on an error-count metric causes alarms to fire when zero errors occur at night.
*   **The CloudOps Safeguard**: Always set `treat_missing_data = "notBreaching"` on error counts.

### 💥 Disaster 2: The Unbounded Log Retention Bill Shock
*   **The Problem**: Omitting `retention_in_days` in `aws_cloudwatch_log_group` causes logs to be retained permanently.
*   **The CloudOps Safeguard**: Always declare `retention_in_days = 30` (or 14/90 days).

---

## 5. Beginner Checklist for CloudWatch in Terraform

- [x] **Define `retention_in_days`** on every `aws_cloudwatch_log_group`.
- [x] **Set `treat_missing_data = "notBreaching"`** on error-count alarms.
- [x] **Set `evaluation_periods = 3`** on CPU/Memory alarms to filter out transient spikes.
- [x] **Attach `ec2:recover` actions** on `StatusCheckFailed_System` alarms.
- [x] **Use Composite Alarms** to combine symptoms before triggering high-priority on-call alerts.
