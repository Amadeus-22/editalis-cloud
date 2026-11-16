# editalis-cloud

[![ci](https://github.com/Amadeus-22/editalis-cloud/actions/workflows/ci.yml/badge.svg)](https://github.com/Amadeus-22/editalis-cloud/actions/workflows/ci.yml)

**Reference infrastructure for a small Python service (API, scheduled worker, PostgreSQL): AWS with Terraform, Kubernetes with Helm and Argo CD, Prometheus alerting, and a backup that is verified by restoring it.**

> **Status: lab, not deployed.** `terraform apply` has never been run on AWS and
> no real resources exist. Everything is checked statically in CI (format,
> validate, security scans, schema validation, rule checks), and the backup and
> restore path runs for real in Docker on every push.

The application it targets (Editalis) lives in a separate private repository;
this repo contains only the infrastructure.

## Architecture

```
                Internet
                   │ 443 (TLS 1.3/1.2 policy)
          ┌────────▼─────────┐
          │ Application LB   │  public subnets, 2 AZs
          └────────┬─────────┘
                   │ ingress NodePort, from the LB security group only
          ┌────────▼─────────┐        ┌──────────────────────┐
          │ k3s node (EC2)   │───────▶│ S3: backups, logs    │
          │ Argo CD + chart  │  IAM   └──────────────────────┘
          └────────┬─────────┘
                   │ 5432, from the node security group only
          ┌────────▼─────────┐
          │ RDS PostgreSQL 16│  private subnets, no internet route
          └──────────────────┘
```

## Design decisions

- **k3s on one EC2 instance instead of EKS.** Avoids the fixed EKS control-plane
  charge for a lab; the Helm chart is plain Kubernetes and does not depend on it.
- **No NAT gateway.** Only the database is in private subnets and it needs no
  internet access. The node is in a public subnet; inbound is limited to the
  load balancer by security group.
- **No SSH.** The node has no key pair and no port 22; access is via SSM
  Session Manager.
- **No secrets in Git or Terraform variables.** RDS generates the master
  password into Secrets Manager; the chart reads app secrets from an existing
  Kubernetes Secret (`existingSecret`).
- **One `lab` flag.** `lab = true` turns off Multi-AZ, deletion protection and
  the final snapshot so the stack can be destroyed; `false` turns them on.
- **Scanner exceptions are written down.** Every skipped Checkov check and
  accepted Trivy finding has a reason in
  [docs/security-scan.md](docs/security-scan.md).
- **Local Terraform state, on purpose.** A single-operator lab; an S3 backend
  with locking is the noted next step (`terraform/envs/dev/versions.tf`).

## Layout

| Path | Contents |
|---|---|
| `terraform/modules/network` | VPC, public/private subnets, flow logs, security groups LB → node → DB |
| `terraform/modules/backup` | Two private, encrypted, versioned S3 buckets (DB backups, logs) |
| `terraform/modules/database` | RDS PostgreSQL 16, `rds.force_ssl`, password managed in Secrets Manager |
| `terraform/modules/cluster` | EC2 node running k3s, ALB with HTTPS listener, least-privilege IAM role |
| `terraform/envs/dev` | Composes the modules; includes an AWS Budgets alert |
| `chart/editalis` | Helm chart: API, worker, migration Job, Ingress, NetworkPolicy, backup CronJob |
| `gitops/` | Argo CD Applications for the chart and monitoring |
| `monitoring/` | 7 PrometheusRule alerts, Grafana dashboard, kube-prometheus-stack values |
| `scripts/` | `pg-restore.sh`, the restore drill, and a local kind + Argo CD demo |
| `docs/` | [Runbook](docs/runbook.md) and [security scan record](docs/security-scan.md) |

## What CI checks

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml), on every push to `main` and every pull request.

| Job | Checks |
|---|---|
| `terraform` | `terraform fmt -check`, `terraform validate`, Checkov, Trivy (HIGH/CRITICAL fail the build) |
| `kubernetes` | `helm lint`; rendered chart, Argo CD Applications, PrometheusRule and dashboard ConfigMap validated with kubeconform (Kubernetes 1.31 schemas); Trivy on the rendered chart; `promtool check rules` |
| `restore-drill` | Loads data into PostgreSQL 16 in Docker, backs it up with the chart's script, drops the tables, restores, and compares row counts and a checksum |

## Validate locally

Needs Terraform, Checkov, Trivy, Helm, kubeconform and Docker.

```bash
make check    # fmt, validate, Checkov, Trivy, helm lint, kubeconform
make drill    # backup and restore drill in Docker
```

Last local run of both targets, matching CI:

| Check | Result |
|---|---|
| `terraform validate` | Valid |
| Checkov | 177 passed, 0 failed (11 checks excluded in `.checkov.yaml`, each justified) |
| Trivy, Terraform and rendered chart | 0 HIGH/CRITICAL (3 accepted in `.trivyignore`, each justified) |
| Helm chart | Lints; 11/11 rendered resources valid |
| GitOps and monitoring manifests | 4/4 valid |
| Alert rules | 7 rules pass `promtool` |
| Restore drill | 5,000 subscribers and 20,000 deliveries restored; counts and checksum match |

## Not done yet

| Item | Status |
|---|---|
| `terraform apply` on AWS | Never run. No plan against a real account either |
| Argo CD sync | `make demo` (kind + Argo CD) is written but has not been run end to end |
| Container image | The chart references `ghcr.io/amadeus-22/editalis`, which is not published |

## Applying it (untested)

```bash
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars   # ACM certificate ARN, budget e-mail
terraform init && terraform plan
terraform apply
terraform destroy
```

Billable resources it would create include an ALB, one `t4g.small` instance and
one `db.t4g.micro` RDS instance. A budget alert fires at 80% of the
`monthly_budget_usd` variable (default USD 10). No real cost has been measured.

## Operations

[docs/runbook.md](docs/runbook.md): what each alert means, what to do, and the restore procedure.
