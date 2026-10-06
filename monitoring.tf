# ─── TFE Headless Metrics Service ────────────────────────────────────────────
# Headless so DNS resolves to all pod IPs — Prometheus scrapes each pod individually.

resource "kubernetes_service_v1" "tfe_metrics" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-metrics"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
  }

  spec {
    selector = {
      app = "terraform-enterprise"
    }

    cluster_ip = "None"

    port {
      name        = "metrics"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }
  }
}

# ─── Prometheus ConfigMap ────────────────────────────────────────────────────

resource "kubernetes_config_map_v1" "prometheus_config" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-prometheus-config"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
  }

  data = {
    "prometheus.yml" = <<-YAML
      global:
        scrape_interval: 5s
        evaluation_interval: 5s
      scrape_configs:
        - job_name: 'tfe'
          params:
            format:
              - prometheus
          dns_sd_configs:
            - names:
                - '${var.tag_prefix}-metrics.${kubernetes_namespace_v1.terraform_enterprise.metadata[0].name}.svc.cluster.local'
              type: A
              port: 9090
    YAML
  }

  depends_on = [kubernetes_service_v1.tfe_metrics]
}

# ─── Prometheus Pod ──────────────────────────────────────────────────────────

resource "kubernetes_pod_v1" "prometheus" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-prometheus"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    container {
      name  = "prometheus"
      image = var.image_prometheus

      port {
        container_port = 9090
      }

      volume_mount {
        name       = "config"
        mount_path = "/etc/prometheus/prometheus.yml"
        sub_path   = "prometheus.yml"
      }

      readiness_probe {
        tcp_socket {
          port = 9090
        }
        initial_delay_seconds = 10
        period_seconds        = 5
      }

      liveness_probe {
        tcp_socket {
          port = 9090
        }
        initial_delay_seconds = 30
        period_seconds        = 10
      }
    }

    volume {
      name = "config"
      config_map {
        name = kubernetes_config_map_v1.prometheus_config[0].metadata[0].name
      }
    }
  }

  depends_on = [kubernetes_config_map_v1.prometheus_config]
}

# ─── Prometheus Service ──────────────────────────────────────────────────────

resource "kubernetes_service_v1" "prometheus" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-prometheus"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_pod_v1.prometheus[0].metadata[0].labels.app
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# ─── Grafana Provisioning ConfigMap ─────────────────────────────────────────

resource "kubernetes_config_map_v1" "grafana_provisioning" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-grafana-provisioning"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
  }

  data = {
    "datasources.yaml" = <<-YAML
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://${var.tag_prefix}-prometheus.${kubernetes_namespace_v1.terraform_enterprise.metadata[0].name}.svc.cluster.local:9090
          access: proxy
          isDefault: true
          jsonData:
            scrapeInterval: 5s
            timeInterval: 5s
    YAML
  }
}

# ─── Grafana Pod ─────────────────────────────────────────────────────────────

resource "kubernetes_pod_v1" "grafana" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-grafana"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    container {
      name  = "grafana"
      image = var.image_grafana

      port {
        container_port = 3000
      }

      env {
        name  = "GF_SERVER_ROOT_URL"
        value = "https://grafana-${local.fqdn}"
      }

      volume_mount {
        name       = "provisioning"
        mount_path = "/etc/grafana/provisioning/datasources"
        read_only  = true
      }

      readiness_probe {
        tcp_socket {
          port = 3000
        }
        initial_delay_seconds = 10
        period_seconds        = 5
      }

      liveness_probe {
        tcp_socket {
          port = 3000
        }
        initial_delay_seconds = 30
        period_seconds        = 10
      }
    }

    volume {
      name = "provisioning"
      config_map {
        name = kubernetes_config_map_v1.grafana_provisioning[0].metadata[0].name
      }
    }
  }

  depends_on = [kubernetes_config_map_v1.grafana_provisioning]
}

# ─── Grafana Service ─────────────────────────────────────────────────────────

resource "kubernetes_service_v1" "grafana" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "${var.tag_prefix}-grafana"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_pod_v1.grafana[0].metadata[0].labels.app
    }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
