# 🎯 Media Server Quick Reference

One-page cheat sheet for your media server stack.

---

## 🌐 **Access URLs**

| Application | URL | Purpose |
|-------------|-----|---------|
| **Jellyfin** | https://jellyfin.tabby-carp.ts.net | 🎬 Watch movies/TV |
| **Jellyseerr** | https://jellyseerr.tabby-carp.ts.net | 🎫 Request content |
| **Radarr** | https://radarr.tabby-carp.ts.net | 🎬 Manage movies |
| **Sonarr** | https://sonarr.tabby-carp.ts.net | 📺 Manage TV shows |
| **Bazarr** | https://bazarr.tabby-carp.ts.net | 💬 Manage subtitles |
| **Jackett** | https://jackett.tabby-carp.ts.net | 🔍 Torrent indexers |
| **qBittorrent** | https://qbitt.tabby-carp.ts.net | 📥 Download torrents |
| **Tdarr** | https://tdarr.tabby-carp.ts.net | 🎞️ Transcode media |

---

## 🔄 **Workflow**

```
User Request (Jellyseerr)
    ↓
Search for Content (Radarr/Sonarr + Jackett)
    ↓
Download Torrent (qBittorrent)
    ↓
Download Subtitles (Bazarr)
    ↓
Transcode if needed (Tdarr)
    ↓
Available in Jellyfin
```

---

## ⚙️ **Common Tasks**

### **Request a Movie/TV Show:**
1. Go to Jellyseerr
2. Search for content
3. Click "Request"
4. Wait for notification

### **Check Download Status:**
1. Go to Radarr/Sonarr → Activity
2. Or go to qBittorrent → Torrents

### **Add Torrent Indexer:**
1. Go to Jackett
2. Add indexer
3. Copy API key
4. Add to Radarr/Sonarr → Settings → Indexers

### **Manually Search for Content:**
1. Go to Radarr/Sonarr
2. Find movie/show
3. Click "Search" or "Interactive Search"

---

## 🐛 **Troubleshooting**

### **Content not downloading:**
- Check Radarr/Sonarr → Activity → Queue
- Check qBittorrent for active torrents
- Check Jackett indexers are working

### **Subtitles missing:**
- Check Bazarr is connected to Radarr/Sonarr
- Check subtitle providers are configured
- Manually search in Bazarr

### **Quality issues:**
- Check Radarr/Sonarr quality profile
- Check Recyclarr sync status
- Manually trigger upgrade search

---

## 📊 **Status Check**

```bash
# Check all pods
kubectl get pods -n media

# Check specific app
kubectl logs -n media <pod-name>

# Restart app
kubectl rollout restart statefulset/<app-name> -n media

# Check Recyclarr sync
kubectl logs -n media -l app=recyclarr --tail=50
```

---

## 🔑 **API Keys Location**

| App | Location |
|-----|----------|
| **Radarr** | Settings → General → Security → API Key |
| **Sonarr** | Settings → General → Security → API Key |
| **Jackett** | Dashboard → Top right |
| **Jellyfin** | Dashboard → API Keys |

---

## 📁 **File Paths**

| Type | Path |
|------|------|
| **Movies** | `/mnt/media/movies` |
| **TV Shows** | `/mnt/media/tv` |
| **Downloads** | `/mnt/downloads` |
| **Config** | PVCs in Longhorn |

---

## ✅ **Configuration Status**

| App | Status | Next Step |
|-----|--------|-----------|
| Jellyfin | ✅ Ready | - |
| Jellyseerr | ✅ Ready | Configure Sonarr |
| Radarr | ✅ Ready | - |
| Sonarr | ⚠️ Needs Config | Add indexers, download client |
| Bazarr | ⚠️ Needs Config | Connect to Radarr/Sonarr |
| Jackett | ✅ Ready | - |
| qBittorrent | ✅ Ready | - |
| Tdarr | ⚠️ Needs Config | Add libraries |
| Recyclarr | ✅ Ready (Radarr) | Add Sonarr API key |
| Cross-seed | ⚠️ Needs Config | Configure qBittorrent |

---

## 🚨 **Emergency Commands**

```bash
# Restart all media apps
kubectl rollout restart statefulset -n media

# Check storage
kubectl get pvc -n media

# Check ingress
kubectl get ingress -n media

# Force Recyclarr sync
kubectl create job --from=cronjob/recyclarr recyclarr-manual-$(date +%s) -n media

# View app logs
kubectl logs -n media <pod-name> --tail=100 -f
```

---

**Quick Help:** See `MEDIA-SERVER-GUIDE.md` for detailed documentation.

