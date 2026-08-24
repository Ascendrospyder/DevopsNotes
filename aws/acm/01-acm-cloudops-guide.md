# AWS Certificate Manager (ACM) — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering SSL/TLS certificate management with ACM — certificate types, validation methods, lifecycle phases, auto-renewal, CloudFront/ALB integration, monitoring with EventBridge and CloudWatch, CLI operations, and troubleshooting common failures.

---

## 1. Why ACM?

Certificate expiration is one of the most common causes of **preventable production outages**. ACM automates the entire certificate lifecycle so you don't have to manually track, renew, and deploy certificates.

| Traditional Approach | ACM Solution |
| :--- | :--- |
| Manually monitor expiration dates | Automated warnings + auto-renewal |
| Coordinate renewal across teams | Full visibility into status and lifecycle |
| Maintain audit records manually | Searchable CloudTrail records for compliance |
| Limited security visibility | Track who requests, modifies, or deletes certs |

**Key facts:**
- Public certificates from ACM are **free** when used with supported AWS services
- Private keys **never leave AWS** (unless you explicitly export)
- Certificates are replicated across **multiple AZs** within a Region
- ACM certificates are **Regional resources** (critical for deployment planning)

---

## 2. Certificate Types

### Public vs Private

| Feature | Public Certificates | Private Certificates |
| :--- | :--- | :--- |
| **Purpose** | Public-facing websites and APIs | Internal systems, microservices |
| **Issued by** | Amazon Trust Services (publicly trusted CA) | AWS Private CA (you control) |
| **Browser trust** | Automatically trusted by all browsers | Must configure trust on each client |
| **Use cases** | Customer-facing apps, public APIs, CDN | Microservice auth, internal APIs, DevOps tooling |

### How Certificates Secure Data (4 Functions)

```
┌──────────────────────────────────────────────────────────┐
│         How SSL/TLS Certificates Work                    │
│                                                          │
│   1. AUTHENTICATION                                      │
│      Server presents CA-signed certificate               │
│      Browser verifies identity                           │
│                     │                                    │
│   2. KEY EXCHANGE                                        │
│      Browser uses certificate's public key               │
│      to establish shared session key                     │
│                     │                                    │
│   3. ENCRYPTION                                          │
│      Session key encrypts all data in transit            │
│                     │                                    │
│   4. INTEGRITY                                           │
│      MACs detect any tampering during transmission       │
└──────────────────────────────────────────────────────────┘
```

> **Your responsibility:** AWS auto-encrypts infrastructure traffic (between data centres, VPCs, service endpoints). You must encrypt: your applications, third-party integrations, non-HTTPS protocols, and public internet traffic to users.

---

## 3. Certificate Management Options

| Feature | AWS Managed Public | AWS Private CA | Third-Party (Imported) |
| :--- | :--- | :--- | :--- |
| **Source** | Amazon Trust Services | Your Private CA | External CA |
| **Auto-renewal** | Yes | Yes (if associated with AWS service or previously exported) | No — manual renewal required |
| **Cost** | Free with AWS services | Private CA pricing | No import charges |
| **Validity** | 13 months | Configurable | Varies |
| **Export** | Yes (if enabled at creation) | Yes | N/A (already yours) |
| **Browser trust** | Global | Must configure | Depends on CA |

---

## 4. Validation Methods

You must prove domain ownership before ACM issues a certificate:

| Feature | DNS Validation (Recommended) | Email Validation | HTTP Validation |
| :--- | :--- | :--- | :--- |
| **Process** | Add ACM-provided CNAME to DNS | Respond to emails sent to domain admin | Automatic via HTTP requests |
| **Automation** | Fully automated renewals | Manual approval each renewal | Automatic if CloudFront config remains |
| **Requirements** | DNS record access | Email access | CloudFront distribution |
| **Best for** | Production, automated infra | When DNS access is restricted | CloudFront-hosted apps |
| **Limitations** | Requires DNS control | Emails may be filtered as spam | CloudFront only, not directly selectable |
| **Timeout** | Must complete within 72 hours | Must complete within 72 hours | Must complete within 72 hours |

