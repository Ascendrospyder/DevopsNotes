# Amazon S3 Lifecycle Rules — Deep Dive Reference

> **AWS Skill Builder Summary:**
> Detailed CloudOps reference covering S3 Lifecycle rule configuration — durability vs availability, rule elements (filters, transitions, expirations), versioning interactions, noncurrent version management, XML examples, and operational considerations.

---

## 1. Durability vs Availability

Two terms that sound similar but mean very different things:

| Concept | What It Means | S3 Guarantee |
| :--- | :--- | :--- |
| **Durability** | Will my data survive long-term without loss or corruption? | **99.999999999% (11 nines)** — across all storage classes. Store 10 million objects → expect to lose 1 object every 10,000 years. |
| **Availability** | Can I access my data right now when I need it? | Varies by storage class (e.g., Standard = 99.99%, Standard-IA = 99.9%) |

> **Key insight:** All S3 storage classes have the same durability (11 nines). They differ in **availability** and **retrieval speed**. Choose lower-availability tiers for backups/archives where instant access isn't critical — and save money.

---

## 2. Lifecycle Configuration Overview

An S3 Lifecycle configuration is a **set of rules** attached to a bucket that tell S3 to automatically transition or delete objects based on age, size, tags, or prefixes.

```
┌──────────────────────────────────────────────────────────┐
│                  Two Types of Actions                     │
│                                                          │
│   TRANSITION                      EXPIRATION             │
│   Move objects to a               Delete objects          │
│   cheaper storage class           permanently             │
│                                                          │
│   Day 0: S3 Standard              Day 365: Delete        │
│   Day 30: → Standard-IA                                  │
│   Day 90: → Glacier                                      │
│                                                          │
│   Works on:                       Works on:              │
│   • Current versions              • Current versions     │
│   • Noncurrent versions           • Noncurrent versions  │
│                                   • Delete markers       │
│                                   • Incomplete uploads   │
└──────────────────────────────────────────────────────────┘
```

---

## 3. Rule Elements

Every lifecycle rule is built from these elements:

| Element | Description | Notes |
| :--- | :--- | :--- |
| **ID** | Unique identifier for the rule | Max 255 characters; up to **1,000 rules** per bucket (hard limit) |
| **Status** | `Enabled` or `Disabled` | Disabled rules are ignored — S3 performs no actions |
| **Filter** | Which objects the rule applies to | By prefix, tags, object size, or combination (logical AND) |
| **Actions** | What to do (transition, expiration, abort) | One or more per rule |

### 3.1 Filter Options

| Filter | How It Works | Example |
| :--- | :--- | :--- |
| **Key prefix** | Matches objects starting with a specific path | `logs/` — only objects under the logs prefix |
| **Object tags** | Matches objects with specific tag key-value pairs | `Environment=Production` — both key and value must match exactly |
| **Object size** | Min/max size in bytes (up to 5 TB) | Objects between 1 MB and 1 GB only |
| **Combination** | Logical AND of multiple filters | Prefix `logs/` AND tag `Team=Backend` |

> **Important:** To apply rules to objects with different prefixes, create **separate rules** — you can't use OR logic in a single filter.

```xml
<!-- Example: Separate rules for different prefixes -->
<LifecycleConfiguration>
    <Rule>
        <Filter><Prefix>projectA/</Prefix></Filter>
        <!-- transition/expiration actions -->
    </Rule>
    <Rule>
        <Filter><Prefix>projectB/</Prefix></Filter>
        <!-- transition/expiration actions -->
    </Rule>
</LifecycleConfiguration>
```

---

## 4. Lifecycle Actions

### 4.1 Transition Actions

Move objects to cheaper storage classes based on age.

| Action | Applies To | What It Does |
| :--- | :--- | :--- |
| **Transition** | Current versions | Move current objects to another storage class after X days |
| **NoncurrentVersionTransition** | Noncurrent versions | Move old versions to another class after X days since becoming noncurrent |

### 4.2 Expiration Actions

Delete objects based on age or state.

| Action | Applies To | What It Does |
| :--- | :--- | :--- |
| **Expiration** | Current versions | Delete current objects after X days |
| **NoncurrentVersionExpiration** | Noncurrent versions | Permanently delete old versions after X noncurrent days |
| **ExpiredObjectDeleteMarker** | Delete markers | Clean up orphaned delete markers (no remaining noncurrent versions) |
| **AbortIncompleteMultipartUpload** | Incomplete uploads | Stop and clean up multipart uploads after X days |

### 4.3 Noncurrent Version Controls

For versioned buckets, you can control how many noncurrent versions to **retain** before S3 starts deleting or transitioning:

- `<NoncurrentDays>` — how many days since the version became noncurrent
- `<NewerNoncurrentVersions>` — how many newer noncurrent versions must exist (1–100)

**Both conditions must be met** before S3 takes action. A `<Filter>` element is required when using `NewerNoncurrentVersions`.

---

## 5. Example Configurations

### 5.1 Transition + Noncurrent Version Management

**Goal:** Keep 1 year of history, retain 5 most recent noncurrent versions, transition cold data to Glacier, move current versions to Standard-IA after 90 days.

