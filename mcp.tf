resource "kubernetes_secret_v1" "mcp" {
  count = var.enable_mcp_server ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-mcp-secrets"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
  }

  data = {
    "tfe-token" = var.mcp_tfe_token
  }
}

resource "kubernetes_pod_v1" "mcp" {
  count = var.enable_mcp_server ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-terraform-mcp"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
    labels = {
      app = "terraform-mcp"
    }
  }

  spec {
    container {
      name  = "terraform-mcp"
      image = var.mcp_image

      port {
        container_port = var.mcp_port
      }

      env {
        name  = "TRANSPORT_MODE"
        value = "streamable-http"
      }

      env {
        name  = "TRANSPORT_HOST"
        value = "0.0.0.0"
      }

      env {
        name  = "TRANSPORT_PORT"
        value = tostring(var.mcp_port)
      }

      env {
        name  = "MCP_ENDPOINT"
        value = var.mcp_endpoint
      }

      env {
        name  = "LOG_LEVEL"
        value = var.mcp_log_level
      }

      env {
        name  = "TFE_ADDRESS"
        value = var.mcp_tfe_address
      }

      env {
        name  = "MCP_CORS_MODE"
        value = "disabled"
      }

      env {
        name = "TFE_TOKEN"
        value_from {
          secret_key_ref {
            name = kubernetes_secret_v1.mcp[0].metadata[0].name
            key  = "tfe-token"
          }
        }
      }

      readiness_probe {
        tcp_socket {
          port = var.mcp_port
        }
        initial_delay_seconds = 10
        period_seconds        = 5
      }

      liveness_probe {
        tcp_socket {
          port = var.mcp_port
        }
        initial_delay_seconds = 30
        period_seconds        = 10
      }
    }
  }

  depends_on = [kubernetes_secret_v1.mcp]
}

resource "kubernetes_service_v1" "mcp" {
  count = var.enable_mcp_server ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-terraform-mcp"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_pod_v1.mcp[0].metadata[0].labels.app
    }

    port {
      name        = "http"
      port        = var.mcp_port
      target_port = var.mcp_port
      protocol    = "TCP"
    }

    type = var.mcp_service_type
  }

  wait_for_load_balancer = false
}
