# 📺 Media Server Stack Guide

Complete guide to all media server applications running in your Kubernetes homelab.

---

## 🎯 **Overview**

Your media server stack is a complete automated media management and streaming solution with 10 applications working together.

### **Architecture Flow:**

```
┌─────────────┐
│  Jellyseerr │ ← Users request movies/TV shows
└──────┬──────┘
       │
       ├──────────────┬──────────────┐
       ▼              ▼              ▼
   ┌────────┐    ┌────────┐    ┌─────────┐
   │ Radarr │    │ Sonarr │    │ Jackett │ ← Search for content
   └───┬────┘    └───┬────┘    └────┬────┘
       │             │              │
       └─────────────┴──────────────┘
                     ▼
              ┌────────────┐
              │ qBittorrent│ ← Download torrents
              └──────┬─────┘
                     │
       ┌─────────────┴──────────────┐
       ▼                            ▼
   ┌────────┐                  ┌──────────┐
   │ Bazarr │                  │  Tdarr   │ ← Post-processing
   └───┬────┘                  └────┬─────┘
       │                            │
       └────────────┬───────────────┘
                    ▼
              ┌──────────┐
              │ Jellyfin │ ← Stream to users
              └──────────┘
                    ▲
              ┌─────┴──────┐
         ┌────────┐   ┌─────────┐
         │Posterr │   │Recyclarr│ ← Maintenance
         └────────┘   └─────────┘
```

---

## 📋 **Application Inventory**

| # | Application | Category | Status | Purpose |
|---|-------------|----------|--------|---------|
| 1 | **Jellyfin** | Media Server | ✅ Running | Stream movies/TV shows |
| 2 | **Jellyseerr** | Request Manager | ✅ Running | User requests interface |
| 3 | **Radarr** | Movie Manager | ✅ Running | Automated movie downloads |
| 4 | **Sonarr** | TV Manager | ✅ Running | Automated TV show downloads |
| 5 | **Bazarr** | Subtitle Manager | ⚠️ Starting | Download subtitles |
| 6 | **Jackett** | Indexer Proxy | ✅ Running | Torrent indexer aggregator |
| 7 | **qBittorrent** | Download Client | ✅ Running | Torrent downloader |
| 8 | **Tdarr** | Transcoder | ✅ Running | Automated transcoding |
| 9 | **Recyclarr** | Config Manager | ✅ Running | Sync TRaSH guides |
| 10 | **Posterr** | Artwork Manager | 📦 Deployed | Generate posters |
| 11 | **Cross-seed** | Seeding Helper | ⚠️ Starting | Cross-seed torrents |

---

## 🎬 **1. Jellyfin** - Media Server

**What it does:** Streams your media library to any device (web, mobile, TV, etc.)

### **Access:**
- **Internal:** `http://beelink:30096`
- **External:** `https://jellyfin.tabby-carp.ts.net`
- **Cluster DNS:** `http://jellyfin.media.svc.cluster.local`

### **Key Features:**
- 🎥 Stream movies and TV shows
- 📱 Apps for all platforms (iOS, Android, Roku, Fire TV, etc.)
- 👥 Multi-user support with separate libraries
- 📊 Watch history and resume playback
- 🎨 Automatic metadata and artwork

### **Storage:**
- **Config:** PVC `jellyfin` (Longhorn)
- **Media:** NFS mount `/mnt/media`

### **Configuration:**
- User: `pablo`
- Libraries configured for movies and TV shows
- Hardware transcoding: Available (if supported)

---

## 🎫 **2. Jellyseerr** - Request Management

**What it does:** Beautiful interface for users to request movies/TV shows

### **Access:**
- **External:** `https://jellyseerr.tabby-carp.ts.net`
- **Cluster DNS:** `http://jellyseerr.media.svc.cluster.local:5055`

### **Key Features:**
- 🔍 Search for movies/TV shows
- ✅ One-click requests
- 📧 Notifications when content is available
- 👥 User management and quotas
- 🎬 Integration with Radarr and Sonarr

### **Connected To:**
- ✅ Jellyfin (authentication and library)
- ✅ Radarr (movie requests)
- ⚠️ Sonarr (TV show requests - needs configuration)

### **Storage:**
- **Config:** PVC `jellyseerr` (Longhorn, 1Gi)

---

## 🎬 **3. Radarr** - Movie Management

**What it does:** Automatically searches, downloads, and organizes movies

### **Access:**
- **External:** `https://radarr.tabby-carp.ts.net`
- **Cluster DNS:** `http://radarr.media.svc.cluster.local`

### **Key Features:**
- 🔍 Automatic movie searching
- 📅 Release calendar
- ⬆️ Automatic quality upgrades
- 📊 Quality profiles (managed by Recyclarr)
- 🎯 Custom formats for release selection

### **Connected To:**
- ✅ Jackett (torrent indexers)
- ✅ qBittorrent (download client)
- ✅ Jellyseerr (receives requests)
- ✅ Recyclarr (quality profile sync)

