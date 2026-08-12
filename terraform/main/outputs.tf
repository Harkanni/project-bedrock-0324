# Exam requires the root module to output exactly these five values.
# cluster_endpoint / cluster_name / assets_bucket_name get filled in
# once we write the EKS and S3 configs — left as placeholders (commented)
# so this file doesn't reference resources that don't exist yet.



output "region" {
  description = "AWS region resources are deployed in"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the Project Bedrock VPC"
  value       = aws_vpc.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "assets_bucket_name" {
  description = "S3 bucket for product image uploads — one of the 5 required root outputs"
  value       = aws_s3_bucket.assets.bucket
}












# assets_bucket_name still pending — added once the S3 bucket for
# the serverless section (4.5) is written.



# output "github_actions_role_arn" {
#   description = "ARN of the IAM Role for GitHub Actions OIDC"
#   value       = aws_iam_role.github_actions_role.arn
# }

# # --- Outputs for debugging ---

# output "bedrock_dev_view_access_key_id" {
#   description = "Access key ID for the bedrock-dev-view IAM user — pair with the secret access key for kubectl/AWS CLI access scoped to retail-app"
#   value       = aws_iam_access_key.bedrock_dev_view.id
# }

# output "bedrock_dev_view_secret_access_key" {
#   description = "Secret access key for bedrock-dev-view — SENSITIVE. Record this in the exam's Deliverables doc, never commit it to git."
#   value       = aws_iam_access_key.bedrock_dev_view.secret
#   sensitive   = true
# }

# output "bedrock_dev_view_console_password" {
#   description = "Console login password for bedrock-dev-view user"
#   value       = aws_iam_user_login_profile.bedrock_dev_view.password
#   sensitive   = true
# }

# output "ui_ingress_hostname" {
#   description = "ALB hostname for the retail store UI — resolve after a few minutes for DNS propagation"
#   value       = kubernetes_ingress_v1.retail_ui.status[0].load_balancer[0].ingress[0].hostname
# }
