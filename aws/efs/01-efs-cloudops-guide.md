# Amazon Elastic File System (EFS) — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering Amazon EFS architecture, storage classes, lifecycle policies, performance modes, and throughput modes for cloud engineers managing scalable shared file storage.

---

## 1. What Is Amazon EFS?

Amazon EFS is a **fully managed, elastic NFS file system** that scales automatically (to petabytes) as files are added or removed — no provisioning required. It provides shared, concurrent file access across multiple EC2 instances, containers, Lambda functions, and on-premises servers via NFSv4.

### Core Characteristics

| Property | Detail |
| :--- | :--- |
| **Protocol** | NFSv4 |
| **Scalability** | Automatic scaling to petabytes; no manual intervention |
| **Durability** | Data replicated across multiple Availability Zones (Regional) or within a single AZ (One Zone) |
| **Security** | Encryption at rest & in transit, IAM access control, security groups on mount targets |
| **Integration** | EC2, Lambda, ECS, EKS, on-premises (via Direct Connect / VPN) |

---

## 2. Architecture: Mount Targets

Mount targets are the NFSv4 endpoints that EC2 instances use to connect to an EFS file system.

```
┌──────────────────────────────────────────────────────────────────┐
│                        VPC (Regional EFS)                        │
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │     AZ-1a       │  │     AZ-1b       │  │     AZ-1c       │  │
│  │                 │  │                 │  │                 │  │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │  │
│  │  │ Mount     │  │  │  │ Mount     │  │  │  │ Mount     │  │  │
│  │  │ Target    │  │  │  │ Target    │  │  │  │ Target    │  │  │
│  │  └─────┬─────┘  │  │  └─────┬─────┘  │  │  └─────┬─────┘  │  │
│  │        │        │  │        │        │  │        │        │  │
│  │   EC2  EC2      │  │   EC2  EC2      │  │   EC2  EC2      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                              │                                   │
│                    ┌─────────▼──────────┐                        │
│                    │   Amazon EFS       │                        │
│                    │   File System      │                        │
│                    └────────────────────┘                        │
└──────────────────────────────────────────────────────────────────┘
```

**Key rules:**
- **Regional file systems** → create one mount target **per AZ** in the Region.
- **One Zone file systems** → single mount target in the same AZ as the file system.
- Multiple subnets in one AZ? Only **one mount target per AZ** is needed — all instances in that AZ share it.
- **On-premises access** → connect via AWS Direct Connect or VPN to any mount target; allow inbound NFS port **2049** in the mount target security group.

---

## 3. Storage Classes & Lifecycle Policies

### 3.1 Storage Classes

| Storage Class | Use Case | First-Byte Latency | Relative Cost |
| :--- | :--- | :--- | :--- |
| **EFS Standard** | Frequently accessed, active data | Sub-millisecond | Highest |
| **EFS Infrequent Access (IA)** | Accessed a few times per quarter | Tens of milliseconds | Lower |
| **EFS Archive** | Accessed a few times per year or less | Tens of milliseconds | Lowest |

### 3.2 Lifecycle Policies

Lifecycle policies **automatically tier files** between storage classes based on last-access time — per file, not per directory.

| Policy | Default Behaviour | Configurable? |
| :--- | :--- | :--- |
| **Transition to IA** | Files not accessed for **30 days** → EFS IA | ✓ (customise days) |
| **Transition to Archive** | Files not accessed for **90 days** → EFS Archive | ✓ (customise days) |
| **Transition back to Standard** | **Disabled** by default — files stay in IA/Archive when accessed | ✓ (can enable) |

> **Operational Note:** Lifecycle transitions run in the background with no impact on file system availability or performance. New data always writes to EFS Standard first.

---

## 4. Performance Modes

Performance mode is set **at file system creation and cannot be changed afterwards**.

| Mode | Optimised For | Latency | Best For |
| :--- | :--- | :--- | :--- |
| **General Purpose** | Low-latency operations | Lowest | Most workloads — web serving, CMS, home directories, dev environments |
| **Max I/O** | High aggregate throughput & IOPS | Higher per-operation latency | Highly parallelised workloads — big data analytics, video transcoding, genomics |

> **AWS Recommendation:** Use **General Purpose** for all file systems unless you have a proven need for Max I/O. Start with General Purpose and benchmark before considering Max I/O.

---

## 5. Throughput Modes

Throughput mode **can be changed once every 24 hours** after creation.

| Mode | How It Works | Best For |
| :--- | :--- | :--- |
| **Elastic** (default) | Automatically scales throughput up and down based on workload demand | Spiky or unpredictable workloads; when requirements are hard to forecast |
| **Provisioned** | You set a fixed throughput level (MiB/s) independent of storage size | Known, consistent high-throughput requirements |
| **Bursting** | Throughput scales with storage size; uses a burst credit model | Workloads where throughput needs correlate with data volume; avoid if consistently using >80% of permitted throughput |

---

## 6. Key CloudWatch Metrics

| Metric | What It Tells You |
| :--- | :--- |
| **`TotalIOBytes`** | Total bytes for all file system operations (read, write, metadata) |
| **`DataReadIOBytes`** | Bytes read from the file system |
| **`DataWriteIOBytes`** | Bytes written to the file system |
| **`MetadataIOBytes`** | Bytes used for metadata operations |
| **`PercentIOLimit`** | How close the file system is to the General Purpose I/O limit (100% = throttling) |
| **`BurstCreditBalance`** | Remaining burst credits (Bursting throughput mode only) |
| **`StorageBytes`** | Total size of the file system, broken down by storage class |

---

## 7. Quick Decision Flowchart

```
                ┌─────────────────────────────────────────┐
                │  Shared file access across multiple     │
                │  instances needed?                      │
                └───────────────┬─────────────────────────┘
                                │
                 ┌──────────────┴──────────────┐
                 │                             │
                YES                            NO
                 │                             │
                 ▼                             ▼
    ┌────────────────────────┐    ┌──────────────────────┐
    │  What is the workload  │    │   Consider EBS       │
    │  pattern?              │    │   (single instance)  │
    └───────────┬────────────┘    └──────────────────────┘
                │
     ┌──────────┼───────────────────┐
     │          │                   │
     ▼          ▼                   ▼
 Spiky /    Consistent         Massively
 Unpredict- High               Parallel
 able       Throughput         Analytics
     │          │                   │
     ▼          ▼                   ▼
 ┌──────────┐ ┌──────────────┐ ┌──────────────┐
 │ Elastic  │ │ Provisioned  │ │ Elastic      │
 │ Through- │ │ Throughput + │ │ Throughput + │
 │ put +    │ │ General      │ │ Max I/O      │
 │ General  │ │ Purpose      │ │              │
 │ Purpose  │ │              │ │              │
 └──────────┘ └──────────────┘ └──────────────┘
```

---

## 8. Quick-Reference Checklist

- [ ] **Choose file system scope**: Regional (multi-AZ durability) vs One Zone (cost savings for non-critical data).
- [ ] **Deploy mount targets**: One per AZ for Regional; one in the file system's AZ for One Zone.
- [ ] **Set performance mode at creation**: General Purpose unless proven parallel I/O need → Max I/O.
- [ ] **Select throughput mode**: Elastic (default) for most; Provisioned for predictable high-throughput workloads.
- [ ] **Configure lifecycle policies**: Enable IA and Archive transitions to automatically reduce storage costs.
- [ ] **Enable encryption**: At rest (KMS) and in transit (TLS mount option).
- [ ] **Monitor with CloudWatch**: Watch `PercentIOLimit` and `BurstCreditBalance` to catch throttling early.
