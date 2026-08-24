# AWS KMS Cross-Account Key Sharing — CloudOps Reference Guide

> **AWS Skill Builder Summary:**
> Concise reference covering how to securely share KMS keys across AWS accounts — dual security boundaries, three cross-account scenarios (direct access, service-mediated, grant-based), policy configuration examples, troubleshooting, and security best practices.

---

## 1. Why Cross-Account KMS Sharing?

Instead of creating duplicate keys in every account, share a single customer managed key from a central account:

| Benefit | Detail |
| :--- | :--- |
| **Centralised key management** | Keys live in one security account |
| **Simplified rotation** | Rotate once, all accounts benefit immediately |
| **Least privilege** | Grant specific permissions to specific accounts |
| **Audit trail** | CloudTrail tracks key usage across all accounts |
| **Cost efficiency** | One key instead of duplicates per account |
| **Data segregation** | Sensitive data stays in dedicated accounts |

> **Important:** Only **customer managed keys** support cross-account sharing. AWS managed keys and AWS owned keys cannot be shared.

---

## 2. The Dual Security Boundary

Cross-account access requires **both sides** to explicitly permit it — neither account can unilaterally grant access:

```
┌──────────────────────────────────────────────────────────┐
│           Dual Security Boundary Model                    │
│                                                          │
│   KEY OWNER ACCOUNT (111122223333)                       │
│   ┌──────────────────────────────────┐                   │
│   │ KMS Key Policy must grant        │                   │
│   │ access to requesting account     │ ◄── Boundary 1   │
│   └──────────────────────────────────┘                   │
│                                                          │
│              BOTH must allow access                      │
│                                                          │
│   REQUESTING ACCOUNT (444455556666)                      │
│   ┌──────────────────────────────────┐                   │
│   │ IAM Policy must grant the        │                   │
│   │ principal access to the          │ ◄── Boundary 2   │
│   │ external KMS key                 │                   │
│   └──────────────────────────────────┘                   │
│                                                          │
│   If either side denies → access denied.                 │
└──────────────────────────────────────────────────────────┘
```

### Three Elements to Identify

| Element | Description |
| :--- | :--- |
| **Key owner account** | The AWS account that owns and manages the KMS key |
| **Encrypted resource** | The AWS resource or data being encrypted (S3 objects, EBS volumes, etc.) |
| **Requesting principal** | The IAM user, role, or service in the requesting account that needs crypto operations |

---

## 3. Three Cross-Account Scenarios

### Scenario 1: Direct KMS API Access

**What:** The requesting account's principals call KMS APIs directly using the key owner's key.

```
┌──────────────────────────────────────────────────────────┐
│   Requesting Account          Key Owner Account          │
│                                                          │
│   ┌──────────┐               ┌──────────┐               │
│   │ IAM Role │ ──── KMS API ──►│ KMS Key  │              │
│   │ (analyst)│   (Decrypt,   │          │               │
│   └──────────┘   GenDataKey) └──────────┘               │
│                                                          │
│   CloudTrail: requesting account's principal as requestor│
└──────────────────────────────────────────────────────────┘
```

**Use case:** Data analytics role processing sensitive data across multiple accounts.

**Configuration — Key Owner Account** (key policy):

```json
{
  "Sid": "AllowExternalAccountAccess",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::444455556666:root"
  },
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey",
    "kms:GenerateDataKey*"
  ],
  "Resource": "*"
}
```

**Configuration — Requesting Account** (IAM policy attached to role):

```json
{
  "Sid": "UseExternalKMSKey",
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey",
    "kms:GenerateDataKey*"
  ],
  "Resource": "arn:aws:kms:us-west-2:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
}
```

> **Key point:** Granting access to `arn:aws:iam::444455556666:root` doesn't give root direct access — it allows the requesting account's admins to **delegate** these permissions to their own IAM principals.

---

### Scenario 2: Service-Mediated Access (Encrypted Resources in Owner Account)

**What:** Both the KMS key and encrypted resources (S3 bucket, EBS volume) live in the key owner account. The requesting account accesses resources through AWS services — **never calls KMS directly**. The AWS service makes KMS calls on behalf of the requesting principal.

