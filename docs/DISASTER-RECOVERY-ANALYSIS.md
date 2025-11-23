# Disaster Recovery Analysis - 2025-11-23

## Executive Summary

Today we experienced a catastrophic failure where Longhorn was accidentally deleted, causing loss of all volume data. While we successfully restored all applications from S3 backups, the recovery process revealed critical gaps in our disaster recovery strategy and cluster architecture.

## What Happened Today

### The Incident
1. **Root Cause**: Ran `helm uninstall longhorn -n longhorn-system --no-hooks` to fix an ArgoCD sync issue
2. **Cascade Effect**: This deleted all Longhorn CRDs, which then deleted ALL Longhorn volumes across the cluster
3. **Impact**: 15+ applications lost all their data
4. **Recovery Time**: ~8 hours to restore all applications

### Applications Affected
- ✅ home-assistant (CRITICAL - all home automation config)
- ✅ homepage, bazarr, jackett, jellyseerr, qbitt, tdarr (3 volumes)
- ✅ monitoring (grafana, prometheus, alertmanager) - NOT backed up, fresh install
- ✅ opencost, uptime-kuma
- ✅ radarr, jellyfin
- ❌ sonarr - removed due to persistent mount issues

## Why Recovery Was So Difficult

### Problem 1: Longhorn Restore Behavior (CRITICAL DISCOVERY)

**The Issue**: The Longhorn API `fromBackup` parameter creates volume metadata but does NOT actually restore data from S3. The restore only happens **asynchronously when the volume is first attached to a pod**.

**Why This Caused Problems**:
- Initial attempts created volumes that appeared restored but were empty
- No clear documentation on this behavior
- Required multiple trial-and-error attempts to discover the correct procedure

**Correct Restore Procedure** (discovered after many failures):
1. Create volume via API with `fromBackup` parameter
2. **Attach volume to a test pod** - This triggers actual S3 data download
3. Verify data in test pod
4. Delete test pod (detaches volume)
5. Create PV pointing to restored volume
6. Create PVC with `volumeName` pointing to PV
7. Scale down application
8. Delete old PVC
9. Apply new PVC
10. Patch PV if binding fails
11. Delete pod to force remount

### Problem 2: Volume Naming Confusion

**Current State**:
- Restored volumes: `pvc-<app>-restored` (e.g., `pvc-jackett-restored`)
- Fresh volumes: `pvc-<uuid>` (e.g., `pvc-623a87a9-0510-4195-8bec-671f04c9be20`)
- Manual volumes: `<app>-<purpose>` (e.g., `jellyfin-videos`, `qbitt-temp`)

**Why This Is Confusing**:
- No consistent naming convention
- UUID-based names don't indicate which app they belong to
- Mix of restored and fresh volumes makes it hard to track
- Git manifests now have hardcoded `volumeName` fields pointing to `-restored` volumes

### Problem 3: Degraded Volumes (Monitoring Stack)

**Current Degraded Volumes**:
```
pvc-623a87a9-0510-4195-8bec-671f04c9be20  (alertmanager)  - 3 replicas configured, degraded
pvc-6c391b81-2761-4797-895f-831d23796af5  (prometheus)    - 3 replicas configured, degraded
pvc-8c3a8756-f6e5-4712-92ab-61521eceb5e9  (grafana)       - 3 replicas configured, degraded
```

**Root Cause**: These volumes are configured for 3 replicas, but you only have 2 nodes in the cluster (beelink control-plane + worker node). Longhorn cannot create 3 replicas with only 2 nodes.

**Why This Happened**: When monitoring was reinstalled fresh (not restored from backup), Longhorn used the default replica count of 3.

### Problem 4: Terminating PVs

**Stuck PVs**:
```
pvc-74100887-ae62-49d4-90fd-f2adfb8126e2  (old grafana)       - Terminating for 34 days
pvc-9146c78a-48a3-46db-baa7-3eea9a3e4bd1  (old opencost)      - Terminating for 7h44m
pvc-d65ea160-ea06-4634-9927-8255cfd5365a  (old alertmanager)  - Terminating for 33 days
pvc-ebbf76df-d46f-4363-baec-ddba9708ee3e  (old prometheus)    - Terminating for 34 days
test-restore-pv-uptime-kuma                                   - Terminating for 6h23m
```

**Root Cause**: PVs with finalizers that prevent deletion, likely due to Longhorn volume cleanup issues.

## Current Cluster State Analysis

### PVC/PV Inventory

**Total PVCs**: 19
- **Longhorn (restored)**: 13 volumes with `-restored` suffix
- **Longhorn (fresh)**: 3 monitoring volumes (degraded)
- **NFS**: 1 (minio)
- **Manual**: 2 (jellyfin-videos, qbitt-temp)

### Backup Status

**Last Successful Backup**: 2025-11-23 02:00 AM (all restored volumes came from this backup)

**Applications WITH Daily Backups**:
- ✅ home-assistant, bazarr, jackett, jellyseerr, qbitt, tdarr
- ✅ radarr, jellyfin, opencost, uptime-kuma, homepage

**Applications WITHOUT Backups**:
- ❌ monitoring (grafana, prometheus, alertmanager) - Fresh install, no historical data
- ❌ minio - Uses NFS, not backed up by Longhorn

