# 🚀 Media Stack API Quick Reference

**Last Updated:** 2025-11-09

---

## 📋 Service Endpoints Table

| Service | Container Port | Service URL | API Base | Auth Header | VPN |
|---------|----------------|-------------|----------|-------------|-----|
| **Jellyfin** | 8096 | `jellyfin:80` | `/api` | `X-Emby-Token` | ❌ |
| **Jellyseerr** | 5055 | `jellyseerr:5055` | `/api/v1` | `X-Api-Key` | ❌ |
| **Radarr** | 7878 | `radarr:80` | `/api/v3` | `X-Api-Key` | ✅ Proxy |
| **Sonarr** | 8989 | `sonarr:8989` | `/api/v3` | `X-Api-Key` | ❌ |
| **Bazarr** | 6767 | `bazarr:6767` | `/api` | `X-API-KEY` | ❌ |
| **Jackett** | 9117 | `jackett:80` | `/api/v2.0` | `?apikey=` | ✅ qBitt Proxy |
| **qBittorrent** | 8080 | `qbitt:80` | `/api/v2` | `Cookie: SID` | ✅ Sidecar |
| **Tdarr** | 8265 | `tdarr:8265` | `/api` | None | ❌ |

---

## 🔗 Common API Calls

### **Radarr**

```bash
# Get API key
kubectl exec -it radarr-0 -n media -c radarr -- cat /config/config.xml | grep -oP '(?<=<ApiKey>)[^<]+'

# Search for a movie
curl "http://radarr:80/api/v3/movie/lookup?term=avatar&apikey=YOUR_API_KEY"

# List all movies
curl "http://radarr:80/api/v3/movie?apikey=YOUR_API_KEY"

# Add a movie
curl -X POST "http://radarr:80/api/v3/movie?apikey=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Interstellar",
    "tmdbId": 157336,
    "qualityProfileId": 4,
    "rootFolderPath": "/movies/movies/",
    "monitored": true,
    "addOptions": {"searchForMovie": true}
  }'

# Check system status
curl "http://radarr:80/api/v3/system/status?apikey=YOUR_API_KEY"

# Check health
curl "http://radarr:80/api/v3/health?apikey=YOUR_API_KEY"

# List indexers
curl "http://radarr:80/api/v3/indexer?apikey=YOUR_API_KEY"

# List download clients
curl "http://radarr:80/api/v3/downloadclient?apikey=YOUR_API_KEY"
```

### **Sonarr**

```bash
# Get API key
kubectl exec -it sonarr-0 -n media -c sonarr -- cat /config/config.xml | grep -oP '(?<=<ApiKey>)[^<]+'

# Search for a TV show
curl "http://sonarr:8989/api/v3/series/lookup?term=breaking+bad&apikey=YOUR_API_KEY"

# List all series
curl "http://sonarr:8989/api/v3/series?apikey=YOUR_API_KEY"

# Add a series
curl -X POST "http://sonarr:8989/api/v3/series?apikey=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Breaking Bad",
    "tvdbId": 81189,
    "qualityProfileId": 4,
    "rootFolderPath": "/tv/",
    "monitored": true,
    "addOptions": {"searchForMissingEpisodes": true}
  }'
```

### **qBittorrent**

```bash
# Login (get SID cookie)
curl -X POST "http://qbitt:80/api/v2/auth/login" \
  -d "username=admin&password=adminadmin" \
  -c cookies.txt

# Get version
curl "http://qbitt:80/api/v2/app/version" -b cookies.txt

# List all torrents
curl "http://qbitt:80/api/v2/torrents/info" -b cookies.txt

# Add torrent
curl -X POST "http://qbitt:80/api/v2/torrents/add" \
  -b cookies.txt \
  -d "urls=magnet:?xt=..." \
  -d "category=movies" \
  -d "savepath=/downloads"

# Get torrent properties
curl "http://qbitt:80/api/v2/torrents/properties?hash=TORRENT_HASH" -b cookies.txt

# Delete torrent
curl -X POST "http://qbitt:80/api/v2/torrents/delete?hashes=TORRENT_HASH&deleteFiles=true" -b cookies.txt
```

### **Jackett**

