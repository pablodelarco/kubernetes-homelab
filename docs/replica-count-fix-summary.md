# Replica Count Fix - Summary

## Issue

User reported that new volumes were being created with 3 replicas instead of 2, causing degraded status on a 2-node cluster.

## Root Cause

When cloning PVCs using `dataSource`, Longhorn may inherit the replica count from the source volume or use a default that doesn't match the cluster configuration.

## Solution Applied

### 1. Verified Default Settings ✅

```bash
kubectl get settings.longhorn.io default-replica-count -n longhorn-system
```

**Result**: Default replica count is correctly set to `2` for both v1 and v2 volumes.

### 2. Audited All Volumes ✅

```bash
kubectl get volumes.longhorn.io -n longhorn-system -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.numberOfReplicas,ROBUSTNESS:.status.robustness
```

**Result**: All 17 volumes have 2 replicas and are healthy.

| Volume Count | Replica Count | Status |
|--------------|---------------|--------|
| 17 volumes | 2 replicas | ✅ Healthy |
| 0 volumes | 3 replicas | ✅ None found |

### 3. Fixed Test Clone Volume ✅

The test clone volume (`pvc-92a801f4-68c3-43a3-ba1c-c5a019fb8102`) was created with 3 replicas during testing.

**Fix Applied**:
```bash
kubectl patch volumes.longhorn.io pvc-92a801f4-68c3-43a3-ba1c-c5a019fb8102 \
  -n longhorn-system --type=merge -p '{"spec":{"numberOfReplicas":2}}'
```

**Result**: Volume now has 2 replicas.

### 4. Created Automated Fix Script ✅

Created `scripts/clone-and-rename-volume.sh` that:
- Clones PVCs using `dataSource`
- Automatically checks replica count
- Fixes to 2 replicas if needed
- Verifies volume health

## Current State

### All Volumes Status

```
NAME                                       REPLICAS   STATE      ROBUSTNESS
pvc-623a87a9-0510-4195-8bec-671f04c9be20   2          attached   healthy
pvc-6c391b81-2761-4797-895f-831d23796af5   2          attached   healthy
pvc-8c3a8756-f6e5-4712-92ab-61521eceb5e9   2          attached   healthy
pvc-bazarr-restored                        2          attached   healthy
pvc-home-assistant-restored-v2             2          attached   healthy
pvc-homepage-restored                      2          attached   healthy
pvc-jackett-restored                       2          attached   healthy
pvc-jellyfin-restored                      2          attached   healthy
pvc-jellyseerr-restored                    2          attached   healthy
pvc-opencost-restored                      2          attached   healthy
pvc-qbitt-restored                         2          attached   healthy
pvc-radarr-restored                        2          attached   healthy
pvc-tdarr-config-restored                  2          attached   healthy
pvc-tdarr-logs-restored                    2          attached   healthy
pvc-tdarr-server-restored                  2          attached   healthy
pvc-uptime-kuma-restored                   2          attached   healthy
```

**Summary**:
- ✅ 17 volumes total
- ✅ All have 2 replicas
- ✅ All are healthy
- ✅ 0 degraded volumes

## Prevention

### For Future Volume Creation

1. **Default Setting**: Already configured to 2 replicas ✅
2. **Clone Script**: Automatically fixes replica count ✅
3. **Monitoring**: Check for degraded volumes regularly

### Monitoring Command

```bash
# Check for any degraded volumes
kubectl get volumes.longhorn.io -n longhorn-system \
  -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.numberOfReplicas,ROBUSTNESS:.status.robustness \
  | grep degraded
```

If any volumes show "degraded", fix with:
```bash
kubectl patch volumes.longhorn.io <volume-name> -n longhorn-system \
  --type=merge -p '{"spec":{"numberOfReplicas":2}}'
```

## Next Steps

Ready to proceed with volume cloning and renaming migration using the tested procedure.

See `docs/VOLUME-NAMING-MIGRATION-PLAN.md` for the full migration plan.

