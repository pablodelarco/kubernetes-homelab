# 🎞️ Tdarr Complete Guide

Comprehensive guide to using Tdarr for automated media transcoding in your Kubernetes homelab.

---

## 📋 **What is Tdarr?**

Tdarr is an **automated media transcoding and health-checking application** that:
- Converts video files to save space (e.g., H.264 → H.265/HEVC)
- Ensures media compatibility across all devices
- Removes unwanted audio/subtitle tracks
- Standardizes your media library
- Runs automated health checks on your files

---

## 🎯 **Why Use Tdarr?**

### **1. Save Storage Space**
- **H.265/HEVC encoding** can reduce file sizes by 40-60% with same quality
- **Remove unnecessary streams** (extra audio tracks, subtitles you don't need)
- **Example:** A 10GB H.264 movie → 4-6GB H.265 movie (same quality)

### **2. Ensure Compatibility**
- Convert files that won't play on certain devices
- Standardize codecs across your library
- Fix problematic files before they cause issues

### **3. Automation**
- Set it and forget it - Tdarr watches your library
- Automatically processes new files
- Queues and prioritizes transcoding jobs

### **4. Quality Control**
- Health checks detect corrupted files
- Verify audio/video sync
- Ensure proper metadata

---

## 🏗️ **Your Tdarr Setup**

### **Current Configuration:**

<augment_code_snippet path="apps/media-server/tdarr/tdarr-sts.yaml" mode="EXCERPT">
````yaml
containers:
  - name: tdarr
    image: ghcr.io/haveagitgat/tdarr:latest
    env:
      - name: PUID
        value: "65534"
      - name: PGID
        value: "65534"
      - name: TZ
        value: "Europe/Madrid"
      - name: serverIP
        value: "0.0.0.0"
      - name: serverPort
        value: "8266"
      - name: webUIPort
        value: "8265"
      - name: internalNode
        value: "true"
      - name: nodeID
        value: "InternalNode"
````
</augment_code_snippet>

### **Access:**
- **External URL:** https://tdarr.tabby-carp.ts.net
- **Internal URL:** http://tdarr.media.svc.cluster.local:8265
- **Web UI Port:** 8265
- **Server Port:** 8266

### **Storage:**
- **Config:** PVC `tdarr-config` (1Gi, Longhorn)
- **Server Data:** PVC `tdarr-server` (10Gi, Longhorn)
- **Logs:** PVC `tdarr-logs` (1Gi, Longhorn)
- **Media:** NFS mount `jellyfin-videos` (400Gi) at `/media`
- **Transcode Cache:** EmptyDir (temporary, fast storage)

### **Resources:**
- **CPU Request:** 500m (0.5 cores)
- **CPU Limit:** 4000m (4 cores)
- **Memory Request:** 1Gi
- **Memory Limit:** 4Gi

**Note:** Transcoding is CPU-intensive. The 4-core limit allows Tdarr to use significant processing power.

---

## 🚀 **Getting Started**

### **Step 1: Access Tdarr Web UI**

1. Open https://tdarr.tabby-carp.ts.net
2. You'll see the Tdarr dashboard

### **Step 2: Add Your Media Library**

1. Go to **Libraries** tab
2. Click **+ Library**
3. Configure:
   - **Name:** Movies (or TV Shows)
   - **Source:** `/media/movies` (or `/media/tv`)
   - **Folder Watch:** Enable (auto-detect new files)
   - **Schedule:** Set when to scan (e.g., daily at 3 AM)

### **Step 3: Choose a Transcode Flow**

Tdarr uses "Flows" (workflows) to process files. Here are recommended flows:

#### **For Space Saving (Recommended):**
1. Go to **Flows** tab
2. Create new flow: **"H265 Space Saver"**
3. Add plugins:
   - **Check Video Codec** → If not H.265, transcode
   - **Transcode to H.265** → Use preset "Medium" or "Slow"
   - **Remove Extra Audio** → Keep only primary language
   - **Remove Extra Subtitles** → Keep only needed languages

#### **For Compatibility:**
1. Create flow: **"Universal Compatibility"**
2. Add plugins:
   - **Check Container** → Ensure MP4 or MKV
   - **Check Video Codec** → Ensure H.264 or H.265
   - **Check Audio Codec** → Ensure AAC or AC3

#### **For Health Checks Only:**
1. Create flow: **"Health Check"**
2. Add plugins:
   - **Check File Health**
   - **Verify Streams**
   - **Check for Corruption**

---

## 💡 **Common Use Cases**

### **Use Case 1: Convert Entire Library to H.265**

**Goal:** Save 40-60% storage space

**Steps:**
1. Create library pointing to `/media/movies`
2. Create flow with plugin: **"Transcode Video to H.265"**
3. Settings:
   - **Preset:** Medium (good balance of speed/quality)
   - **CRF:** 23 (lower = better quality, higher = smaller file)
   - **Keep original until verified:** Yes
4. Start scan
5. Tdarr will queue all non-H.265 files

**Expected Results:**
- 10GB H.264 file → 4-6GB H.265 file
- Same visual quality
- Processing time: 0.5-2x realtime (depends on CPU)

---

### **Use Case 2: Remove Unwanted Audio Tracks**

**Goal:** Remove foreign language audio tracks you don't need

**Steps:**
1. Create flow with plugin: **"Remove All Audio Except"**
2. Settings:
   - **Keep languages:** eng, spa (English, Spanish)
   - **Remove commentary tracks:** Yes
3. Apply to library

**Expected Results:**
- Smaller file sizes (each audio track = 100-500MB)
- Cleaner, more organized files

---

### **Use Case 3: Standardize to MP4**

**Goal:** Ensure all files are MP4 for maximum compatibility

**Steps:**
1. Create flow with plugin: **"Ensure Container is MP4"**
2. Settings:
   - **Remux if possible:** Yes (fast, no quality loss)
   - **Transcode if needed:** Yes
3. Apply to library

**Expected Results:**
- All files in MP4 container
- Works on all devices (smart TVs, mobile, etc.)

---

### **Use Case 4: Automated New File Processing**

**Goal:** Automatically process new downloads from Radarr/Sonarr

**Steps:**
1. Enable **Folder Watch** on library
2. Set **Scan Interval:** 1 hour
3. Create flow for new files:
   - Check if H.265 → Skip
   - Check if H.264 and >10GB → Transcode to H.265
   - Check if other codec → Transcode to H.264
4. Set **Priority:** Low (don't interfere with playback)

**Expected Results:**
- New downloads automatically queued
- Processed during off-peak hours
- No manual intervention needed

---

## ⚙️ **Recommended Settings**

### **For Your Setup:**

Given your hardware and use case, here are optimal settings:

#### **Transcode Settings:**
- **Video Codec:** H.265 (HEVC)
- **Preset:** Medium (good balance)
- **CRF:** 23 (visually lossless)
- **Audio Codec:** AAC or copy original
- **Container:** MP4 or MKV

#### **Performance Settings:**
- **Worker Threads:** 2-3 (leave CPU for other services)
- **Concurrent Jobs:** 1 (transcoding is resource-intensive)
- **Priority:** Low (don't impact Jellyfin streaming)

#### **Schedule:**
- **Scan Libraries:** Daily at 3 AM
- **Transcode Window:** 12 AM - 6 AM (off-peak)
- **Health Checks:** Weekly

---

## 📊 **Understanding Tdarr Concepts**

### **Libraries**
- Collections of media files to process
- Each library has its own settings and flows
- Can have multiple libraries (Movies, TV, etc.)

### **Flows**
- Workflows that define what to do with files
- Made up of plugins in sequence
- Can have different flows for different scenarios

### **Plugins**
- Individual actions (transcode, check, remove, etc.)
- Community-maintained library of 100+ plugins
- Can create custom plugins

### **Nodes**
- Workers that process transcode jobs
- Your setup has 1 internal node (built-in)
- Can add external nodes for distributed processing

### **Queues**
- **Transcode Queue:** Files waiting to be transcoded
- **Health Check Queue:** Files waiting for health checks
- Prioritized by file size, age, or custom rules

---

## 🎯 **Quick Start Workflow**

### **Recommended First Steps:**

1. **Add Movies Library**
   ```
   Name: Movies
   Path: /media/movies
   Folder Watch: Enabled
   Scan Schedule: Daily 3 AM
   ```

2. **Create Simple H.265 Flow**
   ```
   Flow Name: Convert to H.265
   Plugin 1: Check if video is H.265
     - If yes: Skip
     - If no: Continue
   Plugin 2: Transcode to H.265
     - Preset: Medium
     - CRF: 23
     - Audio: Copy
   ```

3. **Run Initial Scan**
   - Click "Scan" on library
   - Wait for files to be discovered
   - Check queue to see what will be processed

4. **Start Small**
   - Process 5-10 files first
   - Verify quality and file sizes
   - Adjust settings if needed
   - Then process entire library

---

## 📈 **Monitoring & Management**

### **Dashboard Metrics:**
- **Files Processed:** Total transcoded files
- **Space Saved:** GB saved by transcoding
- **Queue Size:** Files waiting to process
- **Worker Status:** Active/idle workers
- **Current Job:** What's being processed now

### **Logs:**
- Located in `/app/logs` (PVC: tdarr-logs)
- View in Tdarr UI under "Logs" tab
- Or: `kubectl logs -n media tdarr-0 --tail=100`

### **Health Checks:**
- Run weekly to detect issues
- Check for corrupted files
- Verify stream integrity
- Fix problems before users notice

---

## 🔧 **Troubleshooting**

### **Problem: Transcode is too slow**
**Solution:**
- Increase CPU limit in StatefulSet
- Use faster preset (e.g., "Fast" instead of "Medium")
- Process fewer files concurrently
- Add hardware acceleration (if available)

### **Problem: Quality loss after transcoding**
**Solution:**
- Lower CRF value (e.g., 20 instead of 23)
- Use slower preset for better quality
- Check source file quality first
- Consider keeping original files

### **Problem: Files won't play after transcoding**
**Solution:**
- Check codec compatibility
- Verify container format (MP4 vs MKV)
- Test with different player
- Check Tdarr logs for errors

### **Problem: Running out of cache space**
**Solution:**
- Transcode cache uses emptyDir (node storage)
- Process smaller files first
- Increase emptyDir size if needed
- Clean up failed jobs

---

## 💾 **Storage Impact**

### **Expected Space Savings:**

| Original Format | File Size | After H.265 | Savings |
|-----------------|-----------|-------------|---------|
| H.264 1080p Movie | 10 GB | 4-6 GB | 40-60% |
| H.264 4K Movie | 40 GB | 15-25 GB | 37-62% |
| H.264 TV Episode | 2 GB | 0.8-1.2 GB | 40-60% |
| MPEG-2 (old) | 8 GB | 2-3 GB | 62-75% |

### **Processing Time:**

| File Type | Size | CPU | Time |
|-----------|------|-----|------|
| 1080p Movie | 10 GB | 4 cores | 1-3 hours |
| 4K Movie | 40 GB | 4 cores | 4-8 hours |
| TV Episode | 2 GB | 4 cores | 15-45 min |

**Note:** Times vary based on preset (Fast/Medium/Slow) and source quality.

---

## 🎬 **Integration with Your Stack**

### **With Radarr/Sonarr:**
1. Radarr/Sonarr downloads movie/show
2. File saved to `/media/movies` or `/media/tv`
3. Tdarr detects new file (folder watch)
4. Tdarr queues file for processing
5. Transcoding happens during off-peak hours
6. Optimized file ready for Jellyfin

### **With Jellyfin:**
- Tdarr processes files in-place or creates new versions
- Jellyfin automatically detects changes
- Users stream optimized files
- Better performance, less buffering

---

## 📚 **Additional Resources**

- **Official Docs:** https://docs.tdarr.io/
- **Plugin Library:** https://docs.tdarr.io/docs/plugins/overview
- **Community Flows:** https://github.com/HaveAGitGat/Tdarr_Plugins
- **Discord:** https://discord.gg/GF8Choco (Tdarr community)

---

## ✅ **Next Steps**

1. **Access Tdarr:** https://tdarr.tabby-carp.ts.net
2. **Add your first library** (Movies or TV)
3. **Create a simple H.265 flow**
4. **Test on 5-10 files** to verify quality
5. **Expand to full library** once satisfied
6. **Set up automated processing** for new files

---

**Status:** ✅ Tdarr is running and ready to use!
**Last Updated:** 2025-11-02

