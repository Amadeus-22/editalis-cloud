# Security scan record

Checkov and Trivy run on every push. This file records what they found: what
was fixed in the code, and what is accepted and why. A skipped check without a
written reason is a finding nobody looked at.

## Fixed in the code

| Finding | Fix |
|---|---|
| Availability zones taken from a data source, so the plan could change when AWS adds a zone | Zones are passed explicitly (`azs`) and validated to be exactly two |
| No access logging on the backup bucket | Access to the backup bucket is logged into the logs bucket |
| No enhanced monitoring on RDS | Monitoring role and a 60-second interval added |
| Public access block not visible to the scanner (resources created with `for_each`) | One explicit block per bucket |

## Accepted

| Check | What it wants | Why it is accepted here |
|---|---|---|
| `CKV_AWS_88` | No public IP on the instance | Without a NAT gateway the node needs one for outbound traffic. Inbound is closed: the security group admits the load balancer only, and there is no SSH |
| `CKV_AWS_145`, `AWS-0132` | Customer-managed KMS key for S3 | SSE-S3 encrypts at rest; a customer key adds cost and key management a lab does not need |
| `CKV_AWS_354` | Customer-managed KMS key for Performance Insights | Same reason; the AWS-managed key is used |
| `CKV_AWS_293`, `CKV_AWS_157`, `CKV_AWS_150` | Deletion protection and Multi-AZ | Controlled by the `lab` variable: off for the lab so it can be destroyed, on otherwise |
| `CKV_AWS_144` | Cross-region replication for S3 | Single-region lab |
| `CKV_AWS_18` (logs bucket) | Access logging | The logs bucket would have to log into itself |
| `CKV2_AWS_62` | S3 event notifications | Nothing consumes them |
| `CKV2_AWS_28` | WAF in front of the load balancer | Out of scope for a lab; the first thing to add for a public production service |
| `CKV2_AWS_5` | Security groups attached to a resource | False positive: they are attached in another module |
| `AWS-0053` | Load balancer not public | It is the public entry point by design |
| `AWS-0104` | No unrestricted egress | The node needs outbound HTTPS for image pulls, SSM and S3. VPC endpoints would remove this and are the production answer |
