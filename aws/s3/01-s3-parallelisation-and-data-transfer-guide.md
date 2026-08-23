# Amazon S3 Parallelisation: Multipart Uploads & DataSync

> **AWS Skill Builder Summary:**
> Concise CloudOps reference covering S3 performance through parallel requests, multipart upload mechanics, AWS DataSync for large-scale data transfers, and S3 Transfer Acceleration for optimising long-distance uploads.

---

## 1. S3 Parallelisation — Why It Matters

Amazon S3 is a distributed system with **no connection limits per bucket**. Performance scales horizontally — more parallel requests = higher throughput. Two key tools enable this:

| Tool | What It Does | When to Use |
| :--- | :--- | :--- |
| **Multipart Upload** | Splits a single large object into parts uploaded in parallel | Large file uploads (≥ 100 MB) |
| **AWS DataSync** | Purpose-built transfer service with parallel architecture | Bulk migrations, hybrid workflows, cross-service transfers |

---

## 2. Multipart Upload

**What it is:** Instead of uploading a large file as one request, you split it into smaller parts that upload independently and in parallel. S3 assembles them into the final object after all parts arrive.

```
┌──────────────────────────────────────────────────────────┐
│              Multipart Upload Flow                        │
│                                                          │
│   Large File (2 GB)                                      │
│   ┌──────┬──────┬──────┬──────┬──────┐                   │
│   │Part 1│Part 2│Part 3│Part 4│Part 5│  Split into parts │
│   └──┬───┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘                   │
│      │       │      │      │      │     Upload parallel  │
│      ▼       ▼      ▼      ▼      ▼                      │
│   ┌──────────────────────────────────┐                   │
│   │          Amazon S3               │                   │
│   │   Assembles parts into object    │                   │
│   └──────────────────────────────────┘                   │
│                                                          │
│   If Part 3 fails? Retry ONLY Part 3.                    │
│   Parts can arrive in any order.                         │
│   No expiration — complete or abort explicitly.          │
└──────────────────────────────────────────────────────────┘
```

### 2.1 Benefits

| Benefit | Detail |
| :--- | :--- |
| **Faster uploads** | Multiple parts upload simultaneously, saturating available bandwidth |
| **Resilient to failures** | Failed parts are retried individually — no restart from scratch |
| **No time limit** | Upload parts over hours or days; no expiration after initiation |
| **Stream as you generate** | Start uploading before you know the final object size |

### 2.2 When to Use

| Scenario | Why Multipart Helps |
| :--- | :--- |
| **Objects ≥ 100 MB** | AWS best practice threshold — always use multipart above this |
| **Stable high-bandwidth network** | Maximise throughput by uploading many parts in parallel |
| **Unreliable or spotty network** | Only retry the failed parts, not the entire object |

> **Important:** You must explicitly **complete** or **abort** a multipart upload. Incomplete uploads consume storage and incur charges. Use S3 lifecycle rules to auto-abort incomplete multipart uploads after a set number of days.

---

## 3. AWS DataSync

**What it is:** A fully managed data transfer service that moves data at scale between on-premises storage, AWS services, and other cloud providers — using a purpose-built protocol with parallel architecture.

### 3.1 Transfer Paths

```
┌──────────────────────────────────────────────────────────┐
│              DataSync Transfer Paths                      │
│                                                          │
│   On-premises Storage ◄──────────► AWS Storage Services  │
│   (NFS, SMB, HDFS,                 (S3, EFS, FSx)       │
│    object storage)                                       │
│                                                          │
│   AWS Storage Service ◄──────────► AWS Storage Service   │
│   (S3 ◄──► EFS, FSx ◄──► S3, etc.)                      │
│                                                          │
│   Other Cloud Storage ◄──────────► AWS Storage Services  │
│   (Azure, Google, etc.)            (S3, EFS, FSx)       │
└──────────────────────────────────────────────────────────┘
```

### 3.2 Benefits

