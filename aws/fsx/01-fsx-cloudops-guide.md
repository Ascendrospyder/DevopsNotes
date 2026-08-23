# Amazon FSx — Fully Managed File Systems Guide

> **AWS Skill Builder Summary:**
> Beginner-friendly reference covering what Amazon FSx is, the four file system types (NetApp ONTAP, OpenZFS, Windows File Server, Lustre), when to use each, and how they compare on performance, protocols, cost, and security.

---

## 1. What Is Amazon FSx?

**The simple version:** Amazon FSx gives you a fully managed file server in the cloud. You pick the file system type that matches your workload, and AWS handles all the hard parts — hardware, software updates, backups, and failover.

**Why it exists:** Many applications need specific file system features (Windows shares, high-speed parallel I/O, NFS with snapshots, etc.). Amazon EFS only provides NFS. Amazon FSx fills the gap by offering **four different file system types**, each purpose-built for different workloads.

### The Analogy

Think of Amazon FSx like choosing a vehicle:

| Vehicle | FSx Equivalent | Best For |
| :--- | :--- | :--- |
| 🏎️ Race car | **FSx for Lustre** | Raw speed — HPC, ML training, video rendering |
| 🚐 Multi-purpose van | **FSx for NetApp ONTAP** | Carries everything — multi-protocol, multi-OS, enterprise features |
| 🖥️ Company shuttle | **FSx for Windows File Server** | Windows ecosystem — AD integration, SMB shares, SQL Server |
| 🏍️ Sport bike | **FSx for OpenZFS** | Fast and lightweight — low-latency NFS for Linux workloads |

---

## 2. Common Features (All FSx Types)

Before diving into each type, here's what **all** FSx file systems share:

- **Fully managed** — AWS handles provisioning, patching, backups, and hardware failures.
- **Automatic backups** — daily backups by default, plus on-demand backups anytime.
- **Encryption** — at rest and in transit.
- **SSD and HDD options** — balance performance vs cost.
- **Single-AZ and Multi-AZ deployments** — choose based on availability requirements.
- **Crash-consistent incremental backups** — supported across all types.

---

## 3. The Four FSx File System Types

### 3.1 FSx for NetApp ONTAP — The Multi-Tool

**What it is:** A fully managed version of NetApp's ONTAP file system — the same technology many enterprises already run in their on-premises data centres.

**Why you'd choose it:** You need one file system that works with **everything** — Linux, macOS, and Windows — using multiple protocols (NFS, SMB, and iSCSI for block storage).

```
┌─────────────────────────────────────────────────────────────┐
│                  FSx for NetApp ONTAP                        │
│                                                             │
│   Protocols:  NFS  +  SMB  +  iSCSI (block storage)        │
│   OS Support: Linux, macOS, Windows                         │
│                                                             │
│   ┌────────────┐    ┌────────────┐    ┌────────────┐        │
│   │  SSD Tier  │◄──►│  Cold Tier │    │ FlexCache  │        │
│   │ (hot data) │    │ (auto-tier)│    │ (local     │        │
│   │            │    │            │    │  caching)  │        │
│   └────────────┘    └────────────┘    └────────────┘        │
│                                                             │
│   Key Features:                                             │
│   • Intelligent tiering (hot ↔ cold automatically)          │
│   • Instant cloning (zero-copy clones for dev/test)         │
│   • SnapMirror replication (on-prem ↔ cloud DR)             │
│   • FlexCache (cache remote data locally)                   │
│   • Data deduplication + compression                        │
└─────────────────────────────────────────────────────────────┘
```

**Key concept — FlexCache:**
> Imagine two offices in different cities both working on the same project files. FlexCache stores a local read copy at each location for fast access, but **all writes go back to the single origin volume**. This guarantees everyone always works with the latest version — no conflicting edits.

**Use cases:** Enterprise workloads, databases, home directories, backup/DR from on-premises ONTAP, big data analytics, media processing.

---

### 3.2 FSx for Windows File Server — The Windows Native

**What it is:** A fully managed Windows file server built on Windows Server, with native SMB protocol and Active Directory integration.

**Why you'd choose it:** Your organisation runs Windows workloads and needs **SMB file shares, Active Directory authentication, and Windows-specific features** like file access auditing and data deduplication.

