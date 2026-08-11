# --- Developer read-only access ------------------------------------------
# A separate IAM identity for a "developer" role — can see and debug
# what's running in retail-app, but can't create, edit, or delete
# anything, and has zero visibility into kube-system or any other
# namespace. This is the least-privilege counterpart to the full-admin
# access entry in eks.tf (which is for cluster operators, not app devs).

resource "aws_iam_user" "bedrock_dev_view" {
  name = "bedrock-dev-view"

  tags = {
    Name = "bedrock-dev-view"
  }
}

# Programmatic credentials
resource "aws_iam_access_key" "bedrock_dev_view" {
  user = aws_iam_user.bedrock_dev_view.name
}

# AWS Console access profile (Exam requirement 4.3)
resource "aws_iam_user_login_profile" "bedrock_dev_view" {
  user                    = aws_iam_user.bedrock_dev_view.name
  password_reset_required = false
}

# Exam requirement 4.3: Console ReadOnlyAccess
resource "aws_iam_user_policy_attachment" "dev_view_readonly" {
  user       = aws_iam_user.bedrock_dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Scoped permission needed for aws eks update-kubeconfig
resource "aws_iam_user_policy" "bedrock_dev_view_describe_cluster" {
  name = "eks-describe-cluster-only"
  user = aws_iam_user.bedrock_dev_view.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = aws_eks_cluster.main.arn
      }
    ]
  })
}

resource "aws_eks_access_entry" "dev_view" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_user.bedrock_dev_view.arn
}

resource "aws_eks_access_policy_association" "dev_view" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_user.bedrock_dev_view.arn

  # Built-in EKS policy for read-only verbs across standard resource types
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [local.app_namespace]
  }
}

# --- Outputs for debugging ---

output "bedrock_dev_view_access_key_id" {
  description = "Access key ID for the bedrock-dev-view IAM user — pair with the secret access key for kubectl/AWS CLI access scoped to retail-app"
  value       = aws_iam_access_key.bedrock_dev_view.id
}

output "bedrock_dev_view_secret_access_key" {
  description = "Secret access key for bedrock-dev-view — SENSITIVE. Record this in the exam's Deliverables doc, never commit it to git."
  value       = aws_iam_access_key.bedrock_dev_view.secret
  sensitive   = true
}

output "bedrock_dev_view_console_password" {
  description = "Console login password for bedrock-dev-view user"
  value       = aws_iam_user_login_profile.bedrock_dev_view.password
  sensitive   = true
}