# GitOps Deployment Guide - Media Server Stack

## Overview

This media server stack is deployed using **ArgoCD** following GitOps principles. This means:

- ✅ Git is the single source of truth
- ✅ All changes are version controlled
- ✅ ArgoCD automatically syncs cluster state with Git
- ✅ Easy rollback to previous versions
- ✅ Audit trail of all changes

## ArgoCD Applications

The following ArgoCD Applications are configured for the media server stack:

| Application | Path | Namespace | Auto-Sync | Self-Heal |
|------------|------|-----------|-----------|-----------|
| **jellyfin** | `apps/media-server/jellyfin` | media | ✅ | ✅ |
| **radarr** | `apps/media-server/radarr` | media | ✅ | ✅ |
| **qbitt** | `apps/media-server/qbitt` | media | ✅ | ✅ |
| **jackett** | `apps/media-server/jackett` | media | ✅ | ✅ |

**Auto-Sync**: ArgoCD automatically syncs changes from Git every 3 minutes  
**Self-Heal**: ArgoCD automatically corrects any manual changes to match Git state

## Deployment Workflow

### Step 1: Make Changes Locally

Edit the Kubernetes manifests in the appropriate directory:

```bash
# Example: Add health probes to Jellyfin
vim apps/media-server/jellyfin/jellyfin-sts.yaml

# Example: Change service type
vim apps/media-server/radarr/radarr-svc.yaml
```

### Step 2: Test Changes Locally (Optional)

You can validate your changes before committing:

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -k apps/media-server/jellyfin/

# Or use kustomize directly
kustomize build apps/media-server/jellyfin/ | kubectl apply --dry-run=client -f -
```

### Step 3: Commit and Push Changes

```bash
# Stage your changes
git add apps/media-server/

# Commit with a descriptive message
git commit -m "feat(media): add health probes to all applications"

# Push to main branch
git push origin main
```

### Step 4: Wait for ArgoCD Sync (or Trigger Manually)

**Option A: Wait for Auto-Sync (3 minutes)**

ArgoCD will automatically detect changes and sync within 3 minutes.

**Option B: Trigger Manual Sync**

```bash
# Using ArgoCD CLI
argocd app sync jellyfin
argocd app sync radarr
argocd app sync qbitt
argocd app sync jackett

# Or sync all at once
argocd app sync jellyfin radarr qbitt jackett

# Or use the deployment script
cd apps/media-server
./deploy.sh
# Choose option 2 (Manual ArgoCD Sync)
```

**Option C: Sync via ArgoCD UI**

1. Access ArgoCD UI: https://argocd.tabby-carp.ts.net (or your ArgoCD URL)
2. Find the application (e.g., "jellyfin")
3. Click "Sync" → "Synchronize"

### Step 5: Verify Deployment

```bash
# Check ArgoCD application status
argocd app get jellyfin

# Check pod status
kubectl get pods -n media

# Check application logs
kubectl logs -n media jellyfin-0 --tail=50

# Check ArgoCD sync status for all media apps
argocd app list | grep -E "jellyfin|radarr|qbitt|jackett"
```

## ArgoCD Application Manifests

The ArgoCD Application manifests are located in `argocd-apps/`:

### Jellyfin Application

<augment_code_snippet path="argocd-apps/jellyfin.yaml" mode="EXCERPT">
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jellyfin
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/pablodelarco/kubernetes-homelab'
    targetRevision: main
    path: apps/media-server/jellyfin
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: media
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
</augment_code_snippet>

**Key Settings**:
- `prune: true` - Removes resources deleted from Git
- `selfHeal: true` - Automatically corrects drift from Git state
- `targetRevision: main` - Syncs from the main branch

## Kustomization Structure

Each application uses Kustomize for manifest organization:

```
apps/media-server/
├── jellyfin/
│   ├── kustomization.yaml       # Kustomize config
│   ├── nfs-media-pv-pvc.yaml   # NFS storage
│   ├── jellyfin-pvc.yaml       # Longhorn config storage
│   ├── jellyfin-sts.yaml       # StatefulSet
│   ├── jellyfin-svc.yaml       # Service
│   └── jellyfin-ingress.yaml   # Tailscale ingress
├── radarr/
│   ├── kustomization.yaml
│   ├── radarr-pvc.yaml
│   ├── radarr-sts.yaml
│   ├── radarr-svc.yaml
│   └── radarr-ingress.yaml
├── qbitt/
│   ├── kustomization.yaml
│   ├── nfs-download-pv-pvc.yaml
│   ├── qbitt-pvc.yaml
│   ├── qbitt-sts.yaml
│   ├── qbitt-svc.yaml
│   └── qbitt-ingress.yaml
└── jackett/
    ├── kustomization.yaml
    ├── jackett-pvc.yaml
    ├── jackett-deploy.yaml
    ├── jackett-svc.yaml
    └── jackett-ingress.yaml
```

## Common Operations

### Check Application Status

```bash
# Get detailed status
argocd app get jellyfin

# List all applications
argocd app list

# Check sync status
argocd app get jellyfin -o json | jq '.status.sync.status'