> **Strong recommendation:** Use **DNS validation** for production. It enables fully automated renewals with zero manual intervention.

---

## 5. Certificate Lifecycle

```
┌──────────────────────────────────────────────────────────┐
│              ACM Certificate Lifecycle                    │
│                                                          │
│   1. REQUEST                                             │
│      Specify domain + SANs, key algorithm,               │
│      validation method, tags                             │
│                     │                                    │
│   2. VALIDATE                                            │
│      DNS (CNAME) / Email / HTTP                          │
│      Must complete within 72 hours                       │
│                     │                                    │
│   3. ISSUE                                               │
│      ACM generates cert, stores securely in HSMs         │
│      Logged to Certificate Transparency (CT) logs        │
│                     │                                    │
│   4. DEPLOY                                              │
│      Associate with CloudFront, ALB, API Gateway, etc.   │
│      ACM handles installation on integrated services     │
│                     │                                    │
│   5. RENEW (automatic)                                   │
│      DNS/HTTP: 60 days before expiry (fully automated)   │
│      Email: 45 days before expiry (manual approval)      │
│      Same ARN, new serial number                         │
│                     │                                    │
│   6. EXPIRE / DELETE                                     │
│      Remove service associations before deletion         │
│      CT log entries persist permanently                  │
│      Certificates CANNOT be modified after issuance      │
└──────────────────────────────────────────────────────────┘
```

**Critical details:**
- Certificates are **immutable** after issuance — request a new one to make changes
- Renewal preserves the **same ARN** (important for automation)
- You must **remove all service associations** before deleting a certificate
- CT log entries are **permanent** even after deletion

---

## 6. Regional Deployment Rules

This is a common source of errors:

| Service | Region Requirement |
| :--- | :--- |
| **CloudFront** | Must use certificates from **us-east-1 only** (auto-distributes globally to edge locations) |
| **ALB / ELB** | Separate certificate required **in each Region** where load balancers are deployed |
| **API Gateway** | Certificate must be in the **same Region** as the API |
| **All others** | Certificate must be in the **same Region** as the service |

---

## 7. Example: Securing a Static Website

```
┌──────────────────────────────────────────────────────────┐
│   User → Route 53 → CloudFront → S3 (static site)       │
│                                                          │
│   1. User enters example.com                             │
│   2. Route 53 resolves to CloudFront distribution        │
│   3. Browser ← TLS handshake → CloudFront               │
│      CloudFront presents ACM certificate                 │
│      Browser validates, encrypted session established    │
│   4. CloudFront checks cache                             │
│      ├── Cached → serve over HTTPS                       │
│      └── Not cached → fetch from S3, cache, serve HTTPS  │
│                                                          │
│   ACM certificate must be in us-east-1 for CloudFront   │
└──────────────────────────────────────────────────────────┘
```

**Steps:**
1. Request public certificate in ACM (us-east-1) for `example.com`
2. Validate domain ownership (DNS validation recommended)
3. Create CloudFront distribution with S3 origin
4. Associate ACM certificate with the distribution
5. Update Route 53 DNS to point to CloudFront

---

## 8. Automation for Exported Certificates

ACM auto-renews and auto-deploys to integrated AWS services (CloudFront, ALB, API Gateway). But for **exported certificates** used on EC2, containers, or on-premises, you need automation:

```
┌──────────────────────────────────────────────────────────┐
│   Certificate Renewal Automation Pattern                 │
│                                                          │
│   ACM renews cert (same ARN, new content)                │
│          │                                               │
│          ▼                                               │
│   EventBridge captures renewal event                     │
│          │                                               │
│          ▼                                               │
│   Lambda downloads renewed certificate                   │
│          │                                               │
│          ▼                                               │
│   Systems Manager deploys to EC2 / on-prem               │
│          │                                               │
│          ▼                                               │
│   Application restarts to load new cert                  │
└──────────────────────────────────────────────────────────┘
```

> **Key:** Use the same certificate ARN — ACM maintains the ARN while updating the certificate content.

---

## 9. Monitoring and Logging

### EventBridge Events

