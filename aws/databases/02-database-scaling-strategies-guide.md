# Database Scaling Strategies — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering vertical, horizontal, and combined scaling patterns, single instance vs cluster architectures, read replicas, sharding vs partitioning, and how to choose the right strategy for your workload.

---

## 1. What Is Scaling?

Scaling is adjusting resource allocation to match workload demand — growing when demand increases, shrinking when it drops. The goal is to do this **automatically** based on monitoring metrics, not manually reacting to every fluctuation.

---

## 2. Scaling Patterns

### 2.1 Vertical Scaling (Scale Up/Down)

**What it is:** Change the **size** of the instance — more CPU, memory, storage, or network capacity.

```
┌──────────────────────────────────────────────────────────┐
│                   Vertical Scaling                       │
│                                                          │
│   ┌─────────┐       ┌─────────────┐       ┌───────┐     │
│   │ Small   │  ──►  │   Large     │  ──►  │ Small │     │
│   │ db.r5.  │       │   db.r5.    │       │ db.r5.│     │
│   │ large   │       │   4xlarge   │       │ large │     │
│   │         │       │             │       │       │     │
│   │ 2 vCPU  │       │ 16 vCPU    │       │ 2 vCPU│     │
│   │ 16 GB   │       │ 128 GB     │       │ 16 GB │     │
│   └─────────┘       └─────────────┘       └───────┘     │
│                                                          │
│   Low demand         Peak season          Back to normal │
└──────────────────────────────────────────────────────────┘
```

**The process (with downtime):**
1. Provision new, larger instance → install DB software
2. Import data from old instance (**downtime required**)
3. Redirect traffic to new instance
4. Dispose of old instance

**Minimising downtime (standby approach):**
1. Upgrade the **standby** database first
2. Promote standby to primary
3. Redirect traffic to new primary
4. Upgrade original primary → set as new standby

**Best for:**

| Scenario | Why Vertical |
| :--- | :--- |
| Monolithic databases | Single instance handles everything |
| Write-heavy workloads | Writing can't easily be distributed across nodes |
| CPU/memory under stress | More resources = immediate relief |
| Strong consistency required | One instance = no replication lag |

**Limitations:** There's always a maximum instance size ceiling. Requires downtime or careful standby orchestration.

---

### 2.2 Horizontal Scaling (Scale Out/In)

**What it is:** Add or remove **instances** to distribute the workload across multiple nodes.

```
┌──────────────────────────────────────────────────────────┐
│                  Horizontal Scaling                      │
│                                                          │
│   Low demand:          Peak demand:         Back to low: │
│                                                          │
│   ┌────┐               ┌────┐ ┌────┐       ┌────┐       │
│   │ DB │               │ DB │ │ DB │       │ DB │       │
│   └────┘               └────┘ └────┘       └────┘       │
│   1 node               │ DB │ │ DB │       1 node       │
│                        └────┘ └────┘                     │
│                        │ DB │                            │
│                        └────┘                            │
│                        5 nodes                           │
└──────────────────────────────────────────────────────────┘
```

**Key advantage:** No downtime — instances can be added while the database is running.

**Best for:**

| Scenario | Why Horizontal |
| :--- | :--- |
| Read-heavy workloads | Distribute reads across replicas |
| Geographically distributed users | Place replicas closer to users |
| High availability requirements | Multiple nodes = no single point of failure |

**Limitations:** More complex management, potential consistency challenges across nodes.

---

### 2.3 Combined Scaling

For complex workloads, use **both** patterns together:

```
┌──────────────────────────────────────────────────────────┐
│                  Combined Scaling                        │
│                                                          │
│   Primary (writes):  Scale UP for more write power       │
│   ┌────────────┐                                         │
│   │ db.r5.4xl  │ ← Vertically scaled for write demand   │
│   └─────┬──────┘                                         │
│         │ replication                                    │
│    ┌────┴────┬──────────┐                                │
│    ▼         ▼          ▼                                │
│   ┌────┐   ┌────┐    ┌────┐                              │
│   │ RR │   │ RR │    │ RR │  ← Horizontally scaled      │
│   └────┘   └────┘    └────┘    for read demand           │
│                                                          │
│   RR = Read Replica                                      │
└──────────────────────────────────────────────────────────┘
```

**Best for:** Complex applications with varying workload patterns and systems requiring both read and write scalability.

---

## 3. Single Instance vs Cluster

| Feature | Single Instance | Cluster |
| :--- | :--- | :--- |
| **Servers** | One database server | Multiple database servers |
| **Failure handling** | Single point of failure (full outage) | If one fails, others keep running |
| **Redundancy** | None | Built-in via replication |
| **Scalability** | Limited to one machine | Add/remove nodes as needed |
| **Geographic reach** | One location | Distribute across regions |
| **Performance under load** | Degrades as load increases | Distributes work across nodes |
| **Management complexity** | Simple, straightforward | More complex coordination |
| **Setup cost** | Lower | Higher |
| **Consistency** | Always consistent (single source) | Potential replication lag |

