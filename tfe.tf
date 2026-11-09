locals {
  effective_registry_url      = var.tfe_beta_release ? var.beta_registry_images_url : var.registry_images_url
  effective_registry_username = var.tfe_beta_release ? var.tfe_beta_release_user : var.registry_username
  effective_registry_password = var.tfe_beta_release ? var.tfe_beta_release_password : var.tfe_raw_license

  # redis_host = var.use_valkey ? "${var.tag_prefix}-valkey.${var.dep_namespace}" : "${var.tag_prefix}-redis.${var.dep_namespace}"
}

resource "kubernetes_secret_v1" "terraform-enterprise" {
  metadata {
    name      = "terraform-enterprise"
    namespace = kubernetes_namespace_v1.terraform_enterprise.metadata.0.name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (local.effective_registry_url) = {
          "username" = local.effective_registry_username
          "password" = local.effective_registry_password
          "auth"     = base64encode("${local.effective_registry_username}:${local.effective_registry_password}")
        }
      }
    })
  }
}


resource "helm_release" "tfe" {
  name            = "${var.tag_prefix}-tfe"
  repository      = "https://helm.releases.hashicorp.com"
  chart           = "terraform-enterprise"
  # chart           = "/Users/patrick/git/TFE/terraform-enterprise-helm2"
  namespace       = kubernetes_namespace_v1.terraform_enterprise.metadata.0.name
  version         = var.tfe_helm_chart_version
  cleanup_on_fail = true


  values = [
    templatefile("${path.module}/overrides.yaml", {
      tag_prefix          = var.tag_prefix
      replica_count       = var.replica_count
      enc_password        = var.tfe_encryption_password
      pg_dbname           = kubernetes_secret_v1.postgres.data.POSTGRES_DB
      pg_user             = kubernetes_secret_v1.postgres.data.POSTGRES_USER
      pg_password         = kubernetes_secret_v1.postgres.data.POSTGRES_PASSWORD
      pg_address          = "${kubernetes_service_v1.postgres.metadata[0].name}.${kubernetes_namespace_v1.terraform_enterprise.metadata.0.name}.svc.cluster.local:${kubernetes_service_v1.postgres.spec[0].port[0].port}"
      fqdn                = local.fqdn
      s3_bucket           = "${var.tag_prefix}-bucket"
      s3_bucket_key       = var.seaweedfs_access_key
      s3_bucket_secret    = var.seaweedfs_secret_key
      s3_endpoint         = "http://${kubernetes_service_v1.seaweedfs.metadata[0].name}.${kubernetes_namespace_v1.terraform_enterprise.metadata.0.name}.svc.cluster.local:${kubernetes_service_v1.seaweedfs.spec[0].port[0].port}"
      cert_data           = base64encode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}")
      key_data            = base64encode(nonsensitive(acme_certificate.certificate.private_key_pem))
      ca_cert_data        = base64encode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}")
      redis_host          = "${var.tag_prefix}-redis.${kubernetes_namespace_v1.terraform_enterprise.metadata.0.name}.svc.cluster.local"
      redis_port          = "6379"
      tfe_license         = var.tfe_raw_license
      tfe_release         = var.release_sequence
      tfe_beta_release    = var.tfe_beta_release
      registry_images_url = local.effective_registry_url
      enable_proxy        = var.enable_proxy
      namespace           = kubernetes_namespace_v1.terraform_enterprise.metadata.0.name
    })
  ]

  timeout = var.tfe_helm_release_timeout
}

output "tfe_execute_script_to_create_user_admin" {
  value = "./scripts/configure_tfe.sh ${local.fqdn} ${var.admin_email} ${var.admin_username} ${var.admin_password}"
}

output "tfe_url" {
  value = "https://${local.fqdn}"  
}

output "tfe_admin_console" {
  value = "https://admin-${local.fqdn}"  
}