### **Storage:**
- **Config:** PVC `radarr` (Longhorn)
- **Movies:** NFS mount `/mnt/media/movies`

### **Current Configuration:**
- Quality Profile: HD-1080p
- Managed by Recyclarr with TRaSH guides

---

## 📺 **4. Sonarr** - TV Show Management

**What it does:** Automatically searches, downloads, and organizes TV shows

### **Access:**
- **External:** `https://sonarr.tabby-carp.ts.net`
- **Cluster DNS:** `http://sonarr.media.svc.cluster.local:8989`

### **Key Features:**
- 📅 Episode calendar and tracking
- 🔍 Automatic episode searching
- ⬆️ Automatic quality upgrades
- 📊 Season monitoring
- 🎯 Custom formats for release selection

### **Connected To:**
- ⚠️ Jackett (needs configuration)
- ⚠️ qBittorrent (needs configuration)
- ⚠️ Jellyseerr (needs configuration)
- ⚠️ Recyclarr (needs API key)

### **Storage:**
- **Config:** PVC `sonarr` (Longhorn, 1Gi)
- **TV Shows:** NFS mount `/mnt/media/tv` (needs configuration)

### **Status:**
- ✅ Deployed and running
- ⚠️ Needs initial configuration

---

## 💬 **5. Bazarr** - Subtitle Management

**What it does:** Automatically downloads subtitles for movies and TV shows

### **Access:**
- **External:** `https://bazarr.tabby-carp.ts.net`
- **Cluster DNS:** `http://bazarr.media.svc.cluster.local:6767`

### **Key Features:**
- 🌍 Multi-language subtitle support
- 🔍 Automatic subtitle searching
- 🎯 Subtitle providers (OpenSubtitles, etc.)
- 📊 Integration with Radarr/Sonarr
- ⚙️ Subtitle format conversion

### **Connected To:**
- ⚠️ Radarr (needs configuration)
- ⚠️ Sonarr (needs configuration)

### **Storage:**
- **Config:** PVC `bazarr` (Longhorn, 1Gi)

### **Status:**
- ⚠️ Pod starting (ContainerCreating)

---

## 🔍 **6. Jackett** - Indexer Proxy

**What it does:** Aggregates torrent indexers into a single API for Radarr/Sonarr

### **Access:**
- **External:** `https://jackett.tabby-carp.ts.net`
- **Cluster DNS:** `http://jackett.media.svc.cluster.local`

### **Key Features:**
- 🌐 Support for 100+ torrent indexers
- 🔑 Single API for all indexers
- 🔍 Manual search capability
- 📊 Indexer statistics
- ⚙️ Custom indexer configuration

### **Connected To:**
- ✅ Radarr (configured)
- ⚠️ Sonarr (needs configuration)

### **Storage:**
- **Config:** PVC `jackett` (Longhorn)

---

## 📥 **7. qBittorrent** - Download Client

**What it does:** Downloads torrents sent by Radarr/Sonarr

### **Access:**
- **External:** `https://qbitt.tabby-carp.ts.net`
- **Cluster DNS:** `http://qbitt.media.svc.cluster.local`

### **Key Features:**
- 📥 Torrent downloading
- 🌐 Web UI for management
- 📊 Speed limits and scheduling
- 🎯 Category-based organization
- 🔒 VPN support (Gluetun sidecar)

### **Connected To:**
- ✅ Radarr (configured)
- ⚠️ Sonarr (needs configuration)
- ⚠️ Cross-seed (needs configuration)

### **Storage:**
- **Config:** PVC `qbitt` (Longhorn)
- **Downloads:** NFS mount `/mnt/downloads`

### **VPN:**
- ✅ Gluetun sidecar container
- Network policy enforced

---

## 🎞️ **8. Tdarr** - Automated Transcoding

**What it does:** Automatically transcodes media files to save space and ensure compatibility

### **Access:**
- **External:** `https://tdarr.tabby-carp.ts.net`
- **Cluster DNS:** `http://tdarr.media.svc.cluster.local:8265`

### **Key Features:**
- 🔄 Automated transcoding workflows
- 💾 Space-saving (H.264 → H.265/HEVC)
- 🎯 Custom transcode rules
- 📊 Library health checks
- ⚙️ Hardware acceleration support

### **Storage:**
- **Config:** PVC `tdarr` (Longhorn, 5Gi)
- **Media:** NFS mount (needs configuration)

### **Status:**
- ✅ Running
- ⚠️ Needs library configuration

---

## ⚙️ **9. Recyclarr** - Configuration Manager

**What it does:** Automatically syncs TRaSH guide quality profiles to Radarr/Sonarr

### **Access:**
- No web UI (runs as CronJob)

### **Key Features:**
- 🔄 Automatic quality profile sync
- 📊 TRaSH guide custom formats
- ⏰ Runs every 6 hours
- 🎯 Release group scoring
- ⚙️ Quality definition optimization

