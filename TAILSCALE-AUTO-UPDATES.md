# Tailscale Auto-Updates Configuration

## Overview

This document explains how Tailscale auto-updates are configured for both physical nodes and Kubernetes-managed services.

## 1. Physical Nodes (beelink, worker)

For physical nodes running Tailscale client directly on the OS, auto-updates are enabled using the `tailscale set --auto-update` command.

### Configuration Steps:

```bash
# On each node (beelink, worker)
sudo tailscale set --auto-update
sudo tailscale up --ssh --accept-routes
```

### Verification:

```bash
tailscale status
# Or check the Tailscale admin console at https://login.tailscale.com/admin/machines
```

### What This Does:

- ✅ Tailscale will automatically update itself when new versions are released
- ✅ Updates use the same package manager that installed Tailscale (apt-get for Ubuntu)
- ✅ Updates happen even if the client is disconnected from Tailscale
- ✅ Updates are scheduled automatically to minimize disruption
- ✅ Security updates may be applied faster than regular updates

---

## 2. Kubernetes Ingress Pods (argocd, bazarr, grafana, etc.)

For Tailscale ingress pods created by the Tailscale Kubernetes Operator, auto-updates work differently:

### How It Works:

1. **Tailscale Operator** is managed by ArgoCD using a Helm chart
2. **Renovate Bot** automatically detects new Tailscale operator versions
3. **Renovate creates PRs** for minor/patch updates
4. **Auto-merge** is enabled for minor updates (configured in `renovate.json`)
5. **ArgoCD syncs** the new version automatically after PR merge
6. **All ingress pods** are automatically updated to match the operator version

### Architecture:

```
Tailscale Helm Chart (v1.78.3 → v1.90.8)
    ↓
Renovate Bot detects update
    ↓
Creates PR with new version
    ↓
Auto-merges (minor updates)
    ↓
ArgoCD syncs new Helm chart
    ↓
Operator pod restarts with new version
    ↓
All ingress pods (argocd, bazarr, grafana, etc.) restart with new version
```

### Files Involved:

- **`argocd-apps/tailscale-operator.yaml`** - ArgoCD Application manifest
- **`apps/tailscale-operator/custom-values.yaml`** - Helm values configuration
- **`renovate.json`** - Renovate Bot configuration (auto-merge rules)

### Current Configuration:

```yaml
# argocd-apps/tailscale-operator.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tailscale-operator
  namespace: argocd
spec:
  sources:
    # renovate: registryUrl=https://pkgs.tailscale.com/helmcharts
    - repoURL: 'https://pkgs.tailscale.com/helmcharts'
      chart: tailscale-operator
      targetRevision: 1.78.3  # Auto-updated by Renovate
      helm:
        valueFiles:
          - $values/apps/tailscale-operator/custom-values.yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Renovate Auto-Merge Configuration:

```json
{
  "description": "Auto-merge minor updates for stable apps",
  "matchUpdateTypes": ["minor"],
  "matchPackagePatterns": [
    "tailscale-operator"
  ],
  "automerge": true,
  "automergeType": "pr",
  "automergeStrategy": "squash"
}
```

### Verification:

```bash
# Check operator version
kubectl get deployment operator -n tailscale -o yaml | grep image:

# Check ingress pod versions
kubectl get pods -n tailscale -o yaml | grep "image: tailscale"

# Check ArgoCD application status
kubectl get application tailscale-operator -n argocd
```

---

## 3. Affected Services

The following Tailscale ingress pods will be automatically updated:

- **argocd** (100.89.68.67)
- **bazarr** (100.89.140.19)
- **grafana** (100.65.10.107)
- **home-assistant**
- **homepage**
- **jackett**
- **jellyfin**
- **jellyseerr**
- **longhorn**
- **minio**
- **opencost**
- **qbitt**
- **radarr**
- **sonarr**
- **tdarr**
- **uptime-kuma**

All these pods are created by the Tailscale Operator and will automatically use the operator's version.

---

## 4. Update Frequency

- **Physical nodes**: Updates happen automatically within ~1 week of release
- **Kubernetes pods**: Updates happen via Renovate PRs (weekly schedule)
  - Patch updates: Auto-merged immediately
  - Minor updates: Auto-merged immediately
  - Major updates: Require manual review

---

## 5. Manual Updates (if needed)

### Physical Nodes:

```bash
sudo tailscale update
```

### Kubernetes Operator:

```bash
# Update to latest version
helm upgrade tailscale-operator tailscale/tailscale-operator \
  --namespace tailscale \
  --reuse-values \
  --version <NEW_VERSION>
```

Or simply merge the Renovate PR in GitHub.

---

## 6. Monitoring

- **Tailscale Admin Console**: https://login.tailscale.com/admin/machines
- **ArgoCD UI**: Check `tailscale-operator` application status
- **Renovate Dashboard**: Check for pending Tailscale updates in GitHub Issues

---

## References

- [Tailscale Auto-Updates Documentation](https://tailscale.com/kb/1067/update)
- [Tailscale Kubernetes Operator Documentation](https://tailscale.com/kb/1236/kubernetes-operator)
- [Renovate Bot Documentation](https://docs.renovatebot.com/)

