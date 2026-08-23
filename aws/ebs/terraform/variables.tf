variable "aws_region" {
  description = "The AWS Region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "availability_zone" {
  description = "The Availability Zone where the EC2 instance and EBS volume must reside"
  type        = string
  default     = "us-east-1a"
}

variable "ebs_volume_size" {
  description = "Size of the secondary EBS volume in GiB"
  type        = number
  default     = 100
}

variable "ebs_volume_type" {
  description = "The EBS volume type (e.g., gp3, io2)"
  type        = string
  default     = "gp3"
}

variable "ebs_iops" {
  description = "Provisioned IOPS for gp3 (baseline 3000 included for free, max 16000)"
  type        = number
  default     = 3000
}

variable "ebs_throughput" {
  description = "Provisioned throughput in MB/s for gp3 (baseline 125 included for free, max 1000)"
  type        = number
  default     = 125
}

variable "backup_retention_days" {
  description = "Number of days to retain DLM automated snapshots"
  type        = number
  default     = 14
}
