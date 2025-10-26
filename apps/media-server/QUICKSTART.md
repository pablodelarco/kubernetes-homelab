# Media Server Stack - Quick Start Guide

## 🚀 Deploy in 3 Steps

### Step 1: Commit and Push Changes

```bash
# From the repository root
git add apps/media-server/
git commit -m "feat(media): improve media server stack configuration"
git push origin main
```

### Step 2: Sync via ArgoCD

```bash
# Wait for auto-sync (3 minutes) OR trigger manually:
argocd app sync jellyfin radarr qbitt jackett
```

### Step 3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n media

# Expected output:
# NAME         READY   STATUS    RESTARTS   AGE
# jackett-xxx  1/1     Running   0          Xm
# jellyfin-0   1/1     Running   0          Xm
# qbitt-0      2/2     Running   0          Xm
# radarr-0     1/1     Running   0          Xm
```

## 🔧 Configure in 4 Steps

### 1. Jackett - Add Indexers

```
URL: https://jackett.tabby-carp.ts.net
1. Click "Add indexer"
2. Add: 1337x, RARBG, The Pirate Bay (or your preferred indexers)
3. Copy API key (top-right corner)
```

### 2. qBittorrent - Set Paths

```
URL: https://qbitt.tabby-carp.ts.net
Password: kubectl logs -n media qbitt-0 -c qbitt | grep password

Settings → Downloads:
- Default Save Path: /downloads/complete
- Incomplete torrents: /downloads/incomplete

Settings → Web UI:
- Whitelist subnet: 10.43.0.0/16
```

### 3. Radarr - Connect Everything

```
URL: https://radarr.tabby-carp.ts.net

Add Download Client (Settings → Download Clients):
- Type: qBittorrent
- Host: qbitt.media.svc.cluster.local
- Port: 80

Add Indexers (Settings → Indexers):
- Type: Torznab (Custom)
- URL: http://jackett.media.svc.cluster.local/api/v2.0/indexers/[id]/results/torznab/
- API Key: (from Jackett)

Set Root Folder (Settings → Media Management):
- Path: /movies
```

### 4. Jellyfin - Add Library

```
URL: https://jellyfin.tabby-carp.ts.net

Add Media Library:
- Content type: Movies
- Folder: /data/videos
```

## ✅ Test the Workflow

1. **In Radarr**: Search for a movie → Add Movie
2. **Radarr**: Searches indexers via Jackett
3. **Radarr**: Sends torrent to qBittorrent
4. **qBittorrent**: Downloads via VPN
5. **Radarr**: Imports to `/movies`
6. **Jellyfin**: Displays the movie

## 📚 Full Documentation

- **Complete Guide**: [README.md](./README.md)
- **GitOps Workflow**: [GITOPS_DEPLOYMENT.md](./GITOPS_DEPLOYMENT.md)
- **Changes Made**: [CHANGES_SUMMARY.md](./CHANGES_SUMMARY.md)
- **Deployment Summary**: [DEPLOYMENT_SUMMARY.md](./DEPLOYMENT_SUMMARY.md)

## 🆘 Quick Troubleshooting

### Pods not running?
```bash
kubectl describe pod <pod-name> -n media
kubectl logs -n media <pod-name>
```

### ArgoCD not syncing?
```bash
argocd app get jellyfin
argocd app sync jellyfin --force
```

### Can't access applications?
```bash
kubectl get ingress -n media
# Verify Tailscale ingress is configured
```

### Radarr can't connect to qBittorrent?
- Check qBittorrent Web UI settings
- Verify subnet `10.43.0.0/16` is whitelisted
- Use internal DNS: `qbitt.media.svc.cluster.local`

## 🎯 Access URLs

- **Jellyfin**: https://jellyfin.tabby-carp.ts.net
- **Radarr**: https://radarr.tabby-carp.ts.net
- **qBittorrent**: https://qbitt.tabby-carp.ts.net
- **Jackett**: https://jackett.tabby-carp.ts.net

---

**That's it!** Your automated movie downloading and streaming system is ready. 🎬

