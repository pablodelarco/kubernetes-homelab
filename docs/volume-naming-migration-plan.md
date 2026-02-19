# Volume Naming Migration Plan

## Objective

Migrate from inconsistent volume naming to a standardized, human-readable naming convention and remove hardcoded `volumeName` from Git manifests.

## Current State

### Volumes to Migrate (Longhorn)

| Current Volume Name | App | Namespace | Size | New Name |
|---------------------|-----|-----------|------|----------|
| pvc-home-assistant-restored-v2 | home-assistant | home-assistant | 5Gi | home-assistant-config |
| pvc-homepage-restored | homepage | homepage | 5Gi | homepage-logs |
| pvc-bazarr-restored | bazarr | media | 2Gi | media-bazarr-config |
| pvc-jackett-restored | jackett | media | 5Gi | media-jackett-config |
| pvc-jellyfin-restored | jellyfin | media | 5Gi | media-jellyfin-config |
| pvc-jellyseerr-restored | jellyseerr | media | 1Gi | media-jellyseerr-config |
| pvc-qbitt-restored | qbitt | media | 5Gi | media-qbitt-config |
| pvc-radarr-restored | radarr | media | 5Gi | media-radarr-config |
| pvc-tdarr-config-restored | tdarr | media | 1Gi | media-tdarr-config |
| pvc-tdarr-logs-restored | tdarr | media | 1Gi | media-tdarr-logs |
| pvc-tdarr-server-restored | tdarr | media | 10Gi | media-tdarr-server |
| pvc-opencost-restored | opencost | opencost | 5Gi | opencost-data |
| pvc-uptime-kuma-restored | uptime-kuma | uptime-kuma | 5Gi | uptime-kuma-data |
| pvc-623a87a9-0510-4195-8bec-671f04c9be20 | alertmanager | monitoring | 5Gi | monitoring-alertmanager-db |
| pvc-6c391b81-2761-4797-895f-831d23796af5 | prometheus | monitoring | 25Gi | monitoring-prometheus-db |
| pvc-8c3a8756-f6e5-4712-92ab-61521eceb5e9 | grafana | monitoring | 8Gi | monitoring-grafana-data |

### Volumes to Keep (NFS - manually created)

| Volume Name | App | Purpose |
|-------------|-----|---------|
| jellyfin-videos | jellyfin | NFS media storage |
| qbitt-temp | qbitt | NFS temp downloads |

## Naming Convention

**Format**: `<namespace>-<app>-<purpose>`

**Examples**:
- `media-jackett-config` - Jackett config in media namespace
- `monitoring-grafana-data` - Grafana data in monitoring namespace
- `home-assistant-config` - Home Assistant config

**Benefits**:
- Human-readable
- Easy to identify which app owns the volume
- Consistent across all volumes
- Namespace prefix prevents conflicts

## Migration Strategy

### Option 1: In-Place Rename (RISKY - NOT RECOMMENDED)

Rename Longhorn volumes directly while pods are running.

**Pros**: No downtime
**Cons**: Very risky, could break volume attachments

### Option 2: Recreate with New Names (RECOMMENDED)

1. Create new PVCs with correct names (dynamic provisioning)
2. Copy data from old volumes to new volumes
3. Update applications to use new PVCs
4. Delete old volumes

**Pros**: Safe, tested approach
**Cons**: Requires downtime per application

### Option 3: Use Longhorn Volume Cloning (BEST)

1. Clone existing volumes with new names
2. Create PVCs pointing to cloned volumes
3. Update applications to use new PVCs
4. Delete old volumes after verification

**Pros**: Fast, safe, no data copy needed
**Cons**: Requires Longhorn v1.5+ (we have v1.10.1 ✅)

## Recommended Approach: Option 3 (Volume Cloning)

### Phase 1: Test with One Application (homepage)

1. Clone `pvc-homepage-restored` → `homepage-logs`
2. Create new PVC without `volumeName`
3. Update Git manifest to remove `volumeName`
4. Scale down homepage deployment
5. Delete old PVC
6. Apply new PVC (ArgoCD will create it)
7. Verify homepage works
8. Delete old volume

### Phase 2: Migrate All Applications

Repeat Phase 1 for all applications in this order:
1. homepage (test case)
2. opencost, uptime-kuma (low risk)
3. bazarr, jackett, jellyseerr (media - low risk)
4. tdarr (3 volumes)
5. qbitt, radarr, jellyfin (media - medium risk)
6. home-assistant (high risk - critical)
7. monitoring (grafana, prometheus, alertmanager)

### Phase 3: Update Git Manifests

Remove `volumeName` from all PVC manifests after migration.

## Rollback Plan

If anything goes wrong:
1. Keep old volumes (don't delete until verified)
2. Revert PVC to point to old volume
3. Restart pod
4. Old data is still intact

## Testing Plan

Before migrating production:
1. Create test namespace
2. Create test volume with data
3. Practice clone → rename → bind procedure
4. Verify data integrity
5. Time the process

## Estimated Time

- Test migration: 30 minutes
- Per-application migration: 5-10 minutes
- Total for all 16 volumes: 2-3 hours

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss | Low | Critical | Keep old volumes until verified |
| Downtime | High | Medium | Migrate during maintenance window |
| PVC binding issues | Medium | Medium | Have rollback procedure ready |
| ArgoCD sync issues | Medium | Low | Disable selfHeal during migration |

## Prerequisites

- ✅ Longhorn v1.10.1 (supports volume cloning via PVC dataSource)
- ✅ All volumes backed up (last backup: 2025-11-23 02:00 AM)
- ✅ Documented rollback procedure
- ✅ Tested cloning procedure (successful)
- ✅ Default replica count set to 2
- ✅ All current volumes have 2 replicas (no degraded volumes)
- ✅ Clone script created: `scripts/clone-and-rename-volume.sh`

## Important: Replica Count Fix

**Issue**: When cloning PVCs, Longhorn may create volumes with 3 replicas (inherited from source or default).
**Solution**: The clone script automatically fixes replica count to 2 after cloning.
**Verification**: All volumes currently have 2 replicas ✅

## Execution Plan

Now that we've verified cloning works, we can proceed with the migration.

