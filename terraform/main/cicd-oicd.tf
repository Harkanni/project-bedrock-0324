# --- GitHub Actions OIDC Provider & IAM Role (Section 4.6) -------------------

# Fetch the current AWS account ID dynamically
# data "aws_caller_identity" "current" {}

# GitHub OIDC Thumbprint (Global OpenID Connect Root CA)
# GitHub Actions uses Digicert root CA
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c3dd1fc5e817fe75c500540315c25b3e6e100a3"]

  tags = {
    Name = "github-actions-oidc-provider"
  }
}

# IAM Role assumed by GitHub Actions
resource "aws_iam_role" "github_actions_role" {
  name = "project-bedrock-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Harkanni/project-bedrock-0324:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "project-bedrock-github-actions-role"
  }
}

# Attach AdministratorAccess so Terraform can manage all resources
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- EKS Access Entry for CI/CD Role ---
# EKS API mode requires explicit access entries even for Admin IAM roles
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.github_actions_role.arn
}

resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.github_actions_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

output "github_actions_role_arn" {
  description = "ARN of the IAM Role for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions_role.arn
}