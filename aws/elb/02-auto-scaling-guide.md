# Auto Scaling — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering how auto scaling works, its core components (Auto Scaling groups, launch templates, scaling policies, health checks, cooldowns), the different auto scaling approaches (EC2, Application, ECS, EKS, Lambda), and a real-world flash sale case study.

---

## 1. What Is Auto Scaling?

Auto scaling dynamically adjusts compute capacity — adding instances when demand rises, removing them when it drops — based on metrics like CPU, network traffic, or custom CloudWatch metrics. The goal: **maintain performance while minimising costs**.

```
┌──────────────────────────────────────────────────────────┐
│           Auto Scaling in Action                         │
│                                                          │
│   Normal traffic:     Spike:              After spike:   │
│                                                          │
│   ┌──┐ ┌──┐          ┌──┐ ┌──┐ ┌──┐      ┌──┐ ┌──┐     │
│   │EC│ │EC│          │EC│ │EC│ │EC│      │EC│ │EC│     │
│   │2 │ │2 │          │2 │ │2 │ │2 │      │2 │ │2 │     │
│   └──┘ └──┘          │EC│ │EC│ │EC│      └──┘ └──┘     │
│   2 instances         │2 │ │2 │ │2 │      2 instances   │
│                      └──┘ └──┘ └──┘                     │
│   CPU: 40%           6 instances          CPU: 35%      │
│                      CPU: 65%                            │
│                                                          │
│   min=2  desired=2   desired=6  max=10   desired=2      │
└──────────────────────────────────────────────────────────┘
```

---

## 2. Core Components

| Component | What It Does |
| :--- | :--- |
| **Auto Scaling Group (ASG)** | Logical collection of EC2 instances treated as one entity. Defines **min**, **max**, and **desired** instance counts. Maintains healthy instances automatically. |
| **Launch Template** | Blueprint for new instances — AMI ID, instance type, key pair, security groups, user data. |
| **Scaling Policy** | Rules that determine **when and how** to scale (target tracking, step, scheduled, predictive). |
| **Health Checks** | Periodic tests to verify instances are healthy. Unhealthy instances are **automatically terminated and replaced**. |
| **Load Balancer** | Distributes traffic across healthy instances in the ASG. |
| **Target Group** | Collection of registered targets the load balancer routes requests to. |
| **Cooldown Period** | Wait time after a scaling action before another can start — prevents rapid fluctuation. |

---

## 3. How Auto Scaling Works

```
┌──────────────────────────────────────────────────────────┐
│              Auto Scaling Process                        │
│                                                          │
│   1. SET UP AUTO SCALING GROUP                           │
│      Define min, max, desired capacity                   │
│      Choose subnets / Availability Zones                 │
│                        │                                 │
│   2. CREATE LAUNCH TEMPLATE                              │
│      AMI, instance type, security groups, key pair       │
│                        │                                 │
│   3. CONFIGURE HEALTH CHECKS                             │
│      EC2 status checks + ELB health checks               │
│      Unhealthy → auto-terminate → auto-replace           │
│                        │                                 │
│   4. MONITOR + EVALUATE                                  │
│      CloudWatch metrics continuously monitored           │
│      CPU > 70% → launch instance                         │
│      CPU < 30% → terminate instance                      │
│                        │                                 │
│   5. COOLDOWN PERIOD                                     │
│      Wait before next scaling action                     │
│      Prevents rapid add/remove fluctuations              │
│                        │                                 │
│   6. LOAD BALANCER ADJUSTS                               │
│      New instances registered automatically              │
│      Terminated instances deregistered                   │
│      Traffic redistribution is seamless                  │
└──────────────────────────────────────────────────────────┘
```

### Health Check Types

| Check | What It Monitors | Who Fixes It |
| :--- | :--- | :--- |
| **System status check** | Underlying hardware and virtualisation software | AWS (infrastructure issue) |
| **Instance status check** | Software and network connectivity (ARP to NIC) | You (OS/application issue) |
| **ELB health check** | Application responsiveness on a configured endpoint | You (application issue) |

> **Key behaviour:** When an instance is marked unhealthy, the ASG terminates it and launches a replacement. If automatic termination is suspended, the group can grow up to **10% beyond max** to maintain healthy capacity.

---

## 4. Scaling Policy Types

| Policy Type | How It Works | Best For |
| :--- | :--- | :--- |
| **Target tracking** | Maintain a specific metric at a target value (e.g., keep CPU at 60%) | Most use cases — simple and effective |
| **Step scaling** | Add/remove different numbers of instances at different threshold breaches | Graduated responses to load |
| **Scheduled scaling** | Adjust capacity at specific times (e.g., scale up at 8 AM, down at 8 PM) | Predictable load patterns |
| **Predictive scaling** | ML-based — forecasts traffic and pre-scales before demand arrives | Recurring patterns with lead time |

---

## 5. Auto Scaling Approaches

### 5.1 Amazon EC2 Auto Scaling

The core auto scaling service — adjusts the number of **EC2 instances** in an ASG based on policies and metrics.

- Monitors health and availability automatically
- Integrates with ELB for traffic distribution
- Spans **multiple AZs** for high availability
- Uses CloudWatch metrics to trigger scaling

### 5.2 Application Auto Scaling

For resources **other than EC2 instances**:

