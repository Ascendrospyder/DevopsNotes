# Amazon S3 Storage Optimisation: Intelligent-Tiering & Lifecycle Rules

> **AWS Skill Builder Summary:**
> Concise CloudOps reference covering how to optimise S3 storage costs using access patterns — S3 Intelligent-Tiering for unpredictable access and S3 Lifecycle rules for predictable access patterns.

---

## 1. The Core Decision

**One question determines which tool to use:** Do you know how often your objects will be accessed?

```
┌──────────────────────────────────────────────────────────┐
│           How are your objects accessed?                  │
│                                                          │
│   UNPREDICTABLE                    PREDICTABLE           │
│   "We don't know when              "We know logs are     │
│    users will access                hot for 30 days,     │
│    these files again"               then rarely touched" │
│         │                                │               │
│         ▼                                ▼               │
│   ┌──────────────────┐      ┌──────────────────────┐     │
│   │ S3 Intelligent-  │      │ S3 Lifecycle Rules   │     │
│   │ Tiering          │      │                      │     │
│   │                  │      │ You define the        │     │
│   │ AWS monitors and │      │ transition schedule   │     │
│   │ moves objects    │      │ (e.g., 30d -> IA,    │     │
│   │ automatically    │      │  90d -> Glacier)     │     │
│   └──────────────────┘      └──────────────────────┘     │
└──────────────────────────────────────────────────────────┘
```

---

## 2. S3 Intelligent-Tiering

**What it does:** Monitors each object's access pattern and **automatically** moves it between tiers to minimise cost — with no retrieval fees and no performance impact on the frequently used tiers.

### 2.1 Access Tiers

| Tier | When Objects Move Here | Latency | Activation |
| :--- | :--- | :--- | :--- |
| **Frequent Access** | Default tier; objects return here when accessed | Milliseconds | Automatic |
| **Infrequent Access** | Not accessed for **30 consecutive days** | Milliseconds | Automatic |
| **Archive Instant Access** | Not accessed for **90 consecutive days** | Milliseconds | Automatic |
| **Archive Access** | Not accessed for extended period (configurable) | Minutes | Optional (you activate) |
| **Deep Archive Access** | Not accessed for extended period (configurable) | Hours | Optional (you activate) |

```
┌──────────────────────────────────────────────────────────┐
│          S3 Intelligent-Tiering Auto-Movement            │
│                                                          │
│   Object uploaded                                        │
│       │                                                  │
│       ▼                                                  │
│   [Frequent Access] ◄─── object accessed (moves back)   │
│       │                       free, no retrieval fee     │
│       │ 30 days no access                                │
│       ▼                                                  │
│   [Infrequent Access] ◄─── still millisecond latency    │
│       │                                                  │
│       │ 90 days no access                                │
│       ▼                                                  │
│   [Archive Instant Access] ◄─── still millisecond       │
│       │                                                  │
│       │ (optional tiers, if activated)                   │
│       ▼                                                  │
│   [Archive Access] ──── minutes to retrieve              │
│       │                                                  │
│       ▼                                                  │
│   [Deep Archive Access] ──── hours to retrieve           │
└──────────────────────────────────────────────────────────┘
```

### 2.2 Key Rules

- **No retrieval charges** — when objects move between tiers or when you access them, there's no retrieval fee.
- **No additional tiering charges** — moving between tiers is free.
- **No performance impact** — the top 3 tiers all have millisecond access.
- **Small monitoring fee** — Intelligent-Tiering charges a small per-object monitoring and automation fee.
- **Archive tiers are optional** — you must explicitly activate Archive Access and Deep Archive Access.

---

## 3. S3 Lifecycle Rules

**What they do:** You define rules that automatically **transition objects to cheaper storage classes** or **delete them** based on a schedule you set. Best for predictable access patterns where you know when data becomes cold.

### 3.1 How They Work

| Action Type | What It Does | Example |
| :--- | :--- | :--- |
| **Transition** | Move objects to a cheaper storage class after X days | After 30 days → S3 Standard-IA; after 90 days → S3 Glacier |
| **Expiration** | Delete objects after X days | Delete logs after 365 days |

### 3.2 Example Lifecycle Policy

```
┌──────────────────────────────────────────────────────────┐
│          Example: Application Log Lifecycle               │
│                                                          │
│   Day 0:    Object created in S3 Standard                │
│       │                                                  │
│       │ 30 days                                          │
│       ▼                                                  │
│   Day 30:   Transition to S3 Standard-IA                 │
│       │     (cheaper, still fast access)                  │
│       │ 60 more days                                     │
│       ▼                                                  │
│   Day 90:   Transition to S3 Glacier Flexible Retrieval  │
│       │     (much cheaper, minutes-to-hours retrieval)    │
│       │ 275 more days                                    │
│       ▼                                                  │
│   Day 365:  Delete object (expiration)                   │
│                                                          │
│   Total cost savings vs keeping in Standard: ~70-80%     │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Intelligent-Tiering vs Lifecycle Rules

| Feature | S3 Intelligent-Tiering | S3 Lifecycle Rules |
| :--- | :--- | :--- |
| **Access pattern** | Unpredictable or changing | Predictable and well-understood |
| **Who decides when to move?** | AWS (automatic based on access monitoring) | You (define day-based transition rules) |
| **Retrieval fees** | None (top 3 tiers) | Vary by storage class (IA, Glacier, etc.) |
| **Performance impact** | None for top 3 tiers | Depends on target class (Glacier = minutes/hours) |
| **Operational overhead** | Zero — fully automated | Low — set rules once, but you must design them correctly |
| **Cost** | Small monitoring fee per object | No additional fee for the rules themselves |
| **Can delete objects?** | No — only moves between tiers | Yes — expiration rules delete objects automatically |
| **Best for** | Mixed/unknown access, user-generated content | Logs, backups, compliance data with known retention |

---

## 5. Quick-Reference Checklist

- [ ] **Audit your access patterns first** — check CloudWatch and S3 Storage Lens to understand how objects are actually accessed.
- [ ] **Unpredictable access → Intelligent-Tiering** — let AWS handle it; no retrieval fees, no performance hit.
- [ ] **Predictable access → Lifecycle rules** — define transition schedules based on known data lifecycle (hot → warm → cold → delete).
- [ ] **Activate archive tiers only if needed** — Intelligent-Tiering's Archive and Deep Archive tiers are optional and have minutes/hours retrieval times.
- [ ] **Use both together** — they're not mutually exclusive. Apply Intelligent-Tiering to buckets with mixed patterns and Lifecycle rules to buckets with known retention policies.
- [ ] **Set expiration rules for temporary data** — logs, build artifacts, and temp files should auto-delete to avoid cost creep.
- [ ] **Account for the monitoring fee** — Intelligent-Tiering charges a small per-object fee; for millions of tiny objects, this can add up.
