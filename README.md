# Cloud Operations & DevOps Engineering Notes

Welcome to the Cloud Operations (CloudOps) & DevOps Engineering Notes repository. This documentation is organized modularly by technology domain (`aws > <technology> > <files>`), featuring **clear, formal technical definitions first**, **intuitive conceptual analogies second**, **real-world production outage stories**, and **tested Infrastructure as Code (Terraform) & Configuration Management (Puppet) modules**.

---

## 🗂️ Repository Structure

```
DevopsNotes/
├── README.md
├── aws/
│   ├── cloudwatch/
│   │   ├── 01-cloudwatch-cloudops-guide.md
│   │   ├── 02-terraform-cloudwatch-guide.md
│   │   └── terraform/
│   ├── databases/
│   │   ├── 01-database-monitoring-guide.md
│   │   └── 02-database-scaling-strategies-guide.md
│   ├── ebs/
│   │   ├── 01-ebs-cloudops-guide.md
│   │   ├── 02-terraform-ebs-guide.md
│   │   ├── 03-ebs-troubleshooting-and-performance-optimization.md
│   │   ├── 04-managing-and-optimizing-mountable-storage-guide.md
│   │   ├── 06-ebs-snapshots-backup-and-recovery-guide.md
│   │   ├── 07-dlm-automated-snapshot-management-guide.md
│   │   └── terraform/
│   ├── efs/
│   │   └── 01-efs-cloudops-guide.md
│   ├── fsx/
│   │   └── 01-fsx-cloudops-guide.md
│   ├── kms/
│   │   └── 01-kms-cloudops-guide.md
│   ├── s3/
│   │   ├── 01-s3-parallelisation-and-data-transfer-guide.md
│   │   ├── 02-s3-directory-buckets-guide.md
│   │   ├── 03-s3-table-buckets-guide.md
│   │   ├── 04-s3-intelligent-tiering-and-lifecycle-guide.md
│   │   ├── 05-s3-lifecycle-rules-deep-dive.md
│   │   └── 06-s3-versioning-and-object-lock-guide.md
│   └── vpc/
│       ├── 01-vpc-cloudops-guide.md
│       ├── 02-terraform-vpc-guide.md
│       └── terraform/
└── puppet/
    ├── 01-puppet-fundamentals-guide.md
    ├── 02-puppet-advanced-cloudops-guide.md
    └── examples/
        ├── Puppetfile
        ├── hiera.yaml
        ├── manifests/
        ├── data/
        └── modules/
```