```bash
# List indexers
curl "http://jackett:80/api/v2.0/indexers?apikey=YOUR_API_KEY"

# Search via Torznab
curl "http://jackett:80/api/v2.0/indexers/1337x/results/torznab/api?t=search&q=interstellar&cat=2000,2010&apikey=YOUR_API_KEY"
```

### **Jellyseerr**

```bash
# Check status
curl "http://jellyseerr:5055/api/v1/status"

# List requests
curl "http://jellyseerr:5055/api/v1/request" \
  -H "X-Api-Key: YOUR_API_KEY"

# Create movie request
curl -X POST "http://jellyseerr:5055/api/v1/request" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "mediaType": "movie",
    "mediaId": 157336,
    "is4k": false
  }'
```

### **Bazarr**

```bash
# Get system status
curl "http://bazarr:6767/api/system/status" \
  -H "X-API-KEY: YOUR_API_KEY"

# List movies
curl "http://bazarr:6767/api/movies" \
  -H "X-API-KEY: YOUR_API_KEY"

# List series
curl "http://bazarr:6767/api/series" \
  -H "X-API-KEY: YOUR_API_KEY"
```

### **Jellyfin**

```bash
# Get system info
curl "http://jellyfin:80/api/System/Info" \
  -H "X-Emby-Token: YOUR_API_KEY"

# Get library items
curl "http://jellyfin:80/api/Items?Recursive=true" \
  -H "X-Emby-Token: YOUR_API_KEY"

# Trigger library scan
curl -X POST "http://jellyfin:80/api/Library/Refresh" \
  -H "X-Emby-Token: YOUR_API_KEY"
```

---

## 🔄 Integration Examples

### **Jellyseerr → Radarr (Add Movie)**

```bash
# 1. User requests movie in Jellyseerr
# 2. Jellyseerr calls Radarr API

curl -X POST "http://radarr:80/api/v3/movie?apikey=RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Fight Club",
    "tmdbId": 550,
    "qualityProfileId": 4,
    "rootFolderPath": "/movies/movies/",
    "monitored": true,
    "addOptions": {"searchForMovie": true}
  }'
```

### **Radarr → Jackett (Search Torrents)**

```bash
# Radarr searches for torrents via Jackett

curl "http://jackett:80/api/v2.0/indexers/1337x/results/torznab/api?t=search&q=Fight+Club+1999&cat=2000,2010,2020&apikey=JACKETT_API_KEY"

# Returns Torznab XML with magnet links
```

### **Radarr → qBittorrent (Add Torrent)**

```bash
# 1. Login to qBittorrent
curl -X POST "http://qbitt:80/api/v2/auth/login" \
  -d "username=admin&password=adminadmin" \
  -c cookies.txt

# 2. Add torrent
curl -X POST "http://qbitt:80/api/v2/torrents/add" \
  -b cookies.txt \
  -d "urls=magnet:?xt=urn:btih:..." \
  -d "category=movies" \
  -d "savepath=/downloads"
```

### **Bazarr → Radarr (Sync Movies)**

```bash
# Bazarr fetches movie list from Radarr

curl "http://radarr:80/api/v3/movie?apikey=RADARR_API_KEY"

# Returns JSON array of all movies
# Bazarr uses this to know which movies need subtitles
```

---

## 🧪 Testing Connectivity

### **From Radarr Pod**

```bash
# Test qBittorrent
kubectl exec -it radarr-0 -n media -c radarr -- curl http://qbitt:80/api/v2/app/version

# Test Jackett
kubectl exec -it radarr-0 -n media -c radarr -- curl http://jackett:80/api/v2.0/indexers

# Test Skyhook (via VPN)
kubectl exec -it radarr-0 -n media -c radarr -- curl https://radarr.servarr.com/v1/ping

# Test DNS resolution
kubectl exec -it radarr-0 -n media -c radarr -- nslookup qbitt.media.svc.cluster.local
```

### **From qBittorrent Pod**

```bash
# Check VPN IP
kubectl exec -it qbitt-0 -n media -c gluetun -- wget -qO- https://api.ipify.org

# Test torrent indexer (via VPN)
kubectl exec -it qbitt-0 -n media -c qbitt -- curl -I https://1337x.to
```

