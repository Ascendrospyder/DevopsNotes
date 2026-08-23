output "kms_key_arn" {
  description = "ARN of the Customer Managed KMS Key for EBS"
  value       = aws_kms_key.ebs_cmk.arn
}

output "kms_key_alias" {
  description = "Alias of the Customer Managed KMS Key"
  value       = aws_kms_alias.ebs_cmk_alias.name
}

output "ebs_volume_id" {
  description = "ID of the created secondary EBS volume"
  value       = aws_ebs_volume.app_data.id
}

output "ebs_volume_arn" {
  description = "ARN of the created secondary EBS volume"
  value       = aws_ebs_volume.app_data.arn
}

output "dlm_policy_id" {
  description = "ID of the Data Lifecycle Manager backup policy"
  value       = aws_dlm_lifecycle_policy.daily_snapshot_policy.id
}

output "instance_id" {
  description = "ID of the attached EC2 instance"
  value       = aws_instance.app_server.id
}
