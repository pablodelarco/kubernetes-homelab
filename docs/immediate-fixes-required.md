# Immediate Fixes Required - 2025-11-23

## Priority 1: Fix Degraded Monitoring Volumes

### Problem
Monitoring volumes (Grafana, Prometheus, Alertmanager) are degraded because they're configured for 3 replicas on a 2-node cluster.

### Solution
```bash
# Update Longhorn default replica count to 2
kubectl edit settings.longhorn.io default-replica-count -n longhorn-system
# Change from 3 to 2

# Recreate monitoring volumes with correct replica count
# Option 1: Update existing volumes
kubectl patch volumes.longhorn.io pvc-623a87a9-0510-4195-8bec-671f04c9be20 -n longhorn-system --type=merge -p '{"spec":{"numberOfReplicas":2}}'
kubectl patch volumes.longhorn.io pvc-6c391b81-2761-4797-895f-831d23796af5 -n longhorn-system --type=merge -p '{"spec":{"numberOfReplicas":2}}'
kubectl patch volumes.longhorn.io pvc-8c3a8756-f6e5-4712-92ab-61521eceb5e9 -n longhorn-system --type=merge -p '{"spec":{"numberOfReplicas":2}}'
```

### Expected Result
- All monitoring volumes show "healthy" instead of "degraded"
- Longhorn stops trying to create impossible 3rd replica

---

## Priority 2: Clean Up Terminating PVs

### Problem
5 PVs stuck in Terminating state (some for 34 days), wasting resources.

### Solution
```bash
# Remove finalizers from stuck PVs
kubectl patch pv pvc-74100887-ae62-49d4-90fd-f2adfb8126e2 --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
kubectl patch pv pvc-9146c78a-48a3-46db-baa7-3eea9a3e4bd1 --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
kubectl patch pv pvc-d65ea160-ea06-4634-9927-8255cfd5365a --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
kubectl patch pv pvc-ebbf76df-d46f-4363-baec-ddba9708ee3e --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
kubectl patch pv test-restore-pv-uptime-kuma --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'

# Clean up test PVC if it exists
kubectl delete pvc test-restore-pvc-uptime-kuma -n default 2>/dev/null || true
```

### Expected Result
- All terminating PVs deleted
- Clean `kubectl get pv` output

---

## Priority 3: Enable Monitoring Backups

### Problem
Monitoring stack (Grafana, Prometheus, Alertmanager) has NO backups. If Longhorn fails again, all metrics and dashboards will be lost.

### Solution
Create recurring backup jobs for monitoring volumes:

```yaml
# File: apps/kube-prometheus-stack/monitoring-backup.yaml
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: monitoring-backup
  namespace: longhorn-system
spec:
  cron: "0 2 * * *"  # Daily at 2:00 AM
  task: "backup"
  groups:
    - monitoring
  retain: 7
  concurrency: 2
---
# Label monitoring volumes with group
# This needs to be done via kubectl or Longhorn UI
```

### Manual Steps
```bash
# Label monitoring volumes for backup
kubectl label volumes.longhorn.io pvc-623a87a9-0510-4195-8bec-671f04c9be20 -n longhorn-system recurring-job.longhorn.io/monitoring=enabled
kubectl label volumes.longhorn.io pvc-6c391b81-2761-4797-895f-831d23796af5 -n longhorn-system recurring-job.longhorn.io/monitoring=enabled
kubectl label volumes.longhorn.io pvc-8c3a8756-f6e5-4712-92ab-61521eceb5e9 -n longhorn-system recurring-job.longhorn.io/monitoring=enabled
```

### Expected Result
- Monitoring volumes backed up daily at 2:00 AM
- 7 days retention
- Can recover Grafana dashboards and Prometheus metrics after disaster

---

## Priority 4: Remove volumeName from Git Manifests

### Problem
All PVC manifests now have hardcoded `volumeName` fields pointing to `-restored` volumes. This breaks GitOps and will cause issues in future.

### Files to Fix
```
apps/media-server/jackett/jackett-pvc.yaml
apps/media-server/jellyfin/jellyfin-pvc.yaml
apps/media-server/tdarr/tdarr-pvc.yaml
apps/homepage/custom-values.yaml
```

### Solution
Remove `volumeName` from all PVC manifests. But WAIT - this will cause ArgoCD sync issues because the PVCs in the cluster have volumeName set.

### Correct Procedure
1. **First**: Rename Longhorn volumes to remove `-restored` suffix
2. **Then**: Remove `volumeName` from Git manifests
3. **Finally**: Let ArgoCD sync

### Detailed Steps
```bash
# Example for jackett:
# 1. Rename Longhorn volume
kubectl patch volumes.longhorn.io pvc-jackett-restored -n longhorn-system --type=json -p='[{"op": "replace", "path": "/metadata/name", "value": "pvc-jackett"}]'

# 2. Update PV to point to renamed volume
kubectl patch pv pvc-jackett-restored --type=json -p='[{"op": "replace", "path": "/spec/csi/volumeHandle", "value": "pvc-jackett"}]'

# 3. Remove volumeName from Git manifest
# Edit apps/media-server/jackett/jackett-pvc.yaml and remove volumeName line

# 4. Commit and push
git add apps/media-server/jackett/jackett-pvc.yaml
git commit -m "Remove hardcoded volumeName from jackett PVC"
git push
```

**WARNING**: This is complex and risky. Recommend doing this AFTER testing in a non-production environment.

---

## Priority 5: Document Current Volume Mapping

### Problem
Cannot identify which UUID-based volume belongs to which app.

### Solution
Create a mapping document:

```bash
# Generate current volume mapping
kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,PVC:.metadata.name,VOLUME:.spec.volumeName,STORAGECLASS:.spec.storageClassName > docs/VOLUME-MAPPING.md
```

### Expected Result
- Clear documentation of which volume belongs to which app
- Reference for future troubleshooting

---

## Execution Order

1. ✅ **Fix degraded volumes** (5 minutes) - No risk, immediate benefit
2. ✅ **Clean up terminating PVs** (2 minutes) - No risk, cleanup
3. ✅ **Enable monitoring backups** (10 minutes) - No risk, critical protection
4. ✅ **Document volume mapping** (2 minutes) - No risk, helpful reference
5. ⚠️ **Remove volumeName from Git** (30+ minutes) - HIGH RISK, requires testing

**Recommendation**: Do steps 1-4 immediately. Do step 5 only after thorough testing and planning.

---

## Testing Plan

Before making any changes:
1. Take a snapshot of all Longhorn volumes
2. Document current state
3. Test changes in a non-production namespace first
4. Have rollback plan ready

After making changes:
1. Verify all pods still running
2. Verify all PVCs still bound
3. Verify ArgoCD shows all apps as Synced and Healthy
4. Test application functionality
5. Verify backups are running

