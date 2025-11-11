# 🎬 Media Stack Complete Interconnection Guide

**Last Updated:** 2025-11-09  
**Status:** ✅ Fully Operational

---

## 📊 Architecture Overview

The media stack consists of **11 interconnected applications** organized into 5 layers:

1. **User-Facing Layer**: Jellyfin, Jellyseerr
2. **Automation Layer**: Radarr, Sonarr, Bazarr
3. **Indexing & Download Layer**: Jackett, qBittorrent
4. **VPN Layer**: Gluetun (sidecars)
5. **Maintenance Layer**: Recyclarr, Tdarr, Posterr

---

## 🔗 Service Endpoints & APIs

### **User-Facing Applications**

#### **Jellyfin** (Media Server)
- **Container Port:** 8096
- **Service:** `jellyfin.media.svc.cluster.local:80`
- **NodePort:** 30096
- **Tailscale Ingress:** `https://jellyfin.tail-scale.ts.net`
- **API Base:** `/api`
- **Authentication:** API Key in header `X-Emby-Token`

**Key API Endpoints:**
```
GET  /api/System/Info                    # System information
GET  /api/Items                          # Get media items
GET  /api/Users/{userId}/Items           # Get user's library
POST /api/Library/Refresh                # Trigger library scan
```

#### **Jellyseerr** (Request Manager)
- **Container Port:** 5055
- **Service:** `jellyseerr.media.svc.cluster.local:5055`
- **Tailscale Ingress:** `https://jellyseerr.tail-scale.ts.net`
- **API Base:** `/api/v1`
- **Authentication:** API Key in header `X-Api-Key`

**Key API Endpoints:**
```
GET  /api/v1/status                      # Health check
POST /api/v1/request                     # Create media request
GET  /api/v1/request                     # List requests
GET  /api/v1/service/radarr              # Get Radarr config
GET  /api/v1/service/sonarr              # Get Sonarr config
```

**Jellyseerr → Radarr Integration:**
```
POST http://radarr.media.svc.cluster.local/api/v3/movie
Headers: X-Api-Key: {radarr_api_key}
Body: {
  "title": "Movie Title",
  "tmdbId": 12345,
  "qualityProfileId": 4,
  "rootFolderPath": "/movies/movies/",
  "monitored": true,
  "addOptions": {"searchForMovie": true}
}
```

---

### **Automation Layer (Servarr Stack)**

#### **Radarr** (Movie Manager)
- **Container Port:** 7878
- **Service:** `radarr.media.svc.cluster.local:80`
- **Tailscale Ingress:** `https://radarr.tail-scale.ts.net`
- **API Base:** `/api/v3`
- **Authentication:** API Key in query param `?apikey=` or header `X-Api-Key`
- **VPN:** HTTP_PROXY=localhost:8888 (Gluetun sidecar)

**Key API Endpoints:**
```
GET  /api/v3/system/status               # System info
GET  /api/v3/health                      # Health checks
GET  /api/v3/movie                       # List all movies
POST /api/v3/movie                       # Add movie
GET  /api/v3/movie/lookup?term=avatar    # Search movies (via Skyhook)
GET  /api/v3/indexer                     # List indexers
GET  /api/v3/downloadclient              # List download clients
POST /api/v3/command                     # Execute commands
```

**Radarr → Skyhook API (via VPN):**
```
GET https://radarr.servarr.com/v1/movie/lookup?term=avatar
→ Proxied through Gluetun (HTTP_PROXY=localhost:8888)
→ Returns TMDB metadata
```

**Radarr → Jackett Integration:**
```
GET http://jackett.media.svc.cluster.local/api/v2.0/indexers/1337x/results/torznab/api
Params: t=search, cat=2000,2010, q=Movie+Title, apikey={jackett_api_key}
→ Returns torrent results in Torznab XML format
```