```xml
<LifecycleConfiguration>
    <Rule>
        <ID>sample-rule</ID>
        <Filter><Prefix></Prefix></Filter>
        <Status>Enabled</Status>
        <Transition>
            <Days>90</Days>
            <StorageClass>STANDARD_IA</StorageClass>
        </Transition>
        <NoncurrentVersionTransition>
            <NoncurrentDays>30</NoncurrentDays>
            <StorageClass>GLACIER</StorageClass>
        </NoncurrentVersionTransition>
        <NoncurrentVersionExpiration>
            <NewerNoncurrentVersions>5</NewerNoncurrentVersions>
            <NoncurrentDays>365</NoncurrentDays>
        </NoncurrentVersionExpiration>
    </Rule>
</LifecycleConfiguration>
```

```
Day 0 ──► Object created in S3 Standard
Day 90 ──► Current version → Standard-IA
           (when a new version is uploaded, old version becomes noncurrent)
           Noncurrent version + 30 days ──► Glacier
           Noncurrent version + 365 days AND >5 newer versions ──► Deleted
```

### 5.2 Expiration with Noncurrent Cleanup

**Goal:** Expire current versions after 60 days, delete noncurrent versions after 30 days.

```xml
<LifecycleConfiguration>
    <Rule>
        <Expiration>
            <Days>60</Days>
        </Expiration>
        <NoncurrentVersionExpiration>
            <NoncurrentDays>30</NoncurrentDays>
        </NoncurrentVersionExpiration>
    </Rule>
</LifecycleConfiguration>
```

### 5.3 Clean Up Expired Delete Markers

**Goal:** After noncurrent versions are deleted, remove the leftover orphaned delete markers.

```xml
<LifecycleConfiguration>
    <Rule>
        <ID>Rule 1</ID>
        <Filter><Prefix>logs/</Prefix></Filter>
        <Status>Enabled</Status>
        <Expiration>
            <ExpiredObjectDeleteMarker>true</ExpiredObjectDeleteMarker>
        </Expiration>
        <NoncurrentVersionExpiration>
            <NoncurrentDays>30</NoncurrentDays>
        </NoncurrentVersionExpiration>
    </Rule>
</LifecycleConfiguration>
```

### 5.4 Abort Incomplete Multipart Uploads

**Goal:** Clean up multipart uploads that weren't completed within 7 days.

```xml
<LifecycleConfiguration>
    <Rule>
        <ID>sample-rule</ID>
        <Status>Enabled</Status>
        <AbortIncompleteMultipartUpload>
            <DaysAfterInitiation>7</DaysAfterInitiation>
        </AbortIncompleteMultipartUpload>
    </Rule>
</LifecycleConfiguration>
```

---

## 6. Conflict Resolution — When Multiple Rules Apply

When an object matches multiple rules on the same day, S3 follows this priority:

```
┌──────────────────────────────────────────────────────────┐
│           Rule Conflict Priority (highest first)         │
│                                                          │
│   1. Permanent deletion     (wins over everything)       │
│   2. Transition             (wins over delete markers)   │
│   3. Delete marker creation (lowest priority)            │
│                                                          │
│   If eligible for BOTH Glacier AND Standard-IA:          │
│   → S3 chooses Glacier (cheaper class wins)              │
└──────────────────────────────────────────────────────────┘
```

---

## 7. Operational Considerations

| Consideration | Detail |
| :--- | :--- |
| **Propagation delay** | New or updated lifecycle configs take a few minutes to fully propagate across S3 systems |
| **Action delay** | Objects may not be deleted/transitioned immediately when the rule is satisfied — S3 queues actions asynchronously (can take days or weeks) |
| **Billing is immediate** | Billing changes apply when the rule is **satisfied**, even if the action hasn't completed yet. Exception: Intelligent-Tiering billing only starts after the actual transition |
| **Applies to all objects** | Rules apply to both existing objects and future uploads — not just new objects |
| **Disabling rules** | Stops scheduling new actions after a small delay; already-scheduled objects are unscheduled |
| **Minimum storage duration** | Some classes charge for minimum storage duration (e.g., 30 days for Standard-IA). Expiring objects before this period still incurs the full charge |
| **MFA-enabled buckets** | Lifecycle configuration is **not supported** on MFA-enabled buckets |
| **No CloudTrail logging** | Lifecycle actions are not captured by CloudTrail object-level logging — use **S3 server access logs** instead |

---

## 8. Quick-Reference Checklist

- [ ] **Always set an AbortIncompleteMultipartUpload rule** — orphaned multipart uploads silently accumulate storage costs.
- [ ] **Design for versioned buckets** — use `NoncurrentVersionTransition` and `NoncurrentVersionExpiration` to control old version costs.
- [ ] **Set `NewerNoncurrentVersions`** — retain a fixed number of old versions (e.g., 5) for accidental delete recovery.
- [ ] **Clean up expired delete markers** — set `ExpiredObjectDeleteMarker` to `true` to prevent marker buildup.
- [ ] **Remember billing is immediate** — you'll be charged the destination class rate as soon as the rule is satisfied, even before the transition completes.
- [ ] **Use S3 server access logs** — CloudTrail doesn't capture lifecycle actions; access logs are the only audit trail.
- [ ] **Account for minimum storage duration** — don't transition or expire objects before the minimum duration of their current class.
- [ ] **Test with disabled rules first** — create rules as `Disabled`, verify the filter scope, then enable.
