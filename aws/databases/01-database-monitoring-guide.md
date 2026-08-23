# Database Monitoring — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering why database monitoring matters, the key metric categories (performance, query, storage, connections, latency), how monitoring data informs scaling decisions, and operational best practices.

---

## 1. Why Monitor Databases?

Without monitoring data, you're guessing. Guessing leads to two expensive outcomes:

```
┌──────────────────────────────────────────────────────────┐
│              The Cost of Not Monitoring                   │
│                                                          │
│   OVER-PROVISIONED                UNDER-PROVISIONED      │
│   • Paying for unused capacity    • Slow queries         │
│   • Wasted budget                 • Timeouts             │
│   • Resources sitting idle        • User-facing outages  │
│                                   • Revenue loss         │
│                                                          │
│                  MONITORING FIXES BOTH                    │
│   • Right-size based on real data, not assumptions       │
│   • Detect problems before users notice them             │
│   • Make scaling decisions backed by metrics              │
└──────────────────────────────────────────────────────────┘
```

**The goal:** Be **proactive**, not reactive. Monitoring gives you early warning signals so you can resolve issues before they become outages.

---

## 2. Key Metric Categories

### 2.1 Performance Metrics

How efficiently is the database engine operating?

| Metric | What It Tells You | Alert Threshold |
| :--- | :--- | :--- |
| **CPU Usage** | Is the database under heavy load? High CPU = bottleneck or inefficient queries | **> 80%** — consider larger instance type or query optimisation |
| **Memory Usage** | Is the DB efficiently using available RAM? Low freeable memory forces reads from disk instead of cache | Low freeable memory → performance degradation |
| **Disk I/O (IOPS)** | Are storage operations creating a bottleneck? High IOPS can slow all operations | Sustained high IOPS → consider provisioned IOPS or GP3 tuning |

> **Key insight:** Memory pressure and disk I/O are connected — when the database runs low on memory, it can't cache data in RAM and must read from disk, which spikes IOPS and increases latency.

### 2.2 Query Metrics

Are individual queries performing well?

| Metric | What It Tells You |
| :--- | :--- |
| **Average runtime** | How long a query typically takes — baseline for detecting regressions |
| **Average CPU time** | Whether you have enough compute resources for typical query demand |
| **Slow query count** | Number of queries exceeding acceptable duration — targets for optimisation |

> **Tip:** Enable query-level insights (e.g., RDS Performance Insights, CloudWatch Query Insights) to identify the specific queries dragging down performance.

### 2.3 Storage Metrics

Is the database running out of space?

| Metric | What It Tells You | Alert Threshold |
| :--- | :--- | :--- |
| **Free storage space** | How much disk capacity remains | **< 20% remaining** — set alarm to give time to respond |
| **Table size** | Data growth patterns for capacity planning | Track trends over weeks/months |
| **Free local storage** | Temp storage for sorts, joins, temp tables | Low → performance degradation on complex queries |

> **Critical:** Running out of storage can cause the database to become **read-only or crash**. Always alert well before reaching capacity.

### 2.4 Connection Metrics

Can the database handle the current connection load?

| Metric | What It Tells You |
| :--- | :--- |
| **Active connections** | Current load — is it approaching the max allowed connections? |
| **Connection spikes** | Sudden jumps may indicate an application bug (connection leak) |
| **Query duration per connection** | Helps determine if connection pooling would improve performance |

**What to watch for:**
- **Sudden spike** → likely an application issue (connection leak, retry storm)
- **Consistently near max** → need to increase max connections, scale up, or implement connection pooling

### 2.5 Latency and Throughput Metrics

How fast is the database responding?

| Metric | What It Tells You |
| :--- | :--- |
| **Read latency** | Time to complete read operations — impacts query response times |
| **Write latency** | Time to complete write operations — impacts transaction commit speed |
| **Successful request latency** | End-to-end latency for completed operations (read + write) |

---

## 3. Monitoring → Scaling Decision Flow

```
┌──────────────────────────────────────────────────────────┐
│        How Monitoring Data Drives Scaling                │
│                                                          │
│   1. ESTABLISH BASELINES                                 │
│      Measure metrics during normal operation             │
│      (what does "healthy" look like?)                    │
│                   │                                      │
│   2. DETECT ANOMALIES                                    │
│      Set alarms for threshold breaches                   │
│      (CPU > 80%, storage < 20%, latency spike)           │
│                   │                                      │
│   3. DIAGNOSE ROOT CAUSE                                 │
│      Is it a bad query? Resource exhaustion?              │
│      Connection leak? Storage growth?                    │
│                   │                                      │
│   4. TAKE ACTION                                         │
│      ┌────────────┼────────────────┐                     │
│      │            │                │                     │
│   Optimise     Scale Up         Scale Out                │
│   queries      (bigger          (read replicas,          │
│                instance)        connection pooling)      │
│                                                          │
│   5. VERIFY                                              │
│      Confirm metrics return to baseline after changes    │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Best Practices

| Practice | Detail |
| :--- | :--- |
| **Establish baselines first** | Measure normal-state metrics before setting alarms — otherwise you'll get false alerts |
| **Set threshold alerts** | Automated alarms on critical metrics (CPU, storage, connections, latency) |
| **Monitor holistically** | No single metric tells the full story — correlate performance + storage + connections + latency together |
| **Identify slow queries** | Use monitoring data to find and optimise the specific queries causing problems |
| **Real-time collection** | Collect and monitor metrics in real time, not just daily summaries |
| **Review trends regularly** | Weekly/monthly trend analysis catches slow-burn issues (gradual storage growth, creeping latency) |
| **Tune proactively** | Adjust DB parameters and run maintenance tasks based on metric trends, not just when things break |
| **Data-driven decisions** | Scale based on concrete metrics, never on gut feeling |

---

## 5. Quick-Reference Checklist

- [ ] **Set up CloudWatch alarms** for CPU > 80%, free storage < 20%, and connection count near max.
- [ ] **Establish baselines** during normal operation before tuning anything.
- [ ] **Enable query insights** (RDS Performance Insights or equivalent) to identify slow queries.
- [ ] **Monitor memory pressure** — low freeable memory cascades into high disk I/O and latency spikes.
- [ ] **Track storage trends** — set alarms early enough to act before running out of space.
- [ ] **Watch for connection spikes** — sudden jumps usually indicate application-level issues.
- [ ] **Review metrics weekly** — catch gradual degradation before it becomes an outage.
- [ ] **Correlate metrics** — a CPU spike + latency spike + high IOPS usually points to a bad query, not an undersized instance.
