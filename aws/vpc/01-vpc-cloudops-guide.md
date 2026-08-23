# AWS Virtual Private Cloud (VPC) — Beginner to CloudOps Pro Guide

---

## 1. Technical Definition: Amazon Virtual Private Cloud (VPC)

> **Formal Technical Definition:**
> **Amazon Virtual Private Cloud (VPC)** is a logically isolated, software-defined virtual network (SDN) dedicated to an AWS account within an AWS Region. It closely resembles a traditional on-premises enterprise data center network, complete with scalable IPv4 and IPv6 **Classless Inter-Domain Routing (CIDR)** address spaces, public and private subnet topologies mapped to discrete **Availability Zones**, software-defined routing tables, ingress/egress network gateways (**Internet Gateways, NAT Gateways, Egress-Only IGWs**), and multi-layered packet filtering security controls (**Stateful Security Groups** and **Stateless Network Access Control Lists**).

### 1.1 The Conceptual Analogy (For Intuition)

*   **The Gated Corporate Campus**:
    *   **VPC (The Perimeter Fence)**: A private plot of land with an outer security perimeter. Nothing enters or leaves unless you explicitly build an entrance gate.
    *   **Subnets (Building Floors)**:
        *   *Public Subnet (The Front Lobby)*: Open to visitors from the public street (Public Load Balancers).
        *   *Private App Subnet (Private Office Suites)*: Internal employees only (Backend API services). They can order internet packages via the mailroom, but outsiders cannot walk in.
        *   *Isolated DB Subnet (The Underground Cash Vault)*: Deep internal rooms with zero access to the outside world (RDS Databases).
    *   **Internet Gateway (The Main Campus Gate)**: Allows two-way vehicle traffic between the campus and the public highway.
    *   **NAT Gateway (The Outbound Mailroom Courier)**: Allows private employees to request outbound supplies from the internet without exposing their room locations.
    *   **Security Group (The Room Keycard Reader)**: Stateful electronic locks directly on the door of each individual server room.
    *   **NACL (The Driveway Guard Checkpoint)**: A strict, stateless guard checking license plates at the perimeter border of the entire floor.
    *   **VPC Endpoint (The Private Underground Tunnel)**: A direct underground private tunnel straight into the Amazon S3 warehouse without ever driving on the public highway.