| Event | Detail |
| :--- | :--- |
| **Certificate issuance** | ARN + domain names on successful issue |
| **Validation status changes** | Validation method + current status |
| **Renewal start** | 45 days before expiration |
| **Renewal success/failure** | New cert details or failure reason |
| **Expiration warnings** | Sent at **45, 30, and 15 days** before expiry (escalating alerts) |

### CloudWatch Metric

| Metric | Purpose |
| :--- | :--- |
| **`DaysToExpiry`** | Days remaining before certificate expires — works for every cert in your account. Set custom alarm thresholds. Especially valuable for **imported certificates** that require manual renewal. |

### CloudTrail Audit

Records all API activity: who requested/deleted/modified certificates, when, and from where. Essential for compliance and security analysis.

---

## 10. CLI Quick Reference

```bash
# Request a certificate with DNS validation + SANs
aws acm request-certificate \
    --domain-name example.com \
    --validation-method DNS \
    --subject-alternative-names www.example.com api.example.com \
    --tags Key=Environment,Value=Production

# List certificates (filtered by key type and status)
aws acm list-certificates \
    --includes keyTypes=RSA_2048,RSA_1024 \
    --certificate-statuses ISSUED EXPIRED

# Describe a certificate (validation status, domains, expiry)
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:region:account:certificate/cert-id

# Get certificate content in PEM format
aws acm get-certificate \
    --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/cert-id

# Import a third-party certificate
aws acm import-certificate \
    --certificate fileb://Certificate.pem \
    --private-key fileb://PrivateKey.pem \
    --certificate-chain fileb://CertificateChain.pem

# Resend validation email (if original was missed)
aws acm resend-validation-email \
    --certificate-arn arn:aws:acm:region:account:certificate/cert-id \
    --domain example.com \
    --validation-domain example.com
```

---

## 11. Troubleshooting

| Problem | Root Cause | Solution |
| :--- | :--- | :--- |
| **Pending validation for hours / validation fails** | DNS propagation delay, incorrect CNAME, email delivery issues, CAA records blocking | Verify CNAME matches exactly with `dig`/`nslookup`; check CAA DNS records; switch to DNS validation |
| **ALB can't find certificate** | Certificate is in wrong Region (e.g., cert in us-east-1, ALB in eu-west-1) | Request separate certificate in each Region where services run; CloudFront = us-east-1 only |
| **Auto-renewal fails** | DNS validation records removed, domain ownership changed, Route 53 permissions broken | Check CloudTrail for failure reason; verify DNS records still exist; check Route 53 permissions |
| **Third-party import fails** | Wrong format, missing chain, mismatched private key | Ensure PEM format; include complete chain (root + intermediates); validate private key is plaintext; check not expired |
| **Permission denied despite admin access** | Missing ACM-specific IAM permissions or condition key restrictions | Add explicit `acm:RequestCertificate` / `acm:DescribeCertificate`; check condition keys; review CloudTrail |
| **Certificate exists but not visible in ALB/CloudFront** | Wrong Region, not validated yet, missing service permissions | Same Region as service (except CloudFront); verify status is `Issued`; check `acm:GetCertificate` permission |

---

## 12. Quick-Reference Checklist

- [ ] **Use DNS validation for production** — fully automated renewals with zero manual intervention.
- [ ] **CloudFront certs must be in us-east-1** — this is the #1 gotcha for multi-Region deployments.
- [ ] **Request separate certs per Region for ALBs** — certificates cannot be copied between Regions.
- [ ] **Monitor `DaysToExpiry` CloudWatch metric** — set alarms especially for imported certificates that need manual renewal.
- [ ] **Set up EventBridge rules** for renewal failure events — don't wait for the outage.
- [ ] **Don't remove DNS validation records** after certificate issuance — they're needed for auto-renewal.
- [ ] **Tag all certificates** — at minimum: Environment, Application — for audit and cost tracking.
- [ ] **Automate exported cert deployment** — EventBridge → Lambda → Systems Manager for EC2/on-prem.
- [ ] **Certificates are immutable** — request a new one to make changes, don't try to modify.
- [ ] **Remove all service associations** before deleting a certificate — deletion will fail otherwise.
