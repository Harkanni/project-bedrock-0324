# ------------------------------------------------------------------------------
# 1. GENERATE PRIVATE KEY & WILDCARD TLS CERTIFICATE
# ------------------------------------------------------------------------------

# Generate a 2048-bit RSA Private Key
resource "tls_private_key" "nip_io" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a Self-Signed Certificate covering ALL nip.io subdomains dynamically
resource "tls_self_signed_cert" "nip_io" {
  private_key_pem = tls_private_key.nip_io.private_key_pem

  subject {
    common_name  = "nip.io"
    organization = "AltSchool Bedrock Capstone"
  }

  validity_period_hours = 8760 # 1 Year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    "nip.io",
    "*.nip.io",
    "*.nip.io",
    "*.nip.io",
  ]
}

# ------------------------------------------------------------------------------
# 2. IMPORT CERTIFICATE DIRECTLY INTO AWS ACM
# ------------------------------------------------------------------------------

resource "aws_acm_certificate" "imported_nip_io" {
  private_key      = tls_private_key.nip_io.private_key_pem
  certificate_body = tls_self_signed_cert.nip_io.cert_pem

  tags = {
    Name        = "project-bedrock-cert"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# 3. KUBERNETES INGRESS WITH CATCH-ALL ROUTING
# ------------------------------------------------------------------------------

resource "kubernetes_ingress_v1" "retail_store_ui" {
  metadata {
    name      = "retail-store-ui"
    namespace = "retail-app"

    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/certificate-arn"      = aws_acm_certificate.imported_nip_io.arn
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": {\"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
    }
  }

  spec {
    rule {
      http {
        # 1. Intercept path and route to redirect action
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "ssl-redirect"
              port {
                name = "use-annotation"
              }
            }
          }
        }

        # 2. Main application path
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

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
}