### **From Jellyseerr Pod**

```bash
# Test Radarr
kubectl exec -it jellyseerr-0 -n media -c jellyseerr -- curl http://radarr:80/api/v3/system/status?apikey=YOUR_API_KEY

# Test Sonarr
kubectl exec -it jellyseerr-0 -n media -c jellyseerr -- curl http://sonarr:8989/api/v3/system/status?apikey=YOUR_API_KEY

# Test Jellyfin
kubectl exec -it jellyseerr-0 -n media -c jellyseerr -- curl http://jellyfin:80/api/System/Info
```

---

## 🔐 Getting API Keys

### **Radarr**
```bash
kubectl exec -it radarr-0 -n media -c radarr -- cat /config/config.xml | grep -oP '(?<=<ApiKey>)[^<]+'
```

### **Sonarr**
```bash
kubectl exec -it sonarr-0 -n media -c sonarr -- cat /config/config.xml | grep -oP '(?<=<ApiKey>)[^<]+'
```

### **Bazarr**
```bash
kubectl exec -it bazarr-0 -n media -c bazarr -- cat /config/config/config.yaml | grep -oP '(?<=apikey: )[^\s]+'
```

### **Jackett**
```bash
kubectl exec -it jackett-0 -n media -c jackett -- cat /config/Jackett/ServerConfig.json | grep -oP '(?<="APIKey": ")[^"]+'
```

### **Jellyfin**
- Go to Dashboard → API Keys → Create new key

### **Jellyseerr**
- Go to Settings → General → API Key

---

## 📊 Service Health Checks

```bash
# Check all pods
kubectl get pods -n media

# Check Radarr health
curl "http://radarr:80/api/v3/health?apikey=YOUR_API_KEY"

# Check Sonarr health
curl "http://sonarr:8989/api/v3/health?apikey=YOUR_API_KEY"

# Check qBittorrent
curl "http://qbitt:80/api/v2/app/version"

# Check Jellyseerr
curl "http://jellyseerr:5055/api/v1/status"

# Check Jellyfin
curl "http://jellyfin:80/health"
```

---

## 🌐 External Access (Tailscale Ingress)

| Service | Tailscale URL |
|---------|---------------|
| Jellyfin | `https://jellyfin.tail-scale.ts.net` |
| Jellyseerr | `https://jellyseerr.tail-scale.ts.net` |
| Radarr | `https://radarr.tail-scale.ts.net` |
| Sonarr | `https://sonarr.tail-scale.ts.net` |
| Bazarr | `https://bazarr.tail-scale.ts.net` |
| Jackett | `https://jackett.tail-scale.ts.net` |
| qBittorrent | `https://qbitt.tail-scale.ts.net` |
| Tdarr | `https://tdarr.tail-scale.ts.net` |

---

## 🚨 Common Issues & Solutions

### **Radarr can't reach Skyhook API**
```bash
# Check VPN status
kubectl exec -it radarr-0 -n media -c gluetun -- wget -qO- https://api.ipify.org

# Test Skyhook
kubectl exec -it radarr-0 -n media -c radarr -- curl https://radarr.servarr.com/v1/ping

# Should return: "Pong"
```

### **Radarr can't reach qBittorrent**
```bash
# Check DNS
kubectl exec -it radarr-0 -n media -c radarr -- nslookup qbitt

# Test connection
kubectl exec -it radarr-0 -n media -c radarr -- curl http://qbitt:80/api/v2/app/version

# Should return version number (not "Forbidden")
```

### **Jackett can't reach indexers**
```bash
# Check if using qBittorrent's VPN proxy
kubectl exec -it jackett-0 -n media -c jackett -- env | grep PROXY

# Should show:
# HTTP_PROXY=http://qbitt.media.svc.cluster.local:8888
# HTTPS_PROXY=http://qbitt.media.svc.cluster.local:8888
```

### **qBittorrent not downloading**
```bash
# Check VPN connection
kubectl logs qbitt-0 -n media -c gluetun | grep "ip"

# Check public IP (should be VPN IP, not your real IP)
kubectl exec -it qbitt-0 -n media -c gluetun -- wget -qO- https://api.ipify.org
```

---

**End of Quick Reference**