**Radarr → qBittorrent Integration:**
```
POST http://qbitt.media.svc.cluster.local/api/v2/torrents/add
Headers: Cookie: SID={session_id}
Body: urls={magnet_link}&category=movies&savepath=/downloads
→ Adds torrent to qBittorrent with "movies" category
```

#### **Sonarr** (TV Show Manager)
- **Container Port:** 8989
- **Service:** `sonarr.media.svc.cluster.local:8989`
- **Tailscale Ingress:** `https://sonarr.tail-scale.ts.net`
- **API Base:** `/api/v3`
- **Authentication:** API Key in query param `?apikey=` or header `X-Api-Key`
- **VPN:** None (direct connection)

**Key API Endpoints:**
```
GET  /api/v3/system/status               # System info
GET  /api/v3/series                      # List all series
POST /api/v3/series                      # Add series
GET  /api/v3/series/lookup?term=breaking # Search series (via Skyhook)
GET  /api/v3/episode                     # List episodes
```

**Sonarr → Skyhook API (Direct):**
```
GET https://sonarr.servarr.com/v1/series/lookup?term=breaking+bad
→ Direct connection (no VPN)
→ Returns TVDB metadata
```

#### **Bazarr** (Subtitle Manager)
- **Container Port:** 6767
- **Service:** `bazarr.media.svc.cluster.local:6767`
- **Tailscale Ingress:** `https://bazarr.tail-scale.ts.net`
- **API Base:** `/api`
- **Authentication:** API Key in header `X-API-KEY`

**Key API Endpoints:**
```
GET  /api/system/status                  # System info
GET  /api/movies                         # List movies (from Radarr)
GET  /api/series                         # List series (from Sonarr)
POST /api/movies/subtitles               # Download movie subtitles
POST /api/episodes/subtitles             # Download episode subtitles
```

**Bazarr → Radarr Integration:**
```
GET http://radarr.media.svc.cluster.local/api/v3/movie
Headers: X-Api-Key: {radarr_api_key}
→ Fetches movie list to sync
```

**Bazarr → OpenSubtitles API:**
```
POST https://api.opensubtitles.com/api/v1/download
Headers: Api-Key: {opensubtitles_api_key}
→ Downloads subtitle files (.srt)
→ Saves to /media/movies/Movie (Year)/Movie.srt
```

---

### **Indexing & Download Layer**

