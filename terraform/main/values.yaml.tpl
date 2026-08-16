# Rendered by Terraform (see app-deploy.tf) into a committed values.yaml
# at the repo root on every `terraform apply`. Don't hand-edit the
# generated values.yaml directly — edit this template instead, since
# RDS endpoints change on every destroy/recreate cycle and Terraform
# is what keeps this file in sync with reality.

catalog:
  serviceAccount:
    annotations:
      # Not for the catalog app's own AWS calls (it doesn't make any) —
      # this is so External Secrets Operator can assume this exact role
      # when authenticating as the "catalog" service account (see
      # external-secrets.tf SecretStore).
      eks.amazonaws.com/role-arn: ${catalog_role_arn}
  mysql:
    create: false # disable the chart's own throwaway in-cluster MySQL
    endpoint: ${catalog_mysql_endpoint}
    database: ${catalog_mysql_database}
    secret:
      create: false        # ESO supplies this secret, not Helm
      name: catalog-db     # must match chart default exactly

orders:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: ${orders_role_arn}
  postgresql:
    create: false
    database: ${orders_postgres_database}
    endpoint:
      host: ${orders_postgres_host}
      port: "${orders_postgres_port}"
    secret:
      create: false
      name: orders-db
  # rabbitmq intentionally left on chart defaults (in-cluster) — not in
  # scope for this exam's data-layer requirements.

carts:
  serviceAccount:
    annotations:
      # carts DOES call AWS directly (DynamoDB item operations), unlike
      # catalog/orders — this role is used by the running pod itself,
      # not just by ESO.
      eks.amazonaws.com/role-arn: ${carts_role_arn}
  dynamodb:
    create: false      # disable the chart's dynamodb-local dev container
    createTable: false # table already exists — Terraform manages it
    tableName: ${carts_dynamodb_table_name}

# Internal-only ClusterIP for now — the ALB/Ingress step comes next
# and will expose the ui service properly.
ui:
  service:
    type: ClusterIP
  endpoints:
    assets: http://retail-store-assets:80
    carts: http://retail-store-carts:80
    catalog: http://retail-store-catalog:80
    checkout: http://retail-store-checkout:80
    orders: http://retail-store-orders:80