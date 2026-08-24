# Elastic Load Balancing (ELB) — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering how load balancing works in AWS, the three load balancer types (ALB, NLB, GLB), listeners, target groups, and when to use each type.

---

## 1. What Is a Load Balancer?

A load balancer distributes incoming traffic across multiple compute resources (EC2 instances, containers, Lambda functions) to improve **performance**, **reliability**, and **availability**.

```
┌──────────────────────────────────────────────────────────┐
│               How Load Balancing Works                    │
│                                                          │
│   Clients                                                │
│   ┌─────┐ ┌─────┐ ┌─────┐                               │
│   │ Req │ │ Req │ │ Req │                                │
│   └──┬──┘ └──┬──┘ └──┬──┘                                │
│      │       │       │                                   │
│      └───────┼───────┘                                   │
│              ▼                                           │
│   ┌──────────────────────┐                               │
│   │    LOAD BALANCER     │ ◄── Entry point for traffic   │
│   │                      │                               │
│   │  Listener: checks    │                               │
│   │  requests on a       │                               │
│   │  protocol + port     │                               │
│   └──────────┬───────────┘                               │
│              │ forwards to target group                  │
│      ┌───────┼───────┐                                   │
│      ▼       ▼       ▼                                   │
│   ┌──────┐┌──────┐┌──────┐                               │
│   │ EC2  ││ EC2  ││ EC2  │  ◄── Target Group             │
│   │  #1  ││  #2  ││  #3  │  (registered targets)        │
│   └──────┘└──────┘└──────┘                               │
└──────────────────────────────────────────────────────────┘
```

---

## 2. Key Components

Based on the standard Elastic Load Balancing architecture, there are five primary components:

| # | Component | What It Does |
| :--- | :--- | :--- |
| **1** | **Elastic Load Balancing** | The parent service that distributes incoming traffic across compute targets. |
| **2** | **Listener** | Checks for connection requests from clients using a configured **protocol + port**. |
| **3** | **Listener Rule** | Evaluates conditions (like URL path or headers) and forwards matching requests to a specific target group. |
| **4** | **Target Group** | A logical collection that routes requests to one or more **registered targets** (EC2 instances, containers, IPs, etc.). |
| **5** | **Health Checks** | Periodic tests that monitor target health — unhealthy targets stop receiving traffic until they recover. |

---

## 3. Three Load Balancer Types

### 3.1 Application Load Balancer (ALB) — Layer 7

Operates at the **application layer** (HTTP/HTTPS). Evaluates listener rules in priority order to decide which target group receives each request.

**Key features:**
- **Content-based routing** — route by URL path, hostname, HTTP headers, query strings
- Native support for **container-based** applications (ECS, EKS)
- **WebSocket** and **HTTP/2** support
- Integrates with **AWS WAF** for security
- Can target **Lambda functions** directly

**Best for:** Web applications, microservices, API routing.

---

### 3.2 Network Load Balancer (NLB) — Layer 4

Operates at the **transport layer** (TCP/UDP). Handles **millions of requests per second** with ultra-low latency. Opens a TCP connection to the selected target on the listener's configured port.

**Key features:**
- **Preserves source IP** address (clients see real IPs)
- Supports **static IP addresses** and **Elastic IPs**
- **TLS offloading** support
- Can target an **ALB** (NLB → ALB chaining for static IP + Layer 7 routing)

**Best for:** Real-time applications, high-performance workloads, gaming, IoT.

---

### 3.3 Gateway Load Balancer (GLB) — Layer 3

Operates at the **network layer** (IP). Acts as a **transparent network gateway** — single entry/exit point for all traffic — while distributing traffic to virtual appliances and scaling them with demand.

**Key features:**
- **Transparent** — traffic passes through without termination
- Deploy, scale, and manage **virtual appliances** (firewalls, IDS/IPS, deep packet inspection)
- Supports **static IP**

**Best for:** Security appliances, network monitoring, compliance inspection.

---

## 4. Comparison Table

| Feature | ALB | NLB | GLB |
| :--- | :--- | :--- | :--- |
| **OSI Layer** | Layer 7 (Application) | Layer 4 (Transport) | Layer 3 (Network) |
| **Protocol listeners** | HTTP, HTTPS, gRPC | TCP, UDP, TLS | IP |
| **Terminates flow** | Yes | Yes | No (transparent) |
| **Static IP support** | No | Yes | Yes |
| **Target types** | IP, Instance, Lambda | IP, Instance, ALB | IP, Instance |
| **Content-based routing** | Yes (path, host, headers) | No | No |
| **Preserves source IP** | No (use `X-Forwarded-For`) | Yes | Yes |
| **Use case** | Web apps, microservices | Real-time, high-performance | Security appliances |

---

## 5. Quick Decision Guide

```
┌──────────────────────────────────────────────────────────┐
│              Which Load Balancer?                         │
│                                                          │
│   Need to route by URL path, hostname, or headers?       │
│   └──► ALB (Layer 7)                                     │
│                                                          │
│   Need ultra-low latency, static IPs, or millions of     │
│   concurrent connections?                                │
│   └──► NLB (Layer 4)                                     │
│                                                          │
│   Need to inspect all traffic with firewalls/IDS/IPS?    │
│   └──► GLB (Layer 3)                                     │
│                                                          │
│   Need static IP + content-based routing?                │
│   └──► NLB → ALB (chained)                               │
└──────────────────────────────────────────────────────────┘
```
