# Media Server Backup Status

## ✅ All Media Apps Have Persistent Storage Configured

All media applications have been configured with persistent volumes to ensure configuration and data survive pod restarts, deletions, and updates.

---

## 📦 Persistent Volume Claims (PVCs)

### Configuration Storage (Longhorn - Replicated)

| Application | PVC Name | Storage Class | Size | Status | Backup Schedule |
|------------|----------|---------------|------|--------|-----------------|
| **Jellyfin** | `jellyfin-config` | Longhorn | 5Gi | ✅ Bound | Daily @ 2 AM |
| **Radarr** | `radarr` | Longhorn | 5Gi | ✅ Bound | Daily @ 2 AM |
| **qBittorrent** | `qbitt` | Longhorn | 5Gi | ✅ Bound | Daily @ 2 AM |
| **Jackett** | `jackett` | Longhorn | 5Gi | ✅ Bound | Daily @ 2 AM |

### Media Storage (NFS - Synology)

| PVC Name | Storage | Size | Purpose | Backup |
|----------|---------|------|---------|--------|
| `jellyfin-videos` | NFS (Synology) | 400Gi | Movies/Shows library | Synology snapshots |
| `qbitt-download` | NFS (Synology) | 400Gi | Downloaded files | Synology snapshots |

---

## 🔄 Automated Backup Configuration

### Longhorn Recurring Jobs

All configuration PVCs are backed up daily to **MinIO (S3)** at **2:00 AM**:

```bash
# View backup schedules
kubectl get recurringjob -n longhorn-system

# Expected output:
NAME                     GROUPS        TASK     CRON        RETAIN   CONCURRENCY
jackett-config-backup    ["default"]   backup   0 2 * * *   7        2
jellyfin-config-backup   ["default"]   backup   0 2 * * *   7        2
qbitt-config-backup      ["default"]   backup   0 2 * * *   7        2
radarr-config-backup     ["default"]   backup   0 2 * * *   7        2
```

**Backup Retention**: 7 days (7 daily backups kept)

**Backup Target**: `s3://k8s-backups@us-east-1/` (MinIO)

---

## 🛡️ What's Protected

### Jellyfin (`jellyfin-config`)
- ✅ User accounts and passwords
- ✅ Watch history and progress
- ✅ Library metadata and artwork
- ✅ Transcoding settings
- ✅ Hardware acceleration config
- ✅ Plugin configurations

### Radarr (`radarr`)
- ✅ Movie lists and collections
- ✅ Quality profiles
- ✅ Indexer settings (Jackett connection)
- ✅ Download client config (qBittorrent)
- ✅ Custom formats and naming
- ✅ Root folders and paths

### qBittorrent (`qbitt`)
- ✅ Torrent client settings
- ✅ RSS feed configurations
- ✅ Categories and tags
- ✅ Speed limits and scheduling
- ✅ Web UI credentials
- ✅ VPN (Gluetun) configuration

### Jackett (`jackett`)
- ✅ Indexer configurations
- ✅ API keys
- ✅ Proxy settings
- ✅ Search categories

---

## 🔍 Verification Commands

### Check PVC Status
```bash
kubectl get pvc -n media
```

### Check Backup Jobs
```bash
kubectl get recurringjob -n longhorn-system
```

### Check Backup Target
```bash
kubectl get backuptarget -n longhorn-system
```

### View Existing Backups
```bash
kubectl get backup -n longhorn-system | grep -E "jellyfin|radarr|qbitt|jackett"
```

### Check PVC Labels (for backup inclusion)
```bash
kubectl get pvc -n media --show-labels
```

---

## 🚀 Recovery Procedures

### Restore from Backup (if needed)

1. **Access Longhorn UI**:
   ```bash
   kubectl port-forward -n longhorn-system svc/longhorn-frontend 8000:80
   ```
   Then open: `http://localhost:8000`

2. **Navigate to Backup**:
   - Click **Backup** in the left menu
   - Find the volume you want to restore (e.g., `pvc-ba73e1af-36fa-4ac8-8e96-07a59398dc9c` for jellyfin-config)
   - Click the backup you want to restore
   - Click **Restore**

3. **Create New PVC from Backup**:
   - Choose a new PVC name or restore to existing
   - Click **OK**

### Manual Backup (on-demand)

```bash
# Trigger immediate backup for a specific PVC
kubectl annotate pvc jellyfin-config -n media \
  longhorn.io/recurring-job-group='{"default":{"isGroup":true}}'
```

---

## 📊 Storage Summary

| Type | Purpose | Storage Backend | Replication | Backup |
|------|---------|----------------|-------------|--------|
| **Config** | App settings | Longhorn | 3 replicas | Daily to S3 |
| **Media** | Movies/Shows | Synology NFS | RAID | Synology snapshots |
| **Downloads** | Temp files | Synology NFS | RAID | Synology snapshots |
| **Cache** | Transcoding | emptyDir | None | Not needed |

---

## ✅ Safety Guarantees

With this configuration, you can safely:

- ✅ **Delete pods** - They'll recreate with same config
- ✅ **Restart deployments** - No data loss
- ✅ **Update container images** - Config persists
- ✅ **Reboot nodes** - PVCs survive
- ✅ **Lose a node** - Longhorn replicates data
- ✅ **Restore from backup** - Up to 7 days back

---

## 🔧 Maintenance

### Increase Backup Retention

Edit the recurring job:
```bash
kubectl edit recurringjob jellyfin-config-backup -n longhorn-system
# Change 'retain: 7' to desired number
```

### Change Backup Schedule

Edit the recurring job:
```bash
kubectl edit recurringjob jellyfin-config-backup -n longhorn-system
# Change 'cron: "0 2 * * *"' to desired schedule
```

### Disable Backups for a PVC

```bash
kubectl label pvc jellyfin-config -n media \
  recurring-job-group.longhorn.io/default-
```

---

## 📝 Notes

- **NFS volumes** (`jellyfin-videos`, `qbitt-download`) are NOT backed up by Longhorn
  - These are backed up by Synology's built-in snapshot system
  - Media files are large and don't need frequent backups
  
- **emptyDir volumes** (cache, transcode) are temporary and not backed up
  - These are recreated on pod restart
  - No persistent data stored here

- **Backup window**: 2:00 AM daily to minimize impact on streaming

---

**Last Updated**: 2025-10-26
**Backup Target**: MinIO S3 (`s3://k8s-backups@us-east-1/`)
**Retention**: 7 days