```
┌──────────────────────────────────────────────────────────┐
│   Requesting Account          Key Owner Account          │
│                                                          │
│   ┌──────────┐               ┌──────────┐               │
│   │ IAM Role │ ── S3 API ──► │ S3 Bucket│               │
│   └──────────┘               │(encrypted)│              │
│                              └─────┬─────┘               │
│                                    │ S3 calls KMS        │
│                                    ▼                     │
│                              ┌──────────┐               │
│                              │ KMS Key  │               │
│                              └──────────┘               │
│                                                          │
│   CloudTrail: AWS service as requestor                   │
│   Requires: resource policy + KMS key policy             │
└──────────────────────────────────────────────────────────┘
```

**Use case:** Team in account B needs to read/write encrypted objects in account A's S3 bucket.

**Requires permissions at three levels:**
1. **KMS key policy** (owner account) — allows the requesting role to use the encryption key
2. **Resource policy** (owner account) — allows the requesting role access to the S3 bucket
3. **IAM policy** (requesting account) — grants the role access to the external S3 bucket (no KMS permissions needed — S3 calls KMS on your behalf)

**Step 1 — Key Owner: KMS Key Policy**

```json
{
  "Sid": "AllowExternalAccountAccessToEncryptedResources",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::444455556666:role/S3AccessRole"
  },
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:GenerateDataKey*",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

**Step 2 — Key Owner: S3 Bucket Policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::444455556666:role/S3AccessRole"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::example-bucket",
        "arn:aws:s3:::example-bucket/*"
      ]
    }
  ]
}
```

**Step 3 — Requesting Account: IAM Policy** (attach to `S3AccessRole`)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AccessEncryptedResourcesInExternalAccount",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::example-bucket",
        "arn:aws:s3:::example-bucket/*"
      ]
    }
  ]
}
```

> **Key insight:** The requesting account's IAM policy does NOT include any `kms:*` permissions. S3 makes KMS calls on behalf of the requesting principal — the key policy already grants those permissions to the principal's ARN.

---

### Scenario 3: Grant-Based Access (Service-Linked Roles)

**What:** Services like Auto Scaling use **service-linked roles (SLRs)** with fixed, immutable permissions. You can't modify SLR IAM policies, so you use **KMS grants** to delegate temporary access to the key.

```
┌──────────────────────────────────────────────────────────┐
│   Requesting Account          Key Owner Account          │
│                                                          │
│   ┌──────────────────┐       ┌──────────┐               │
│   │ Auto Scaling SLR │ ◄─────│ KMS Grant│               │
│   │ (cannot modify   │       │ (temporary│              │
│   │  permissions)    │       │  decrypt  │              │
│   └────────┬─────────┘       │  access)  │              │
│            │                 └─────┬─────┘               │
│            │ launches EC2         │                      │
│            ▼                      ▼                      │
│   ┌──────────────┐         ┌──────────┐                  │
│   │ EC2 Instance │         │ KMS Key  │                  │
│   │ (encrypted   │         └──────────┘                  │
│   │  AMI)        │                                       │
│   └──────────────┘                                       │
│                                                          │
│   Grant can be retired when no longer needed.            │
└──────────────────────────────────────────────────────────┘
```

**Use case:** Sharing encrypted AMIs for Auto Scaling groups across accounts.

**Why grants are needed here:**
- SLR permissions are predefined by AWS — you **cannot** add cross-account KMS permissions to them
- Grants provide temporary, fine-grained, auditable delegation
- Grants can be automatically retired when no longer needed

**Step 1 — Key Owner: KMS Key Policy** (two statements)

```json
{
  "Sid": "Allow use of the key by requesting account's SLR",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::444455556666:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  },
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey"
  ],
  "Resource": "*"
},
{
  "Sid": "Allow grant creation by requesting account",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::444455556666:role/GrantCreator"
  },
  "Action": [
    "kms:CreateGrant",
    "kms:ListGrants",
    "kms:RevokeGrant"
  ],
  "Resource": "*"
}
```

**Step 2 — Requesting Account: IAM Policy** (attach to `GrantCreator` role)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ],
      "Resource": "arn:aws:kms:us-west-2:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    }
  ]
}
```

**Step 3 — Create the Grant** (run as `GrantCreator`)

```bash
aws kms create-grant \
    --key-id arn:aws:kms:us-west-2:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab \
    --grantee-principal arn:aws:iam::444455556666:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling \
    --operations Decrypt Encrypt GenerateDataKey GenerateDataKeyWithoutPlaintext \
                 ReEncryptFrom ReEncryptTo CreateGrant DescribeKey
```

