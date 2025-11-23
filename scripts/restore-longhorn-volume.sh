#!/bin/bash
set -e

# Longhorn Volume Restore Script
# Usage: ./restore-longhorn-volume.sh <app-name> <namespace> <pvc-name> <backup-name> <original-volume-name> <size-bytes>

APP_NAME=$1
NAMESPACE=$2
PVC_NAME=$3
BACKUP_NAME=$4
ORIGINAL_VOLUME=$5
SIZE_BYTES=$6

if [ -z "$APP_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$PVC_NAME" ] || [ -z "$BACKUP_NAME" ] || [ -z "$ORIGINAL_VOLUME" ] || [ -z "$SIZE_BYTES" ]; then
  echo "Usage: $0 <app-name> <namespace> <pvc-name> <backup-name> <original-volume-name> <size-bytes>"
  echo ""
  echo "Example:"
  echo "  $0 home-assistant home-assistant home-assistant-home-assistant-0 \\"
  echo "     backup-a9ffde902273474e pvc-d09cc8a2-3ad6-444e-8add-9e7c6be71d7a 5368709120"
  exit 1
fi

RESTORED_VOLUME="pvc-${APP_NAME}-restored"
LONGHORN_MANAGER=$(kubectl get pods -n longhorn-system -l app=longhorn-manager -o jsonpath='{.items[0].metadata.name}')

echo "========================================="
echo "Longhorn Volume Restore"
echo "========================================="
echo "App Name:         $APP_NAME"
echo "Namespace:        $NAMESPACE"
echo "PVC Name:         $PVC_NAME"
echo "Backup Name:      $BACKUP_NAME"
echo "Original Volume:  $ORIGINAL_VOLUME"
echo "Size:             $SIZE_BYTES bytes"
echo "Restored Volume:  $RESTORED_VOLUME"
echo "========================================="
echo ""

# Step 1: Create volume from backup
echo "[1/6] Creating Longhorn volume from backup..."
kubectl exec -n longhorn-system $LONGHORN_MANAGER -c longhorn-manager -- curl -s -X POST http://longhorn-backend:9500/v1/volumes \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$RESTORED_VOLUME\",
    \"size\": \"$SIZE_BYTES\",
    \"numberOfReplicas\": 2,
    \"fromBackup\": \"s3://k8s-backups@us-east-1/?backup=$BACKUP_NAME&volume=$ORIGINAL_VOLUME\"
  }" | jq -r '.name'

echo "✓ Volume created: $RESTORED_VOLUME"
echo ""

# Step 2: Create test pod to trigger restore
echo "[2/6] Creating test pod to trigger restore..."
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-restore-pv-${APP_NAME}
spec:
  capacity:
    storage: 5Gi
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
    volumeHandle: $RESTORED_VOLUME
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-restore-pvc-${APP_NAME}
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn
  volumeName: test-restore-pv-${APP_NAME}
---
apiVersion: v1
kind: Pod
metadata:
  name: test-restore-pod-${APP_NAME}
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-restore-pvc-${APP_NAME}
EOF

echo "✓ Test pod created"
echo ""

# Step 3: Wait for restore
echo "[3/6] Waiting for restore to complete (30s)..."
sleep 30

# Step 4: Verify data
echo "[4/6] Verifying restored data..."
kubectl exec test-restore-pod-${APP_NAME} -n default -- ls -lah /data/ | head -10
echo ""
read -p "Does the data look correct? (y/n): " confirm
if [ "$confirm" != "y" ]; then
  echo "Aborting. Clean up manually with:"
  echo "  kubectl delete pod test-restore-pod-${APP_NAME} -n default"
  echo "  kubectl delete pvc test-restore-pvc-${APP_NAME} -n default"
  echo "  kubectl delete pv test-restore-pv-${APP_NAME}"
  exit 1
fi

# Step 5: Clean up test resources
echo "[5/6] Cleaning up test resources..."
kubectl delete pod test-restore-pod-${APP_NAME} -n default
kubectl delete pvc test-restore-pvc-${APP_NAME} -n default
kubectl delete pv test-restore-pv-${APP_NAME}
echo "✓ Test resources deleted"
echo ""

# Step 6: Bind to application
echo "[6/6] Binding restored volume to application..."

# Scale down
kubectl scale statefulset $APP_NAME -n $NAMESPACE --replicas=0 2>/dev/null || kubectl scale deployment $APP_NAME -n $NAMESPACE --replicas=0 2>/dev/null || true
sleep 5

# Delete old PVC
kubectl delete pvc $PVC_NAME -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
kubectl patch pvc $PVC_NAME -n $NAMESPACE -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
sleep 5

# Create new PV and PVC
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $RESTORED_VOLUME
spec:
  capacity:
    storage: 5Gi
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
    volumeHandle: $RESTORED_VOLUME
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: $PVC_NAME
    namespace: $NAMESPACE
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn
  volumeName: $RESTORED_VOLUME
EOF

# Patch PV to remove UID
kubectl patch pv $RESTORED_VOLUME -p '{"spec":{"claimRef":{"uid":null,"resourceVersion":null}}}' 2>/dev/null || true
sleep 3

# Scale up
kubectl scale statefulset $APP_NAME -n $NAMESPACE --replicas=1 2>/dev/null || kubectl scale deployment $APP_NAME -n $NAMESPACE --replicas=1 2>/dev/null || true

echo ""
echo "========================================="
echo "✓ Restore complete!"
echo "========================================="
echo ""
echo "Verify the application is working correctly."

