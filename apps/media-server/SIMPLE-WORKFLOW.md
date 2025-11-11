# 🎬 Media Stack - Simple Workflow Guide

**Last Updated:** 2025-11-09

---

## 📊 The Simple Flow

```
👤 User
  ↓ (1. Request "Interstellar")
📱 Jellyseerr (Request Manager)
  ↓ (2. Add to library)
🎬 Radarr (Movie Manager)
  ↓ (3. Search for torrents)
🔍 Jackett (Torrent Finder)
  ↓ (4. Return torrent links)
🎬 Radarr (Picks best quality)
  ↓ (5. Send torrent)
⬇️ qBittorrent + VPN (Downloader)
  ↓ (6. Download to /temp)
💾 NFS Storage
  ↓ (7. Radarr moves to /movies)
💾 NFS Storage
  ↓ (8. Jellyfin scans)
📺 Jellyfin (Media Server)
  ↓ (9. Stream movie)
👤 User (Watches movie)
```

---

## 🎯 What Each App Does

| App | Purpose | Simple Explanation |
|-----|---------|-------------------|
| **Jellyseerr** | Request Manager | Where you request movies/TV shows |
| **Radarr** | Movie Manager | Finds and organizes movies |
| **Sonarr** | TV Manager | Finds and organizes TV shows |
| **Jackett** | Torrent Finder | Searches torrent sites for you |
| **qBittorrent** | Downloader | Downloads the torrents via VPN |
| **Jellyfin** | Media Server | Where you watch everything |
| **Bazarr** | Subtitle Manager | Downloads subtitles automatically |

---

## 🔄 Complete Example: Requesting "Interstellar"

### **Step 1: User Requests Movie**
- Open Jellyseerr
- Search "Interstellar"
- Click "Request"

### **Step 2: Jellyseerr → Radarr**
- Jellyseerr tells Radarr: "Add Interstellar (TMDB ID: 157336)"
- Radarr adds it to the library

### **Step 3: Radarr → Jackett**
- Radarr asks Jackett: "Find torrents for Interstellar 2014"
- Jackett searches 8 torrent sites (1337x, TPB, RARBG, etc.)

### **Step 4: Jackett → Radarr**
- Jackett returns: "Found 131 torrents!"
- Radarr picks the best one (1080p BluRay)

### **Step 5: Radarr → qBittorrent**
- Radarr sends the torrent to qBittorrent
- Category: "movies"

### **Step 6: qBittorrent Downloads**
- Downloads via VPN (Netherlands)
- Saves to: `/temp/Interstellar.2014.1080p.mkv`

### **Step 7: Radarr Organizes**
- Download complete!
- Radarr moves file:
  - From: `/temp/Interstellar.2014.1080p.mkv`
  - To: `/movies/Interstellar (2014)/Interstellar (2014) - 1080p.mkv`

### **Step 8: Jellyfin Scans**
- Jellyfin detects new movie
- Downloads metadata (poster, description, etc.)
- Adds to library

### **Step 9: User Watches**
- Open Jellyfin
- "Interstellar" appears in library
- Click play and enjoy! 🍿

---

## 🌐 How They Talk to Each Other

### **Service URLs (Internal)**
```
jellyseerr:5055  → Jellyseerr
radarr:80        → Radarr
sonarr:8989      → Sonarr
jackett:80       → Jackett
qbitt:80         → qBittorrent
jellyfin:80      → Jellyfin
bazarr:6767      → Bazarr
```

### **API Calls**

**Jellyseerr → Radarr:**
```
POST http://radarr:80/api/v3/movie
"Hey Radarr, add this movie!"
```

**Radarr → Jackett:**
```
GET http://jackett:80/api/v2.0/indexers/1337x/results/torznab/api?q=Interstellar
"Hey Jackett, find torrents for Interstellar!"
```

**Radarr → qBittorrent:**
```
POST http://qbitt:80/api/v2/torrents/add
"Hey qBittorrent, download this torrent!"
```

---

## 🔒 VPN Setup (Simple)

### **Why VPN?**
- Hides your IP when downloading torrents
- Bypasses ISP blocking of torrent sites

