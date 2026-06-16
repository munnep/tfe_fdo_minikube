# General
variable "route53_zone" {
  description = "The domain used in the URL."
  type        = string
}

variable "route53_subdomain" {
  description = "the subdomain of the url"
  type        = string
}

variable "cert_email" {
  description = "Email address used to obtain ssl certificate."
  type        = string
}

variable "kubectl_config_path" {
  description = "Path to the kube config file."
  type        = string
  default     = "~/.kube/config"
}

variable "kubectl_context" {
  description = "The context to use within the kube config file."
  type        = string
  default     = "tfe"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy resources into."
  type        = string
  default     = "terraform-enterprise"
}

variable "tag_prefix" {
  description = "Prefix for naming Kubernetes resources."
  type        = string
  default     = "tfe"
}

# Cloudflare
variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "cloudflare_api_token" {
  description = "API token for Cloudflare DNS challenge."
  type        = string
}

# SeaweedFS
variable "seaweedfs_access_key" {
  description = "SeaweedFS access key."
  type        = string
  default = "admin"
}

variable "seaweedfs_secret_key" {
  description = "SeaweedFS secret key."
  type        = string
  default = "password"
}

variable "image_seaweedfs" {
  description = "SeaweedFS docker image."
  type        = string
  default = "docker.io/chrislusf/seaweedfs:4.09"
}

# Postgres
variable "postgres_user" {
  description = "Postgres username."
  type        = string
  default = "postgres"
}

variable "postgres_password" {
  description = "Postgres password."
  type        = string
  default     = "postgresql"
}

variable "postgres_db" {
  description = "Postgres database name."
  type        = string
  default     = "tfe"
}

variable "postgres_db_explorer" {
  description = "Second Postgres database name."
  type        = string
  default     = "tfe_explorer"
}

variable "image_postgres" {
  description = "Postgres docker image."
  type        = string
  default     = "docker.io/library/postgres:16"
}

variable "image_pgbouncer" {
  description = "PgBouncer docker image."
  type        = string
  default     = "docker.io/edoburu/pgbouncer:v1.25.1-p0"
}

variable "image_haproxy" {
  description = "HAProxy docker image."
  type        = string
  default     = "docker.io/library/haproxy:2.8.18"
}

# Redis
variable "image_redis" {
  description = "Redis docker image."
  type        = string
  default     = "docker.io/library/redis:7"
}

# Squid
variable "image_squid" {
  description = "Squid proxy docker image."
  type        = string
  default     = "docker.io/ubuntu/squid:latest"
}

# AWS
variable "aws_region" {
  description = "AWS region where the S3 bucket is created."
  type        = string
  default     = "eu-west-1"
}

variable "aws_s3_bucket_prefix" {
  description = "Prefix used for the S3 bucket name."
  type        = string
  default     = "tfe-bucket"
}

variable "enable_proxy" {
  description = "Enable the Squid proxy server and configure TFE to use it."
  type        = bool
  default     = false
}

# TFE
variable "tfe_encryption_password" {
  description = "Password used to encrypt TFE data."
  type        = string
}

variable "admin_username" {
  description = "Username for the TFE admin account."
  type        = string
}

variable "admin_email" {
  description = "Email address for the TFE admin account."
  type        = string
}

variable "admin_password" {
  description = "Password for the TFE admin account."
  type        = string
}

variable "release_sequence" {
  description = "Release number of the TFE version you wish to install."
  type        = string
}

variable "registry_username" {
  description = "Username to download docker tfe image."
  type        = string
  default     = "terraform"
}

variable "registry_images_url" {
  description = "URL for the images registry to download docker tfe image."
  type        = string
  default     = "images.releases.hashicorp.com"
}

variable "tfe_raw_license" {
  description = "The raw TFE license string"
  type        = string
}

variable "replica_count" {
  description = "Number of replicas (pods)."
  type        = number
  default     = 1
}

# MCP server
variable "enable_mcp_server" {
  description = "Enable deployment of a Terraform MCP server pod."
  type        = bool
  default     = true
}

variable "mcp_image" {
  description = "Container image for the Terraform MCP server."
  type        = string
  default     = "docker.io/hashicorp/terraform-mcp-server:1.0.0"
}

variable "mcp_port" {
  description = "Port used by the Terraform MCP server container and service."
  type        = number
  default     = 8080
}

variable "mcp_log_level" {
  description = "Log level for the Terraform MCP server."
  type        = string
  default     = "info"
}

variable "mcp_tfe_address" {
  description = "Terraform Enterprise address used by the MCP server."
  type        = string
  default     = "https://tfe1.munnep.com"
}

variable "mcp_tfe_token" {
  description = "Terraform Enterprise token used by the MCP server."
  type        = string
  sensitive   = true
  default     = ""
}

variable "mcp_service_type" {
  description = "Kubernetes Service type for the MCP server."
  type        = string
  default     = "ClusterIP"
}

variable "mcp_endpoint" {
  description = "HTTP endpoint path exposed by the MCP server."
  type        = string
  default     = "/mcp"
}

