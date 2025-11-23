#!/bin/bash
set -e

echo "========================================="
echo "Batch Restore All Applications"
echo "========================================="
echo ""

# Applications to restore (app-name|namespace|pvc-name|restored-volume|size)
APPS=(
  "bazarr|media|bazarr|pvc-bazarr-restored|2Gi"
  "jellyseerr|media|jellyseerr|pvc-jellyseerr-restored|1Gi"
  "qbitt|media|qbitt|pvc-qbitt-restored|5Gi"
  "tdarr-config|media|tdarr-config|pvc-tdarr-config-restored|1Gi"
  "tdarr-logs|media|tdarr-logs|pvc-tdarr-logs-restored|1Gi"
  "tdarr-server|media|tdarr-server|pvc-tdarr-server-restored|10Gi"
  "homepage|homepage|homepage-logs|pvc-homepage-restored|5Gi"
  "uptime-kuma|uptime-kuma|uptime-kuma-pvc|pvc-uptime-kuma-restored|5Gi"
  "opencost|opencost|opencost-pvc|pvc-opencost-restored|5Gi"
)

# Step 1: Scale down all applications
echo "[1/5] Scaling down all applications..."
kubectl scale statefulset bazarr jellyseerr tdarr qbitt -n media --replicas=0 2>/dev/null || true
kubectl scale deployment homepage -n homepage --replicas=0 2>/dev/null || true
kubectl scale deployment uptime-kuma -n uptime-kuma --replicas=0 2>/dev/null || true
kubectl scale deployment opencost -n opencost --replicas=0 2>/dev/null || true
echo "✓ All applications scaled down"
sleep 10
echo ""

# Step 2: Delete old PVCs
echo "[2/5] Deleting old PVCs..."
for app_info in "${APPS[@]}"; do
  IFS='|' read -r app namespace pvc volume size <<< "$app_info"
  kubectl delete pvc $pvc -n $namespace --force --grace-period=0 2>/dev/null || true
done
sleep 5

# Remove finalizers
for app_info in "${APPS[@]}"; do
  IFS='|' read -r app namespace pvc volume size <<< "$app_info"
  kubectl patch pvc $pvc -n $namespace -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
done
echo "✓ Old PVCs deleted"
sleep 5
echo ""

# Step 3: Create PVs and PVCs
echo "[3/5] Creating PVs and PVCs..."
for app_info in "${APPS[@]}"; do
  IFS='|' read -r app namespace pvc volume size <<< "$app_info"
  
  cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $volume
spec:
  capacity:
    storage: $size
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: longhorn
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeAttributes:
      numberOfReplicas: "2"
    volumeHandle: $volume
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: $pvc
    namespace: $namespace
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc
  namespace: $namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $size
  storageClassName: longhorn
  volumeName: $volume
EOF

  # Patch PV to remove UID
  kubectl patch pv $volume -p '{"spec":{"claimRef":{"uid":null,"resourceVersion":null}}}' 2>/dev/null || true
  
  echo "✓ Created PV/PVC for $app"
done
echo ""

# Step 4: Wait for PVCs to bind
echo "[4/5] Waiting for PVCs to bind..."
sleep 10
kubectl get pvc -n media | grep -E "bazarr|jellyseerr|qbitt|tdarr"
kubectl get pvc -n homepage
kubectl get pvc -n uptime-kuma
kubectl get pvc -n opencost
echo ""

# Step 5: Scale up applications
echo "[5/5] Scaling up applications..."
kubectl scale statefulset bazarr jellyseerr tdarr qbitt -n media --replicas=1
kubectl scale deployment homepage -n homepage --replicas=1
kubectl scale deployment uptime-kuma -n uptime-kuma --replicas=1
kubectl scale deployment opencost -n opencost --replicas=1
echo "✓ All applications scaled up"
echo ""

echo "========================================="
echo "✓ Batch restore complete!"
echo "========================================="
echo ""
echo "Waiting for pods to start..."
sleep 30
kubectl get pods -n media | grep -E "NAME|bazarr|jellyseerr|qbitt|tdarr"
kubectl get pods -n homepage
kubectl get pods -n uptime-kuma
kubectl get pods -n opencost

