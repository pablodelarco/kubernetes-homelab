# 🔍 Radarr Diagnostic Report
**Date**: 2025-11-09  
**Issue**: Movies not being downloaded from Jellyseerr requests

---

## **Summary**

### **Root Causes Identified:**

1. ❌ **CRITICAL**: Radarr Skyhook API (radarr.servarr.com) is **completely blocked/unreachable**
   - IP: 188.114.96.5 (Cloudflare)
   - 100% packet loss
   - Connection timeout on port 443
   - **This prevents Radarr from fetching movie metadata**

2. ⚠️ **CONFIGURATION**: Jellyseerr is using wrong root folder path
   - Current: `/movies`
   - Should be: `/movies/movies/`

3. ✅ **qBittorrent**: Working perfectly
   - API responding (v5.1.2)
   - VPN connected (Netherlands - 86.104.22.234)
   - Download folder accessible

---

## **Detailed Findings**

### **1. Network Connectivity Tests**

#### **From Radarr Pod:**
```bash
# DNS Resolution - ✅ WORKS
radarr.servarr.com → 188.114.96.5, 188.114.97.5

# Ping - ❌ FAILS
188.114.96.5 → 100% packet loss

# HTTPS Connection - ❌ FAILS
https://radarr.servarr.com → Connection timeout after 10s

# IPv6 - ❌ NOT AVAILABLE
2a06:98c1:3120::5 → Network unreachable
```

#### **From Host:**
```bash
# Same results - API is blocked at network level
```

#### **Other Services:**
```bash
# Google - ✅ WORKS
https://www.google.com → 200 OK

# TMDB API - ✅ WORKS (with auth)
https://api.themoviedb.org → 401 (requires API key, but reachable)

# qBittorrent - ✅ WORKS
http://qbitt.media.svc.cluster.local:80 → Connection successful
```

---

### **2. Radarr Logs Analysis**

**Error Pattern:**
```
[Warn] SkyHookProxy: System.Net.WebException: Http request timed out
System.Threading.Tasks.TaskCanceledException: A task was canceled
```

**What's happening:**
- Radarr tries to fetch movie metadata from radarr.servarr.com
- Connection times out after ~10 seconds
- Movie cannot be added to Radarr
- Jellyseerr marks request as FAILED

---

### **3. Folder Structure**

#### **Current Setup:**
```
NFS: /volume1/media_player/
├── movies/              ← Organized movies
│   ├── Conclave (2024)/
│   ├── Interstellar (2014)/
│   └── ...
├── temp/                ← Downloads (empty)
└── [old files]
```

#### **Container Mounts:**
| Service | Mount | Maps To | Status |
|---------|-------|---------|--------|
| Radarr | `/movies` | `/volume1/media_player` | ⚠️ Wrong |
| Radarr | `/downloads` | `/volume1/media_player/temp` | ✅ OK |
| qBittorrent | `/downloads` | `/volume1/media_player/temp` | ✅ OK |

**Issue**: Radarr sees `/movies/` but movies are in `/movies/movies/`

---

### **4. qBittorrent Status**

✅ **All checks passed:**
- API Version: v5.1.2
- VPN: Connected (NordVPN Netherlands)
- Public IP: 86.104.22.234 (Netherlands)
- Download folder: `/downloads/` (accessible, empty)
- Web UI: Responding on port 8080
- Gluetun: VPN tunnel active

---

## **Why Movies Are Not Downloading**

### **The Flow:**

1. **User requests movie in Jellyseerr** ✅
2. **Jellyseerr sends request to Radarr** ✅
   - With root folder: `/movies` (wrong, but not critical)
3. **Radarr tries to fetch movie metadata from Skyhook API** ❌ **FAILS HERE**
   - Connection to radarr.servarr.com times out
   - Cannot get movie details (title, year, quality, etc.)
4. **Radarr returns error to Jellyseerr** ❌
5. **Jellyseerr marks request as FAILED** ❌
6. **Movie is never sent to qBittorrent** ❌

---

## **Solutions**

### **Option 1: Fix Network Blocking (Recommended)**

The Skyhook API is hosted on Cloudflare (188.114.96.5). It might be blocked by:
- **Your ISP** (some ISPs block Cloudflare IPs)
- **Your router/firewall**
- **Pi-hole or DNS filtering**
- **Cloudflare blocking your IP** (rate limiting)

**Steps to diagnose:**
1. Check if you have Pi-hole or AdGuard blocking Cloudflare
2. Try accessing https://radarr.servarr.com/v1/ping from your browser
3. Check your router firewall rules
4. Contact your ISP if needed

**Temporary workaround:**
- Use a VPN on the Radarr pod (similar to qBittorrent)
- Or use a proxy

---

### **Option 2: Fix Jellyseerr Root Folder**

Even if we fix the network issue, Jellyseerr needs the correct path:

1. Open **Jellyseerr UI**
2. Go to **Settings** → **Services** → **Radarr**
3. Change **Default Root Folder** from `/movies` to `/movies/movies/`
4. Click **Save** and **Test**

---

### **Option 3: Fix Radarr Root Folder**

1. Open **Radarr UI**
2. Go to **Settings** → **Media Management** → **Root Folders**
3. Delete `/movies` if it exists
4. Add `/movies/movies/`
5. Click **Save**

---

## **Immediate Next Steps**

### **Priority 1: Unblock Skyhook API**

**Test from your computer:**
```bash
curl -v https://radarr.servarr.com/v1/ping
```

If this fails, the issue is at your network level.

**Possible fixes:**
- Disable Pi-hole temporarily
- Check router firewall
- Add firewall rule to allow 188.114.96.5:443
- Use VPN for Radarr pod

---

### **Priority 2: Update Jellyseerr Configuration**

Once Skyhook is accessible, update the root folder path in Jellyseerr.

---

## **Testing Commands**

### **Test Skyhook API:**
```bash
# From host
curl -4 --max-time 5 https://radarr.servarr.com/v1/ping

# From Radarr pod
kubectl exec -it radarr-0 -n media -- curl --max-time 5 https://radarr.servarr.com/v1/ping
```

### **Test qBittorrent:**
```bash
# From Radarr pod
kubectl exec -it radarr-0 -n media -- nc -zv qbitt.media.svc.cluster.local 80
```

### **Check Radarr logs:**
```bash
kubectl logs radarr-0 -n media --tail=100 | grep -E "SkyHook|timeout|error"
```

---

## **Current Status**

| Component | Status | Notes |
|-----------|--------|-------|
| **Radarr** | ❌ Cannot fetch metadata | Skyhook API blocked |
| **qBittorrent** | ✅ Working | VPN active, ready to download |
| **Jellyseerr** | ⚠️ Wrong config | Root folder path incorrect |
| **Network** | ❌ Blocking Cloudflare | ISP/firewall issue |
| **Folders** | ✅ Correct | Structure is good |

---

## **Conclusion**

The main blocker is **network-level blocking of radarr.servarr.com (Cloudflare IP 188.114.96.5)**.

Until this is resolved, Radarr cannot fetch movie metadata and will fail all requests from Jellyseerr.

**Recommended action**: Check your network firewall/Pi-hole/router to unblock Cloudflare IPs or add a VPN to the Radarr pod.