| Benefit | Detail |
| :--- | :--- |
| **Speed** | Purpose-built protocol with parallel transfers — significantly faster than scripts or CLI tools |
| **Security** | Encrypted in transit (TLS) with automatic data integrity verification |
| **Simplicity** | Managed service — no custom scripts, cron jobs, or transfer orchestration |
| **Discovery** | DataSync Discovery analyses on-premises storage and recommends the best AWS target service |

### 3.3 Key Use Cases

| Use Case | Detail |
| :--- | :--- |
| **Cloud migration** | Move active datasets to AWS with integrity checks; DataSync Discovery recommends target services |
| **Archival offload** | Free on-premises storage by moving cold data to S3 Glacier Flexible Retrieval or Deep Archive |
| **Backup and DR** | Copy data to cost-effective S3 storage classes or maintain standby file systems (EFS, FSx) |
| **Hybrid workflows** | Move data in/out of AWS for ML training, media production, financial analytics |

---

## 4. S3 Transfer Acceleration

**What it is:** An S3 feature that speeds up long-distance uploads by routing data through the nearest **Amazon CloudFront edge location**, then transferring it over AWS's optimised internal network to the destination bucket — instead of traversing the public internet the entire way.

```
┌──────────────────────────────────────────────────────────────┐
│             Transfer Acceleration Flow                       │
│                                                              │
│   Client (Sydney)                                            │
│       │                                                      │
│       │  Upload to: bucketname.s3-accelerate.amazonaws.com   │
│       │                                                      │
│       ▼                                                      │
│   CloudFront Edge Location (Sydney)                          │
│       │                                                      │
│       │  AWS optimised backbone (not public internet)         │
│       │                                                      │
│       ▼                                                      │
│   S3 Bucket (us-east-1)                                      │
│                                                              │
│   Result: 50-500% faster than direct public internet upload  │
└──────────────────────────────────────────────────────────────┘
```

### 4.1 How to Enable

1. Enable Transfer Acceleration on the S3 bucket.
2. Use the acceleration endpoint: `bucketname.s3-accelerate.amazonaws.com`
3. That's it — no other application changes needed.

### 4.2 Benefits

| Benefit | Detail |
| :--- | :--- |
| **50–500% faster** | Cross-Region transfers over long geographic distances see the biggest gains |
| **AWS backbone routing** | Avoids congested public internet paths; uses optimised AWS internal network |
| **Consistent speeds** | More predictable upload/download for globally distributed users |
| **Minimal code changes** | Just change the endpoint URL — no SDK or architecture changes |
| **Pay only if faster** | No charge if Transfer Acceleration doesn't improve performance for a given transfer |

### 4.3 Use Cases

| Use Case | Why Transfer Acceleration Helps |
| :--- | :--- |
| **Global client uploads** | Users worldwide upload to the nearest edge location instead of a distant bucket Region |
| **Cross-continent dataset transfers** | Large datasets moving between continents benefit most from backbone routing |
| **Poor or variable network conditions** | Edge routing provides a more stable, optimised path than the public internet |

> **Cost note:** You only pay the Transfer Acceleration fee when it actually improves transfer speed. If a transfer wouldn't benefit (e.g., client is already close to the bucket Region), S3 routes it normally at no extra charge.

---

## 5. Quick-Reference Checklist

- [ ] **Use multipart upload for objects ≥ 100 MB** — this is an AWS best practice, not optional for large files.
- [ ] **Set lifecycle rules to abort incomplete multipart uploads** — prevents hidden storage costs from abandoned uploads.
- [ ] **Maximise parallelism** — more concurrent part uploads = higher throughput (S3 has no connection limits).
- [ ] **Use DataSync for bulk transfers** — don't script your own `aws s3 cp` loops for large migrations.
- [ ] **Run DataSync Discovery first** — before migrating, let it analyse on-premises storage and recommend the right AWS target.
- [ ] **Enable Transfer Acceleration for cross-Region uploads** — especially when clients are geographically far from the bucket Region.
- [ ] **Combine multipart + Transfer Acceleration** — they work together; large files get both parallel parts and edge-routed transfers.
- [ ] **Verify data integrity** — DataSync does this automatically; for multipart uploads, enable MD5 checksums or use additional checksum algorithms (SHA-256, CRC32).