### Cluster Scaling Options

- **Vertical:** Upgrade all nodes to larger instance types (more CPU per node)
- **Horizontal:** Add or remove nodes from the cluster
- **Independent storage scaling:** When the DB engine uses a separate storage cluster (e.g., Aurora), compute nodes and storage can scale independently

> **Typical evolution:** Small operations start with a single instance and migrate to a cluster as they grow and need more reliability and capacity.

---

## 4. Read Replicas

**What they are:** Read-only copies of your primary database that stay synchronised via replication. Offload read traffic from the primary, leaving it free to handle writes.

```
┌──────────────────────────────────────────────────────────┐
│                   Read Replica Pattern                    │
│                                                          │
│             ┌──────────────┐                             │
│             │   Primary    │ ◄── Writes (inserts,        │
│             │   Database   │     updates, deletes)       │
│             └──────┬───────┘                             │
│                    │ replication (async)                  │
│          ┌─────────┼──────────┐                          │
│          ▼         ▼          ▼                          │
│      ┌───────┐ ┌───────┐ ┌───────┐                      │
│      │Read   │ │Read   │ │Read   │ ◄── Reads (queries,  │
│      │Replica│ │Replica│ │Replica│     reports,          │
│      │  #1   │ │  #2   │ │  #3   │     analytics)       │
│      └───────┘ └───────┘ └───────┘                      │
└──────────────────────────────────────────────────────────┘
```

**Best for:**

| Use Case | Why Replicas Help |
| :--- | :--- |
| **Reporting and analytics** | Heavy queries don't impact production writes |
| **Content delivery** | Replicas closer to users reduce latency |
| **Read-heavy applications** | Distribute read load across multiple copies |

> **Note:** Replication is asynchronous — there's a small delay before replicas reflect writes from the primary. This is called **replication lag**. Design your application to tolerate this.

---

## 5. Sharding vs Partitioning

Both techniques break large datasets into smaller pieces, but at different levels:

| Feature | Sharding | Partitioning |
| :--- | :--- | :--- |
| **Where data splits** | Across **multiple separate servers** | Within a **single database** |
| **Independence** | Each shard operates independently | All partitions in the same DB instance |
| **Primary purpose** | Scale writes beyond a single server's capacity | Improve query performance and maintenance |
| **How data is divided** | By a shard key (e.g., customer IDs 0–10K on shard 1, 10K–20K on shard 2) | By criteria like date, category, or region |
| **Complexity** | High — cross-shard joins are difficult, ACID compliance is challenging | Lower — standard DB features handle partitions |
| **Example** | Customer data spread across 5 database servers | Sales table partitioned by month within one DB |

---

## 6. Choosing a Scaling Strategy

```
┌──────────────────────────────────────────────────────────┐
│                 Which Strategy to Use?                    │
│                                                          │
│   What's the workload type?                              │
│                                                          │
│   WRITE-HEAVY ──────► Vertical scaling                   │
│                       (bigger instance)                  │
│                                                          │
│   READ-HEAVY ───────► Horizontal scaling                 │
│                       (read replicas)                    │
│                                                          │
│   BALANCED ─────────► Combined scaling                   │
│                       (vertical primary + read replicas) │
│                                                          │
│   TOO BIG FOR ──────► Sharding                           │
│   ONE SERVER          (distribute writes)                │
│                                                          │
│   SLOW QUERIES ─────► Partitioning                       │
│   ON LARGE TABLES     (divide tables within one DB)      │
└──────────────────────────────────────────────────────────┘
```

### Decision Factors

| Factor | Consideration |
| :--- | :--- |
| **Database type** | Relational → vertical for writes, replicas for reads. NoSQL → typically horizontal by design. |
| **Workload pattern** | Read-heavy → replicas. Write-heavy → scale up. Mixed → combined. |
| **Performance requirements** | Must match or exceed baseline established during monitoring |
| **Cost** | Find the best compromise between performance and affordability |
| **Data consistency** | What replication lag is tolerable between instances? |
| **User geography** | Replicas closer to users = less latency, better experience |
| **Downtime tolerance** | Vertical scaling needs downtime (or standby). Horizontal scaling does not. |

---

## 7. Quick-Reference Checklist

- [ ] **Establish a performance baseline first** — you can't evaluate scaling results without knowing the starting point.
- [ ] **Start with vertical scaling for write-heavy loads** — simpler to implement, no consistency challenges.
- [ ] **Add read replicas for read-heavy loads** — no downtime to add, immediately offloads the primary.
- [ ] **Design for replication lag** — applications reading from replicas must tolerate slightly stale data.
- [ ] **Use the standby promotion method** to minimise vertical scaling downtime.
- [ ] **Plan for cluster migration early** — don't wait until a single instance is at its ceiling to start designing for a cluster.
- [ ] **Consider sharding only when necessary** — it adds significant complexity; try vertical + replicas first.
- [ ] **Monitor after scaling** — verify metrics return to healthy baselines and the scaling action actually solved the problem.
