# --- EKS Cluster ---------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = "project-bedrock-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  # Oldest actively-supported (standard support) version at build time.
  # Checked against the EKS version lifecycle table — do not let this
  # go stale; re-check before you actually apply if time has passed.
  version = "1.35"

  vpc_config {
    subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)

    # Keep the API server reachable both from within the VPC (nodes)
    # and from your local machine / CI runner for kubectl and Terraform.
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Control plane logging — required by section 4.4 (Observability).
  # These five log types ship straight to CloudWatch Logs once enabled.
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  # Access Entries (used in section 4.3 for bedrock-dev-view) require
  # this authentication mode instead of the legacy aws-auth ConfigMap.
  access_config {
    authentication_mode = "API"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = "project-bedrock-cluster"
  }
}

# --- Explicit cluster admin access ---------------------------------------
# Don't rely on EKS's implicit "creator gets admin" behavior — it's tied
# to one exact IAM principal/session and breaks the moment a different
# profile, refreshed SSO session, or (later) a CI role runs Terraform.
# Declaring access explicitly here means it's reproducible for anyone
# listed, including the GitHub Actions role we'll add in the CI/CD step.

data "aws_caller_identity" "current" {}

variable "eks_admin_principal_arns" {
  description = "IAM principal ARNs granted full admin access to the cluster, in addition to the identity currently running Terraform"
  type        = list(string)
  default     = []
}

locals {
  eks_admin_arns = toset(concat(
    [data.aws_caller_identity.current.arn],
    var.eks_admin_principal_arns
  ))
}

resource "aws_eks_access_entry" "admin" {
  for_each = local.eks_admin_arns

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = local.eks_admin_arns

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# CloudWatch Log Group the control plane logs above ship into.
# EKS creates this automatically when logging is enabled, but
# declaring it here lets us control retention (cost guardrail —
# unlimited retention on control plane logs adds up over time).
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/project-bedrock-cluster/cluster"
  retention_in_days = 14

  tags = {
    Name = "project-bedrock-eks-logs"
  }
}

# --- Managed Node Group ---------------------------------------------------
# Worker nodes live in the PRIVATE subnets only — they should never be
# directly internet-facing. Outbound internet (image pulls, etc.) goes
# through the single NAT Gateway.

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "project-bedrock-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id
  version         = aws_eks_cluster.main.version

  # t3.small — confirmed free-tier eligible on this specific AWS account
  # (checked via `aws ec2 describe-instance-types --filters
  # Name=free-tier-eligible,Values=true`). t3.micro was ruled out: its
  # pod-per-node ceiling (~4) is too low to fit even the required
  # system daemonsets plus real workloads.
  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 3
    min_size     = 1
    max_size     = 4 # slightly more headroom since t3.small holds fewer pods/node than t3.medium did
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
  ]

  tags = {
    Name = "project-bedrock-nodes"
  }
}