### **Connected To:**
- ✅ Radarr (configured and syncing)
- ⚠️ Sonarr (needs API key)

### **Storage:**
- **Config:** PVC `recyclarr` (Longhorn, 1Gi)

### **Schedule:**
- Runs every 6 hours: `0 */6 * * *`

### **Current Status:**
- ✅ Radarr: All profiles synced
- ⚠️ Sonarr: Connection timeout (needs API key)

---

## 🎨 **10. Posterr** - Artwork Manager

**What it does:** Generates custom posters and artwork for your media library

### **Access:**
- No web UI (runs as CronJob)

### **Key Features:**
- 🎨 Custom poster generation
- 📅 Scheduled artwork updates
- 🎯 Integration with media libraries
- ⚙️ Customizable templates

### **Storage:**
- **Config:** PVC `posterr` (Longhorn, 1Gi)

### **Status:**
- 📦 Deployed (CronJob)

---

## 🌱 **11. Cross-seed** - Seeding Helper

**What it does:** Finds and cross-seeds torrents across multiple trackers

### **Access:**
- **Cluster DNS:** `http://cross-seed.media.svc.cluster.local:2468`

### **Key Features:**
- 🌱 Automatic cross-seeding
- 📊 Tracker comparison
- 🎯 Ratio improvement
- ⚙️ Integration with qBittorrent

### **Connected To:**
- ⚠️ qBittorrent (needs configuration)

### **Storage:**
- **Config:** PVC `cross-seed` (Longhorn, 1Gi)

### **Status:**
- ⚠️ Pod starting (ContainerCreating)

---

## 🔗 **Integration Matrix**

| From → To | Jellyfin | Jellyseerr | Radarr | Sonarr | Bazarr | Jackett | qBitt | Tdarr | Recyclarr |
|-----------|----------|------------|--------|--------|--------|---------|-------|-------|-----------|
| **Jellyseerr** | ✅ | - | ✅ | ⚠️ | - | - | - | - | - |
| **Radarr** | - | - | - | - | - | ✅ | ✅ | - | - |
| **Sonarr** | - | - | - | - | - | ⚠️ | ⚠️ | - | - |
| **Bazarr** | - | - | ⚠️ | ⚠️ | - | - | - | - | - |
| **Recyclarr** | - | - | ✅ | ⚠️ | - | - | - | - | - |

**Legend:**
- ✅ Configured and working
- ⚠️ Needs configuration
- `-` Not applicable

---

## 📊 **Quick Reference**

### **All External URLs (Tailscale):**
```
https://jellyfin.tabby-carp.ts.net      # Media streaming
https://jellyseerr.tabby-carp.ts.net    # Request movies/TV
https://radarr.tabby-carp.ts.net        # Movie management
https://sonarr.tabby-carp.ts.net        # TV show management
https://bazarr.tabby-carp.ts.net        # Subtitle management
https://jackett.tabby-carp.ts.net       # Indexer proxy
https://qbitt.tabby-carp.ts.net         # Torrent client
https://tdarr.tabby-carp.ts.net         # Transcoding
```

### **Storage Summary:**
- **Total PVCs:** 11
- **Storage Class:** Longhorn
- **NFS Mounts:** 2 (media, downloads)

### **Namespace:**
All applications run in the `media` namespace.

---

## 🚀 **Next Steps**

### **High Priority:**
1. ⚠️ **Configure Sonarr:**
   - Add Jackett indexers
   - Add qBittorrent download client
   - Connect to Jellyseerr
   - Add Sonarr API key to Recyclarr

2. ⚠️ **Configure Bazarr:**
   - Connect to Radarr
   - Connect to Sonarr
   - Add subtitle providers

### **Medium Priority:**
3. ⚠️ **Configure Tdarr:**
   - Add media libraries
   - Set up transcode workflows
   - Configure hardware acceleration

4. ⚠️ **Configure Cross-seed:**
   - Connect to qBittorrent
   - Add tracker configurations

### **Optional Enhancements:**
5. 🎯 **Enhance Recyclarr:**
   - Add TRaSH guide custom formats
   - Configure release group scoring

---

## 📚 **Documentation Links**

- **Jellyfin:** https://jellyfin.org/docs/
- **Jellyseerr:** https://docs.jellyseerr.dev/
- **Radarr:** https://wiki.servarr.com/radarr
- **Sonarr:** https://wiki.servarr.com/sonarr
- **Bazarr:** https://wiki.bazarr.media/
- **Jackett:** https://github.com/Jackett/Jackett
- **qBittorrent:** https://github.com/qbittorrent/qBittorrent/wiki
- **Tdarr:** https://docs.tdarr.io/
- **Recyclarr:** https://recyclarr.dev/
- **TRaSH Guides:** https://trash-guides.info/

---

**Last Updated:** 2025-11-02
**Maintained by:** Pablo
**Cluster:** kubernetes-homelab