### **What's Protected?**
- ✅ qBittorrent (all downloads)
- ✅ Jackett (searching torrent sites)
- ✅ Radarr (accessing blocked APIs)
- ❌ Jellyfin (no need, just streaming)
- ❌ Jellyseerr (no need, just requests)

### **VPN Details**
- **Provider:** NordVPN
- **Location:** Netherlands (Amsterdam)
- **Your IP:** Hidden (shows as 176.97.206.215)

---

## 💾 Storage (Simple)

### **Where Files Live**

**NFS Server:** `192.168.1.42:/volume1/media_player`

```
/volume1/media_player/
├── movies/                    ← Organized movies (Jellyfin reads from here)
│   ├── Interstellar (2014)/
│   │   └── Interstellar (2014) - 1080p.mkv
│   └── Fight Club (1999)/
│       └── Fight Club (1999) - 1080p.mkv
│
├── tv/                        ← Organized TV shows
│   └── Breaking Bad/
│       └── Season 01/
│           └── Breaking Bad - S01E01.mkv
│
└── temp/                      ← Downloads (qBittorrent saves here first)
    └── Interstellar.2014.1080p.mkv  (gets moved to /movies)
```

---

## 🎯 Quick Troubleshooting

### **Movie not downloading?**
```bash
# Check if Radarr can reach qBittorrent
kubectl exec -it radarr-0 -n media -c radarr -- curl http://qbitt:80/api/v2/app/version
```

### **Can't find torrents?**
```bash
# Check if Jackett is working
kubectl exec -it radarr-0 -n media -c radarr -- curl http://jackett:80/api/v2.0/indexers
```

### **VPN not working?**
```bash
# Check VPN IP (should NOT be your real IP)
kubectl exec -it qbitt-0 -n media -c gluetun -- wget -qO- https://api.ipify.org
```

### **Movie not appearing in Jellyfin?**
```bash
# Trigger library scan
# Go to Jellyfin → Dashboard → Libraries → Scan All Libraries
```

---

## 📱 Access URLs

### **From Your Network**
- Jellyfin: `http://192.168.1.X:30096`
- Jellyseerr: `https://jellyseerr.tail-scale.ts.net`
- Radarr: `https://radarr.tail-scale.ts.net`
- qBittorrent: `https://qbitt.tail-scale.ts.net`

### **From Internet (Tailscale)**
- Jellyfin: `https://jellyfin.tail-scale.ts.net`
- Jellyseerr: `https://jellyseerr.tail-scale.ts.net`

---

## ✅ Current Status

| App | Status | What It's Doing |
|-----|--------|-----------------|
| Jellyfin | ✅ Running | Serving 260+ movies |
| Jellyseerr | ✅ Running | Ready for requests |
| Radarr | ✅ Running | Managing 260 movies |
| Sonarr | ✅ Running | Managing TV shows |
| Jackett | ✅ Running | 8 indexers configured |
| qBittorrent | ✅ Running | 10 active downloads |
| Bazarr | ✅ Running | Downloading subtitles |
| VPN | ✅ Connected | Netherlands (176.97.206.215) |

---

## 🚀 How to Use

### **Request a Movie**
1. Open Jellyseerr
2. Search for movie
3. Click "Request"
4. Wait 5-30 minutes
5. Watch in Jellyfin!

### **Request a TV Show**
1. Open Jellyseerr
2. Search for TV show
3. Click "Request" → Select seasons
4. Wait for episodes to download
5. Watch in Jellyfin!

### **Manual Download**
1. Open qBittorrent
2. Add torrent manually
3. Wait for download
4. File appears in Jellyfin automatically

---

## 🎓 Key Concepts

### **What is Radarr/Sonarr?**
Think of them as "smart download managers" that:
- Know what quality you want
- Search for torrents automatically
- Send them to qBittorrent
- Organize files nicely
- Tell Jellyfin when new content is ready

### **What is Jackett?**
A "torrent search engine" that searches multiple sites at once:
- 1337x
- The Pirate Bay
- RARBG
- And 5+ more

### **What is Jellyseerr?**
A "request system" so you don't have to:
- Search for torrents manually
- Configure Radarr/Sonarr
- Just click "Request" and it handles everything!

---

**That's it! Simple, right?** 🎉

The whole system works automatically:
1. You request → 2. It downloads → 3. You watch

No manual searching, no organizing files, no hassle!

