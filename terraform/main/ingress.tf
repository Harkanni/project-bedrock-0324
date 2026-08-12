resource "kubernetes_ingress_v1" "retail_ui" {
  metadata {
    name      = "retail-store-ui"
    namespace = local.app_namespace

    annotations = {
      "kubernetes.io/ingress.class"      = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      # IP mode is required for pods on EKS's own VPC CNI (each pod gets
      # a real VPC IP) — "instance" mode would route to node ports
      # instead, which works too but adds an extra network hop.
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/actuator/health"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "retail-store-ui"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.alb_controller, helm_release.retail_store]
}

