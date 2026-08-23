# Amazon S3 Directory Buckets & S3 Express One Zone

> **AWS Skill Builder Summary:**
> Concise CloudOps reference covering S3 directory buckets — what they are, how they differ from standard (general purpose) buckets, the S3 Express One Zone storage class, and when to use them.

---

## 1. What Are Directory Buckets?

**The simple version:** Standard S3 buckets use a flat namespace — every object is just a key in one big list (the `/` in paths is cosmetic, not real folders). Directory buckets implement **true hierarchical directories**, like a real file system.

**The underlying tech:** Directory buckets run on **S3 Express One Zone** — a specialised storage class that colocates data in a **single Availability Zone** for the lowest possible latency.

```
┌──────────────────────────────────────────────────────────────┐
│         Standard Bucket              Directory Bucket         │
│         (General Purpose)            (S3 Express One Zone)    │
│                                                              │
│  s3://my-bucket/                s3express://my-bucket/        │
│    photos/cat.jpg                 photos/                     │
│    photos/dog.jpg                   cat.jpg                   │
│    logs/app.log                     dog.jpg                   │
│                                   logs/                       │
│  Flat namespace:                    app.log                   │
│  "/" is just part of the key                                  │
│  No real folders exist          True directory hierarchy:     │
│                                 Directories are real objects  │
│                                                              │
│  Multi-AZ replication           Single-AZ (colocated data)   │
│  Standard latency               Single-digit ms latency      │
└──────────────────────────────────────────────────────────────┘
```

### Path Format

```
s3express://bucket-name/directory/subdirectory/object-key
```

---

## 2. Standard Buckets vs Directory Buckets

| Feature | Standard (General Purpose) Bucket | Directory Bucket (S3 Express One Zone) |
| :--- | :--- | :--- |
| **Namespace** | Flat (prefixes simulate folders) | True hierarchical directories |
| **Latency** | Typically low, but variable | **Consistent single-digit millisecond** |
| **Availability Zones** | Multi-AZ (data replicated across AZs) | **Single-AZ** (data in one AZ only) |
| **Durability trade-off** | Higher (multi-AZ redundancy) | Lower (single-AZ — no cross-AZ replication) |
| **Directory operations** | Simulated via prefix listing | Native, lower overhead |
| **Best for** | General storage, archival, multi-AZ durability | Low-latency, high-throughput directory workloads |

> **Key trade-off:** Directory buckets sacrifice multi-AZ redundancy for speed. Data lives in **one AZ only** — if that AZ has an issue, data is unavailable. Use them for workloads where latency matters more than cross-AZ durability (e.g., caches, scratch data, compute-adjacent storage).

---

## 3. Benefits

| Benefit | Detail |
| :--- | :--- |
| **Consistent single-digit ms latency** | Read and write operations are significantly faster than standard S3 |
| **No cross-AZ transfer overhead** | Data colocated in one AZ eliminates inter-AZ network hops |
| **Lower directory operation overhead** | Native directory semantics are cheaper than flat-namespace prefix scans |
| **High-throughput with low variance** | Reduced latency jitter for demanding workloads |

---

## 4. Use Cases

| Use Case | Why Directory Buckets Fit |
| :--- | :--- |
| **ML model training** | Training jobs need fast, repeated reads from structured datasets |
| **Real-time analytics** | Low-latency access to intermediate computation results |
| **High-frequency trading data** | Consistent single-digit ms reads for time-sensitive financial data |
| **Compute scratch storage** | Temporary high-speed storage colocated with EC2/compute in the same AZ |
| **Interactive data exploration** | Notebooks and queries that need fast iteration over structured data |

---

## 5. Quick-Reference Checklist

- [ ] **Use directory buckets when latency is the priority** — not for general-purpose storage or archival.
- [ ] **Understand the single-AZ trade-off** — no cross-AZ replication means lower durability than standard buckets.
- [ ] **Colocate compute and storage** — place EC2/compute instances in the same AZ as the directory bucket for maximum benefit.
- [ ] **Don't use for long-term durable storage** — pair with standard S3 or S3 Glacier for durable copies of important data.
- [ ] **Use the correct endpoint format** — `s3express://bucket-name/path`, not the standard `s3://` URI.
