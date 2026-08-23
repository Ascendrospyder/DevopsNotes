# Amazon Data Lifecycle Manager: Automated EBS Snapshot Management

> **AWS Skill Builder Summary:**
> Concise reference covering Amazon Data Lifecycle Manager (DLM) policy design, default vs custom policies, tag-based resource targeting, crash-consistent and application-consistent backups, tiered schedule/retention strategies, and when to choose DLM vs AWS Backup.

---

## 1. Why Automate? — Purpose & Benefits of DLM

As AWS environments scale to hundreds or thousands of EBS volumes, manual snapshot management becomes untenable:

| Benefit | Detail |
| :--- | :--- |
| **Operational Efficiency** | Eliminates manual snapshot creation/deletion; frees CloudOps time for higher-value work. |
| **Consistency & Reliability** | Policy-driven automation removes human error from backup processes. |
| **Scalable Protection** | Tag-based targeting automatically covers new resources that match policy criteria. |
| **Cost Optimisation** | Automated retention rules prevent snapshot sprawl and unnecessary storage charges. |

---

## 2. Core Concepts: Crash-Consistent Backups via DLM

For multi-volume applications (databases, RAID, LVM), DLM **instance-based policies** create crash-consistent snapshots:

```
┌────────────────────────────────────────────────────────────────────┐
│  EC2 Instance: i-0abc123 (Database Server)                        │
│                                                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                         │
│  │ /dev/sda │  │ /dev/sdb │  │ /dev/sdc │  ← 3 attached EBS vols  │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘                         │
│        │             │             │                               │
│        └──────── DLM Trigger ──────┘                               │
│                      │                                             │
│                      ▼                                             │
│        Synchronized point-in-time snapshots                        │
│        of ALL volumes simultaneously                               │
│        (consistent tagging maintained)                             │
└────────────────────────────────────────────────────────────────────┘
```

**Key behaviours:**
- Snapshots all attached volumes at the **exact same point in time**.
- Maintains inter-snapshot relationships via **consistent tagging**.
- Enables reliable **point-in-time restore** across the full volume set.

---

## 3. Lifecycle Policies: Default vs Custom

DLM provides two policy approaches. Custom policies unlock the advanced features CloudOps teams typically need.

### 3.1 Policy Types Available

| Policy Type | Target |
| :--- | :--- |
| **EBS Snapshot Policy** | Volumes or Instances |
| **EBS-backed AMI Policy** | Instances |
| **Cross-Account Copy Event Policy** | Shared snapshots |

### 3.2 Default vs Custom Policy Comparison

| Feature | Default Policy | Custom Policy |
| :--- | :--- | :--- |
| **Resource Targeting** | All volumes in Region without recent snapshots (exclusion-based) | Only volumes/instances with **specific tags** |
| **Multiple Schedules** | ✗ | ✓ (up to 4 per policy) |
| **Retention Types** | Age-based only (2–14 days) | Age-based (up to 100 years) **or** count-based (up to 1,000 snapshots) |
| **Snapshot Frequency** | Every 1–7 days | Daily, weekly, monthly, yearly, or **cron expression** |
| **Application-Consistent Snapshots** | ✗ | ✓ (pre/post scripts) |
| **Fast Snapshot Restore (FSR)** | ✗ | ✓ |
| **Cross-Region Copy** | ✓ (default settings) | ✓ (custom settings) |
| **Cross-Account Sharing** | ✗ | ✓ |
| **Snapshot Archiving** | ✗ | ✓ |
| **AWS Outposts Support** | ✗ | ✓ |
| **Extended Deletion** | ✓ | ✗ |

> **Key Takeaway:** Default policies are simple, broad-coverage safety nets. Custom policies are the workhorse for production CloudOps — they support tag targeting, tiered schedules, FSR, cross-Region copy with custom settings, and application-consistent backups.

---

## 4. Tag-Based Resource Targeting

Custom DLM policies identify resources through **tag matching**:

- Resources with **at least one matching tag** are included in the policy.
- Tags are **case-sensitive** — enforce consistent casing across the organisation.
- **Target volumes** for granular, per-disk control.
- **Target instances** for crash-consistent multi-volume backups.
- Use **multiple policies with different tags** to implement tiered backup strategies (e.g., `BackupTier: Gold` vs `BackupTier: Silver`).

### Tagging Best Practices

- Define and document a **consistent tagging schema** organisation-wide.
- Establish **clear ownership** of who is responsible for applying backup tags.
- Document tagging standards so new resources are automatically captured by existing policies.

---

## 5. Application-Consistent Backups

Crash-consistent snapshots may be insufficient for databases and transactional systems. DLM custom policies support **pre-snapshot and post-snapshot scripts** for true application consistency:

```
┌──────────────────────────────────────────────────────────┐
│              Application-Consistent Workflow              │
│                                                          │
│  1. PRE-SNAPSHOT SCRIPT                                  │
│     • Pause application I/O                              │
│     • Flush dirty pages from memory to disk              │
│     • Execute DB checkpoint / lock tables                │
│                                                          │
│  2. SNAPSHOT CREATION                                    │
│     • DLM creates EBS snapshot(s)                        │
│                                                          │
│  3. POST-SNAPSHOT SCRIPT                                 │
│     • Resume normal application operations               │
│     • Unlock tables / resume writes                      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

> **When to use:** Production databases (PostgreSQL, MySQL, Oracle, SQL Server) and any system where in-flight transactions must be cleanly captured.

---

## 6. Designing Schedules & Retention

Custom policies support **up to 4 schedules** per policy (1 mandatory + 3 optional). This enables tiered retention within a single policy.

### 6.1 Tiered Retention Strategy Example

```
┌──────────────────────────────────────────────────────────────────┐
│                    TIERED RETENTION DESIGN                        │
│                                                                  │
│  Schedule 1 — Hourly                                             │
│  ├── Frequency:  Every 6 hours                                   │
│  ├── Retention:  24 snapshots (count-based)                      │
│  └── Purpose:    Granular short-term recovery                    │
│                                                                  │
│  Schedule 2 — Daily                                              │
│  ├── Frequency:  Once per day at 02:00 UTC                       │
│  ├── Retention:  30 days (age-based)                             │
│  └── Purpose:    Standard operational recovery                   │
│                                                                  │
│  Schedule 3 — Monthly                                            │
│  ├── Frequency:  1st of each month                               │
│  ├── Retention:  12 months (age-based)                           │
│  └── Purpose:    Compliance and audit trail                      │
│                                                                  │
│  Schedule 4 — Yearly                                             │
│  ├── Frequency:  1st January                                     │
│  ├── Retention:  7 years (age-based)                             │
│  └── Purpose:    Long-term regulatory retention                  │
└──────────────────────────────────────────────────────────────────┘
```

### 6.2 Design Considerations

- **Balance granularity vs cost**: More frequent snapshots = faster RPO but higher storage costs.
- **Each schedule can enable different advanced features** (e.g., FSR on hourly, cross-Region copy on daily).
- **Mission-critical apps** benefit from multiple schedules in a single policy for both short-term recovery and long-term compliance.

---

## 7. DLM vs AWS Backup: Choosing the Right Service

| Feature | Amazon Data Lifecycle Manager | AWS Backup |
| :--- | :--- | :--- |
| **Scope** | EBS volumes and EC2 instances (AMIs) only | Multi-service (EBS, RDS, DynamoDB, EFS, and more) |
| **Resource Targeting** | Tag-based | Tags, resource IDs, or resource types |
| **Cross-Account Backup** | ✓ | ✓ |
| **Cross-Region Copy** | ✓ | ✓ |
| **Immutable Backups** | ✗ | ✓ (Vault Lock) |
| **AWS Organizations Integration** | Limited | Full multi-account management |
| **Backup Windows** | Cron expressions | Flexible time-based windows |
| **Compliance & Auditing** | Limited | Built-in reporting and audit capabilities |
| **Cost** | Lower (EBS-focused) | Higher (broader feature set) |

### When to Use Each

```
          ┌──────────────────────────────┐
          │   What needs protecting?     │
          └──────────────┬───────────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
   Only EBS volumes              Multiple AWS
   or AMIs                       services
          │                             │
          ▼                             ▼
 ┌──────────────────┐       ┌──────────────────┐
 │ Complex needs?   │       │   AWS Backup     │
 └────────┬─────────┘       └──────────────────┘
          │
   ┌──────┴──────────────────────┐
   │                             │
 Simple,                    Immutable backups,
 cost-sensitive             compliance, cross-account
   │                             │
   ▼                             ▼
 ┌──────────────┐       ┌──────────────────┐
 │ Amazon DLM   │       │   AWS Backup     │
 └──────────────┘       └──────────────────┘
```

> **Practical Path:** Many CloudOps teams start with DLM for EBS-specific automation and later adopt AWS Backup as multi-service and compliance requirements emerge. The two services can run side-by-side — DLM handling specialised EBS use cases while AWS Backup provides broader centralized protection.

---

## 8. Quick-Reference Checklist

- [ ] **Choose Policy Type**: Default for broad safety-net coverage; Custom for production tag-based control.
- [ ] **Implement Tagging Schema**: Case-sensitive, documented, with clear ownership responsibilities.
- [ ] **Design Tiered Schedules**: Balance RPO granularity against storage cost across up to 4 schedules.
- [ ] **Enable Application Consistency**: Configure pre/post scripts for databases and transactional workloads.
- [ ] **Configure Cross-Region Copy**: On at least the daily schedule for DR-critical volumes.
- [ ] **Evaluate DLM vs AWS Backup**: Use DLM for EBS-focused automation; add AWS Backup when multi-service or compliance needs arise.
- [ ] **Monitor & Alert**: Set CloudWatch alarms on DLM policy failures to catch missed backups early.