# Check health status
argocd app get jellyfin -o json | jq '.status.health.status'
```

### Force Sync (Hard Refresh)

```bash
# Force sync (ignores cache)
argocd app sync jellyfin --force

# Sync with prune (remove extra resources)
argocd app sync jellyfin --prune

# Sync specific resource
argocd app sync jellyfin --resource apps:StatefulSet:jellyfin
```

### Rollback to Previous Version

```bash
# View application history
argocd app history jellyfin

# Rollback to specific revision
argocd app rollback jellyfin <revision-id>

# Or use Git to rollback
git revert <commit-hash>
git push origin main
# ArgoCD will sync the reverted state
```

### Pause Auto-Sync (for testing)

```bash
# Disable auto-sync
argocd app set jellyfin --sync-policy none

# Re-enable auto-sync
argocd app set jellyfin --sync-policy automated --auto-prune --self-heal
```

### View Application Logs

```bash
# View ArgoCD application events
argocd app get jellyfin --show-operation

# View pod logs
kubectl logs -n media jellyfin-0 --tail=100 -f

# View ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## Troubleshooting

### Application Stuck in "OutOfSync"

**Cause**: Changes in Git haven't been applied to cluster

**Solution**:
```bash
# Manually trigger sync
argocd app sync jellyfin

# Check for sync errors
argocd app get jellyfin
```

### Application Shows "Degraded" Health

**Cause**: Pods are not ready or failing health checks

**Solution**:
```bash
# Check pod status
kubectl get pods -n media

# Check pod events
kubectl describe pod jellyfin-0 -n media

# Check pod logs
kubectl logs -n media jellyfin-0
```

### Manual Changes Keep Getting Reverted

**Cause**: ArgoCD self-heal is enabled (this is expected behavior!)

**Solution**:
- Make changes in Git, not directly in the cluster
- If you need to test something, temporarily disable self-heal:
  ```bash
  argocd app set jellyfin --self-heal=false
  # Make your changes
  # Re-enable when done
  argocd app set jellyfin --self-heal=true
  ```

### Sync Fails with "Resource Already Exists"

**Cause**: Resource was created manually before ArgoCD took over

**Solution**:
```bash
# Delete the conflicting resource
kubectl delete <resource-type> <resource-name> -n media

# Sync again
argocd app sync jellyfin
```

### Application Not Syncing Automatically

**Cause**: Auto-sync might be disabled or there's a sync error

**Solution**:
```bash
# Check sync policy
argocd app get jellyfin -o json | jq '.spec.syncPolicy'

# Re-enable auto-sync if needed
argocd app set jellyfin --sync-policy automated --auto-prune --self-heal

# Check for sync errors
argocd app get jellyfin
```

## Best Practices

### 1. Always Use Git for Changes

❌ **Don't do this**:
```bash
kubectl edit statefulset jellyfin -n media
```

✅ **Do this instead**:
```bash
vim apps/media-server/jellyfin/jellyfin-sts.yaml
git add apps/media-server/jellyfin/jellyfin-sts.yaml
git commit -m "feat: update jellyfin configuration"
git push origin main
```

### 2. Use Descriptive Commit Messages

Follow conventional commits:

```bash
git commit -m "feat(jellyfin): add health probes"
git commit -m "fix(radarr): correct service port"
git commit -m "chore(media): update all images to latest"
```

### 3. Test Changes Before Committing

```bash
# Validate YAML
kubectl apply --dry-run=client -k apps/media-server/jellyfin/

# Check for syntax errors
yamllint apps/media-server/jellyfin/*.yaml
```

### 4. Monitor ArgoCD After Changes

```bash
# Watch application status
watch argocd app get jellyfin

# Watch pod status
watch kubectl get pods -n media
```

### 5. Use Branches for Major Changes

```bash
# Create feature branch
git checkout -b feature/add-sonarr

# Make changes
vim apps/media-server/sonarr/...

# Commit and push
git add apps/media-server/sonarr/
git commit -m "feat: add sonarr for TV show management"
git push origin feature/add-sonarr

# Create PR, review, then merge to main
```

## Emergency Procedures

### Disable ArgoCD for Emergency Fix

If you need to make an emergency fix directly in the cluster:

```bash
# 1. Disable auto-sync and self-heal
argocd app set jellyfin --sync-policy none

# 2. Make your emergency fix
kubectl edit statefulset jellyfin -n media

# 3. Update Git to match your fix
vim apps/media-server/jellyfin/jellyfin-sts.yaml
git add apps/media-server/jellyfin/jellyfin-sts.yaml
git commit -m "fix: emergency fix for jellyfin"
git push origin main

# 4. Re-enable auto-sync
argocd app set jellyfin --sync-policy automated --auto-prune --self-heal
```

### Complete Rollback

If a deployment goes wrong:

```bash
# Option 1: Git revert
git revert <bad-commit-hash>
git push origin main
argocd app sync jellyfin

# Option 2: ArgoCD rollback
argocd app history jellyfin
argocd app rollback jellyfin <good-revision-id>
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Media Server Configuration Guide](./README.md)

