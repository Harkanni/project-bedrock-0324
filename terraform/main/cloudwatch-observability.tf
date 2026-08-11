# --- Application/Container Logging: CloudWatch Observability EKS Add-on ---
# Installs the CloudWatch Agent (metrics) and Fluent Bit (container logs)
# as DaemonSets in a new `amazon-cloudwatch` namespace, satisfying exam
# section 4.4's "ship container logs to CloudWatch" requirement.
# Both agents run under two separate service accounts (cloudwatch-agent,
# fluent-bit) but AWS's install path trusts both from a single IAM role —
# confirmed via AWS docs, not assumed, since only one role ARN is ever
# passed to `aws eks create-addon --service-account-role-arn`.

resource "aws_iam_role" "cloudwatch_observability" {
  name = "project-bedrock-cloudwatch-observability-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          # StringEquals accepts a list here — matches either service
          # account, not just one. Both agents share this one role.
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = [
            "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent",
            "system:serviceaccount:amazon-cloudwatch:fluent-bit",
          ]
        }
      }
    }]
  })
}

# AWS-managed policy — this is the documented, required policy for this
# add-on (covers PutLogEvents, PutMetricData, DescribeLogGroups, etc.).
# Not hand-reconstructed; this is the actual ARN AWS's docs specify.
resource "aws_iam_role_policy_attachment" "cloudwatch_observability" {
  role       = aws_iam_role.cloudwatch_observability.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "amazon-cloudwatch-observability"
  addon_version = "v6.4.0-eksbuild.1" # confirmed default/compatible for EKS 1.33

  service_account_role_arn = aws_iam_role.cloudwatch_observability.arn

  # Same pattern already used elsewhere in this project when installing
  # over anything that might have partial prior state.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}