| Service | What Scales |
| :--- | :--- |
| **Amazon ECS** | Number of tasks |
| **DynamoDB** | Table/index read/write capacity |
| **Aurora** | Number of read replicas |
| **SageMaker** | Model endpoint instances |
| **Lambda provisioned concurrency** | Pre-initialised execution environments |

Supports: target tracking, step scaling, scheduled scaling, and predictive scaling.

### 5.3 Amazon ECS Auto Scaling

Two layers of scaling:

```
┌──────────────────────────────────────────────────────────┐
│             ECS Scaling (Two Layers)                     │
│                                                          │
│   Layer 1: SERVICE AUTO SCALING                          │
│   Application Auto Scaling adjusts the number of TASKS  │
│   based on CPU, memory, or custom metrics                │
│                                                          │
│   Layer 2: CAPACITY PROVIDER (Managed Scaling)           │
│   ECS manages EC2 instances in the ASG                   │
│   Set targetCapacity % for instance utilisation          │
│   ECS creates CloudWatch metrics + target tracking       │
│   Scales EC2 nodes based on TASK demand, not instances   │
└──────────────────────────────────────────────────────────┘
```

### 5.4 Amazon EKS (Kubernetes)

**Cluster Autoscaler:**
- Watches for pods that **fail to schedule** (not enough nodes) and **underutilised nodes** (wasting resources)
- Simulates adding/removing nodes before applying changes
- Scales based on CPU, memory, or custom metrics

### 5.5 AWS Lambda

**No configuration needed** — scaling is fully automatic and event-driven:
- Each concurrent request gets its own execution environment
- Lambda scales instantly up to your account's concurrency limit
- No metrics, policies, or ASGs to manage

---

## 6. Auto Scaling + ELB Architecture

```
┌──────────────────────────────────────────────────────────┐
│        Multi-AZ Auto Scaling Architecture                │
│                                                          │
│                    ┌─────────────┐                       │
│                    │     ALB     │                       │
│                    └──────┬──────┘                       │
│                           │                              │
│              ┌────────────┼────────────┐                 │
│              ▼            ▼            ▼                 │
│        ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│        │   AZ-a   │ │   AZ-b   │ │   AZ-c   │           │
│        │ ┌──┐┌──┐ │ │ ┌──┐┌──┐ │ │ ┌──┐     │           │
│        │ │EC││EC│ │ │ │EC││EC│ │ │ │EC│     │           │
│        │ │2 ││2 │ │ │ │2 ││2 │ │ │ │2 │     │           │
│        │ └──┘└──┘ │ │ └──┘└──┘ │ │ └──┘     │           │
│        └──────────┘ └──────────┘ └──────────┘           │
│                                                          │
│        ◄──────── Auto Scaling Group ────────►           │
│        min=2   desired=5   max=20                       │
│                                                          │
│   Cross-zone load balancing distributes traffic          │
│   evenly across ALL targets in ALL enabled AZs.          │
└──────────────────────────────────────────────────────────┘
```

---

## 7. Real-World Case Study: Flash Sale

**Scenario:** Ecommerce app — steady traffic normally, 10x spikes during flash sales. Manual provisioning led to either overspending or outages. Single AZ = single point of failure.

**Solution implemented:**

| Component | Configuration |
| :--- | :--- |
| **ASG** | min=2, desired=4, max=22, multi-AZ |
| **Scaling policy** | Target tracking: scale out if avg CPU > 60% for 5 minutes |
| **Load balancer** | ALB with health checks on each instance |
| **Monitoring** | CloudWatch alarms on `RequestCount`, `CPUUtilization`, `5xx errors`, `TargetResponseTime` |
| **Scale-in** | Cooldown configured to prevent aggressive downsizing during temporary dips |

**Result during flash sale:**

```
┌──────────────────────────────────────────────────────────┐
│   Traffic: 7x spike in under 10 minutes                  │
│                                                          │
│   Before:   4 instances                                  │
│   Peak:    22 instances (auto-scaled)                    │
│   After:    6 instances (auto-scaled down)               │
│                                                          │
│   Result:   Zero downtime                                │
│             Low latency throughout                       │
│             Significant cost savings vs manual approach  │
│             Multi-AZ = no single point of failure        │
└──────────────────────────────────────────────────────────┘
```

---

## 8. Quick-Reference Checklist

- [ ] **Use multi-AZ** — always spread ASG across at least 2 AZs to eliminate single points of failure.
- [ ] **Start with target tracking** — simplest and most effective policy for most workloads (e.g., keep CPU at 60%).
- [ ] **Configure cooldown periods** — prevent rapid scaling oscillation during traffic fluctuations.
- [ ] **Use launch templates** (not launch configurations) — templates support versioning and are the current best practice.
- [ ] **Enable ELB health checks** on the ASG — EC2 status checks alone miss application-level failures.
- [ ] **Monitor after scaling** — watch `5xx errors`, `TargetResponseTime`, and `UnHealthyHostCount` to verify scaling actually solved the problem.
- [ ] **Set up CloudWatch alarms** for unhealthy hosts, latency spikes, and CPU thresholds.
- [ ] **Use scale-in protection** for instances that shouldn't be terminated (e.g., running batch jobs).
- [ ] **Right-size min/max** — too low a max and you can't handle spikes; too high and you risk runaway costs.
- [ ] **Lambda doesn't need auto scaling config** — it's fully automatic and event-driven.
