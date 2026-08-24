# AWS Key Management Service (KMS) — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering AWS KMS key types (symmetric, asymmetric, HMAC), managed key categories (customer, AWS, AWS-owned), key stores, multi-Region keys, key policies, grants, rotation, deletion, and BYOK — with CLI examples.

---

## 1. What Is AWS KMS?

**The simple version:** AWS KMS is a managed service that creates, stores, and controls encryption keys used to protect your data across AWS. Think of it as a **secure vault for digital keys** — you control who can use which keys and for what.

**Under the hood:** Keys are generated and stored in **FIPS 140-3 validated hardware security modules (HSMs)**. Key material never leaves KMS unencrypted.

> **AWS CloudHSM** is the alternative when you need **dedicated** (single-tenant) HSMs for your own encryption keys.

---

## 2. Three Categories of Managed Keys

| Category | Who Manages It | In Your Account? | Auto-Rotation | Key Policy Control | CloudTrail Logging |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Customer managed key** | You | Yes | Optional (90–2,560 days, default 365) | Full control | Yes |
| **AWS managed key** | AWS KMS | Yes | Required (every ~365 days) | Viewable, not editable | Yes |
| **AWS owned key** | AWS service | No | AWS controls | Not viewable | No |

> **Rule of thumb:** Use **customer managed keys** when you need control over rotation, deletion, policies, or compliance evidence. Use **AWS managed keys** when you just want encryption enabled with minimal effort.

---

## 3. Customer Managed Key Types

| Key Type | How It Works | Primary Use | Key Material |
| :--- | :--- | :--- | :--- |
| **Symmetric** | Single key encrypts and decrypts | Most encryption use cases (default) | Never leaves KMS unencrypted |
| **Asymmetric** | Public + private key pair | Sign/verify, encrypt/decrypt, or key agreement | Private key stays in KMS; public key downloadable |
| **HMAC** | Shared secret | Generate and verify message authentication codes (MACs) | Never leaves KMS |

```
┌──────────────────────────────────────────────────────────┐
│              Which Key Type to Use?                       │
│                                                          │
│   Need to encrypt/decrypt data?                          │
│   └──► Symmetric key (default, simplest)                 │
│                                                          │
│   Need to sign/verify or encrypt outside AWS?            │
│   └──► Asymmetric key (public key downloadable)          │
│                                                          │
│   Need to verify data integrity/authenticity?            │
│   └──► HMAC key                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Key Stores

Where the cryptographic key material physically lives:

| Key Store | What It Is | Best For |
| :--- | :--- | :--- |
| **Standard (default)** | AWS-managed HSMs within KMS | Most customers — strong encryption without compliance overhead |
| **Custom key store (CloudHSM)** | Your dedicated CloudHSM cluster | Regulatory requirements needing single-tenant HSMs |
| **External key store** | Keys stored outside AWS entirely | Sovereignty or compliance requiring keys never enter AWS |

**Choosing factors:** Compliance requirements → key residency needs → performance → integration complexity → operational overhead.

---

## 5. Key Lifecycle Operations

### 5.1 Creating Keys

```bash
# Symmetric key (default)
aws kms create-key

# Asymmetric key for signing
aws kms create-key \
    --key-spec ECC_NIST_P256 \
    --key-usage SIGN_VERIFY

# HMAC key (512-bit)
aws kms create-key \
    --key-spec HMAC_512 \
    --key-usage GENERATE_VERIFY_MAC
```

### 5.2 Aliases

Human-readable names for keys — use them instead of key IDs in commands:

```bash
# Create an alias
aws kms create-alias \
    --alias-name alias/my-app-key \
    --target-key-id 1234abcd-12ab-34cd-56ef-1234567890ab

# List aliases for a key
aws kms list-aliases --key-id "1234abcd-12ab-34cd-56ef-1234567890ab"
```

### 5.3 Key Rotation

```bash
# Enable automatic rotation
aws kms enable-key-rotation \
    --key-id 1234abcd-12ab-34cd-56ef-1234567890ab

# Verify rotation status
aws kms get-key-rotation-status \
    --key-id 1234abcd-12ab-34cd-56ef-1234567890ab
```

- Default: rotates every **365 days** (configurable: 90–2,560 days)
- **Previous key material is retained** — existing encrypted data still decryptable
- Enforce rotation via IAM/SCP policy (deny `kms:DisableKeyRotation`)

### 5.4 Disabling and Deleting Keys

```bash
# Disable a key (reversible)
aws kms disable-key --key-id <key-id>

# Re-enable later
aws kms enable-key --key-id <key-id>

# Schedule deletion (irreversible after waiting period)
aws kms schedule-key-deletion \
    --key-id <key-id> \
    --pending-window-in-days 30
