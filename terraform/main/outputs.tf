# Exam requires the root module to output exactly these five values.
# cluster_endpoint / cluster_name / assets_bucket_name get filled in
# once we write the EKS and S3 configs — left as placeholders (commented)
# so this file doesn't reference resources that don't exist yet.

output "vpc_id" {
  description = "ID of the Project Bedrock VPC"
  value       = aws_vpc.main.id
}

output "region" {
  description = "AWS region resources are deployed in"
  value       = var.aws_region
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

# assets_bucket_name still pending — added once the S3 bucket for
# the serverless section (4.5) is written.
# output "assets_bucket_name" {
#   value = aws_s3_bucket.assets.id
# }
