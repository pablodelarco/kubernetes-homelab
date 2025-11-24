# Longhorn Disaster Recovery Strategy

## Overview

This document outlines the strategy for recovering from a Longhorn disaster, based on lessons learned from the 2025-11-23 incident where all Longhorn volumes were accidentally deleted.

## Current Backup Configuration

### Automated Backups
- **Backup Target**: S3-compatible storage (MinIO)
- **Backup Schedule**: Daily at 3:00 AM (configured via Longhorn recurring jobs)
- **Retention**: Configurable per volume
- **Scope**: All Longhorn volumes with `recurring-job-group.longhorn.io/default: enabled` label

### What Gets Backed Up
- All application data volumes (media apps, home-assistant, uptime-kuma, opencost, etc.)
- Monitoring volumes (grafana, prometheus, alertmanager)
- Configuration and state data

### What Does NOT Get Backed Up
- NFS volumes (jellyfin-videos, qbitt-temp, minio)
- Kubernetes manifests (stored in Git)
- Longhorn system configuration

## Disaster Recovery Procedure

### Scenario 1: Single Volume Corruption/Loss

**Steps:**
1. Identify the backup to restore from Longhorn UI or CLI
2. Create a new volume from backup using Longhorn API
3. Update PVC to bind to the restored volume
4. Restart the affected pod

**Example:**
```bash
# List available backups for a volume
kubectl get backupvolumes.longhorn.io -n longhorn-system

# Restore from backup (via Longhorn UI or API)
# The volume will be created with name pattern: pvc-<app>-restored
```

### Scenario 2: Complete Longhorn Failure (All Volumes Lost)

**This is what happened on 2025-11-23. Recovery took 8+ hours.**

#### Phase 1: Assess the Damage (15 minutes)
1. Check if Longhorn CRDs still exist:
   ```bash
   kubectl get crd | grep longhorn
   ```

2. Check if any volumes survived:
   ```bash
   kubectl get volumes.longhorn.io -n longhorn-system
   kubectl get pvc --all-namespaces
   ```

3. List all applications and their status:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods --all-namespaces | grep -v Running
   ```

#### Phase 2: Reinstall Longhorn (if needed) (30 minutes)
1. If Longhorn CRDs were deleted, reinstall Longhorn:
   ```bash
   helm upgrade --install longhorn longhorn/longhorn \
     --namespace longhorn-system \
     --create-namespace \
     -f apps/longhorn/custom-values.yaml
   ```

2. Wait for Longhorn to be fully operational:
   ```bash
   kubectl get pods -n longhorn-system
   ```

3. Reconfigure backup target in Longhorn UI or via CRD

#### Phase 3: Restore All Volumes (6-7 hours)
1. Get list of all backups:
   ```bash
   # Access Longhorn UI
   kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
   # Open http://localhost:8080
   # Go to Backup → Backup Volume
   ```

2. For each application, restore its volumes:
   ```bash
   # Use Longhorn UI or API to restore
   # Volumes will be created with pattern: pvc-<app>-restored
   ```

3. Create PVs and PVCs for restored volumes (see Phase 4)

#### Phase 4: Reconnect Applications to Restored Volumes (1-2 hours)
1. For each application, create PV pointing to restored Longhorn volume:
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: pv-<app>
   spec:
     capacity:
       storage: <size>Gi
     volumeMode: Filesystem
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: longhorn
     csi:
       driver: driver.longhorn.io
       fsType: ext4
       volumeAttributes:
         numberOfReplicas: "2"
         staleReplicaTimeout: "2880"
       volumeHandle: pvc-<app>-restored  # Longhorn volume name
   EOF
   ```

2. Update or create PVC to bind to the PV:
   ```bash
   # For manually managed PVCs (jackett, jellyfin, tdarr, uptime-kuma, homepage):
   kubectl apply -f apps/<app>/manifests/pvc.yaml
   
   # For StatefulSet-managed PVCs (prometheus, alertmanager, home-assistant):
   # Delete pod and PVC, then create new PVC with volumeName pointing to PV
   kubectl delete pod <pod-name> -n <namespace>
   kubectl delete pvc <pvc-name> -n <namespace>
   kubectl create -f <pvc-manifest-with-volumeName>
   ```

3. Verify application is running and data is intact:
   ```bash
   kubectl get pods -n <namespace>
   kubectl logs <pod-name> -n <namespace>
   ```

#### Phase 5: Fix GitOps Drift (30 minutes)
1. Remove hardcoded `volumeName` from Git manifests (if any)
2. Add ArgoCD annotation to ignore volumeName differences:
   ```bash
   kubectl annotate pvc <pvc-name> -n <namespace> \
     argocd.argoproj.io/compare-options='IgnoreExtraneous' --overwrite
   ```

3. Verify all applications are Synced in ArgoCD:
   ```bash
   kubectl get applications -n argocd
   ```

## Automation Opportunities

### Quick Recovery Script
Create a script that automates volume restoration:
```bash
#!/bin/bash
# restore-all-volumes.sh
# TODO: Implement automated restoration from S3 backups
```

### Pre-Disaster Preparation
1. **Document current state regularly**:
   ```bash
   ./scripts/list-volumes.sh > docs/volume-state-$(date +%Y%m%d).txt
   ```

2. **Test restore procedure quarterly** on a non-production volume

3. **Keep backup credentials secure** but accessible

## Prevention Measures

### 1. Protect Longhorn from Accidental Deletion
- Never run `helm uninstall longhorn` in production
- Use RBAC to restrict who can delete Longhorn resources
- Consider using admission controllers to prevent CRD deletion

### 2. Multiple Backup Targets
- Primary: MinIO (current)
- Secondary: External S3 bucket (recommended)

### 3. Regular Backup Verification
- Monthly: Verify backups exist in S3
- Quarterly: Test restore of one volume

### 4. Monitoring and Alerts
- Alert on backup failures
- Alert on volume degradation
- Alert on missing replicas

## Recovery Time Objectives (RTO)

| Scenario | Target RTO | Actual (2025-11-23) |
|----------|-----------|---------------------|
| Single volume | 30 minutes | N/A |
| Multiple volumes | 2 hours | N/A |
| Complete Longhorn failure | 4 hours | 8+ hours |

## Key Lessons Learned

1. **Longhorn volume names are just metadata** - they can be anything (pvc-*, pv-*, etc.)
2. **PV names matter for clarity** - use `pv-<app>` pattern for human readability
3. **Hardcoded volumeName breaks GitOps** - always use dynamic binding with ArgoCD annotations
4. **Backup verification is critical** - we were lucky backups existed and were complete
5. **Documentation saves time** - having this guide will reduce RTO significantly

## Next Steps

- [ ] Implement automated restore script
- [ ] Set up secondary backup target (external S3)
- [ ] Create quarterly restore testing schedule
- [ ] Add backup monitoring and alerts
- [ ] Document application-specific restore procedures

