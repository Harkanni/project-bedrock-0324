# IMPORTANT: verify this is still the latest published chart version
# before applying — run:
#   helm show chart oci://public.ecr.aws/aws-containers/retail-store-sample-chart
# and update the default below if a newer one exists.
# Confirmed 0.8.5 via that exact command on 2026-08-09.
variable "retail_store_chart_version" {
  description = "Version of the retail-store-sample-chart to deploy"
  type        = string
  default     = "0.8.5"
}

resource "helm_release" "retail_store" {
  name       = "retail-store"
  repository = "oci://public.ecr.aws/aws-containers"
  chart      = "retail-store-sample-chart"
  version    = var.retail_store_chart_version
  namespace  = local.app_namespace

  # Every key below was checked against the REAL subchart values.yaml
  # files (helm pull --untar + cat charts/*/values.yaml) after an
  # earlier apply failed on made-up key names — not guessed from
  # documentation for a different deployment method.
  values = [
    yamlencode({
      catalog = {
        serviceAccount = {
          annotations = {
            # Not for the catalog app's own AWS calls (it doesn't make
            # any) — this is so External Secrets Operator can assume
            # this exact role when authenticating as the "catalog"
            # service account (see external-secrets.tf SecretStore).
            "eks.amazonaws.com/role-arn" = aws_iam_role.catalog_service.arn
          }
        }
        mysql = {
          create   = false # disable the chart's own throwaway in-cluster MySQL
          endpoint = aws_db_instance.catalog_mysql.address
          database = aws_db_instance.catalog_mysql.db_name
          secret = {
            create = false        # ESO supplies this secret, not Helm
            name   = "catalog-db" # must match chart default exactly
          }
        }
      }

      orders = {
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.orders_service.arn
          }
        }
        postgresql = {
          create   = false
          database = aws_db_instance.orders_postgres.db_name
          endpoint = {
            host = aws_db_instance.orders_postgres.address
            port = tostring(aws_db_instance.orders_postgres.port)
          }
          secret = {
            create = false
            name   = "orders-db"
          }
        }
        # rabbitmq intentionally left on chart defaults (in-cluster) —
        # not in scope for this exam's data-layer requirements.
      }

      carts = {
        serviceAccount = {
          annotations = {
            # carts DOES call AWS directly (DynamoDB item operations),
            # unlike catalog/orders — this role is used by the running
            # pod itself, not just by ESO.
            "eks.amazonaws.com/role-arn" = aws_iam_role.carts_service.arn
          }
        }
        dynamodb = {
          create      = false # disable the chart's dynamodb-local dev container
          createTable = false # table already exists — Terraform manages it
          tableName   = aws_dynamodb_table.carts.name
        }
      }

      # Internal-only ClusterIP for now — the ALB/Ingress step comes next
      # and will expose the ui service properly.
      ui = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [
    kubernetes_manifest.externalsecret_catalog,
    kubernetes_manifest.externalsecret_orders,
    aws_dynamodb_table.carts,
  ]
}
