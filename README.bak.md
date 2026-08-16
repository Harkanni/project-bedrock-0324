# Project Bedrock — AWS EKS Cloud Infrastructure Capstone

[![Terraform CI/CD](https://github.com/Harkanni/project-bedrock-0324/actions/workflows/terraform.yml/badge.svg)](https://github.com/Harkanni/project-bedrock-0324/actions)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-1.11.0-7B42BC?style=flat&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.33.13-326CE5?style=flat&logo=kubernetes&logoColor=white)

---

## 📌 Project Overview
This repository contains the complete Infrastructure-as-Code (IaC) and deployment manifests for **Project Bedrock**, a production-grade AWS EKS infrastructure provisioning a microservice-based Retail Store application.

The project enforces automated multi-AZ networking, secret management, automated continuous delivery via GitHub Actions, dynamic scaling, ingress routing with TLS termination, and pod resilience.

* **Project Tag:** `Project: tinyuka-2025-capstone`
* **Target AWS Region:** `us-east-1`
* **Live Application URL:** [https://store.44.205.183.114.nip.io](https://store.44.205.183.114.nip.io)

---

## 🏗️ Architecture & Topology

```text
                  [ AWS ALB Ingress (HTTPS / Port 443) ]
                                    │
                         ┌──────────┴──────────┐
                         ▼                     ▼
             [ Private Subnet 1A ]    [ Private Subnet 1B ]
             ┌───────────────────┐    ┌───────────────────┐
             │ EKS Worker Node 1 │    │ EKS Worker Node 2 │
             │  - UI Microservice│    │  - Catalog Pod    │
             │  - Assets Pod     │    │  - Cart / DB Pod  │
             └───────────────────┘    └───────────────────┘
                         │                     │
                         └──────────┬──────────┘
                                    ▼
             [ S3 Asset Bucket ] ◄──► [ Event Lambda ]
```

### Key Components:

1. **Custom VPC Networking:** Multi-AZ deployment spanning public and private subnets, managed NAT Gateways, and isolated route tables.
2. **Managed EKS Cluster:** Provisioned with managed Node Groups (`t3.small`), Cluster Autoscaler enabled, and RBAC via AWS EKS Access Entries.
3. **Ingress Controller & Security:** AWS Application Load Balancer (ALB) Controller handling incoming HTTPS traffic with wildcard TLS certificates imported into AWS Certificate Manager (ACM).
4. **Data & Storage Layer:** S3 Asset bucket (`bedrock-assets-alt-soe-tin-o25-0324`) paired with an S3-to-Lambda event notification pipeline.

---

## 🚀 CI/CD Automation Pipeline

Infrastructure provisioning is fully automated using GitHub Actions defined in `.github/workflows/terraform.yml`.

```text
        ┌─────────────────────────────────────────────────┐
        │                 Developer Git Push              │
        └────────────────────────┬────────────────────────┘
                                 │
             ┌───────────────────┴───────────────────┐
             ▼                                       ▼
    [ Pull Request Event ]                   [ Push to Main ]
             │                                       │
             ▼                                       ▼
    - terraform init                         - terraform init
    - terraform validate                     - terraform validate
    - terraform plan                         - terraform apply -auto-approve
    - Post Plan as PR Comment                
```

* **On Pull Request (`main`):** Runs `terraform fmt`, `init`, `validate`, and `plan`. The resulting plan is formatted and posted as a comment on the PR.
* **On Merge (`main`):** Automatically executes `terraform apply -auto-approve` to provision live AWS infrastructure.

---

## 📂 Repository Layout

```text
.
├── .github/
│   └── workflows/
│       └── terraform.yml          # GitHub Actions CI/CD Pipeline
├── docs/
│   └── architecture-diagram.png   # Architectural visual diagram
├── terraform/
│   └── main/                      # Primary IaC configuration
│       ├── main.tf                # VPC, EKS, IAM, and Security Groups
│       ├── ingress.tf             # ACM Certificate & ALB Ingress definitions
│       ├── network-policy.yaml    # Kubernetes Pod isolation policies
│       └── retail-store-chart/    # Helm values & chart overlays for retail services
├── grading.json                   # Output export file for automated grading script
└── README.md                      # Documentation
```

---

## 🛠️ Step-by-Step Deployment Guide

### Prerequisites

* [Terraform v1.11.0+](https://www.terraform.io/downloads)
* [AWS CLI v2](https://aws.amazon.com/cli/) configured with deployment permissions
* [kubectl v1.30+](https://kubernetes.io/docs/tasks/tools/)
* [Helm v3+](https://helm.sh/docs/intro/install/)

### Local Deployment

```bash
# 1. Clone repository
git clone https://github.com/Harkanni/project-bedrock-0324.git
cd project-bedrock-0324/terraform/main

# 2. Initialize Terraform
terraform init

# 3. Preview planned changes
terraform plan

# 4. Provision Infrastructure
terraform apply -auto-approve

# 5. Configure local kubectl context
aws eks update-kubeconfig --region us-east-1 --name bedrock-eks-cluster

# 6. Verify cluster node status
kubectl get nodes
```

---

## 🌟 Bonus Objectives & Resilience Proof

### 1. Dynamic Cluster Autoscaling

The cluster is equipped with the **AWS Cluster Autoscaler**.

* **Scale-Up Trigger:** Tested by scaling the UI deployment to 15 replicas:
```bash
kubectl scale deployment/retail-store-ui --replicas=15 -n retail-app
```

* **Result:** Unschedulable pending pods triggered the Cluster Autoscaler to automatically provision additional EC2 instances to the EKS worker node group.

### 2. Pod Self-Healing & Resilience

Kubernetes Deployment controllers guarantee minimum availability:

* **Test:** Simulated pod failure by forcibly deleting a running asset pod:
```bash
kubectl delete pod retail-store-assets-6df56dff4c-pcfk2 -n retail-app
```

* **Recovery Time:** < 2 seconds recovery. The deployment controller immediately initialized a replacement pod (`retail-store-assets-6df56dff4c-m8x9q`).

### 3. Least-Privilege Network Policies

Strict egress and ingress traffic controls are enforced via Kubernetes `NetworkPolicy` objects, restricting inter-pod cross-namespace exposure.

---

## 🧹 Complete Teardown & Clean-Up Guide

To fully tear down the environment, destroy all provisioned resources, and prevent unexpected charges, follow these steps in order.

> ⚠️ **Important:** AWS Application Load Balancers and non-empty S3 buckets will block `terraform destroy` if not cleaned up beforehand.

---

### Step 1: Delete Kubernetes Ingress & Helm Releases

Deleting the Ingress resource forces the AWS Load Balancer Controller to remove the underlying Application Load Balancer (ALB), Target Groups, and Security Groups managed outside of Terraform.

```bash
# Uninstall the retail application Helm chart
helm uninstall retail-store -n retail-app

# Delete the ALB Ingress object directly to trigger target group teardown
kubectl delete ingress retail-store-ui -n retail-app --ignore-not-found=true

# (Optional) Delete all namespaces created for workloads
kubectl delete ns retail-app --ignore-not-found=true
```

---

### Step 2: Empty S3 Bucket Contents (Including Versioning)

Terraform cannot delete S3 buckets containing objects or version logs. Empty all project S3 buckets completely using the AWS CLI:

```bash
# Set your bucket name variable
export BUCKET_NAME="bedrock-assets-alt-soe-tin-o25-0324"

# Delete all current objects
aws s3 rm s3://${BUCKET_NAME} --recursive

# Delete all versioned object revisions and delete markers (if versioning was enabled)
aws s3api delete-objects \
  --bucket ${BUCKET_NAME} \
  --delete "$(aws s3api list-object-versions \
               --bucket ${BUCKET_NAME} \
               --output json \
               --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
  2>/dev/null || true

aws s3api delete-objects \
  --bucket ${BUCKET_NAME} \
  --delete "$(aws s3api list-object-versions \
               --bucket ${BUCKET_NAME} \
               --output json \
               --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
  2>/dev/null || true
```

---

### Step 3: Run Terraform Destroy

Once Kubernetes load balancers and S3 object locks are cleared, execute the automated destruction of all infrastructure:

```bash
# Navigate to the Terraform root directory
cd terraform/main

# Run destruction with auto-approval
terraform destroy -auto-approve
```

---

### Step 4: Manual Sweep & Verification (CloudWatch Logs & IAM)

Some system-generated resources (such as EKS control plane log groups and Lambda logs) persist after `terraform destroy` depending on retention policies.

Run these cleanup commands to ensure no orphan logs or residual IAM roles remain:

```bash
# 1. Delete retained EKS Cluster & Lambda CloudWatch log groups
aws logs delete-log-group --log-group-name /aws/eks/bedrock-eks-cluster/cluster 2>/dev/null || true
aws logs delete-log-group --log-group-name /aws/lambda/bedrock-s3-event-processor 2>/dev/null || true

# 2. Verify all NAT Gateways are deleted (avoids hourly idle charges)
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Project,Values=tinyuka-2025-capstone" \
  --query "NatGateways[*].[NatGatewayId,State]" \
  --output table

# 3. Verify target VPC is fully terminated
aws ec2 describe-vpcs \
  --filter "Name=tag:Project,Values=tinyuka-2025-capstone" \
  --query "Vpcs[*].[VpcId,State]" \
  --output table
```

---

## 📊 Verification Output Export

As required by Capstone evaluation tools, run the following to refresh `grading.json`:

```bash
cd terraform/main
terraform output -json > ../../grading.json
```