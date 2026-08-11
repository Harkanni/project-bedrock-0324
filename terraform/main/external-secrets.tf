# Each SecretStore authenticates as that service's OWN IRSA role (from
# irsa.tf) via its own Kubernetes service account — not a shared ESO
# "god" credential. catalog's SecretStore can only ever reach the MySQL
# secret; orders' can only ever reach the Postgres secret.

resource "kubernetes_manifest" "secretstore_catalog" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "catalog-secret-store"
      namespace = local.app_namespace
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name = "retail-store-catalog"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets, kubernetes_namespace.retail_app]
}

resource "kubernetes_manifest" "externalsecret_catalog" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "catalog-external-secret"
      namespace = local.app_namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "catalog-secret-store"
        kind = "SecretStore"
      }
      target = {
        # Matches the chart's default catalog.mysql.secret.name exactly —
        # confirmed via the real subchart values.yaml, not assumed.
        name = "catalog-db"
      }
      data = [
        {
          secretKey = "username"
          remoteRef = {
            key      = aws_secretsmanager_secret.mysql.name
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = aws_secretsmanager_secret.mysql.name
            property = "password"
          }
        },
      ]
    }
  }

  depends_on = [kubernetes_manifest.secretstore_catalog]
}

resource "kubernetes_manifest" "secretstore_orders" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "orders-secret-store"
      namespace = local.app_namespace
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name = "retail-store-orders"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets, kubernetes_namespace.retail_app]
}

resource "kubernetes_manifest" "externalsecret_orders" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "orders-external-secret"
      namespace = local.app_namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "orders-secret-store"
        kind = "SecretStore"
      }
      target = {
        name = "orders-db"
      }
      data = [
        {
          secretKey = "username"
          remoteRef = {
            key      = aws_secretsmanager_secret.postgres.name
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = aws_secretsmanager_secret.postgres.name
            property = "password"
          }
        },
      ]
    }
  }

  depends_on = [kubernetes_manifest.secretstore_orders]
}