```
┌─────────────────────────────────────────────────────────────┐
│              FSx for Windows File Server                     │
│                                                             │
│   Protocol:   SMB (native Windows sharing)                  │
│   OS Support: Linux, macOS, Windows                         │
│                                                             │
│   ┌───────────────────────────────────────────────────┐     │
│   │           Active Directory Integration            │     │
│   │                                                   │     │
│   │  AWS Managed Microsoft AD                         │     │
│   │       OR                                          │     │
│   │  On-premises AD (direct link, no migration)       │     │
│   └───────────────────────────────────────────────────┘     │
│                                                             │
│   Key Features:                                             │
│   • Default "share" + create custom shares via GUI          │
│   • VSS for crash-consistent snapshots                      │
│   • Data deduplication                                      │
│   • File access auditing (who accessed what)                │
│   • NTFS access control lists (ACLs)                        │
│   • Multi-AZ for high availability                          │
└─────────────────────────────────────────────────────────────┘
```

**Use cases:** Windows user/group shares, Microsoft SQL Server HA, home directories, migrating on-premises Windows file servers to AWS.

#### Shadow Copies (VSS) — Self-Service File Recovery

**What are shadow copies?** Point-in-time snapshots of files on an FSx for Windows volume, powered by Windows Volume Shadow Copy Service (VSS). They let **end users restore their own deleted or changed files** directly from Windows Explorer — no admin ticket required.

```
┌──────────────────────────────────────────────────────────────┐
│                   How Shadow Copies Work                      │
│                                                              │
│   File: report.docx                                          │
│                                                              │
│   Monday 9am ──► Shadow Copy 1  (original version saved)     │
│   Tuesday 9am ──► Shadow Copy 2  (only changed blocks saved) │
│   Wednesday ──► User accidentally deletes report.docx        │
│                                                              │
│   Recovery: Right-click folder → "Restore previous versions" │
│             → Select Tuesday's copy → Restore                │
│                                                              │
│   ✓ No admin intervention needed                             │
│   ✓ No full backup restore needed                            │
│   ✓ Only changed portions consume storage                    │
└──────────────────────────────────────────────────────────────┘
```

**How copy-on-write works:** Windows uses a copy-on-write method — each file write can generate **up to 3 I/O operations** (read old block, write old block to shadow store, write new block). This is why performance planning matters.

**Benefits:**

| Benefit | Detail |
| :--- | :--- |
| **Reduces operational overhead** | Fewer file recovery tickets for support teams |
| **Improves productivity** | Users self-recover after accidental deletion or corruption |
| **Minimises business disruption** | Critical files recovered in seconds, not hours |
| **Complements backups** | Rapid granular recovery for recent changes; backups handle full DR |

**Best practices:**

- **Use SSD storage** — shadow copies require high I/O performance. HDD may not keep up with the copy-on-write overhead.
- **Provision 3x throughput** — set throughput capacity to ~3x your expected workload to absorb the extra I/O from copy-on-write.
- **Limit shadow copy count** — keep only the number you need. Configure automated scripts to delete old copies and prevent storage bloat.
- **Monitor storage** — use CloudWatch or the FSx console to track how much capacity shadow copies are consuming.
- **Shadow copies are NOT backups** — they live on the same volume as your data. If the volume is lost, shadow copies are lost too. Always use AWS Backup or another backup service alongside shadow copies for disaster recovery and compliance.

> **Key rule:** Shadow copies = convenience (self-service file restore). Backups = protection (disaster recovery). You need both.

---

### 3.3 FSx for Lustre — The Speed Demon

**What it is:** A fully managed Lustre parallel file system — the same technology used by the world's fastest supercomputers.

**Why you'd choose it:** You need **extreme throughput** (up to 1,000 Gbps) for compute-intensive workloads like ML training, video rendering, or genomics — and you want it tightly integrated with S3.

```
┌─────────────────────────────────────────────────────────────┐
│                    FSx for Lustre                            │
│                                                             │
│   Protocol:   POSIX-compliant (Linux only)                  │
│   OS Support: Linux                                         │
│                                                             │
│   ┌─────────────────────┐    ┌─────────────────────┐        │
│   │    File Servers     │    │   Amazon S3 Bucket  │        │
│   │  (in-memory cache)  │◄──►│   (data repository) │        │
│   │                     │    │   auto import/export │        │
│   └─────────┬───────────┘    └─────────────────────┘        │
│             │                                               │
│   ┌─────────▼───────────┐                                   │
│   │  Storage Targets    │  ← Data striped across OSTs       │
│   │  (OSTs on disks)    │    for parallel read/write        │
│   └─────────────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
```

