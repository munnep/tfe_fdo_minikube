# Terraform Enterprise (TFE) FDO on Minikube (macOS)

This repository provides a complete **Terraform Enterprise (TFE) development environment** that runs locally on macOS, designed for testing, development, and learning purposes.

---

## Table of Contents

- [Overview & Architecture](#overview--architecture)
  - [Architecture Overview](#architecture-overview)
  - [Key Components](#key-components)
  - [Prerequisites](#prerequisites)
  - [Architecture Diagram](#architecture-diagram)
- [Step-by-Step Setup Guide](#step-by-step-setup-guide)
  - [1. Prepare Code & Configuration](#1-prepare-code--configuration)
  - [2. Podman Desktop Setup](#2-podman-desktop-setup)
  - [3. Minikube Setup](#3-minikube-setup)
  - [4. Cloudflare Configuration](#4-cloudflare-configuration)
  - [5. Deploy Terraform Enterprise](#5-deploy-terraform-enterprise)
  - [6. Post-Deployment Admin Setup](#6-post-deployment-admin-setup)
- [Optional Features & Add-ons](#optional-features--add-ons)
  - [MCP Server](#mcp-server)
  - [Squid Proxy Server](#squid-proxy-server)
  - [Monitoring (Prometheus & Grafana)](#monitoring-prometheus--grafana)
- [Operations & Troubleshooting](#operations--troubleshooting)
  - [Pre-Upgrade Check](#pre-upgrade-check)
  - [Teardown & Cleanup](#teardown--cleanup)
  - [DNS Troubleshooting (CoreDNS)](#dns-troubleshooting-coredns)

---

## Overview & Architecture

### Architecture Overview

The setup creates a production-like TFE environment using modern containerization and cloud-native technologies:

- **🖥️ Local Development**: Runs entirely on macOS using Podman Desktop plus a local Minikube Kubernetes cluster (Podman driver)
- **☁️ External Access**: Leverages Cloudflare tunnels for secure external connectivity without port forwarding
- **🔒 Enterprise Security**: Includes proper SSL certificates and DNS management through Cloudflare
- **📦 Microservices Architecture**: Deploys TFE alongside supporting services (PostgreSQL, SeaweedFS, Redis) as Kubernetes pods inside Minikube

### Key Components

- **Minikube**: Lightweight local Kubernetes cluster using the Podman driver and CRI-O container runtime
- **Terraform Enterprise**: Full TFE installation with persistent storage and session management
- **Cloudflare Integration**: Automated DNS records and secure tunnel connections for external access
- **Supporting Services**: PostgreSQL (database), SeaweedFS (S3-compatible storage), Redis (caching), and cloudflared (tunnel agent)

### Prerequisites

- macOS with sufficient resources (recommended: 6+ CPU cores, 12+ GB RAM)
- Cloudflare account with API token (DNS and Tunnel permissions required)
- Podman Desktop installed and configured

### Architecture Diagram

![](diagram/diagram_tfe_fdo_minikube.png)

---

## Step-by-Step Setup Guide

### 1. Prepare Code & Configuration

1. Clone this repository:
   ```bash
   git clone <repo-url>
   cd tfe_fdo_minikube
   ```
2. Copy the example variable file:
   ```bash
   cp variables.example variables.auto.tfvars
   ```

### 2. Podman Desktop Setup

Reference: [Podman Desktop macOS Installation Guide](https://podman-desktop.io/docs/installation/macos-install)

1. Install Podman Desktop using Homebrew:
   ```bash
   brew install --cask podman-desktop
   ```
2. Start Podman Desktop and initialize a Podman VM with at least 6 CPUs, 12 GB RAM, and 40 GB storage:
   ```bash
   podman machine init --cpus 12 --memory 16000 --disk-size 250
   ```
3. (Optional) Adjust an existing machine if needed:
   ```bash
   podman machine stop
   podman machine set --cpus 12 --memory 16000 --disk-size 260
   podman machine start
   ```

#### View in Podman Desktop
Under the **Containers** section you will see your created Minikube container:  
![](media/2025-10-27-14-18-58.png)

Also in the **Kubernetes -> Nodes** section:  
![](media/2025-10-27-14-19-56.png)

---

### 3. Minikube Setup

Reference: [Minikube Podman Driver Guide](https://minikube.sigs.k8s.io/docs/drivers/podman/)

1. Install Minikube using Homebrew:
   ```bash
   brew install minikube
   ```
2. Set the default driver to Podman:
   ```bash
   minikube config set driver podman
   ```
3. Start Minikube with required parameters:
   ```bash
   minikube start -p tfe --driver=podman --container-runtime=cri-o --kubernetes-version=v1.37.0 --cpus=6 --memory=10192
   ```
   > **Note:** Minikube puts the kubeconfig in `~/.kube/config` automatically. Set the full path in `variables.auto.tfvars` for `kubectl_config_path`.

4. Enable the metrics-server addon:
   ```bash
   minikube addons enable metrics-server -p tfe
   ```
   If the addon fails, apply manually:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   ```

5. (Optional) Access SeaweedFS and PostgreSQL locally:
   ```bash
   sudo minikube tunnel --profile=tfe
   ```
   The tunnel detects all services of type `LoadBalancer` and exposes them on `localhost`.

To stop Minikube when not in use:
```bash
minikube stop -p tfe
```

---

### 4. Cloudflare Configuration

Cloudflare manages the DNS A records and secure Cloudflare Tunnel to expose TFE externally without open inbound ports.

#### Create Cloudflare API Token
1. Log in to your Cloudflare account and navigate to [API Tokens](https://dash.cloudflare.com/profile/api-tokens).  
   ![](media/2025-10-27-13-45-05.png)
2. Click **Create Token**.  
   ![](media/2025-10-27-13-46-19.png)
3. Under **Custom token**, click **Get started**.  
   ![](media/2025-10-27-14-55-35.png)
4. Configure token permissions:
   - **Account** → `Cloudflare Tunnel` → `Edit`
   - **Zone** → `DNS` → `Edit`
5. Configure Zone/Account resources and TTL as needed, then click **Continue to summary** → **Create Token**.
6. Copy the token and set `cloudflare_api_token` in `variables.auto.tfvars`.
7. Set your Cloudflare account ID in `cloudflare_account_id`.

---

### 5. Deploy Terraform Enterprise

1. Update `variables.auto.tfvars` with your settings:
   ```hcl
   # General
   route53_zone        = "munnep.com"                     # Main domain
   route53_subdomain   = "tfe1"                           # Subdomain for TFE
   cert_email          = "patrick.munne@ibm.com"          # Email for certificate generation

   # Cloudflare
   cloudflare_account_id = "xxxxxx"                       # Cloudflare account ID
   cloudflare_api_token  = "xxxxxx"                       # API token for Cloudflare

   # TFE
   admin_username          = "admin"                      # Username for TFE admin user
   admin_email             = "patrick.munne@ibm.com"      # Email for TFE admin user
   admin_password          = "secret$321"                 # Password for TFE admin user
   tfe_encryption_password = "secret$321"                 # Encryption password for TFE
   release_sequence        = "1.0.2"                      # TFE container image version
   tfe_raw_license         = "xxxxxxxx"                   # License string for TFE
   ```

2. Initialize and deploy:
   ```bash
   terraform init
   terraform apply
   ```

3. Example Terraform output:
   ```text
   Plan: 22 to add, 0 to change, 0 to destroy.

   Outputs:
      cloudflare_delete_tunnel_command = "cloudflared tunnel delete tfe-tunnel-minikube"
      cloudflare_list_tunnels_command = "cloudflared tunnel list"
      cloudflare_login_command = "cloudflared login"
      minikube_delete_cluster = "minikube delete --profile=tfe"
      minikube_tunnel = "sudo minikube tunnel --profile=tfe"
      seaweedfs_filer_url = "http://localhost:8888/"
      postgres_url = "postgresql://postgres:postgresql@localhost:5432/postgres"
      tfe_execute_script_to_create_user_admin = "./scripts/configure_tfe.sh tfe1.munnep.com patrick.munne@ibm.com admin secret$321"
      tfe_url = "https://tfe1.munnep.com"
   ```

#### Cloudflare Tunnel UI Overview
![](media/2026-01-23-13-01-37.png)

---

### 6. Post-Deployment Admin Setup

Once `terraform apply` finishes and TFE pods become healthy, run the configuration script output by Terraform to provision the admin user and initial `test` organization:

```bash
./scripts/configure_tfe.sh <fqdn> <email> <username> <password>
```
*(Use the exact command printed in the `tfe_execute_script_to_create_user_admin` output.)*

---

## Optional Features & Add-ons

### MCP Server

This environment can expose an MCP endpoint so AI tools and agents can interact with Terraform Enterprise through the standard Model Context Protocol API.

- **Health check endpoint**: `https://mcp-<your-tfe-host>/health` (example: `https://mcp-tfe1.munnep.com/health`)
- **MCP Endpoint**: `https://mcp-<your-tfe-host>/mcp` (example: `https://mcp-tfe1.munnep.com/mcp`)
- **Authentication**: Pass `TFE_TOKEN` in HTTP headers
- **Capabilities**: Search workspaces, inspect runs, create runs, apply or discard runs via MCP tools

> **Security Note:** Store your `TFE_TOKEN` securely (e.g. environment variables or secret manager) and never commit it to git.

#### Example VS Code Configuration (`mcp.json` / `settings.json`)
```json
{
  "servers": {
    "terraform-mcp-server": {
      "url": "https://mcp-tfe1.munnep.com/mcp",
      "type": "http",
      "headers": {
        "TFE_TOKEN": "xxxxxxxxxxxxxxxxxxxxxxxxxx"
      }
    }
  },
  "inputs": []
}
```

---

### Squid Proxy Server

A Squid proxy server can be deployed into the cluster on port `3128` to test TFE in restricted environments requiring outbound proxy routing.

1. Enable the proxy in `variables.auto.tfvars`:
   ```hcl
   enable_proxy = true
   ```
2. Re-apply Terraform:
   ```bash
   terraform apply
   ```
3. Tail access logs:
   ```bash
   kubectl exec -n terraform-enterprise tfe-squid -- tail -f /var/log/squid/access.log
   ```

---

### Monitoring (Prometheus & Grafana)

Prometheus and Grafana are deployed automatically alongside TFE (`enable_monitoring = true` by default).

- **Grafana URL**: `https://grafana-<your-tfe-host>` (example: `https://grafana-tfe1.munnep.com`)
- **Default Credentials**: `admin` / `admin`
- The Prometheus datasource is provisioned automatically.

To disable monitoring in `variables.auto.tfvars`:
```hcl
enable_monitoring = false
```

#### Import the TFE Grafana Dashboard
1. Open Grafana and navigate to **Dashboards → Import**.
2. Enter Dashboard ID **15630** and click **Load**.
3. Select the **Prometheus** datasource and click **Import**.

> **Note:** Dashboard 15630 was designed for TFE standalone (Replicated). On Kubernetes/FDO, `tfe_container_*` metrics are not emitted, so container-level panels will show no data. Panels for runs, queue depth, and Sidekiq workers (`tfe_run_*`, `tfe_sidekiq_*`) will show data correctly.

---

## Operations & Troubleshooting

### Pre-Upgrade Check

Before upgrading TFE, run the Helm chart's pre-upgrade check job to validate the environment (archivist, config, database, Redis, license, TLS, version compatibility, VCS ingress). It reports passed checks, warnings, and failures.

Step-by-step instructions for running the check job are documented in [preupgrade/README.md](preupgrade/README.md).

---

### Teardown & Cleanup

`terraform destroy` removes the Kubernetes resources created by Terraform, but will **not** delete the Cloudflare tunnel or the Minikube VM automatically.

1. Destroy Terraform-managed resources:
   ```bash
   terraform destroy
   ```
2. Delete the Cloudflare tunnel manually:
   ```bash
   cloudflared tunnel delete tfe-tunnel-minikube
   ```
3. Delete the Minikube cluster:
   ```bash
   minikube delete -p tfe
   ```

---

### DNS Troubleshooting (CoreDNS)

If pods experience intermittent or failing external DNS resolution within Minikube:

1. Edit the CoreDNS ConfigMap:
   ```bash
   kubectl edit configmap coredns -n kube-system
   ```
2. Replace:
   ```text
   forward . /etc/resolv.conf
   ```
   with:
   ```text
   forward . 8.8.8.8 8.8.4.4 {
      max_concurrent 1000
   }
   ```
3. Restart your laptop if network routes or daemon states persist.
