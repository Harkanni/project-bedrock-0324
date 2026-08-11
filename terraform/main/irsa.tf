locals {
  app_namespace = "retail-app"
}

# --- OIDC Provider ----------------------------------------------------------
# EKS clusters each get a unique OIDC issuer. Registering it as an IAM
# identity provider is what makes IRSA possible at all — without this,
# Kubernetes service accounts have no way to assume an AWS IAM role.

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

# --- IRSA: carts service -> DynamoDB ----------------------------------------
# Scoped to exactly one table, exactly the actions the carts service
# needs (item-level read/write) — not "DynamoDB full access."

resource "aws_iam_role" "carts_service" {
  name = "project-bedrock-carts-service-role"

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
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${local.app_namespace}:retail-store-carts"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "carts_dynamodb" {
  name = "project-bedrock-carts-dynamodb-policy"
  role = aws_iam_role.carts_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
      ]
      # Table ARN covers direct item lookups by "id"; the /index/* ARN
      # is required separately — querying a GSI (idx_global_customerId)
      # is a distinct IAM resource from the base table, confirmed by the
      # AccessDenied error naming the index ARN specifically.
      Resource = [
        aws_dynamodb_table.carts.arn,
        "${aws_dynamodb_table.carts.arn}/index/*",
      ]
    }]
  })
}

# --- IRSA: catalog service -> Secrets Manager (MySQL creds only) ------------

resource "aws_iam_role" "catalog_service" {
  name = "project-bedrock-catalog-service-role"

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
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${local.app_namespace}:retail-store-catalog"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "catalog_secrets" {
  name = "project-bedrock-catalog-secrets-policy"
  role = aws_iam_role.catalog_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.mysql.arn
    }]
  })
}

# --- IRSA: orders service -> Secrets Manager (Postgres creds only) ----------

resource "aws_iam_role" "orders_service" {
  name = "project-bedrock-orders-service-role"

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
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${local.app_namespace}:retail-store-orders"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "orders_secrets" {
  name = "project-bedrock-orders-secrets-policy"
  role = aws_iam_role.orders_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.postgres.arn
    }]
  })
}
