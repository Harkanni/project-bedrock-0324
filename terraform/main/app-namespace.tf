# --- Namespace --------------------------------------------------------------
# Everything app-related lives here. This is also the namespace the IRSA
# trust policies in irsa.tf are scoped to — must match exactly.

resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = local.app_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main, aws_eks_access_policy_association.admin] 
}
# The retail app's catalog/orders services expect their DB credentials as
# a plain Kubernetes Secret (that's how the chart is written) — they don't
# call AWS Secrets Manager themselves. ESO is the bridge: it watches AWS
# Secrets Manager and syncs values into real Kubernetes Secrets, using the
# IRSA roles from irsa.tf for auth (one SecretStore per app, using that
# app's own service account — no shared "god" credential).

resource "helm_release" "external_secrets" {
  name = "external-secrets"
  # OCI source instead of the classic https://charts.external-secrets.io
  # index — some corporate networks (TLS inspection, proxies) truncate
  # the classic repo's index.yaml download. OCI uses a different
  # protocol path and tends to route around that.
  repository       = "oci://ghcr.io/external-secrets/charts"
  chart            = "external-secrets"
  version          = "0.10.5"
  namespace        = "kube-system"
  create_namespace = false

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [aws_eks_node_group.main]
}
