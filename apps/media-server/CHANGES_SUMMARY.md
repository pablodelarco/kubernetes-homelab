# Media Server Stack - Changes Summary

## Overview

This document summarizes all the improvements and configurations applied to your Kubernetes-based media server stack based on best practices from the guide at https://merox.dev/blog/kubernetes-media-server/

## Changes Applied

### 1. ✅ Added Jackett Ingress Configuration

**File**: `apps/media-server/jackett/jackett-ingress.yaml` (NEW)

**What**: Created Tailscale ingress for Jackett to make it accessible via HTTPS

**Why**: Jackett was the only application without an ingress, making it inaccessible from outside the cluster

**Access URL**: https://jackett.tabby-carp.ts.net

---

### 2. ✅ Standardized Service Types to ClusterIP

**Files Modified**:
- `apps/media-server/jackett/jackett-svc.yaml`
- `apps/media-server/jellyfin/jellyfin-svc.yaml`
- `apps/media-server/qbitt/qbitt-svc.yaml`

**What**: Changed service type from `LoadBalancer` to `ClusterIP`

**Why**: 
- Services are exposed via Tailscale ingress, not directly via LoadBalancer
- Reduces unnecessary external IPs from MetalLB
- Follows cluster's existing pattern (Radarr already used ClusterIP)
- More secure - services only accessible through ingress

**Before**:
```yaml
spec:
  type: LoadBalancer
```

**After**:
```yaml
spec:
  type: ClusterIP
```

---

### 3. ✅ Added Health Probes to All Applications

**Files Modified**:
- `apps/media-server/jellyfin/jellyfin-sts.yaml`
- `apps/media-server/radarr/radarr-sts.yaml`
- `apps/media-server/qbitt/qbitt-sts.yaml`
- `apps/media-server/jackett/jackett-deploy.yaml`

**What**: Added liveness and readiness probes to all containers

**Why**:
- Kubernetes can automatically detect and restart unhealthy containers
- Prevents traffic from being sent to pods that aren't ready
- Improves overall reliability and uptime
- Follows Kubernetes best practices

**Example** (Jellyfin):
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8096
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health
    port: 8096
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Probe Endpoints**:
- Jellyfin: `/health` on port 8096
- Radarr: `/ping` on port 7878
- qBittorrent: `/` on port 8080
- Jackett: `/health` on port 9117

---

### 4. ✅ Created Comprehensive Documentation

**File**: `apps/media-server/README.md` (NEW)

**What**: Complete configuration and integration guide

**Includes**:
- Architecture overview and workflow diagram
- Storage configuration details
- Step-by-step integration instructions for all applications
- Troubleshooting guide
- Maintenance commands
- Security notes

**Purpose**: Provides clear instructions on how to configure the applications to work together

---

### 5. ✅ Created Prowlarr Migration Guide

**File**: `apps/media-server/PROWLARR_MIGRATION.md` (NEW)

**What**: Evaluation and migration guide for Prowlarr (modern Jackett alternative)

**Includes**:
- Comparison: Prowlarr vs Jackett
- When to migrate and when to stick with Jackett
- Complete deployment manifests for Prowlarr
- Step-by-step migration instructions
- Recommendation based on current setup

**Recommendation**: Stick with Jackett for now since you only have Radarr. Consider Prowlarr if you add Sonarr (TV shows) in the future.

---

### 6. ✅ Created Kustomization Files

**Files**: (NEW)
- `apps/media-server/jellyfin/kustomization.yaml`
- `apps/media-server/radarr/kustomization.yaml`
- `apps/media-server/qbitt/kustomization.yaml`
- `apps/media-server/jackett/kustomization.yaml`

**What**: Kustomize configuration files for organized manifest management

**Why**:
- Better organization of Kubernetes manifests
- ArgoCD can use kustomize to apply all resources
- Easier to manage resource ordering
- Follows Kubernetes best practices

**Example** (Jellyfin):
```yaml
resources:
  - nfs-media-pv-pvc.yaml
  - jellyfin-pvc.yaml
  - jellyfin-sts.yaml
  - jellyfin-svc.yaml
  - jellyfin-ingress.yaml

namespace: media
```

---

### 7. ✅ Updated Deployment Script for GitOps

**File**: `apps/media-server/deploy.sh` (UPDATED)

**What**: GitOps-aware deployment script with ArgoCD integration

**Features**:
- Shows current ArgoCD application status
- Three deployment options: GitOps, Manual ArgoCD Sync, or Direct kubectl
- Checks ArgoCD sync and health status
- Waits for pods to be ready
- Displays access URLs
- Reminds about GitOps best practices

**Usage**:
```bash
cd apps/media-server
./deploy.sh
```

---

## What Was NOT Changed

### ✅ Preserved Existing Configurations

- **Storage**: All existing PVCs and PVs remain unchanged
- **VPN Configuration**: Gluetun with NordVPN settings preserved
- **User/Group IDs**: PUID/PGID settings maintained
- **Node Affinity**: Jellyfin's node affinity to `beelink` preserved
- **Resource Limits**: qBittorrent memory limits preserved
- **Secrets**: nordvpn-secrets remain unchanged

### ✅ No Traefik Middleware

The guide recommends Traefik middleware for security headers, but your cluster uses **Tailscale ingress** instead of Traefik. Tailscale provides:
- Automatic TLS/SSL certificates
- Built-in security
- No need for custom middleware

