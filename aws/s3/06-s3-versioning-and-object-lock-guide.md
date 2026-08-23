# Amazon S3 Versioning, Delete Markers & Object Lock

> **AWS Skill Builder Summary:**
> Concise CloudOps reference covering S3 Versioning (how versions and delete markers work), restoring deleted objects, and S3 Object Lock (WORM storage with retention modes and legal holds).

---

## 1. S3 Versioning

**What it does:** Keeps every version of every object in a bucket. When you overwrite or delete an object, S3 preserves the previous versions instead of destroying them.

**Default state:** Versioning is **disabled** on all new buckets. You must explicitly enable it.

### 1.1 Versioning States

| State | Behaviour |
| :--- | :--- |
| **Unversioned** (default) | Objects have a version ID of `null`. Overwrites and deletes are permanent. |
| **Enabled** | Every PUT/POST/COPY adds a new version with a **unique version ID**. Deletes create a delete marker instead of removing the object. |
| **Suspended** | Stops generating new version IDs for future uploads (uses `null`), but existing versions are preserved. |

```bash
# Enable versioning on a bucket
aws s3api put-bucket-versioning \
    --bucket amzn-s3-demo-bucket1 \
    --versioning-configuration Status=Enabled
```

### 1.2 How It Works

```
┌──────────────────────────────────────────────────────────┐
│                    S3 Versioning Flow                     │
│                                                          │
│   1. UPLOAD photo.gif                                    │
│      → Version ID: 111111 (current)                      │
│                                                          │
│   2. UPLOAD photo.gif again (overwrite)                  │
│      → Version ID: 222222 (current)                      │
│      → Version ID: 111111 (noncurrent, still exists)     │
│                                                          │
│   3. DELETE photo.gif (no version ID specified)          │
│      → Delete marker added (current)                     │
│      → Version 222222 (noncurrent, still exists)         │
│      → Version 111111 (noncurrent, still exists)         │
│                                                          │
│   4. GET photo.gif → 404 Not Found                       │
│      (delete marker makes it look deleted)               │
│                                                          │
│   5. GET photo.gif?versionId=222222 → Returns the file!  │
│      (previous versions are always accessible)           │
└──────────────────────────────────────────────────────────┘
```

### 1.3 Key Rules

