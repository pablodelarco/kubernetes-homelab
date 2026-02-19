# 🎬 Duplicate Movies Issue - Root Cause & Solution

## **Problem:**
Jellyfin was showing duplicate movies (e.g., Lilo & Stitch, The Nightmare Before Christmas, The French Dispatch).

---

## **Root Cause:**

### **NFS Mount Structure:**
```
NFS Server (192.168.1.42):
  /volume1/media_player/              ← Jellyfin mounts THIS (sees everything)
    ├── Conclave (2024)/              ← Organized movies
    ├── Lilo & Stitch (2025)/         ← Organized movies
    ├── The Nightmare.../             ← Organized movies
    └── download/                     ← qBittorrent downloads HERE
        ├── Lilo.And.Stitch.../       ← Downloaded files (duplicates!)
        └── The.Nightmare.../         ← Downloaded files (duplicates!)
```

### **The Flow:**
1. **qBittorrent** downloads to `/downloads/` (which is `/volume1/media_player/download/`)
2. **Radarr** imports and copies/hardlinks to `/movies/Movie (Year)/`
3. **Jellyfin** scans `/data/videos/` and finds:
   - `/data/videos/Movie (Year)/` ✅ Organized
   - `/data/videos/download/Movie.../` ❌ Original download (duplicate!)

### **Why This Happens:**
- Jellyfin's NFS mount (`/volume1/media_player`) **includes** the download folder
- qBittorrent's NFS mount (`/volume1/media_player/download`) is **nested inside** Jellyfin's mount
- Radarr doesn't delete downloads after import by default

---

## **Solution Applied:**

### **1. Cleaned Up Download Folder** ✅
Deleted duplicate files from `/data/videos/download/`:
```bash
kubectl exec -it qbitt-0 -n media -c qbitt -- rm -rf /downloads/*
```

### **2. Configure Radarr to Delete After Import** (Next Step)
In Radarr UI:
1. Go to **Settings** → **Download Clients**
2. Edit **qBittorrent** download client
3. Enable **Remove Completed** (removes from qBittorrent after import)
4. Go to **Settings** → **Media Management**
5. Enable **Delete empty folders** (cleans up download folders)

### **3. Alternative: Separate NFS Mounts** (Long-term Solution)
Reorganize NFS server structure:
```
/volume1/media/           ← Movies only (Jellyfin scans this)
/volume1/downloads/       ← Downloads only (separate path)
```

Then update:
- `apps/media-server/jellyfin/nfs-media-pv-pvc.yaml` → `/volume1/media`
- `apps/media-server/qbitt/nfs-download-pv-pvc.yaml` → `/volume1/downloads`

---

## **Current Configuration:**

### **Volume Mounts:**

**Jellyfin:**
- `/data/videos` → NFS `/volume1/media_player` (sees everything)

**Radarr:**
- `/movies` → NFS `/volume1/media_player` (same as Jellyfin)
- `/downloads` → NFS `/volume1/media_player/download`

**qBittorrent:**
- `/downloads` → NFS `/volume1/media_player/download`

**Problem:** Jellyfin's mount includes Radarr's download folder!

---

## **Recommended Actions:**

### **Immediate (Done):**
- ✅ Cleaned up download folder

### **Short-term (Manual):**
1. Configure Radarr to delete downloads after import
2. Rescan Jellyfin library to remove duplicates

### **Long-term (Optional):**
1. Reorganize NFS server to separate media and downloads
2. Update Kubernetes PV/PVC configurations
3. Migrate existing data to new structure

---

## **How to Prevent This:**

1. **Enable "Remove Completed" in Radarr** - Deletes downloads after successful import
2. **Use separate NFS paths** - Keep downloads outside media library
3. **Configure Jellyfin library exclusions** - Exclude download folders from scanning
4. **Use hardlinks** - Radarr can use hardlinks instead of copies (saves space)

---

## **Testing:**

After configuring Radarr:
1. Download a new movie
2. Wait for Radarr to import it
3. Verify download folder is cleaned up
4. Verify only one copy appears in Jellyfin

---

**Fixed:** 2025-11-06  
**By:** Augment Agent  
**Issue:** Duplicate movies in Jellyfin due to nested NFS mounts