**Key concepts for beginners:**

- **Scratch vs Persistent file systems:**
  - **Scratch** = temporary, no replication, data lost if server fails. Use for short-lived processing jobs.
  - **Persistent** = long-term, data replicated on disk, auto-recovers from failures within minutes.

- **File striping:** Large files are automatically split across multiple storage targets (OSTs). When you read/write, all OSTs work in parallel — like multiple cashiers serving one queue simultaneously.

- **S3 integration:** FSx for Lustre can automatically import data from S3 and export results back. Your ML pipeline reads from Lustre at high speed, then writes final models back to S3 for storage.

**Use cases:** Machine learning training, video rendering, HPC simulations, genomics, data analytics.

---

### 3.4 FSx for OpenZFS — The Low-Latency NFS

**What it is:** A fully managed OpenZFS file system optimised for low-latency NFS workloads.

**Why you'd choose it:** You need **sub-millisecond latency** for Linux/NFS workloads and want features like instant snapshots and cloning — without managing ZFS infrastructure yourself.

```
┌─────────────────────────────────────────────────────────────┐
│                   FSx for OpenZFS                           │
│                                                             │
│   Protocol:   NFS                                           │
│   OS Support: Linux, macOS, Windows                         │
│                                                             │
│   ┌───────────────────────────────────────────────────┐     │
│   │  Active File Server                               │     │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │     │
│   │  │ In-memory│  │  NVMe    │  │  SSD Disk    │    │     │
│   │  │  cache   │  │  cache   │  │  storage     │    │     │
│   │  │  (ARC)   │  │  (L2ARC) │  │              │    │     │
│   │  └──────────┘  └──────────┘  └──────────────┘    │     │
│   └───────────────────────────────────────────────────┘     │
│                                                             │
│   Key Features:                                             │
│   • Sub-0.5ms latency (fastest of all FSx types)            │
│   • Up to 21 Gbps single-client throughput                  │
│   • Instant snapshots and cloning                           │
│   • Data compression                                        │
│   • Single-AZ only (99.5% SLA)                              │
└─────────────────────────────────────────────────────────────┘
```

**Key concept — Multi-layer caching:**
> OpenZFS uses a tiered caching strategy. The hottest data sits in **RAM (ARC)**, warm data in the **NVMe cache (L2ARC)**, and everything else on **SSD disks**. Reads hit the fastest available layer automatically.

**Use cases:** Databases, DevOps, web content management, big data analytics, media rendering, cloning enterprise DB environments for dev/test.

---

## 4. Comparison Tables

### 4.1 Performance

| Attribute | NetApp ONTAP | OpenZFS | Windows File Server | Lustre |
| :--- | :--- | :--- | :--- | :--- |
| **Latency** | < 1 ms | < 0.5 ms | < 1 ms | < 1 ms |
| **Max file system throughput** | 4–6 Gbps | 8–21 Gbps | 2–3 Gbps | **1,000 Gbps** |
| **Max single-client throughput** | 6 Gbps | **21 Gbps** | 3 Gbps | 37.5 Gbps |
| **Max IOPS** | Hundreds of thousands | **1–2 million** | Hundreds of thousands | Millions |
| **Max file system size** | Virtually unlimited | 512 TiB | 64 TiB | Multiple PBs |

### 4.2 Protocol and OS Support

| Feature | NetApp ONTAP | OpenZFS | Windows File Server | Lustre |
| :--- | :--- | :--- | :--- | :--- |
| **OS compatibility** | Linux, macOS, Windows | Linux, macOS, Windows | Linux, macOS, Windows | **Linux only** |
| **Protocol** | SMB, NFS, iSCSI | NFS | SMB | POSIX |

### 4.3 Availability and Deployment

| Feature | NetApp ONTAP | OpenZFS | Windows File Server | Lustre |
| :--- | :--- | :--- | :--- | :--- |
| **Deployment options** | Single-AZ, Multi-AZ | Single-AZ only | Single-AZ, Multi-AZ | Single-AZ (persistent or scratch) |
| **SLA** | Multi-AZ: 99.99%, Single-AZ: 99.9% | 99.5% | Multi-AZ: 99.99%, Single-AZ: 99.5% | 99.5% |

### 4.4 Cost Optimisation