```

> **⚠️ Deletion is permanent.** All data encrypted with the key becomes **unrecoverable**. Waiting period: 7–30 days (default 30). Set up a CloudWatch alarm to detect usage of keys pending deletion.

### 5.5 Importing Key Material (BYOK)

Create an empty KMS key and import your own key material. Use when:
- Compliance requires generating keys outside AWS
- You need control over key material lifecycle and durability
- You want to use your existing keys with AWS services

---

## 6. Multi-Region Keys

**What they are:** KMS keys replicated across multiple AWS Regions — same key ID, same key material. Each replica works independently but produces identical cryptographic results.

```
┌──────────────────────────────────────────────────────────┐
│              Multi-Region Key Architecture               │
│                                                          │
│   us-east-1 (Primary)                                    │
│   ┌──────────────────┐                                   │
│   │ mrk-e1522db...   │                                   │
│   │ PRIMARY key      │                                   │
│   └────────┬─────────┘                                   │
│            │ replicate                                   │
│      ┌─────┴──────┐                                      │
│      ▼             ▼                                     │
│   eu-west-1      us-west-2                               │
│   ┌──────────┐   ┌──────────┐                            │
│   │ REPLICA  │   │ REPLICA  │                            │
│   │ Same ID  │   │ Same ID  │                            │
│   │ Same key │   │ Same key │                            │
│   └──────────┘   └──────────┘                            │
│                                                          │
│   All replicas can encrypt/decrypt interchangeably.      │
│   No cross-Region API calls needed.                      │
└──────────────────────────────────────────────────────────┘
```

### 6.1 When to Use Multi-Region Keys

| Use Case | Why |
| :--- | :--- |
| **Disaster recovery** | Decrypt data in backup Region during primary Region outage |
| **Global data management** | Avoid cross-Region API calls and re-encryption costs |
| **Active-active architectures** | Consistent encryption/decryption across Regions |
| **Cross-Regional signing** | Same signing key available in all Regions |

### 6.2 When You DON'T Need Them

- Certificate chaining with a global trust store (use intermediate CAs instead)
- Single-Region applications

### 6.3 CLI Commands

```bash
# Create a multi-Region primary key
aws kms create-key --multi-region

# Replicate to another Region
aws kms replicate-key \
    --key-id mrk-e1522db505b948c8b36e8a720e352650 \
    --replica-region us-east-2

# Verify the replica
aws kms describe-key \
    --key-id mrk-e1522db505b948c8b36e8a720e352650
```

---

## 7. Access Control

KMS uses **three layers** of access control:

```
┌──────────────────────────────────────────────────────────┐
│              KMS Access Control Layers                    │
│                                                          │
│   1. KEY POLICIES (required, resource-based)             │
│      └── Who can manage and use THIS specific key        │
│          Every KMS key must have exactly one.            │
│          Regional scope only.                            │
│                                                          │
│   2. IAM POLICIES (optional, identity-based)             │
│      └── What KMS actions can this user/role perform?    │
│          Global scope.                                   │
│                                                          │
│   3. GRANTS (optional, programmatic)                     │
│      └── Temporary or granular delegated permissions     │
│          Can be revoked or retired.                      │
└──────────────────────────────────────────────────────────┘
```

### 7.1 Key Policies vs Grants

| Feature | Key Policies | Grants |
| :--- | :--- | :--- |
| **Type** | Resource-based permissions | Temporary/granular delegated permissions |
| **Syntax** | Standard IAM policy JSON | Programmatic (API call) |
| **Best for** | Static permission assignments | Temporary access, fine-grained delegation |
| **Revocation** | Update the policy | Call `RevokeGrant` (immediate) or `RetireGrant` |

### 7.2 Key Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::123456789012:root"},
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow developers to view and rotate",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::123456789012:role/developers"},
      "Action": [
        "kms:DescribeKey",
        "kms:GetKeyPolicy",
        "kms:GetKeyRotationStatus",
        "kms:EnableKeyRotation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow key administrators",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::123456789012:role/operator"},
      "Action": [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    }
  ]
}
```

```bash
# View current key policy
aws kms get-key-policy --policy-name default --key-id <key-id> --output text

# Update key policy
aws kms put-key-policy \
    --policy-name default \
    --key-id <key-id> \
    --policy file://new_key_policy.json
```

### 7.3 Grants Example

```bash
# Create a grant (temporary Decrypt access with encryption context constraint)
aws kms create-grant \
    --key-id c741350b-e047-4d1b-b54d-92d200be6c58 \
    --grantee-principal arn:aws:iam::123456789012:role/keyUserRole \
    --operations Decrypt \
    --retiring-principal arn:aws:iam::123456789012:role/adminRole \
    --constraints EncryptionContextSubset={Department=IT}

# List grants on a key
aws kms list-grants --key-id <key-id>
```

---

## 8. Tagging for ABAC and Cost Tracking

```bash
# Tag a key with environment and application
aws kms tag-resource \
    --key-id <key-id> \
    --tags TagKey=Environment,TagValue=prod TagKey=Application,TagValue=database

# Verify tags
aws kms list-resource-tags --key-id <key-id>
```

Tags enable:
- **Attribute-based access control (ABAC)** — IAM policies that match on tag values
- **Cost allocation** — track KMS costs per environment/application
- **Automated policies** — different rotation/deletion rules per environment

---

## 9. Quick-Reference Checklist

- [ ] **Use customer managed keys** when you need control over rotation, policies, or compliance — AWS managed keys for everything else.
- [ ] **Default to symmetric keys** — use asymmetric only when you need signing or encryption outside AWS.
- [ ] **Enable automatic key rotation** — and enforce it via SCP/IAM policy that denies `kms:DisableKeyRotation`.
- [ ] **Never delete keys casually** — deletion is permanent and makes all encrypted data unrecoverable. Use the full 30-day waiting period.
- [ ] **Set up CloudWatch alarms** for usage of keys pending deletion — catch accidental dependency before it's too late.
- [ ] **Use aliases** — human-readable names make key management and policy auditing far easier.
- [ ] **Use multi-Region keys for DR** — ensures encrypted data is accessible during Regional outages.
- [ ] **Separate key admin from key user** — key policies should grant management permissions and usage permissions to different roles.
- [ ] **Use grants for temporary access** — don't modify key policies for short-lived permissions.
- [ ] **Tag all keys** — at minimum: Environment, Application, Owner — for ABAC and cost tracking.
- [ ] **Remember key policies are Regional** — a policy on a key in us-east-1 has no effect on keys in eu-west-1.
