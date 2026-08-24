# Network Load Balancer (NLB) — Deep Dive

> **AWS Skill Builder Summary:**
> Detailed look at the Network Load Balancer (NLB), operating at Layer 4 to handle millions of requests with ultra-low latency. Covers compliance use cases (healthcare, finance) and key deployment considerations.

---

## 1. Why Network Load Balancers?

NLBs operate at the **transport layer (Layer 4)** of the OSI model. They are designed to handle **millions of requests per second** while maintaining **ultra-low latencies**. Unlike ALBs which look at the HTTP content, NLBs route traffic based on IP protocol data (TCP/UDP).

### Key NLB Use Cases

| Industry / Use Case | How NLB Helps |
| :--- | :--- |
| **Healthcare Organizations** | Directs traffic through secure, HIPAA-compliant encryption channels while balancing large workloads (e.g., multiple departments uploading medical images simultaneously). Health checks quickly route traffic away from failing nodes. |
| **Financial Institutions** | Distributes payment processing workloads securely. Implements SSL/TLS encryption for PCI DSS compliance. Easily handles massive transaction spikes (like tax season) without performance degradation. |

---

## 2. Key Deployment Considerations

When deploying Network Load Balancers, CloudOps engineers must account for several specific rules and prerequisites:

| Consideration | Requirement / Best Practice |
| :--- | :--- |
| **Prerequisites** | EC2 instances are required in multiple Availability Zones. Targets must have properly configured security groups that permit **TCP access** on the listener port. |
| **Security Groups** | Security groups **must be associated during creation**. According to the training material, they cannot be added later (though AWS has recently evolved NLB security group capabilities, stick to this rule for architectural planning). |
| **IP Addressing** | By default, AWS assigns IPv4 addresses from the subnet automatically. However, you can assign **Elastic IP addresses** to the NLB to provide static IPs for your clients (a major advantage over ALB). |
| **Billing** | You are charged for each partial or full hour that the load balancer runs, along with Network Load Balancer Capacity Units (NLCUs) based on bandwidth and connection counts. |

---

## 3. ALB vs NLB Summary Reminder

- Use **ALB** for intelligent, content-based HTTP/HTTPS routing.
- Use **NLB** when you need **ultra-low latency**, **static IP addresses**, or are routing non-HTTP traffic (TCP/UDP) securely.
