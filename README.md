# Project Bedrock — AWS EKS Cloud Infrastructure Capstone

[![Terraform CI/CD](https://github.com/Harkanni/project-bedrock-0324/actions/workflows/terraform.yml/badge.svg)](https://github.com/Harkanni/project-bedrock-0324/actions)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-1.11.0-7B42BC?style=flat&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.33.13-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-v3-0F1689?style=flat&logo=helm&logoColor=white)

---

## 📌 Project Overview

This repository contains the complete Infrastructure-as-Code (IaC), Helm chart, and deployment configuration for **Project Bedrock**, a production-grade AWS EKS infrastructure hosting a microservice-based Retail Store application.

The project enforces automated multi-AZ networking, secret management, continuous delivery via GitHub Actions, dynamic scaling, ingress routing with TLS termination, pod resilience, and external managed data services.

- **Project Tag:** `Project: tinyuka-2025-capstone`
- **Target AWS Region:** `us-east-1`
- **Live Application URL:** [https://store.54.91.203.88.nip.io](https://store.54.91.203.88.nip.io)

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
             │  - Assets Pod     │    │  - Cart Pod       │
             └───────────────────┘    └───────────────────┘
                         │                     │
                         ├─────────────────────┤
                         ▼                     ▼
                 [ AWS RDS MySQL ]      [ AWS DynamoDB ]
                  [ Catalog Data ]       [ Cart Data ]
                         │
                         ▼
                 [ AWS RDS PostgreSQL ]
                    [ Orders Data ]
                         │
                         ▼
                  [ S3 Asset Bucket ]
                         │
                         ▼
                    [ Event Lambda ]
```

### Key Components

1. **Custom VPC Networking:** Multi-AZ deployment spanning public and private subnets, managed NAT Gateways, and isolated route tables.
2. **Managed EKS Cluster:** Provisioned with managed node groups (`t3.small`), Cluster Autoscaler, and RBAC through AWS EKS Access Entries.
3. **Helm Application Deployment:** Retail Store microservices are packaged as a Helm chart and deployed as a single Helm release.
4. **Ingress Controller & Security:** AWS Application Load Balancer (ALB) Controller handles incoming HTTPS traffic with TLS termination.
5. **Managed Data Layer:** Catalog uses Amazon RDS for MySQL, Carts uses Amazon DynamoDB, and Orders uses Amazon RDS PostgreSQL.
6. **IAM/IRSA:** Service-specific Kubernetes service accounts use IAM roles for AWS resource access without embedding long-lived AWS credentials in pods.
7. **Object Storage & Serverless Processing:** S3 stores application assets and triggers Lambda event processing.

---

## 📦 Helm Deployment

The Retail Store application is packaged as a committed Helm chart:

```text
terraform/main/retail-store-sample-chart/
├── .helmignore
├── Chart.yaml
├── Chart.lock
├── values.yaml
└── charts/
    ├── retail-store-sample-assets-chart/
    ├── retail-store-sample-cart-chart/
    ├── retail-store-sample-catalog-chart/
    ├── retail-store-sample-checkout-chart/
    ├── retail-store-sample-orders-chart/
    └── retail-store-sample-ui-chart/
```

The root `values.yaml` configures the application to use managed AWS data services rather than deploying the corresponding local data-layer components inside Kubernetes.

### Data Layer

- **Catalog:** Amazon RDS MySQL
- **Carts:** Amazon DynamoDB
- **Orders:** Amazon RDS PostgreSQL
- **Checkout:** Redis deployed as part of the Helm release
- **Orders Messaging:** RabbitMQ deployed as part of the Helm release

The bundled Catalog MySQL, Cart DynamoDB, and Orders PostgreSQL resources are disabled through Helm values when the external AWS services are used.

### Single-Command Application Deployment

From the **repository root**, deploy or upgrade the complete Retail Store application with:

```bash
helm upgrade --install retail-store ./terraform/main/retail-store-sample-chart \
  --namespace retail-app \
  --create-namespace \
  -f ./terraform/main/retail-store-sample-chart/values.yaml
```

This command:

- Creates the `retail-store` Helm release if it does not already exist.
- Upgrades the existing release when it already exists.
- Deploys all Retail Store microservices as a single Helm release.
- Applies the committed `values.yaml` configuration.
- Uses Amazon RDS and DynamoDB for the configured external data layers.

### Verify the Helm Release

```bash
helm list -n retail-app
```

```bash
kubectl get pods -n retail-app
```

```bash
kubectl get services -n retail-app
```

```bash
kubectl get ingress -n retail-app
```

---

## 🚀 CI/CD Automation Pipeline

Infrastructure provisioning is automated using GitHub Actions defined in `.github/workflows/terraform.yml`.

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
    - terraform fmt                          - terraform init
    - terraform init                         - terraform validate
    - terraform validate                     - terraform apply -auto-approve
    - terraform plan
    - Post Plan as PR Comment
```

### Pull Requests

On pull requests targeting `main`, the workflow performs:

- `terraform fmt`
- `terraform init`
- `terraform validate`
- `terraform plan`

The resulting Terraform plan is formatted and posted as a pull request comment.

### Merge to Main

On merges or pushes to `main`, the workflow executes:

```bash
terraform init
terraform validate
terraform apply -auto-approve
```

This provisions and updates the AWS infrastructure defined in Terraform.

---

## 📂 Repository Layout

```text
.
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── docs/
│   └── architecture-diagram.png
│
├── terraform/
│   └── main/
│       ├── main.tf
│       ├── ingress.tf
│       ├── network-policy.yaml
│       │
│       ├── retail-store-sample-chart/
│       │   ├── .helmignore
│       │   ├── Chart.yaml
│       │   ├── Chart.lock
│       │   ├── values.yaml
│       │   │
│       │   └── charts/
│       │       ├── retail-store-sample-assets-chart/
│       │       ├── retail-store-sample-cart-chart/
│       │       ├── retail-store-sample-catalog-chart/
│       │       ├── retail-store-sample-checkout-chart/
│       │       ├── retail-store-sample-orders-chart/
│       │       └── retail-store-sample-ui-chart/
│       │
│       └── lambda/
│
├── grading.json
└── README.md
```

---

## 🛠️ Step-by-Step Deployment Guide

### Prerequisites

Install and configure the following tools:

- [Terraform v1.11.0+](https://www.terraform.io/downloads)
- [AWS CLI v2](https://aws.amazon.com/cli/)
- [kubectl v1.30+](https://kubernetes.io/docs/tasks/tools/)
- [Helm v3+](https://helm.sh/docs/intro/install/)

Ensure the AWS CLI is authenticated with an IAM identity that has the permissions required to provision and manage the project infrastructure.

### Step 1: Clone the Repository

```bash
git clone https://github.com/Harkanni/project-bedrock-0324.git
cd project-bedrock-0324
```

### Step 2: Initialize Terraform

```bash
cd terraform/main
terraform init
```

### Step 3: Review Terraform Changes

```bash
terraform plan
```

Review the plan carefully before applying infrastructure changes.

### Step 4: Provision the AWS Infrastructure

```bash
terraform apply -auto-approve
```

Terraform provisions the AWS infrastructure including:

- VPC
- Public and private subnets
- Internet Gateway
- NAT Gateways
- Route tables
- Security groups
- EKS cluster
- EKS managed node groups
- IAM roles and policies
- RDS resources
- DynamoDB resources
- S3 bucket
- Lambda resources
- Supporting networking and security resources

### Step 5: Configure the Kubernetes Context

After the EKS cluster is available:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name project-bedrock-cluster
```

Verify connectivity:

```bash
kubectl get nodes
```

Expected output should show the EKS worker nodes in a `Ready` state.

### Step 6: Deploy the Retail Store Application with Helm

From the repository root:

```bash
helm upgrade --install retail-store ./terraform/main/retail-store-sample-chart \
  --namespace retail-app \
  --create-namespace \
  -f ./terraform/main/retail-store-sample-chart/values.yaml
```

This is the **single Helm deployment command** for the entire Retail Store application.

### Step 7: Verify the Helm Release

```bash
helm list -n retail-app
```

Expected status:

```text
NAME          NAMESPACE     STATUS
retail-store  retail-app    deployed
```

### Step 8: Verify Application Pods

```bash
kubectl get pods -n retail-app
```

Verify that the Retail Store application pods reach `Running` and `Ready` status.

### Step 9: Verify Application Services

```bash
kubectl get services -n retail-app
```

### Step 10: Verify the ALB Ingress

```bash
kubectl get ingress -n retail-app
```

The AWS Load Balancer Controller should provision or maintain the associated Application Load Balancer.

---

## 🔐 External Data Layer Configuration

The Helm chart is configured to use managed AWS services for persistent application data.

### Catalog — Amazon RDS MySQL

The Catalog service is configured to use the external RDS MySQL instance instead of deploying MySQL into the Kubernetes cluster.

```yaml
catalog:
  mysql:
    create: false
    endpoint: project-bedrock-catalog-mysql.cwbmiwk2i4r8.us-east-1.rds.amazonaws.com
    database: catalog
    secret:
      create: false
      name: catalog-db
```

### Carts — Amazon DynamoDB

The Carts service is configured to use the external DynamoDB table:

```yaml
carts:
  persistence: dynamodb

  dynamodb:
    tableName: project-bedrock-carts
    createTable: false
    create: false
```

The Carts service account is associated with an IAM role through IRSA so that the application can access DynamoDB without static AWS credentials.

### Orders — Amazon RDS PostgreSQL

The Orders service uses an externally provisioned PostgreSQL database:

```yaml
orders:
  postgresql:
    create: false
    database: orders
    endpoint:
      host: project-bedrock-orders-postgres.cwbmiwk2i4r8.us-east-1.rds.amazonaws.com
      port: "5432"
    secret:
      create: false
      name: orders-db
```

The Orders service account also uses IRSA for AWS access.

---

## 🌟 Bonus Objectives & Resilience Proof

### 1. Dynamic Cluster Autoscaling

The cluster is equipped with the **AWS Cluster Autoscaler**.

#### Scale-Up Trigger

The UI deployment was scaled to 15 replicas:

```bash
kubectl scale deployment/retail-store-ui --replicas=15 -n retail-app
```

#### Result

The resulting unschedulable pods triggered Cluster Autoscaler to provision additional EC2 capacity within the EKS managed node group.

### 2. Pod Self-Healing & Resilience

Kubernetes Deployment controllers automatically replace failed pods to maintain the desired replica count.

#### Test

A running assets pod was forcibly deleted:

```bash
kubectl delete pod retail-store-assets-6df56dff4c-pcfk2 -n retail-app
```

#### Result

The Deployment controller automatically created a replacement pod.

This demonstrates Kubernetes self-healing behavior.

### 3. Least-Privilege Network Policies

Strict egress and ingress traffic controls are enforced through Kubernetes `NetworkPolicy` objects, restricting unnecessary cross-workload and cross-namespace communication.

---

## 🔍 Helm Validation

Before applying Helm changes, the chart can be rendered locally without modifying the cluster.

From `terraform/main`:

```bash
helm template retail-store ./retail-store-sample-chart \
  --namespace retail-app \
  -f ./retail-store-sample-chart/values.yaml
```

The rendered manifests can be saved for inspection:

```bash
helm template retail-store ./retail-store-sample-chart \
  --namespace retail-app \
  -f ./retail-store-sample-chart/values.yaml > rendered.yaml
```

Verify the external data-layer endpoints:

```bash
grep -E "project-bedrock-catalog-mysql|project-bedrock-carts|project-bedrock-orders-postgres" rendered.yaml
```

The rendered configuration should contain:

- RDS MySQL endpoint for Catalog
- DynamoDB table `project-bedrock-carts`
- RDS PostgreSQL endpoint for Orders

The local Catalog MySQL, Cart DynamoDB, and Orders PostgreSQL resources should not be rendered when those external data-layer components are disabled.

---

## 🧹 Complete Teardown & Clean-Up Guide

To fully tear down the environment and prevent unexpected AWS charges, follow these steps in order.

> ⚠️ **Important:** AWS Application Load Balancers, non-empty S3 buckets, and other dependent AWS resources can block `terraform destroy` if they are not cleaned up beforehand.

### Step 1: Remove the Helm Release and Kubernetes Ingress

First uninstall the Retail Store Helm release:

```bash
helm uninstall retail-store -n retail-app
```

Delete the ALB Ingress object if it remains:

```bash
kubectl delete ingress retail-store-ui \
  -n retail-app \
  --ignore-not-found=true
```

If the application namespace is no longer required:

```bash
kubectl delete namespace retail-app \
  --ignore-not-found=true
```

Removing the Ingress allows the AWS Load Balancer Controller to clean up the associated AWS Application Load Balancer resources.

### Step 2: Empty the S3 Bucket

Terraform cannot remove an S3 bucket that still contains objects.

Set the bucket name:

```bash
export BUCKET_NAME="bedrock-assets-alt-soe-tin-o25-0324"
```

Delete the current objects:

```bash
aws s3 rm s3://${BUCKET_NAME} --recursive
```

If the bucket has versioning enabled, remove object versions and delete markers:

```bash
aws s3api delete-objects \
  --bucket ${BUCKET_NAME} \
  --delete "$(aws s3api list-object-versions \
    --bucket ${BUCKET_NAME} \
    --output json \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
  2>/dev/null || true
```

```bash
aws s3api delete-objects \
  --bucket ${BUCKET_NAME} \
  --delete "$(aws s3api list-object-versions \
    --bucket ${BUCKET_NAME} \
    --output json \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
  2>/dev/null || true
```

### Step 3: Run Terraform Destroy

Navigate to the Terraform root:

```bash
cd terraform/main
```

Then destroy the provisioned infrastructure:

```bash
terraform destroy -auto-approve
```

### Step 4: Verify Remaining AWS Resources

Some AWS-generated resources, such as CloudWatch log groups, may persist depending on retention settings.

#### Check EKS CloudWatch Logs

```bash
aws logs describe-log-groups \
  --query "logGroups[?contains(logGroupName, 'project-bedrock-cluster')].logGroupName" \
  --output table
```

Delete a retained EKS log group if required:

```bash
aws logs delete-log-group \
  --log-group-name /aws/eks/project-bedrock-cluster/cluster \
  2>/dev/null || true
```

### Step 5: Verify NAT Gateway Cleanup

NAT Gateways can continue generating hourly charges while they remain active.

```bash
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Project,Values=tinyuka-2025-capstone" \
  --query "NatGateways[*].[NatGatewayId,State]" \
  --output table
```

Ensure no project NAT Gateway remains in an active state.

### Step 6: Verify VPC Cleanup

```bash
aws ec2 describe-vpcs \
  --filter "Name=tag:Project,Values=tinyuka-2025-capstone" \
  --query "Vpcs[*].[VpcId,State]" \
  --output table
```

---

## 📊 Verification Output Export

As required by the capstone evaluation tooling, refresh `grading.json` with the Terraform outputs:

```bash
cd terraform/main
terraform output -json > ../../grading.json
```

This generates:

```text
grading.json
```

at the repository root.

---

## ✅ Helm Requirement Verification

The project satisfies the Helm deployment requirement through the following implementation:

- A Helm chart is committed under `terraform/main/retail-store-sample-chart/`.
- The chart contains the Retail Store microservice subcharts.
- A custom root `values.yaml` is committed with environment-specific configuration.
- Catalog is configured to use Amazon RDS MySQL.
- Carts is configured to use Amazon DynamoDB.
- Orders is configured to use Amazon RDS PostgreSQL.
- Kubernetes service accounts are configured for IAM/IRSA where AWS access is required.
- The application is deployed as a single Helm release named `retail-store`.
- The complete application is deployable with a single documented command:

```bash
helm upgrade --install retail-store ./terraform/main/retail-store-sample-chart \
  --namespace retail-app \
  --create-namespace \
  -f ./terraform/main/retail-store-sample-chart/values.yaml
```

- The live release is managed by Helm and can be inspected with:

```bash
helm list -n retail-app
```

- The chart can be rendered locally with `helm template` before deployment for validation.
'''
