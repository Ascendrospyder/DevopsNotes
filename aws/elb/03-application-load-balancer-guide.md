# Application Load Balancer (ALB) — Deep Dive

> **AWS Skill Builder Summary:**
> Detailed look at the Application Load Balancer (ALB), its primary use cases across different industries, traffic flow mechanisms, and key deployment considerations.

---

## 1. Why Application Load Balancers?

ALBs operate at the **application layer (Layer 7)** of the OSI model. Because they understand HTTP and HTTPS traffic, they can intelligently route requests based on the *content* of the request (URL path, hostname, headers), making them essential for modern application architectures.

### Key ALB Use Cases

| Use Case | How ALB Helps |
| :--- | :--- |
| **Ecommerce Platforms** | Handles traffic spikes (Black Friday, flash sales) by distributing requests across multiple servers, ensuring consistent performance during surges. |
| **Media & Streaming** | Manages millions of concurrent connections for global events. Cross-zone balancing provides consistent performance across geographic locations. |
| **SaaS Providers** | Routes traffic to isolate client data securely while serving thousands of users efficiently, maintaining steady performance even during intensive operations. |
| **Microservices Architecture** | Native support for containerized workloads (ECS, EKS). Routes traffic to specific microservices based on request paths (e.g., `/api/users` vs `/api/billing`). |
| **Blue/Green Deployments** | Enables near-zero downtime releases by gradually and safely shifting traffic between different versions of an application. |

---

## 2. ALB Traffic Flow

How a request travels from a user to a target:

```
┌──────────────────────────────────────────────────────────┐
│              ALB Traffic Flow                             │
│                                                          │
│   1. DNS RESOLUTION                                      │
│      Client resolves the ALB's DNS name to IP addresses  │
│                     │                                    │
│   2. LISTENER EVALUATION                                 │
│      ALB receives request on configured protocol/port    │
│                     │                                    │
│   3. RULE EVALUATION                                     │
│      ALB evaluates listener rules in priority order      │
│      (e.g., "if path is /api/* then...")                 │
│                     │                                    │
│   4. TARGET SELECTION                                    │
│      ALB selects a target from the matched Target Group  │
│      using the configured routing algorithm              │
│                     │                                    │
│   5. HEALTH VERIFICATION                                 │
│      Traffic is ONLY sent if the selected target         │
│      is currently passing its health checks              │
└──────────────────────────────────────────────────────────┘
```

---

## 3. Key Deployment Considerations

When architecting solutions with ALBs, CloudOps engineers must account for the following requirements:

| Consideration | Requirement / Best Practice |
| :--- | :--- |
| **High Availability (Multi-AZ)** | ALBs **require at least two Availability Zones** (AZs) when provisioned. You cannot deploy an ALB in a single AZ. |
| **Prerequisites** | Web servers must be installed on the targets, and EC2 instances must be running across multiple AZs. |
| **Security Groups** | The ALB's security group must allow inbound traffic from clients. The **target's security group** must explicitly allow inbound traffic *from the ALB's security group* on the listener and health check ports. |
| **Health Checks** | ALBs continually monitor targets. If a target fails its health check, the ALB stops routing traffic to it until it recovers. Ensure the health check path (e.g., `/health`) is lightweight and returns an HTTP 200. |
| **Billing** | You are charged for every partial or full hour the load balancer is running, plus Load Balancer Capacity Units (LCUs) based on new connections, active connections, and processed bytes. |