| Feature | NetApp ONTAP | OpenZFS | Windows File Server | Lustre |
| :--- | :--- | :--- | :--- | :--- |
| **Cold data tiering** | ✓ (automatic) | ✗ | HDD storage option | HDD storage option |
| **Tuneable throughput and IOPS** | ✓ (both) | ✓ (both) | Throughput only | Throughput only |
| **Data compression** | ✓ | ✓ | ✓ | ✓ |
| **Data deduplication** | ✓ | ✗ | ✓ | ✗ |

### 4.5 Security and Access Control

| Feature | NetApp ONTAP | OpenZFS | Windows File Server | Lustre |
| :--- | :--- | :--- | :--- | :--- |
| **Active Directory support** | ✓ | ✗ | ✓ | ✗ |
| **File access auditing** | ✓ | ✗ | ✓ | ✗ |
| **ACL type** | NFS + NTFS | N/A | NTFS | N/A |

### 4.6 Hybrid and On-Premises Integration

| Feature | NetApp ONTAP | OpenZFS | Windows File Server | Lustre |
| :--- | :--- | :--- | :--- | :--- |
| **On-prem caching of FSx data** | FlexCache, Global File Cache | ✗ | FSx File Gateway | ✗ |
| **On-prem backup/DR to AWS** | SnapMirror | ✗ | ✗ | ✗ |

---

## 5. How to Choose — Decision Guide

```
                    ┌──────────────────────────────┐
                    │  What does your workload      │
                    │  need most?                   │
                    └──────────────┬────────────────┘
                                  │
        ┌─────────────┬───────────┼───────────┬──────────────┐
        │             │           │           │              │
   Windows SMB    Multi-protocol  Extreme     Low-latency
   + Active       (NFS+SMB+iSCSI) parallel    NFS for
   Directory      + enterprise    throughput   Linux apps
        │         features        (HPC, ML)        │
        │             │           │                │
        ▼             ▼           ▼                ▼
  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
  │ FSx for   │ │ FSx for   │ │ FSx for   │ │ FSx for   │
  │ Windows   │ │ NetApp    │ │ Lustre    │ │ OpenZFS   │
  │ File      │ │ ONTAP     │ │           │ │           │
  │ Server    │ │           │ │           │ │           │
  └───────────┘ └───────────┘ └───────────┘ └───────────┘
```

**Quick rules of thumb:**
- **"We're a Windows shop"** → FSx for Windows File Server
- **"We need one file system for mixed Linux/Windows/Mac"** → FSx for NetApp ONTAP
- **"We need maximum speed for ML/HPC on Linux"** → FSx for Lustre
- **"We need fast NFS with snapshots and cloning"** → FSx for OpenZFS
- **"We're migrating from on-prem NetApp"** → FSx for NetApp ONTAP (same API, same tools)

---

## 6. FSx vs EFS — When to Use Which

| Question | EFS | FSx |
| :--- | :--- | :--- |
| **What protocol?** | NFS only | SMB, NFS, iSCSI, or POSIX depending on type |
| **Need Windows/AD support?** | ✗ | ✓ (Windows File Server, ONTAP) |
| **Need extreme HPC throughput?** | ✗ | ✓ (Lustre: up to 1,000 Gbps) |
| **Need auto-scaling storage?** | ✓ (elastic by default) | Varies by type |
| **Simplest NFS setup?** | ✓ (no capacity planning) | FSx requires more config |
| **Need multi-protocol access?** | ✗ | ✓ (ONTAP: NFS + SMB + iSCSI) |

> **Rule of thumb:** If you just need simple, elastic NFS shared storage → **EFS**. If you need a specific file system type, protocol, or performance tier → **FSx**.

---

## 7. Quick-Reference Checklist

- [ ] **Identify your protocol needs**: SMB → Windows File Server or ONTAP. NFS → OpenZFS, ONTAP, or EFS. POSIX parallel → Lustre.
- [ ] **Check OS requirements**: Linux only? All four work. Windows/AD needed? Narrows to Windows File Server or ONTAP.
- [ ] **Evaluate performance needs**: Extreme throughput → Lustre. Lowest latency → OpenZFS. General enterprise → ONTAP.
- [ ] **Choose deployment mode**: Multi-AZ for production HA (ONTAP, Windows). Single-AZ acceptable for dev/test or cost savings.
- [ ] **Plan for hybrid**: Migrating from on-prem NetApp? → ONTAP with SnapMirror. Windows file servers? → Windows File Server with AD link.
- [ ] **Enable encryption**: At rest and in transit on all file systems.
- [ ] **Configure backups**: Automatic daily backups are enabled by default — verify retention meets your requirements.
