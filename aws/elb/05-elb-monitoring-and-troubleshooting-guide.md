# ELB Monitoring & Troubleshooting — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Comprehensive reference for monitoring Elastic Load Balancing (ELB) resources. Covers access logs, key CloudWatch metrics broken down by ALB/NLB/GLB, and a troubleshooting guide for the 6 most common load balancer issues.

---

## 1. Core Monitoring Concepts

- **Data points:** Building blocks of metrics.
- **Metrics:** Data points grouped by resource type, dimension, and namespace.
- **Statistics:** Aggregated views of metrics over specified time ranges.
- **Logs:** Textual records that provide the "why" behind the "what" shown in metrics.

### ELB Access Logs
Access logs capture detailed information about each request (client IP, response time, request paths). 
- **Target use cases:** Examine traffic patterns, find error sources, and study client activity for capacity planning.
- **How to use:** Enable in the EC2 console attributes. Logs are delivered to an **Amazon S3 bucket**.
- **Analysis:** Best queried using **Amazon Athena** or **Amazon OpenSearch Service**.

---

## 2. Key CloudWatch Metrics by ELB Type

### Application Load Balancer (ALB) Metrics
Provides a comprehensive view of health, performance, and capacity at Layer 7.

| Metric | What It Measures | CloudOps Action |
| :--- | :--- | :--- |
| **`RequestCount`** | Total requests completed or connections made. | Track volume to spot trends/spikes. Monitor by AZ to check traffic distribution. |
| **`TargetResponseTime`** | Time between a request leaving the LB and receiving a target response. | Set performance thresholds (average and percentile). Compare across zones to spot bottlenecks. |
| **`HTTPCode_ELB_4XX/5XX`** | 4XX (client errors) and 5XX (server/target errors). | Create alerts for sudden spikes. Calculate error rates as request percentages. |
| **`Healthy/UnHealthyHostCount`** | Number of targets passing/failing health checks. | Set alerts when healthy hosts fall below required capacity. |

### Network Load Balancer (NLB) Metrics
Provides proactive monitoring of Layer 4 network infrastructure.

| Metric | What It Measures | CloudOps Action |
| :--- | :--- | :--- |
| **`ActiveFlowCount`** | Total concurrent flows (connections) from clients to targets. | Detect connection anomalies, DDoS attacks, and scaling needs. |
| **`ProcessedBytes`** | Total bytes processed (throughput). | Monitor for bandwidth utilization and potential data transfer costs. |
| **`Client/TargetResetCount`** | Number of TCP reset (RST) packets sent from clients or targets. | Alarms here signal application issues, network problems, or misconfigured security groups. |

### Gateway Load Balancer (GLB) Metrics
Monitors health, traffic flow, and security appliance performance.

| Metric | What It Measures | CloudOps Action |
| :--- | :--- | :--- |
| **`ActiveFlowCount`** | Concurrent flows from clients to targets. | Determine when to scale security appliances. |
| **`ConsumedLCUs`** | Load Balancer Capacity Units consumed. | Set budget alerts for unexpected cost increases. |
| **`NewFlowCount`** | New flows established during a specified time. | Compare with historical data to identify unusual traffic behavior. |
| **`ProcessedBytes`** | Total bytes processed. | Track throughput requirements and capacity planning. |

---

## 3. Troubleshooting Guide

When ELB issues occur, verify these common failure points systematically.

### Problem 1: Instances are marked healthy, but traffic is not routed to them
- **Check 1:** Verify the application actually responds correctly to the health check request.
- **Check 2:** Confirm the health check path and port are correctly configured.
- **Check 3:** Ensure security groups permit traffic on the health check port.
- **Check 4:** Verify the target returns the HTTP response code the LB expects (e.g., 200 OK).

### Problem 2: Clients cannot connect or requests time out
- **Check 1:** Is the load balancer scheme set to **internet-facing**? (Internal LBs cannot be reached publicly).
- **Check 2:** Is the listener configured on the correct port?
- **Check 3:** Verify **inbound Security Group rules** on the LB and the target instances.
- **Check 4:** Verify **Network ACLs (NACLs)** allow traffic (both inbound and outbound ephemeral ports).
- **Check 5:** If the application is slow, you may need to increase the configured **idle timeout**.

### Problem 3: Traffic is not routed evenly/correctly
- **Check 1:** Are the target instances actually registered with the target group?
- **Check 2:** Is **Cross-zone load balancing** enabled? (If disabled, traffic is split evenly across AZs regardless of instance count).

### Problem 4: Load Balancer returns 4XX or 5XX errors
- **400 Bad Request:** Malformed request from the client (e.g., spaces in the URL).
- **504 Gateway Timeout:** The target application took too long to respond. Increase the idle timeout or scale capacity.
- **5XX Errors:** Check target server logs directly. Bypass the LB to test instances directly to isolate the issue.

### Problem 5: Traffic blocked by Security Groups / NACLs
- **Check 1:** Double-check inbound rules on the ELB security group.
- **Check 2:** Ensure instance security groups explicitly allow traffic *from the ELB's security group*.
- **Check 3:** Ensure NACLs permit required traffic (remember NACLs are stateless and require outbound ephemeral port rules).

### Problem 6: HTTPS requests return certificate errors
- **Check 1:** Verify the domain name in the URL matches the certificate's alternate name (SAN).
- **Check 2:** Verify the correct ACM certificate is associated with the HTTPS listener on the load balancer.
