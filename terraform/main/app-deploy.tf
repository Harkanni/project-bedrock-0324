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

# Rendered from values.yaml.tpl. Also written out to a committed
# values.yaml at the repo root (see local_file below) so the deployment
# satisfies the exam's "custom values.yaml committed to the repo,
# deployable via a single helm upgrade --install command" requirement —
# without duplicating this logic by hand in two places.
locals {
  retail_store_values = templatefile("${path.module}/values.yaml.tpl", {
    catalog_role_arn          = aws_iam_role.catalog_service.arn
    catalog_mysql_endpoint    = aws_db_instance.catalog_mysql.address
    catalog_mysql_database    = aws_db_instance.catalog_mysql.db_name
    orders_role_arn           = aws_iam_role.orders_service.arn
    orders_postgres_database  = aws_db_instance.orders_postgres.db_name
    orders_postgres_host      = aws_db_instance.orders_postgres.address
    orders_postgres_port      = tostring(aws_db_instance.orders_postgres.port)
    carts_role_arn            = aws_iam_role.carts_service.arn
    carts_dynamodb_table_name = aws_dynamodb_table.carts.name
  })
}

resource "helm_release" "retail_store" {
  name       = "retail-store"
  repository = "oci://public.ecr.aws/aws-containers"
  chart      = "retail-store-sample-chart"
  version    = var.retail_store_chart_version
  namespace  = local.app_namespace

  # Values live in values.yaml.tpl now, not inline — see locals above.
  # Every key in that template was checked against the REAL subchart
  # values.yaml files (helm pull --untar + cat charts/*/values.yaml)
  # after an earlier apply failed on made-up key names — not guessed
  # from documentation for a different deployment method.
  values = [local.retail_store_values]

  depends_on = [
    kubernetes_manifest.externalsecret_catalog,
    kubernetes_manifest.externalsecret_orders,
    aws_dynamodb_table.carts,
  ]
}

# Commits the rendered values to the repo root as a real, reviewable
# file — satisfies "custom values.yaml committed to your repository"
# from exam 5.1, and stays in sync automatically since RDS endpoints
# change on every destroy/recreate (e.g. the pause/resume cycle).
resource "local_file" "retail_store_values" {
  content  = local.retail_store_values
  filename = "${path.module}/../../values.yaml"
}