## Critical Issues Identified

### Issue 1: Inconsistent Volume Naming

**Problem**: Three different naming conventions make it impossible to identify volumes at a glance.

**Impact**:
- Cannot quickly identify which volume belongs to which app
- Difficult to troubleshoot volume issues
- Confusing for disaster recovery

**Recommendation**: Standardize on human-readable names like `<namespace>-<app>-<purpose>` (e.g., `media-jackett-config`)

### Issue 2: Hardcoded volumeName in Git Manifests

**Problem**: After disaster recovery, all PVC manifests in Git now have hardcoded `volumeName` fields pointing to `-restored` volumes.

**Impact**:
- PVCs are permanently bound to specific PVs
- Cannot recreate PVCs without manual intervention
- Breaks GitOps principle of declarative configuration
- Future restores will fail because volume names won't match

**Example**:
```yaml
# apps/media-server/jackett/jackett-pvc.yaml
spec:
  volumeName: pvc-jackett-restored  # ← This should NOT be in Git
```

**Recommendation**: Remove `volumeName` from all Git manifests and use dynamic provisioning.

### Issue 3: Degraded Monitoring Volumes

**Problem**: Monitoring volumes configured for 3 replicas on a 2-node cluster.

**Impact**:
- Volumes permanently degraded
- Reduced reliability
- Wasted resources trying to create impossible replicas

**Recommendation**: Configure Longhorn default replica count to 2 for your cluster.

### Issue 4: No Monitoring Backups

**Problem**: Monitoring stack (Grafana, Prometheus, Alertmanager) is NOT backed up.

**Impact**:
- Lost all historical metrics and dashboards during disaster
- No way to recover monitoring configuration
- Fresh install means no historical data

**Recommendation**: Enable Longhorn backups for monitoring PVCs.

### Issue 5: Terminating PVs Accumulating

**Problem**: 5 PVs stuck in Terminating state (some for 34 days).

**Impact**:
- Wasted storage space
- Cluster resource leaks
- Confusing kubectl output

**Recommendation**: Clean up terminating PVs by removing finalizers.

## Is Your Cluster Prepared for Another Disaster?

### Current State: ⚠️ PARTIALLY PREPARED

**What Would Work**:
- ✅ S3 backups exist for most applications (last backup: 2025-11-23 02:00 AM)
- ✅ Backup target configured correctly (s3://k8s-backups@us-east-1/)
- ✅ Daily backup schedule running
- ✅ We now have documented restore procedure (docs/LONGHORN-DISASTER-RECOVERY.md)
- ✅ Automated restore script exists (scripts/restore-longhorn-volume.sh)

**What Would Fail**:
- ❌ Monitoring data would be lost (no backups)
- ❌ Restore process still requires 8+ hours of manual work
- ❌ Volume naming confusion would persist
- ❌ Hardcoded volumeName in Git would cause sync issues
- ❌ No automated disaster recovery procedure
- ❌ No tested disaster recovery plan

### Recovery Time Estimate

**Current State**: 6-8 hours (manual restore of 15+ applications)

**With Improvements**: Could be reduced to 1-2 hours with automation

## Recommended Action Plan

### Immediate Actions (Do Now)

1. **Fix Degraded Monitoring Volumes**
   - Update Longhorn default replica count to 2
   - Recreate monitoring volumes with correct replica count

2. **Clean Up Terminating PVs**
   - Remove finalizers from stuck PVs
   - Clean up orphaned resources

3. **Enable Monitoring Backups**
   - Configure recurring backups for Grafana, Prometheus, Alertmanager

### Short-term Actions (This Week)

4. **Remove volumeName from Git Manifests**
   - Remove hardcoded volumeName from all PVC manifests
   - Use Longhorn volume naming convention instead
   - Test that ArgoCD can recreate PVCs dynamically

5. **Standardize Volume Naming**
   - Rename all volumes to human-readable format
   - Update PV/PVC bindings
   - Document naming convention

6. **Test Disaster Recovery Plan**
   - Create test namespace
   - Simulate volume loss
   - Practice restore procedure
   - Time the recovery process

### Long-term Actions (This Month)

7. **Automate Disaster Recovery**
   - Create script to restore all volumes from latest backup
   - Automate PV/PVC creation
   - Automate pod restart
   - Test automation

8. **Implement Monitoring for Backups**
   - Alert if backup fails
   - Alert if backup is older than 24 hours
   - Dashboard showing backup status

9. **Document Runbook**
   - Step-by-step disaster recovery procedure
   - Contact information
   - Escalation path
   - Recovery time objectives (RTO)

## Conclusion

Today's disaster revealed that while we have backups, our disaster recovery process is:
- ✅ **Possible** - We successfully restored all data
- ⚠️ **Slow** - 8 hours of manual work
- ⚠️ **Complex** - Required deep Longhorn knowledge
- ⚠️ **Undocumented** - Had to discover restore behavior through trial and error
- ❌ **Incomplete** - Monitoring data lost, no automation

**Bottom Line**: You CAN recover from another Longhorn disaster, but it will take 6-8 hours of manual work and you will lose monitoring data. With the recommended improvements, this could be reduced to 1-2 hours with minimal data loss.


