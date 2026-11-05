# TFE Pre-Upgrade Check

Run the Helm chart's pre-upgrade check job before upgrading Terraform Enterprise.

| Item | Value |
|---|---|
| Namespace | `terraform-enterprise` |
| Release | `tfe-tfe` |
| Current version | `2.1.0` (chart `2.0.8` deployed) |
| Target version | `2.1.1` |

## 1. Check the current Helm release

```bash
helm -n terraform-enterprise ls
```

Example output:

```text
NAME    NAMESPACE               REVISION  UPDATED                               STATUS    CHART                       APP VERSION
tfe-tfe terraform-enterprise    6         2026-11-02 10:26:15.390526 +0100 CET  deployed  terraform-enterprise-2.0.8  2.0.8
```

## 2. Export the current values

```bash
helm get values tfe-tfe -n terraform-enterprise -a -o yaml > override.yaml
```

## 3. Render the pre-upgrade job

```bash
helm template tfe-tfe hashicorp/terraform-enterprise \
  -n terraform-enterprise \
  --version 2.1.1 \
  -f override.yaml \
  --set preupgradeCheck.enabled=true \
  --set preupgradeCheck.tfeNamespace=true \
  --set image.tag=2.1.1 \
  --show-only templates/preupgrade-check-job.yaml \
  > preupgrade.yaml
```

## 4. Run the job

```bash
kubectl apply -n terraform-enterprise -f preupgrade.yaml
```

## 5. Read the result


```bash
kubectl logs -n terraform-enterprise job/terraform-enterprise-preupgrade-check -f
```

It is better to look at the pod itself
```bash
kubectl logs -n terraform-enterprise <pod_name>
```

Example output:

```text
Terraform Enterprise Pre-Upgrade Check
Current environment version: 2.1.0
Target version: 2.1.1
---
✓ archivist
  ✓ write_access

✓ config
  ✓ general

✓ database
  ✓ connection
  ✓ extensions
  ✓ user_permissions
  ✓ version

✓ explorer_database
  ✓ connection

✓ license
  ✓ valid_license

✓ redis
  ✓ config
  ✓ connection
  ✓ permissions
  ✓ version

✓ tls
  ✓ ca_bundle

⚠ upgrade
  ✓ public_registration_disabled
  ⚠ validation
    Warning: Version compatibility check warning: current and target versions are not inter-compatible. Downtime is required to run this version.

⚠ vcs-ingress
  ⚠ agent_ingress_default
    Warning: As of TFE 2.1.0, VCS ingress uses agent jobs by default. For emergency fallback to legacy slug-ingress, set TFE_VCS_INGRESS_SLUG_INGRESS_FALLBACK=true and restart TFE. This fallback will be deprecated and removed in a future release.

Status: WARNING | Time: 1.1s | Checks: 14 Passed, 2 Warning, 0 Failed

Pre-upgrade checks indicate this environment is ready to upgrade to 2.1.1.
but review the warnings above to ensure they are acceptable.
```

### Warnings in this run

| Check | Meaning |
|---|---|
| `upgrade / validation` | Current and target versions are not inter-compatible. **Downtime is required.** |
| `vcs-ingress / agent_ingress_default` | Since 2.1.0, VCS ingress uses agent jobs by default. Emergency fallback: set `TFE_VCS_INGRESS_SLUG_INGRESS_FALLBACK=true` and restart TFE (will be deprecated). |

## 6. Clean up

```bash
kubectl delete job/terraform-enterprise-preupgrade-check -n terraform-enterprise
```

```bash
kubectl delete secret/terraform-enterprise-preupgrade-check-overrides -n terraform-enterprise
```
