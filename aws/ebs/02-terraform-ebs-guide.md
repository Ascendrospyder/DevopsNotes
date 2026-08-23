# Managing AWS EBS with Terraform — Beginner to CloudOps Guide

---

## 1. Technical Definition: Infrastructure as Code (IaC) for Block Storage

> **Formal Technical Definition:**
> In modern Cloud Operations, **Infrastructure as Code (IaC)** is the architectural practice of provisioning, configuring, and lifecycle-managing AWS storage infrastructure via declarative, version-controlled HashiCorp Configuration Language (HCL) definitions. Managing Amazon EBS via Terraform guarantees deterministic storage topologies, cryptographic key association with AWS KMS, automated tag-driven backup orchestration via AWS Data Lifecycle Manager (DLM), and programmatic drift detection against configuration decay.

### 1.1 The Conceptual Analogy (For Intuition)

*   **The Architect Blueprint vs Construction Contractor**:
    *   *ClickOps (The Manual Way)*: Clicking buttons in the AWS Console is like trying to build a 50-story skyscraper from memory. You make typos, forget encryption checkboxes, and cannot replicate the exact build in a Disaster Recovery region.
    *   *Terraform (The Code Blueprint)*: You define the exact blueprint in code (`main.tf`). When you run `terraform apply`, Terraform executes the API commands to construct your encrypted storage volumes, volume attachments, and automated backup schedules identically every time.

```
+----------------------------------------------------------------------------------+
|                            TERRAFORM WORKFLOW IN CLOUDOPS                        |
|                                                                                  |
|  [ Code Blueprint ]  --->  [ terraform plan ]  --->  [ terraform apply ]         |
|     (main.tf)             "Shows exact preview         "Creates / modifies live  |
|                            before making changes"       resources safely in AWS" |
|                                                              |                   |
|                                                              v                   |
|                                                     +------------------+         |
|                                                     |   AWS CLOUD      |         |
|                                                     | - KMS CMK Key    |         |
|                                                     | - Encrypted EBS  |         |
|                                                     | - EC2 Instance   |         |
|                                                     | - DLM Backups    |         |
|                                                     +------------------+         |
+----------------------------------------------------------------------------------+
```

---

## 2. Core Terraform Resources for EBS Storage

| Terraform Resource | Technical Purpose | CloudOps Production Role |
| :--- | :--- | :--- |
| `aws_ebs_volume` | Declaratively manages raw block volumes (`gp3`, `io2`, `st1`, `sc1`). | Primary stateful disk definition. Requires `prevent_destroy = true`. |
| `aws_volume_attachment` | Manages attachment state of an EBS volume to an EC2 instance. | Sets `stop_instance_before_detaching = true` for clean unmounting. |
| `aws_kms_key` & `aws_kms_alias` | Customer Managed Key (CMK) for cryptographic encryption. | Enables envelope encryption (AES-256) and cross-account key sharing. |
| `aws_ebs_encryption_by_default` | Enforces default encryption across the entire AWS region. | Mandatory security baseline in CIS AWS Benchmark. |
| `aws_dlm_lifecycle_policy` | Configures automated, tag-driven snapshot schedules. | Eliminates cron scripts; automates backup retention and deletion. |

---

## 3. Production-Grade Terraform Code (Line-by-Line Breakdown)

### 3.1 The Complete Configuration (`main.tf`)

```hcl
# ==============================================================================
# 1. AWS KMS Encryption Key (Customer Managed Key - CMK)
# ==============================================================================
resource "aws_kms_key" "ebs_encryption_key" {
  description             = "Dedicated KMS key for encrypting production database volumes"
  deletion_window_in_days = 30   # Safety buffer: If deleted, key waits 30 days before destruction
  enable_key_rotation     = true # Automatically rotates the cryptographic key every year

  tags = {
    Name        = "kms-ebs-production"
    Environment = "production"
    Team        = "CloudOperations"
  }
}

# ==============================================================================
# 2. Account-Wide Security: Enforce EBS Encryption by Default
# ==============================================================================
resource "aws_ebs_encryption_by_default" "enforce_account_encryption" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "set_default_kms" {
  key_arn = aws_kms_key.ebs_encryption_key.arn
}

# ==============================================================================
# 3. Dedicated Secondary EBS Volume (gp3)
# ==============================================================================
resource "aws_ebs_volume" "database_data_disk" {
  availability_zone = "us-east-1a" # Disks must reside in the exact same AZ as the EC2 host!
  size              = 100          # In GiB
  type              = "gp3"        # General Purpose SSD

  # Baseline 3,000 IOPS and 125 MB/s throughput included free with gp3:
  iops       = 3000
  throughput = 125

  encrypted  = true
  kms_key_id = aws_kms_key.ebs_encryption_key.arn

  tags = {
    Name        = "vol-production-database-data"
    Environment = "production"
    BackupPlan  = "daily-retained-14d" # Triggers automated DLM snapshot policy!
  }

  # ----------------------------------------------------------------------------
  # CLOUDOPS LIFECYCLE SAFEGUARDS
  # ----------------------------------------------------------------------------
  lifecycle {
    # 1. ACCIDENTAL DELETION SAFEGUARD:
    # Blocks destruction if `terraform destroy` is invoked against production
    prevent_destroy = true

    # 2. CONFIGURATION DRIFT MANAGEMENT:
    # Prevents Terraform from attempting to rollback live 2 AM disk resizes
    ignore_changes = [
      size,
      iops,
      throughput
    ]
  }
}

# ==============================================================================
# 4. Attach the EBS Volume to the EC2 Host
# ==============================================================================
resource "aws_volume_attachment" "database_disk_attachment" {
  device_name                    = "/dev/sdb" # Exposed as /dev/nvme1n1 on Nitro Linux
  volume_id                      = aws_ebs_volume.database_data_disk.id
  instance_id                    = aws_instance.database_server.id
  stop_instance_before_detaching = true
}
```

---

## 4. Real-World Disasters & CloudOps Safeguards in Terraform

### 💥 Disaster 1: The "AZ Swap" Data Wipeout Trap
*   **The Issue**: EBS volumes are physically constrained to a single Availability Zone.
*   **The Trap**: If a developer changes `availability_zone = "us-east-1a"` to `availability_zone = "us-east-1b"`, Terraform plans `forces replacement` — it will **DESTROY the production volume and create an empty one**.
*   **The CloudOps Safeguard**: Always apply `lifecycle { prevent_destroy = true }`.

### 💥 Disaster 2: The 2 AM Drift Conflict (`ignore_changes`)
*   **The Issue**: During high-severity disk space incidents, on-call engineers modify volume size from $100 \text{ GiB}$ to $200 \text{ GiB}$ via AWS CLI.
*   **The Trap**: Subsequent `terraform apply` executions will attempt to reset `size = 100`. Because AWS forbids shrinking EBS volumes, the CI/CD pipeline crashes.
*   **The CloudOps Safeguard**: Use `lifecycle { ignore_changes = [size, iops, throughput] }`.

---

## 5. Essential Terraform Commands for CloudOps

```bash
# 1. Initialize provider plugins and backends
terraform init

# 2. Verify HCL syntax and internal consistency
terraform validate

# 3. Preview execution plan before modifying cloud infrastructure
terraform plan

# 4. Apply changes declaratively
terraform apply

# 5. Import existing EBS volume into Terraform state
terraform import aws_ebs_volume.database_data_disk vol-0123456789abcdef0
```
