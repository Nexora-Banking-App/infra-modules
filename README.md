
***

<div align="center">

# Nexora Core Banking: Infrastructure Modules

### Stateless, Versioned Terraform Blueprints

**Terraform • AWS EKS • Amazon RDS • AWS Secrets Manager • AWS IAM (IRSA)**

<br>

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)

<br>

This repository acts as the **Blueprint Factory** for the Nexora Enterprise Platform. It contains strictly stateless, reusable Terraform modules (`vpc`, `eks`, `rds`). By decoupling these module definitions from environment state, we guarantee that Staging and Production environments are derived from identical, vetted infrastructure code rather than hand-copied configurations.

</div>

---

## Table of Contents

1. [Architectural Philosophy](#architectural-philosophy)
2. [Module Specifications](#module-specifications)
3. [Security & IAM Architecture](#security--iam-architecture)
4. [Integration with GitOps (ESO)](#integration-with-gitops-eso)
5. [Real-World Troubleshooting & Solutions](#real-world-troubleshooting--solutions)
6. [Known Gaps & Open Items](#known-gaps--open-items)

---

## Architectural Philosophy

In the Nexora platform, this repository contains **zero state**. 

It does not know what "staging" or "prod" is. It exposes input variables (e.g., `multi_az`, `desired_size`, `instance_class`) that the `infra-live` repository injects at execution time. This enforces the **DRY (Don't Repeat Yourself)** principle and strictly isolates the blast radius: engineers can test infrastructure changes on branch builds without risking configuration drift in production environments.

---

## Module Specifications

### 1. VPC Module (`/vpc`)
Wraps the official AWS VPC module to construct a rigid, multi-AZ network foundation.
* **Network Isolation:** Enforces strict Public/Private subnet boundaries. EKS worker nodes and RDS databases are deployed exclusively into private subnets.
* **Egress Routing:** Single NAT Gateway configured for private subnet outbound internet access (e.g., pulling external container images).
* **Controller Tagging:** Automatically injects `kubernetes.io/role/elb=1` and `kubernetes.io/role/internal-elb=1` tags, which are hard requirements for the AWS Load Balancer Controller to discover subnets.

### 2. EKS Module (`/eks`)
Provisions the Kubernetes v1.33 control plane and managed node groups using Amazon Linux 2023 (AL2023).
* **Cluster OIDC Federation (IRSA):** Automatically provisions a dedicated IAM OIDC Provider for the EKS cluster itself. *(Note: This is a separate trust boundary from the GitHub Actions CI/CD OIDC provider defined in `infra-live`)*. This enables Kubernetes pods to assume AWS IAM roles.
* **Access Entries:** Replaces the deprecated `aws-auth` ConfigMap. Uses AWS EKS Access Entries to grant deterministic cluster-admin rights to both the AWS Console role and the CLI deployment role.
* **Explicit Addons:** Explicitly manages `vpc-cni`, `kube-proxy`, and `coredns` to prevent node bootstrapping deadlocks.

### 3. RDS Module (`/rds`)
Provisions the MySQL 8.0 database backing the transactional ledger.
* **Dynamic Sizing:** Accepts `multi_az = true/false` to seamlessly toggle between a cost-optimized Single-AZ staging database and a synchronous, RPO=0 Multi-AZ production database.
* **Network Firewalling:** Restricts inbound port 3306 traffic strictly to the internal VPC CIDR block (`10.0.0.0/16`), rejecting all external routing attempts.
* **Automated Secrets:** Generates cryptographically random database passwords and application keys directly within the AWS provider, passing them natively to AWS Secrets Manager.

---

## Security & IAM Architecture

### 1. IRSA (IAM Roles for Service Accounts)
Compute nodes (EC2 instances) in this architecture possess **zero IAM permissions** to access AWS Secrets Manager or manipulate AWS Load Balancers. 

Instead, utilizing the Cluster OIDC Provider created by the EKS module, downstream controllers (like the External Secrets Operator and AWS Load Balancer Controller) receive projected JSON Web Tokens (JWTs) mounted to their Kubernetes `ServiceAccount`. These tokens are traded with AWS STS for temporary, least-privilege IAM credentials scoped exclusively to that specific pod.

### 2. The Secrets Lifecycle (Zero Secrets in Git)
The `rds` module is responsible for the genesis of all platform secrets. It generates:
* `DB_PASSWORD`
* `JWT_SECRET` (For API Gateway edge authentication)
* `INTERNAL_SERVICE_SECRET` (Designed for constant-time verification via `secrets.compare_digest` in the Python application logic)
* `GRAFANA_ADMIN_PASSWORD`

These are serialized into a single JSON payload and pushed to AWS Secrets Manager (`nexora/{env}/db-credentials`). No human engineer ever handles or commits these credentials.

---

## Real-World Troubleshooting & Solutions

This module code reflects several explicit fixes required to bypass undocumented AWS and EKS behaviors encountered during live provisioning:

### 1. Istio Webhook Timeout (Port 15017 Blocked)
* **Symptom:** `istiod` failed to inject Envoy sidecars, throwing `context deadline exceeded` and blocking all pod creation in the namespace.
* **Diagnosis:** The AWS EKS Managed Node Group security group blocks control-plane-to-worker-node traffic by default, except for standard kubelet ports. The Kubernetes API server could not reach the Istio mutating webhook on port `15017`.
* **Fix:** Injected a custom `node_security_group_additional_rules` block in the EKS module to explicitly allow TCP `15017` ingress from the cluster security group.

### 2. EKS Node Group Hangs on Initialization
* **Symptom:** Managed Node Groups remained in `Creating` state for 20+ minutes before timing out, with 0 nodes joining the cluster.
* **Diagnosis:** EKS module v20+ does not install the `vpc-cni` addon by default. Without the CNI, `kubelet` could not assign IP addresses to the `aws-node` daemonset, leaving nodes in a `NotReady` state indefinitely.
* **Fix:** Added the `cluster_addons` block to explicitly enforce the installation of `vpc-cni`, `kube-proxy`, and `coredns` prior to node group creation.

### 3. RDS Free-Tier Backup Retention Rejection
* **Symptom:** RDS creation failed with `FreeTierRestrictionError`.
* **Diagnosis:** AWS Free Tier accounts hard-cap automated backup retention at 1 day. The default Terraform value of 7 days triggered an immediate API rejection.
* **Fix:** Exposed `backup_retention_period` as a module variable, allowing `infra-live` to pass `1` for staging environments and `7` for production.

### 4. ENI Detachment Error on Security Group Updates
* **Symptom:** Updating the RDS security group description caused Terraform to fail with an ENI detachment error.
* **Diagnosis:** Modifying the `description` field of an `aws_security_group` forces a destructive replacement (Delete/Recreate) of the resource in AWS. Because the active RDS instance was using the ENI attached to that security group, AWS blocked the deletion.
* **Fix:** Security group descriptions are treated as immutable in this module. All rule modifications are applied via in-place updates to `ingress` blocks.

---

## Known Gaps & Open Items

In the interest of accurate architectural documentation, the following limitations are acknowledged in the current module definitions:

* **EBS CSI Driver Omission:** The EKS module currently does not provision the AWS EBS CSI Driver addon or its associated IRSA role. Consequently, stateful workloads (like Prometheus) must run in-memory (`emptyDir`), which results in metric data loss upon pod restarts. Adding this driver is a required prerequisite before moving observability metrics to durable storage.
* **VPC CIDR vs. SG ID for RDS Firewall:** The RDS security group currently allows inbound traffic from the entire VPC CIDR (`10.0.0.0/16`) rather than referencing the specific EKS Node Security Group ID. While this resolves a cyclic dependency/timing issue during cluster bootstrapping, it slightly broadens the internal network trust boundary. At production scale, this ingress rule should be tightened to accept traffic solely from the EKS worker node security group.