```
+---------------------------------------------------------------------------------------------------+
|                                  AWS REGION (e.g., us-east-1)                                     |
|                                                                                                   |
|  +---------------------------------------------------------------------------------------------+  |
|  |                          VPC (CIDR Block: 10.0.0.0/16 - 65,536 IPs)                         |  |
|  |                                                                                             |  |
|  |                       +------------------------------------+                                |  |
|  |                       |   INTERNET GATEWAY (IGW)           | <====== The Public Internet    |  |
|  |                       +-----------------+------------------+                                |  |
|  |                                         |                                                   |  |
|  |        +--------------------------------+--------------------------------+                  |  |
|  |        |                                                                 |                  |  |
|  |        v                                                                 v                  |  |
|  |  +---------------------------------------+     +---------------------------------------+    |  |
|  |  |   AVAILABILITY ZONE A (us-east-1a)    |     |   AVAILABILITY ZONE B (us-east-1b)    |    |  |
|  |  |                                       |     |                                       |    |  |
|  |  |  [ Public Subnet A: 10.0.1.0/24 ]     |     |  [ Public Subnet B: 10.0.2.0/24 ]     |    |  |
|  |  |  - Public Load Balancer (ALB)         |     |  - Public Load Balancer (ALB)         |    |  |
|  |  |  - NAT Gateway A                      |     |  - NAT Gateway B                      |    |  |
|  |  +-------------------+-------------------+     +-------------------+-------------------+    |  |
|  |                      |                                             |                        |  |
|  |                      v (Outbound Internet via NAT A)               v (Outbound via NAT B)   |  |
|  |  +-------------------+-------------------+     +-------------------+-------------------+    |  |
|  |  |  [ Private App Subnet A: 10.0.10.0/24]|     |  [ Private App Subnet B: 10.0.20.0/24]|    |  |
|  |  |  - API Microservices                  |     |  - API Microservices                  |    |  |
|  |  +-------------------+-------------------+     +-------------------+-------------------+    |  |
|  |                      | (Internal DB Traffic)                       |                        |  |
|  |                      v                                             v                        |  |
|  |  +---------------------------------------+     +---------------------------------------+    |  |
|  |  |  [ Isolated DB Subnet A: 10.0.100.0/24]     |  [ Isolated DB Subnet B: 10.0.200.0/24]    |  |
|  |  |  - RDS PostgreSQL Primary             | <==>|  - RDS PostgreSQL Standby (Multi-AZ)  |    |  |
|  |  |  (NO Internet Route, Pure Private)    |     |  (NO Internet Route, Pure Private)    |    |  |
|  |  +---------------------------------------+     +---------------------------------------+    |  |
|  +---------------------------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. CIDR Notation & AWS Reserved IPs

### 2.1 Technical CIDR Mathematics
CIDR notation specifies the number of fixed network routing bits (prefix):

$$\text{Total Addresses} = 2^{(32 - \text{Prefix Length})}$$

| CIDR Prefix | Total IP Count | Usable IPs in AWS | Enterprise CloudOps Scope |
| :--- | :--- | :--- | :--- |
| `10.0.0.0/16` | $2^{16} = 65,536$ | $65,531$ | **Standard VPC Allocation** (Allows ample subnetting room). |
| `10.0.1.0/24` | $2^{8} = 256$ | $251$ | **Standard Subnet Allocation** (For App, Web, or DB tiers). |
| `10.0.1.0/28` | $2^{4} = 16$ | $11$ | Small dedicated subnet (e.g. Bastion / Test sandbox). |

### 2.2 The 5 Reserved IPs in Every Subnet (Technical Breakdown)
In every subnet created in AWS, the following **5 IP addresses are reserved** and cannot be assigned to compute resources:

1.  **`10.0.1.0`**: Network Base Address (Standard TCP/IP network identity).
2.  **`10.0.1.1`**: Reserved by AWS for the **VPC Default Router**.
3.  **`10.0.1.2`**: Reserved by AWS for the **Amazon DNS Server** (`AmazonProvidedDNS` / Base + 2).
4.  **`10.0.1.3`**: Reserved by AWS for future internal networking functionality.
5.  **`10.0.1.255`**: Network Broadcast Address (AWS networking fabric handles broadcast internally).

---

## 3. Subnet Classification & Route Table Architecture

A subnet in AWS is categorized strictly by its attached **Route Table**:

```
  PUBLIC SUBNET ROUTE TABLE:
  +--------------------+-------------------------+
  | Destination        | Target                  |
  +--------------------+-------------------------+
  | 10.0.0.0/16 (Local)| local                   | ===> Local VPC inter-subnet communication
  | 0.0.0.0/0 (Default)| igw-0123456789abcdef0   | ===> Direct 2-way route via Internet Gateway
  +--------------------+-------------------------+

  PRIVATE APP SUBNET ROUTE TABLE:
  +--------------------+-------------------------+
  | Destination        | Target                  |
  +--------------------+-------------------------+
  | 10.0.0.0/16 (Local)| local                   | ===> Local VPC inter-subnet communication
  | 0.0.0.0/0 (Default)| nat-0123456789abcdef0   | ===> Outbound internet only via NAT Gateway
  +--------------------+-------------------------+

  ISOLATED DATABASE SUBNET ROUTE TABLE:
  +--------------------+-------------------------+
  | Destination        | Target                  |
  +--------------------+-------------------------+
  | 10.0.0.0/16 (Local)| local                   | ===> Local VPC inter-subnet communication
  | (No 0.0.0.0/0 Route Exists)                  | ===> Zero Internet Access (Air-gapped security)
  +--------------------+-------------------------+
