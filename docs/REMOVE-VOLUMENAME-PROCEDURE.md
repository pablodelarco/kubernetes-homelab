# Remove volumeName from Git Manifests - Safe Procedure

## Problem

After disaster recovery, all PVC manifests have hardcoded `volumeName` fields. This breaks GitOps because:
- PVCs are permanently bound to specific PVs
- Cannot recreate PVCs dynamically
- ArgoCD cannot manage PVC lifecycle
- Future disaster recovery will fail (volume names won't match)

## Solution

Remove `volumeName` from Git manifests while keeping the existing PV/PVC bindings intact.

## Key Insight

**The `volumeName` field in a PVC is immutable ONLY when the PVC is bound.** We can:
1. Remove `volumeName` from Git manifest
2. Annotate the PVC to tell ArgoCD to ignore the `volumeName` field
3. ArgoCD will see the PVC as "in sync" even though the cluster has `volumeName` set

## Procedure

### Step 1: Disable ArgoCD selfHeal for affected applications

```bash
# List of applications with hardcoded volumeName
APPS="homepage jackett jellyfin tdarr"

for app in $APPS; do
  kubectl patch application $app -n argocd --type=json \
    -p='[{"op": "replace", "path": "/spec/syncPolicy/automated/selfHeal", "value": false}]'
done
```

### Step 2: Add ArgoCD ignore annotation to PVCs

This tells ArgoCD to ignore differences in the `volumeName` field.

```bash
# Homepage
kubectl annotate pvc homepage-logs -n homepage \
  argocd.argoproj.io/compare-options='IgnoreExtraneous' --overwrite

# Jackett
kubectl annotate pvc jackett -n media \
  argocd.argoproj.io/compare-options='IgnoreExtraneous' --overwrite

# Jellyfin
kubectl annotate pvc jellyfin-config -n media \
  argocd.argoproj.io/compare-options='IgnoreExtraneous' --overwrite

# Tdarr (3 PVCs)
kubectl annotate pvc tdarr-config -n media \
  argocd.argoproj.io/compare-options='IgnoreExtraneous' --overwrite
kubectl annotate pvc tdarr-server -n media \
  argocd.argoproj.io/compare-options='IgnoreExtraneous' --overwrite
kubectl annotate pvc tdarr-logs -n media \
  argocd.argoproj.io/compare-options='IgnoreExtraneous' --overwrite
```

### Step 3: Remove volumeName from Git manifests

Edit these files and remove the `volumeName` line:
- `apps/homepage/custom-values.yaml`
- `apps/media-server/jackett/jackett-pvc.yaml`
- `apps/media-server/jellyfin/jellyfin-pvc.yaml`
- `apps/media-server/tdarr/tdarr-pvc.yaml`

**DO NOT remove volumeName from NFS volumes:**
- `apps/media-server/qbitt/nfs-temp-pv-pvc.yaml` (keep it)
- `apps/media-server/jellyfin/nfs-media-pv-pvc.yaml` (keep it)

### Step 4: Commit and push changes

```bash
git add apps/
git commit -m "Remove hardcoded volumeName from Longhorn PVC manifests"
git push
```

### Step 5: Verify ArgoCD shows applications as Synced

```bash
kubectl get applications -n argocd | grep -E "homepage|jackett|jellyfin|tdarr"
```

All should show "Synced" status.

### Step 6: Re-enable selfHeal

```bash
for app in homepage jackett jellyfin tdarr; do
  kubectl patch application $app -n argocd --type=json \
    -p='[{"op": "replace", "path": "/spec/syncPolicy/automated/selfHeal", "value": true}]'
done
```

### Step 7: Test that everything still works

```bash
# Check all pods are running
kubectl get pods -n homepage
kubectl get pods -n media | grep -E "jackett|jellyfin|tdarr"

# Check PVCs are still bound
kubectl get pvc -n homepage
kubectl get pvc -n media | grep -E "jackett|jellyfin|tdarr"
```

## What This Achieves

✅ **Removes hardcoded volumeName from Git** - GitOps best practice
✅ **Keeps existing PV/PVC bindings** - No risk to data
✅ **ArgoCD can sync properly** - No more OutOfSync errors
✅ **Applications keep running** - Zero downtime

## What This Doesn't Do

❌ **Doesn't rename volumes** - They still have ugly names like `pvc-jackett-restored`
❌ **Doesn't fix monitoring volumes** - They still have UUID names

## Future: Proper Volume Naming

If you want human-readable volume names in the future, you can:
1. Create new PVCs with proper names (dynamic provisioning)
2. Use Velero or similar tool to migrate data
3. Switch applications to new PVCs
4. Delete old volumes

But this is a separate project and much more complex.

## Rollback

If anything goes wrong:
1. Re-add `volumeName` to Git manifests
2. Commit and push
3. Remove ArgoCD annotations from PVCs
4. Everything returns to previous state

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ArgoCD sync issues | Low | Low | Annotations prevent sync conflicts |
| Data loss | None | N/A | Not touching data or bindings |
| Downtime | None | N/A | No pod restarts required |
| Git conflicts | Low | Low | Clear commit message |

**Overall Risk: VERY LOW** ✅

This is a metadata-only change. We're not touching any actual volumes or data.