#### **Jackett** (Indexer Proxy)
- **Container Port:** 9117
- **Service:** `jackett.media.svc.cluster.local:80`
- **Tailscale Ingress:** `https://jackett.tail-scale.ts.net`
- **API Base:** `/api/v2.0`
- **Authentication:** API Key in query param `?apikey=`
- **VPN:** HTTP_PROXY=qbitt.media.svc.cluster.local:8888 (uses qBittorrent's Gluetun)

**Key API Endpoints:**
```
GET  /api/v2.0/indexers                  # List configured indexers
GET  /api/v2.0/indexers/{indexer}/results/torznab/api
     ?t=search&q={query}&cat={categories}&apikey={key}
     → Returns Torznab XML with torrent results
```

**Configured Indexers:**
- 1337x (via Torznab)
- The Pirate Bay (via Torznab)
- TheRARBG (via Torznab)
- DonTorrent (via Torznab)
- 4+ more indexers

**Jackett → Indexers (via VPN):**
```
GET https://1337x.to/search/{query}
→ Proxied through qBittorrent's Gluetun (HTTP_PROXY)
→ Scrapes torrent results
→ Converts to Torznab XML format
```

#### **qBittorrent** (Torrent Client)
- **Container Port:** 8080
- **Service:** `qbitt.media.svc.cluster.local:80`
- **HTTP Proxy Port:** 8888 (Gluetun)
- **Tailscale Ingress:** `https://qbitt.tail-scale.ts.net`
- **API Base:** `/api/v2`
- **Authentication:** Cookie-based (POST /api/v2/auth/login)
- **VPN:** Gluetun sidecar (all traffic routed through VPN)

**Key API Endpoints:**
```
POST /api/v2/auth/login                  # Login (get SID cookie)
     Body: username=admin&password=adminadmin
GET  /api/v2/app/version                 # Get version
GET  /api/v2/torrents/info               # List all torrents
POST /api/v2/torrents/add                # Add torrent
     Body: urls={magnet}&category={cat}&savepath=/downloads
GET  /api/v2/torrents/properties?hash={hash}  # Get torrent details
POST /api/v2/torrents/delete?hashes={hash}    # Delete torrent
```

**qBittorrent Categories:**
- `movies` → Radarr downloads
- `tv` → Sonarr downloads
- `manual` → Manual downloads

**Download Flow:**
```
1. Radarr/Sonarr → POST /api/v2/torrents/add
2. qBittorrent downloads to /downloads/ (qbitt-temp PVC)
3. Radarr/Sonarr monitors via GET /api/v2/torrents/info
4. On completion, Radarr/Sonarr moves files:
   - Movies: /downloads/ → /movies/movies/Movie (Year)/
   - TV: /downloads/ → /tv/Series Name/Season XX/
```

---

### **VPN Layer**

#### **Gluetun** (VPN Client - qBittorrent Sidecar)
- **Container:** Sidecar in qbitt-0 pod
- **HTTP Proxy Port:** 8888
- **VPN Provider:** NordVPN
- **Server Location:** Netherlands (Amsterdam)
- **Public IP:** 176.97.206.215

**Environment Variables:**
```yaml
VPN_SERVICE_PROVIDER: nordvpn
SERVER_COUNTRIES: Netherlands
HTTPPROXY: on
HTTPPROXY_LISTENING_ADDRESS: :8888
FIREWALL_OUTBOUND_SUBNETS: 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

**Proxy Usage:**
- Jackett uses: `HTTP_PROXY=qbitt.media.svc.cluster.local:8888`
- qBittorrent traffic automatically routed through VPN tunnel

#### **Gluetun** (VPN Client - Radarr Sidecar)
- **Container:** Sidecar in radarr-0 pod
- **HTTP Proxy Port:** 8888 (localhost only)
- **VPN Provider:** NordVPN
- **Server Location:** Netherlands (Amsterdam)

**Split-Tunnel Configuration:**
```yaml
# Radarr container environment
HTTP_PROXY: http://localhost:8888
HTTPS_PROXY: http://localhost:8888
NO_PROXY: localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.svc,.svc.cluster,.svc.cluster.local

# Gluetun container environment
DNS_ADDRESS: 10.43.0.10  # Kubernetes DNS
FIREWALL_OUTBOUND_SUBNETS: 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

**Traffic Routing:**
- External APIs (Skyhook) → Through VPN proxy
- Internal cluster services (qBittorrent, Jackett) → Direct (NO_PROXY)

---

## 📁 Storage Architecture

### **NFS Volumes (Shared Media)**

**NFS Server:** 192.168.1.42:/volume1/media_player

#### **jellyfin-videos PVC**
- **Size:** 400Gi
- **Access Mode:** ReadWriteMany (RWX)
- **Mount Points:**
  - Jellyfin: `/data/media` → `/volume1/media_player`
  - Radarr: `/movies` → `/volume1/media_player`
  - Sonarr: `/tv` → `/volume1/media_player`
  - Bazarr: `/media` → `/volume1/media_player`
  - Tdarr: `/media` → `/volume1/media_player`

**Folder Structure:**
```
/volume1/media_player/
├── movies/                    ← Organized movies (Radarr destination)
│   ├── Interstellar (2014)/
│   │   ├── Interstellar (2014) - 1080p.mkv
│   │   └── Interstellar (2014).srt
│   └── Fight Club (1999)/
├── tv/                        ← Organized TV shows (Sonarr destination)
│   └── Breaking Bad/
│       └── Season 01/
└── temp/                      ← See qbitt-temp PVC below
```

#### **qbitt-temp PVC**
- **Size:** 50Gi
- **Access Mode:** ReadWriteMany (RWX)
- **Mount Points:**
  - qBittorrent: `/downloads` → `/volume1/media_player/temp`
  - Radarr: `/downloads` → `/volume1/media_player/temp`
  - Sonarr: `/downloads` → `/volume1/media_player/temp`
  - Bazarr: `/downloads` → `/volume1/media_player/temp`

**Purpose:** Temporary staging area for incomplete downloads

### **Longhorn Volumes (Config & Metadata)**

**Storage Class:** longhorn  
**Access Mode:** ReadWriteOnce (RWO)

| Application | PVC Name | Size | Purpose |
|-------------|----------|------|---------|
| Jellyfin | jellyfin | 10Gi | Config, cache, metadata |
| Radarr | radarr | 5Gi | Config, database |
| Sonarr | sonarr | 5Gi | Config, database |
| Bazarr | bazarr | 2Gi | Config, database |
| Jellyseerr | jellyseerr | 2Gi | Config, database |
| qBittorrent | qbitt | 5Gi | Config, session data |
| Jackett | jackett | 1Gi | Config, indexer settings |
| Tdarr | tdarr-config | 5Gi | Config |
| Tdarr | tdarr-server | 10Gi | Server data |
| Tdarr | tdarr-logs | 5Gi | Logs |
| Recyclarr | recyclarr | 1Gi | Config, cache |

---

## 🔄 Complete Workflow Examples

### **Movie Request Workflow**

```
1. User requests "Interstellar" in Jellyseerr
   ↓
2. Jellyseerr → POST http://radarr:80/api/v3/movie
   Body: {tmdbId: 157336, rootFolderPath: "/movies/movies/", ...}
   ↓
3. Radarr → GET https://radarr.servarr.com/v1/movie/lookup?term=interstellar
   (via VPN proxy localhost:8888)
   ↓
4. Skyhook → TMDB API → Returns metadata
   ↓
5. Radarr → GET http://jackett:80/api/v2.0/indexers/1337x/results/torznab/api?q=Interstellar
   ↓
6. Jackett → Searches 1337x (via qBittorrent's VPN proxy)
   ↓
7. Jackett → Returns Torznab XML with torrent results
   ↓
8. Radarr selects best release → POST http://qbitt:80/api/v2/torrents/add
   Body: urls=magnet:..., category=movies
   ↓
9. qBittorrent downloads via VPN to /downloads/Interstellar.2014.1080p.mkv
   ↓
10. Radarr monitors → GET http://qbitt:80/api/v2/torrents/info
   ↓
11. Download complete → Radarr moves file:
    /downloads/Interstellar.2014.1080p.mkv
    → /movies/movies/Interstellar (2014)/Interstellar (2014) - 1080p.mkv
   ↓
12. Jellyfin scans /data/media/movies/ → Detects new movie
   ↓
13. User streams "Interstellar" in Jellyfin
```

---

## 🛠️ Maintenance & Optimization

### **Recyclarr** (Quality Profile Sync)
- **Type:** CronJob
- **Schedule:** Daily at 3:00 AM
- **Purpose:** Sync TRaSH Guides quality profiles to Radarr/Sonarr

**API Calls:**
```
GET  http://radarr:80/api/v3/qualityprofile
PUT  http://radarr:80/api/v3/qualityprofile/{id}
→ Updates quality profiles, custom formats, release profiles
```

### **Tdarr** (Media Transcoder)
- **Container Port:** 8265 (Web UI), 8266 (Server)
- **Service:** `tdarr.media.svc.cluster.local:8265`
- **Purpose:** Transcode media to optimize storage/compatibility

**Workflow:**
```
1. Tdarr scans /media/movies/ and /media/tv/
2. Identifies files needing transcoding (e.g., H.264 → H.265)
3. Transcodes in /temp/ (transcode-cache PVC)
4. Replaces original file with optimized version
```

### **Posterr** (Poster Downloader)
- **Type:** CronJob
- **Schedule:** Daily at 2:00 AM
- **Purpose:** Download high-quality posters for movies

**API Calls:**
```
GET http://radarr:80/api/v3/movie
→ Fetches movie list
→ Downloads posters from TMDB
→ Saves to /movies/movies/Movie (Year)/poster.jpg
```

---

## 🔐 Security & Network Policies

### **VPN Traffic Routing**

| Application | External Traffic | Internal Traffic | VPN |
|-------------|------------------|------------------|-----|
| qBittorrent | ✅ Via VPN | ✅ Via VPN | Gluetun Sidecar |
| Radarr | ✅ Via VPN Proxy | ❌ Direct | Gluetun Sidecar |
| Sonarr | ❌ Direct | ❌ Direct | None |
| Jackett | ✅ Via qBitt Proxy | ❌ Direct | Uses qBitt's Gluetun |
| Jellyfin | ❌ Direct | ❌ Direct | None |
| Jellyseerr | ❌ Direct | ❌ Direct | None |
| Bazarr | ❌ Direct | ❌ Direct | None |

### **API Authentication**

| Application | Auth Method | Header/Param |
|-------------|-------------|--------------|
| Radarr | API Key | `X-Api-Key` or `?apikey=` |
| Sonarr | API Key | `X-Api-Key` or `?apikey=` |
| Bazarr | API Key | `X-API-KEY` |
| Jellyfin | API Key | `X-Emby-Token` |
| Jellyseerr | API Key | `X-Api-Key` |
| Jackett | API Key | `?apikey=` |
| qBittorrent | Cookie | `Cookie: SID=...` |

---

## 📞 Service Discovery

All services use Kubernetes DNS for service discovery:

```
{service-name}.{namespace}.svc.cluster.local
```

**Examples:**
- `radarr.media.svc.cluster.local:80`
- `qbitt.media.svc.cluster.local:80`
- `jackett.media.svc.cluster.local:80`
- `jellyfin.media.svc.cluster.local:80`

**Short forms also work within the same namespace:**
- `radarr:80`
- `qbitt:80`
- `jackett:80`

---

## 🚨 Troubleshooting

### **Check Service Connectivity**

```bash
# From Radarr to qBittorrent
kubectl exec -it radarr-0 -n media -c radarr -- curl http://qbitt:80/api/v2/app/version

# From Radarr to Jackett
kubectl exec -it radarr-0 -n media -c radarr -- curl http://jackett:80/api/v2.0/indexers

# From Radarr to Skyhook (via VPN)
kubectl exec -it radarr-0 -n media -c radarr -- curl https://radarr.servarr.com/v1/ping
```

### **Check VPN Status**

```bash
# Check qBittorrent's VPN IP
kubectl exec -it qbitt-0 -n media -c gluetun -- wget -qO- https://api.ipify.org

# Check Radarr's VPN IP
kubectl exec -it radarr-0 -n media -c gluetun -- wget -qO- https://api.ipify.org
```

### **Check API Keys**

```bash
# Get Radarr API key
kubectl exec -it radarr-0 -n media -c radarr -- cat /config/config.xml | grep -oP '(?<=<ApiKey>)[^<]+'

# Get Sonarr API key
kubectl exec -it sonarr-0 -n media -c sonarr -- cat /config/config.xml | grep -oP '(?<=<ApiKey>)[^<]+'
```

---

## 📚 Additional Resources

- **Radarr API Docs:** https://radarr.video/docs/api/
- **Sonarr API Docs:** https://sonarr.tv/docs/api/
- **qBittorrent API Docs:** https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)
- **Jellyfin API Docs:** https://api.jellyfin.org/
- **Torznab Spec:** https://torznab.github.io/spec-1.3-draft/

---

**End of Document**