```

---

## 4. Security Layers: Security Groups vs Network Access Control Lists (NACL)

### 4.1 Technical Definitions

1.  **Security Group (SG)**:
    *   *Technical Definition*: A virtual, stateful firewall applied directly at the Elastic Network Interface (ENI) level of an individual compute resource (EC2, RDS, Lambda). It operates at Layer 4 (Transport Layer).
    *   *Stateful Behavior*: If an inbound packet is allowed, all outbound response traffic is automatically allowed regardless of outbound rules.
2.  **Network Access Control List (NACL)**:
    *   *Technical Definition*: An optional, stateless packet-filtering firewall applied at the subnet boundary. Rules are evaluated in strict numerical order (Rule 100, Rule 200, Default Rule `*`).
    *   *Stateless Behavior*: Inbound and Outbound traffic are completely independent. Outbound responses to permitted inbound connections **must be explicitly permitted** via outbound rules.

### 4.2 Head-to-Head Comparison

| Attribute | Security Group (SG) | Network Access Control List (NACL) |
| :--- | :--- | :--- |
| **Attachment Point** | **Instance Network Interface (ENI)** | **Subnet Boundary** |
| **State Nature** | **Stateful** (Return traffic permitted automatically) | **Stateless** (Return traffic must be explicitly allowed) |
| **Rule Capabilities** | **ALLOW rules only** (Implicit deny all) | **ALLOW and DENY rules** |
| **Rule Processing** | All rules evaluated simultaneously | Evaluated in sequential numerical order (100, 200...) |
| **Ephemeral Ports** | Handled automatically by state tracking | Requires opening **TCP 1024-65535** outbound |

---

## 5. Real-World Incident 1: The $4,000 S3 NAT Gateway Cost Trap

### Technical Root Cause:
*   AWS charges **\$0.045 per GB of data processed** through a NAT Gateway.
*   By default, Amazon S3 endpoints resolve to public AWS IP addresses.
*   Private EC2 application servers pushing 60 TB of daily backups to S3 will route all traffic through the VPC NAT Gateway, generating thousands of dollars in avoidable NAT processing charges.

```
EXPENSIVE ANTI-PATTERN:
[ EC2 Private Subnet ] ===(60 TB / $0.045/GB)===> [ NAT Gateway ] ===> [ Amazon S3 ]

OPTIMAL CLOUDOPS PATTERN (100% FREE):
[ EC2 Private Subnet ] ===(60 TB / $0.00)===> [ S3 VPC Gateway Endpoint ] ===> [ Amazon S3 ]
```

### The CloudOps Fix:
Deploy an **`aws_vpc_endpoint` (Gateway type)** for S3. It modifies subnet route tables to direct S3 prefixes (`com.amazonaws.region.s3`) across AWS's private routing infrastructure with **zero data processing fees**.

---

## 6. Real-World Incident 2: The "Ghost" Connection (The NACL Ephemeral Port Mystery)

### Technical Root Cause:
1.  A web browser establishes an inbound TCP handshake to an EC2 web server on destination Port 80 (HTTP).
2.  The client operating system allocates a source port from the standard **TCP Ephemeral Port range** (`1024 - 65535`) to receive the web server's reply.
3.  The web server transmits response packets back to the client's ephemeral port (e.g. `52143`).
4.  Because the NACL is **stateless**, and only allowed outbound Port 80, the NACL drops all return response packets at the subnet boundary. The browser times out.

```
Client Browser (Port 52143) --------[ Inbound Allowed: Port 80 ]--------> Web Server (Port 80)
                                                                             |
Client Browser (Port 52143) <---X--[ Outbound DROPPED! ]---------------------+
                                    (NACL lacks Outbound Ephemeral 1024-65535 rule)
```

### The CloudOps Solution:
Whenever you implement custom NACLs, you **must explicitly add an outbound rule allowing TCP 1024-65535 to `0.0.0.0/0`**.

---

## 7. Hands-On CloudOps Linux Networking Runbook

```bash
# 1. Test Layer 4 TCP port connectivity (Fastest check for Security Group / NACL blocks)
nc -zv 10.0.100.50 5432
# If it connects: Security Group & NACL rules are valid!
# If it hangs/times out: Traffic is blocked by SG or NACL.

# 2. Verify DNS resolution against the Amazon DNS Server (10.0.0.2)
dig database.internal.production.local +short
# (Or using nslookup): nslookup amazon.com

# 3. Test HTTP/HTTPS reachability with connection timing headers
curl -Iv https://api.example.com

# 4. Inspect the local Linux OS routing table
ip route show

# 5. Identify local processes and listening TCP/UDP sockets
sudo ss -tulpn
```

---

## 8. Beginner Summary Checklist for AWS VPC

- [x] **Deploy Multi-AZ architecture** across at least 2 Availability Zones.
- [x] **Enforce 3-Tier isolation**: Public, Private App, and Isolated Database tiers.
- [x] **Deploy a FREE S3 VPC Gateway Endpoint** to eliminate NAT processing costs.
- [x] **Set `enable_dns_hostnames = true`** on the VPC to avoid RDS hostname resolution errors.
- [x] **Chain Security Groups** together rather than hardcoding internal IP subnets.