> **What this grant does:** Gives the Auto Scaling SLR in the requesting account permission to use the owner account's KMS key for all cryptographic operations needed to launch EC2 instances from encrypted AMIs.

---

## 4. Scenario Comparison

| Feature | Scenario 1: Direct API | Scenario 2: Service-Mediated | Scenario 3: Grant-Based |
| :--- | :--- | :--- | :--- |
| **Who calls KMS?** | Requesting principal directly | AWS service on behalf of principal | SLR via grant |
| **Key + resource location** | Key in owner; resource anywhere | Both in owner account | Both in owner account |
| **Permission mechanism** | Key policy + IAM policy | Resource policy + key policy | Key policy + grant |
| **Can modify requester perms?** | Yes (IAM policy) | Yes (IAM policy) | No (SLR is immutable) |
| **CloudTrail identity** | Requesting principal | AWS service | SLR |
| **Temporary access?** | No (until policies changed) | No (until policies changed) | Yes (grants can expire/retire) |
| **Example services** | Custom apps, analytics | S3, SNS | EC2 Auto Scaling, encrypted AMIs |

---

## 5. Troubleshooting

When cross-account encryption fails, check these in order:

| Check | What to Verify |
| :--- | :--- |
| **1. Key policy** | Does the KMS key policy explicitly allow the requesting account/principal? |
| **2. Resource policy** | Does the resource policy (S3 bucket, SNS topic) allow cross-account access? |
| **3. IAM permissions** | Does the requesting principal have IAM permissions for BOTH the KMS key AND the resource? |
| **4. Grant constraints** | If using grants with constraints (encryption context, operation type), does the request satisfy ALL conditions? |
| **5. Encryption context** | If encryption context was used during encryption, is the same context provided during decryption? |
| **6. Region** | Key policies are Regional — is the principal targeting the key in the correct Region? |

> **Remember:** Both accounts must explicitly allow access. Key owner permits key usage AND resource owner permits resource access. Missing either side = access denied.

### Service-Specific Gotchas

| Service | Authentication Model | Cross-Account Pattern |
| :--- | :--- | :--- |
| **S3, SNS** | Passes through caller's identity to KMS | Direct cross-account (resource policy + key policy) |
| **EC2 Auto Scaling** | Uses SLR with predefined permissions | Grant-based (SLR permissions are immutable) |
| **Other services** | Varies — check service documentation | Check how the service presents identities to KMS |

---

## 6. Security Best Practices

| Practice | Detail |
| :--- | :--- |
| **Enforce dual boundaries** | Both resource policies AND key policies must explicitly permit access — two independent checkpoints |
| **Least privilege** | Grant only required operations (e.g., Decrypt only, not full key access) with time-bound conditions |
| **Use grants for SLRs** | Service-linked roles require grants — don't try to modify SLR permissions |
| **Use IAM Access Analyzer** | Validate that key policies grant precisely the intended access — no more |
| **Monitor with CloudTrail** | Filter on `userIdentity.accountId` ≠ key owner to track cross-account usage |
| **Set CloudWatch alarms** | Alert on unusual cross-account key usage patterns |
| **Retire grants proactively** | Don't leave stale grants — implement lifecycle management |
| **Rotate keys regularly** | Cross-account consumers automatically benefit from rotation |

---

## 7. Quick-Reference Checklist

- [ ] **Verify both boundaries** — key policy (owner side) AND IAM policy (requestor side) must both allow access.
- [ ] **Use only customer managed keys** — AWS managed and AWS owned keys do not support cross-account sharing.
- [ ] **Specify exact operations** — don't grant `kms:*`; list only the actions needed (Decrypt, GenerateDataKey, etc.).
- [ ] **Use full key ARN** — requesting account must reference the complete ARN including Region and account ID.
- [ ] **Use grants for immutable roles** — SLRs (Auto Scaling, etc.) can't have IAM policies modified; use grants instead.
- [ ] **Monitor cross-account usage** — CloudTrail events where `accountId` differs from key owner = cross-account access.
- [ ] **Test with IAM Access Analyzer** — confirm key policy scope before going to production.
- [ ] **Check encryption context** — if used during encryption, the same context must be provided during decryption.