- **Pre-existing objects** keep version ID `null` after enabling versioning — only future uploads get unique IDs.
- **GET without version ID** always returns the current version.
- **GET with version ID** returns that specific version (even if it's not current).
- A **simple DELETE** (no version ID) never permanently removes data in a versioned bucket — it just adds a delete marker.
- **DELETE with version ID** permanently removes that specific version.

```bash
# Retrieve a specific version
aws s3api get-object \
    --bucket BucketName \
    --key photo.GIF \
    --version-id 11111 ./photo.GIF

# Without --version-id, returns the current version
```

---

## 2. Delete Markers

**What they are:** Placeholder objects that S3 creates when you delete an object in a versioned bucket. They make the object **appear** deleted without actually removing any data.

### 2.1 Delete Marker Properties

| Property | Detail |
| :--- | :--- |
| **Has data?** | No — zero bytes of object data |
| **Has ACLs?** | No |
| **Has a version ID?** | Yes — unique version ID like any other version |
| **Storage cost** | Minimal — only the key name size (1–4 bytes per character, stored in S3 Standard) |
| **Who creates them?** | Only S3 — created automatically on DELETE requests without a version ID |

### 2.2 API Responses with Delete Markers

| Request | Response |
| :--- | :--- |
| `GET object` (current version is delete marker) | **404 Not Found** + header `x-amz-delete-marker: true` |
| `GET object?versionId=<delete-marker-id>` | **405 Method Not Allowed** + header `x-amz-delete-marker: true` |

### 2.3 Restoring a "Deleted" Object

To undelete an object, **permanently delete the delete marker** by specifying its version ID:

```
┌──────────────────────────────────────────────────────────┐
│            Restoring a Deleted Object                     │
│                                                          │
│   Before:                                                │
│   [Delete Marker] (current) ← GET returns 404            │
│   [Version 222222] (noncurrent)                          │
│   [Version 111111] (noncurrent)                          │
│                                                          │
│   Action: DELETE the delete marker by its version ID     │
│                                                          │
│   After:                                                 │
│   [Version 222222] (current) ← GET now returns this!     │
│   [Version 111111] (noncurrent)                          │
└──────────────────────────────────────────────────────────┘
```

```bash
# Permanently remove a delete marker (restores the object)
aws s3api delete-object \
    --bucket my-bucket \
    --key my-file.txt \
    --version-id <delete-marker-version-id>
```

> **Warning:** If you DELETE without specifying a version ID when the current version is already a delete marker, S3 **adds another delete marker** on top — it doesn't remove the existing one.

### 2.4 Permanently Deleting Versioned Objects

```bash
# Permanently delete a specific version (irreversible)
aws s3api delete-object \
    --bucket my-bucket \
    --key my-file.txt \
    --version-id <version-id>
```

### 2.5 Versioning + Lifecycle Interactions

| Lifecycle Action | What Happens in a Versioned Bucket |
| :--- | :--- |
| **Expiration** (current version) | Doesn't delete — adds a delete marker; current version becomes noncurrent |
| **NoncurrentVersionExpiration** | **Permanently deletes** noncurrent versions (irreversible) |

> **Tip:** Use **S3 Storage Lens** to see how many current and noncurrent versions exist across your buckets — helps identify version sprawl.

---

## 3. S3 Object Lock (WORM)

**What it does:** Prevents objects from being deleted or overwritten for a fixed period or indefinitely. Uses a **write-once-read-many (WORM)** model.

**Prerequisite:** Object Lock only works on buckets with **versioning enabled**. It locks **individual object versions**, not the entire object key.

### 3.1 Two Protection Mechanisms

```
┌──────────────────────────────────────────────────────────┐
│              S3 Object Lock Options                       │
│                                                          │
│   ┌─────────────────────┐    ┌─────────────────────┐     │
│   │  Retention Period   │    │  Legal Hold          │     │
│   │                     │    │                      │     │
│   │  Fixed duration     │    │  No expiration date  │     │
│   │  (days or years)    │    │  ON until explicitly  │     │
│   │                     │    │  removed (OFF)       │     │
│   │  Auto-expires at    │    │                      │     │
│   │  Retain Until Date  │    │  Independent from    │     │
│   │                     │    │  retention periods   │     │
│   └─────────────────────┘    └─────────────────────┘     │
│                                                          │
│   An object version can have BOTH at the same time.      │
│   New versions can still be created on top of locked     │
│   versions. Delete markers can still be added.           │
└──────────────────────────────────────────────────────────┘
```

### 3.2 Retention Modes

| Mode | Who Can Delete/Overwrite? | Override Possible? | Best For |
| :--- | :--- | :--- | :--- |
| **Governance** | Most users blocked; users with special permissions **can** override | Yes — requires `s3:BypassGovernanceRetention` permission + `x-amz-bypass-governance-retention:true` header | Testing retention settings, internal compliance where flexibility is needed |
| **Compliance** | **Nobody** — not even the root account | No — cannot be shortened or removed once set | Regulatory requirements (SEC, HIPAA, FDA) where immutability is legally mandated |

> **Key difference:** Governance mode is a safety net (admins can override). Compliance mode is a vault door (nobody can override, not even AWS support).

### 3.3 Retention Period Rules

- Set on **individual versions** or as a **bucket default** (auto-applies to all new objects).
- Bucket default specifies a **duration** (days or years); S3 calculates the Retain Until Date from the upload timestamp.
- You can **extend** a retention period (set a later Retain Until Date) but **never shorten** it.
- Different versions of the same object can have **different retention modes and periods**.

```bash
# Set a compliance-mode retention period on a specific version
aws s3api put-object-retention \
    --bucket test-bucket \
    --key sensitive-record.txt \
    --version-id L3YacQXrB9IfveOta4GifLxTwvSR3ZVL \
    --retention '{"Mode": "COMPLIANCE", "RetainUntilDate": "2032-07-04T17:00:00Z"}'
```

### 3.4 Legal Holds

No expiration — remains in effect until explicitly removed. Independent from retention periods (an object can have both).

```bash
# Place a legal hold
aws s3api put-object-legal-hold \
    --bucket myexamplebucket \
    --key client-confidential.pdf \
    --version-id z_s4Z836Cuw.LI42sLapzKYT8H1A5NQg \
    --legal-hold '{"Status": "ON"}'

# Remove a legal hold
aws s3api put-object-legal-hold \
    --bucket myexamplebucket \
    --key client-confidential.pdf \
    --version-id z_s4Z836Cuw.LI42sLapzKYT8H1A5NQg \
    --legal-hold '{"Status": "OFF"}'
```

### 3.5 Use Cases

| Industry | Scenario | Lock Type |
| :--- | :--- | :--- |
| **Financial services** | Retain trade records and audit trails for 7 years (regulatory) | Compliance mode, 7-year retention |
| **Pharmaceutical** | Clinical trial data immutable for 10+ years (FDA) | Compliance mode, 10-year retention |
| **Legal** | Client case files preserved for potential future litigation | Legal hold (no set expiration) |

---

## 4. Quick-Reference Checklist

- [ ] **Enable versioning on critical buckets** — it's the foundation for delete protection, Object Lock, and lifecycle version management.
- [ ] **Understand that DELETE doesn't delete** — in versioned buckets, simple deletes only add delete markers. Teach your team this.
- [ ] **Use version IDs for permanent deletion** — `DELETE Object versionId` is the only way to permanently remove data from a versioned bucket.
- [ ] **Clean up delete markers** — use lifecycle rules with `ExpiredObjectDeleteMarker` to prevent marker buildup.
- [ ] **Set lifecycle rules for noncurrent versions** — without them, old versions accumulate indefinitely and drive up storage costs.
- [ ] **Use Governance mode for testing** — validate retention settings before committing to irrevocable Compliance mode.
- [ ] **Never set Compliance mode casually** — once set, it cannot be shortened or removed by anyone, including the root account.
- [ ] **Use legal holds for litigation** — when you don't know how long data must be preserved, legal holds are more appropriate than retention periods.
- [ ] **Monitor with S3 Storage Lens** — track current vs noncurrent version counts across buckets to catch version sprawl early.
