# 💬 Bazarr Troubleshooting Guide

Current status and troubleshooting steps for Bazarr subtitle management.

---

## ⚠️ **Current Status**

**Problem:** Bazarr pod stuck in `ContainerCreating` state for extended period (10+ minutes)

**Symptoms:**
- Pod status: `ContainerCreating`
- No container logs available
- No error events in pod description
- Other pods using same NFS volume are working fine

---

## 🔍 **What Was Tried**

### **1. Fixed NFS Volume Access Mode** ✅
**Issue:** NFS PV/PVC was set to `ReadWriteOnce` (RWO) but multiple pods needed access
**Solution:** Changed to `ReadWriteMany` (RWX)
**Result:** Other pods (Jellyfin, Radarr, Sonarr, Tdarr) now working fine

### **2. Simplified Volume Mounts** ✅
**Issue:** Bazarr was mounting same PVC twice (`jellyfin-videos` for both `/movies` and `/tv`)
**Solution:** Changed to single mount at `/media`
**Result:** Configuration simplified, but pod still stuck

### **3. Pod Restart** ⚠️
**Action:** Deleted and recreated pod multiple times
**Result:** Pod recreates but remains in `ContainerCreating`

---

## 🐛 **Possible Causes**

### **1. Longhorn Volume Attachment Issue**
- Bazarr config PVC might have attachment problems
- Longhorn CSI driver might be slow to attach
- Volume might be in use by another process

### **2. Image Pull Issue**
- Image `linuxserver/bazarr:latest` might be pulling slowly
- Network issues to Docker Hub
- Image might be corrupted

### **3. Node Resource Constraints**
- Worker node might be low on resources
- Too many pods on same node
- Disk I/O bottleneck

### **4. NFS Mount Timing**
- NFS volume might be slow to mount
- Network latency to NFS server (192.168.1.42)
- Mount options might need adjustment

---

## 🔧 **Troubleshooting Steps**

### **Step 1: Check Image Pull Status**

```bash
# Check if image is being pulled
kubectl describe pod bazarr-0 -n media | grep -A 10 "Events:"

# Check image pull progress
kubectl get events -n media --field-selector involvedObject.name=bazarr-0 --sort-by='.lastTimestamp'
```

**Expected:** Should see "Pulling image" or "Successfully pulled image" events

---

### **Step 2: Check Longhorn Volume Status**

```bash
# Check PVC status
kubectl get pvc bazarr -n media

# Check Longhorn volume
kubectl get volumes -n longhorn-system | grep bazarr

# Describe PVC for details
kubectl describe pvc bazarr -n media
```

**Expected:** PVC should be `Bound` and volume should be `Healthy`

---

### **Step 3: Check Node Resources**

```bash
# Check node status
kubectl describe node worker | grep -A 10 "Allocated resources"

# Check disk usage
kubectl get pods -n media -o wide | grep worker

# Check if node has issues
kubectl get nodes
```

**Expected:** Node should have available CPU, memory, and disk

---

### **Step 4: Check Container Runtime**

```bash
# SSH to worker node and check containerd
ssh worker
sudo crictl ps -a | grep bazarr
sudo crictl logs <container-id>
```

**Expected:** Should see container creation logs or errors

---

### **Step 5: Try Different Approach**

If pod remains stuck, try these alternatives:

#### **Option A: Use Deployment Instead of StatefulSet**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bazarr
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bazarr
  template:
    metadata:
      labels:
        app: bazarr
    spec:
      containers:
        - name: bazarr
          image: linuxserver/bazarr:latest
          # ... rest of config
```

#### **Option B: Simplify Configuration**

Remove probes temporarily to see if pod starts:

```yaml
# Comment out livenessProbe and readinessProbe
# livenessProbe:
#   httpGet:
#     path: /
#     port: 6767
```

#### **Option C: Use Different Image**

Try official Bazarr image instead of linuxserver:

```yaml
image: ghcr.io/linuxserver/bazarr:latest
# or
image: hotio/bazarr:latest
```

---

## 🚀 **Recommended Next Steps**

### **Immediate Actions:**

1. **Wait 5 more minutes** - Sometimes Longhorn volumes take time to attach
2. **Check worker node** - SSH and verify node health
3. **Check Longhorn dashboard** - Verify volume health
4. **Try manual image pull** - Pre-pull image on worker node

### **If Still Stuck:**

1. **Delete PVC and recreate** - Fresh Longhorn volume
   ```bash
   kubectl scale sts bazarr -n media --replicas=0
   kubectl delete pvc bazarr -n media
   kubectl apply -f apps/media-server/bazarr/bazarr-pvc.yaml
   kubectl scale sts bazarr -n media --replicas=1
   ```

2. **Try different node** - Add node selector to force different node
   ```yaml
   spec:
     nodeSelector:
       kubernetes.io/hostname: beelink
   ```

3. **Check Longhorn health** - Restart Longhorn if needed
   ```bash
   kubectl get pods -n longhorn-system
   kubectl logs -n longhorn-system -l app=longhorn-manager
   ```

---

## 📋 **Current Configuration**

### **Bazarr StatefulSet:**
- **Image:** linuxserver/bazarr:latest
- **Replicas:** 1
- **Node:** worker
- **Volumes:**
  - `config` → PVC `bazarr` (Longhorn, 2Gi)
  - `media` → PVC `jellyfin-videos` (NFS, 400Gi, RWX)

### **Resources:**
- **CPU Request:** 100m
- **CPU Limit:** 1000m (1 core)
- **Memory Request:** 256Mi
- **Memory Limit:** 1Gi

### **Probes:**
- **Liveness:** HTTP GET :6767/ (60s delay, 30s period)
- **Readiness:** HTTP GET :6767/ (30s delay, 10s period)

---

## 🔍 **Diagnostic Commands**

```bash
# Full pod description
kubectl describe pod bazarr-0 -n media

# Check all events
kubectl get events -n media --sort-by='.lastTimestamp' | grep bazarr

# Check PVC binding
kubectl get pvc -n media | grep bazarr

# Check if volume is attached
kubectl get volumeattachments | grep bazarr

# Check Longhorn volumes
kubectl get volumes -n longhorn-system

# Check node conditions
kubectl describe node worker | grep -A 20 "Conditions"

# Check kubelet logs (on worker node)
ssh worker
sudo journalctl -u k3s-agent -f | grep bazarr
```

---

## ✅ **When Bazarr Starts Working**

Once Bazarr is running, you'll need to configure it:

### **1. Add Subtitle Providers**
- OpenSubtitles
- Subscene
- Addic7ed
- etc.

### **2. Connect to Radarr**
- URL: `http://radarr.media.svc.cluster.local`
- API Key: (from Radarr settings)

### **3. Connect to Sonarr**
- URL: `http://sonarr.media.svc.cluster.local:8989`
- API Key: (from Sonarr settings)

### **4. Configure Languages**
- Select preferred subtitle languages
- Set download priorities
- Configure automatic search

---

## 📚 **Additional Resources**

- **Bazarr Wiki:** https://wiki.bazarr.media/
- **Longhorn Docs:** https://longhorn.io/docs/
- **K3s Troubleshooting:** https://docs.k3s.io/troubleshooting

---

**Status:** ⚠️ **TROUBLESHOOTING IN PROGRESS**
**Last Checked:** 2025-11-02
**Next Action:** Wait for volume attachment or try alternative approaches above