---

## Deployment Instructions (GitOps with ArgoCD)

This cluster uses **ArgoCD** for GitOps-based deployments. All changes should be committed to Git and synced via ArgoCD.

### Option 1: GitOps Workflow (Recommended)

```bash
# 1. Commit your changes
git add apps/media-server/
git commit -m "feat: improve media server stack with health probes and ingress"

# 2. Push to main branch
git push origin main

# 3. ArgoCD will automatically sync within 3 minutes
# Or manually trigger sync:
argocd app sync jellyfin radarr qbitt jackett
```

**Why GitOps?**
- Single source of truth (Git repository)
- Automatic drift detection and correction
- Audit trail of all changes
- Easy rollback to previous versions

### Option 2: Manual ArgoCD Sync

If you've already pushed changes to Git and want to sync immediately:

```bash
# Using ArgoCD CLI
argocd app sync jellyfin --prune
argocd app sync radarr --prune
argocd app sync qbitt --prune
argocd app sync jackett --prune

# Or use the deployment script
cd apps/media-server
./deploy.sh
# Choose option 2 (Manual ArgoCD Sync)
```

### Option 3: Direct kubectl (NOT Recommended)

Only use this for testing or emergency fixes. This bypasses ArgoCD and may cause drift:

```bash
# Apply using kustomize
kubectl apply -k apps/media-server/jellyfin/
kubectl apply -k apps/media-server/radarr/
kubectl apply -k apps/media-server/qbitt/
kubectl apply -k apps/media-server/jackett/

# Check status
kubectl get pods -n media
kubectl get svc -n media
kubectl get ingress -n media
```

**Warning**: Direct kubectl changes will be overwritten when ArgoCD syncs from Git!

---

## Post-Deployment Configuration

After deploying the updated configurations, you need to configure the applications to work together. Follow the detailed instructions in `README.md`:

1. **Configure Jackett**: Add torrent indexers
2. **Configure qBittorrent**: Set download paths and whitelist Kubernetes subnet
3. **Configure Radarr**: Connect to qBittorrent and Jackett
4. **Configure Jellyfin**: Add media library

---

## Verification Steps

### 1. Check All Pods Are Running

```bash
kubectl get pods -n media
```

Expected output:
```
NAME         READY   STATUS    RESTARTS   AGE
jackett-xxx  1/1     Running   0          Xm
jellyfin-0   1/1     Running   0          Xm
qbitt-0      2/2     Running   0          Xm
radarr-0     1/1     Running   0          Xm
```

### 2. Check Services

```bash
kubectl get svc -n media
```

All services should be `ClusterIP` type (except any you intentionally kept as LoadBalancer).

### 3. Check Ingress

```bash
kubectl get ingress -n media
```

All four applications should have ingress configured.

### 4. Test Access

- Jellyfin: https://jellyfin.tabby-carp.ts.net
- Radarr: https://radarr.tabby-carp.ts.net
- qBittorrent: https://qbitt.tabby-carp.ts.net
- Jackett: https://jackett.tabby-carp.ts.net

### 5. Check Health Probes

```bash
kubectl describe pod jellyfin-0 -n media | grep -A 10 "Liveness\|Readiness"
```

You should see the configured probes.

---

## Rollback Instructions

If you need to rollback any changes:

### Rollback Services to LoadBalancer

```bash
kubectl patch svc jackett -n media -p '{"spec":{"type":"LoadBalancer"}}'
kubectl patch svc jellyfin -n media -p '{"spec":{"type":"LoadBalancer"}}'
kubectl patch svc qbitt -n media -p '{"spec":{"type":"LoadBalancer"}}'
```

### Remove Health Probes

Use `kubectl edit` to manually remove the `livenessProbe` and `readinessProbe` sections:

```bash
kubectl edit statefulset jellyfin -n media
kubectl edit statefulset radarr -n media
kubectl edit statefulset qbitt -n media
kubectl edit deployment jackett -n media
```

### Remove Jackett Ingress

```bash
kubectl delete ingress jackett -n media
```

---

## Future Enhancements

Consider adding these applications to complete your media server stack:

1. **Sonarr** - TV show management (like Radarr but for series)
2. **Prowlarr** - Modern indexer manager (replaces Jackett)
3. **Bazarr** - Subtitle management
4. **Overseerr/Jellyseerr** - User request management

See `PROWLARR_MIGRATION.md` for details on Prowlarr.

---

## Support and Troubleshooting

- **Configuration Guide**: See `README.md` for detailed setup instructions
- **Prowlarr Info**: See `PROWLARR_MIGRATION.md` for Jackett alternative
- **Logs**: `kubectl logs -n media <pod-name>`
- **Describe Pod**: `kubectl describe pod -n media <pod-name>`
- **Events**: `kubectl get events -n media --sort-by='.lastTimestamp'`

---

## Summary

✅ **What Changed**:
- Added Jackett ingress
- Standardized services to ClusterIP
- Added health probes to all apps
- Created comprehensive documentation
- Created deployment automation

✅ **What Stayed the Same**:
- All storage configurations
- VPN setup
- Application data and settings
- User/group permissions
- Node affinity rules

✅ **Result**:
- More reliable deployments (health probes)
- Better security (ClusterIP services)
- Complete access via Tailscale (all apps have ingress)
- Clear documentation for configuration
- Automated deployment process

