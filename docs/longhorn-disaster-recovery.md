# Longhorn Disaster Recovery Guide

## When Longhorn Volumes Are Accidentally Deleted

If you accidentally delete Longhorn (e.g., `helm uninstall longhorn`) and lose all volumes, follow this procedure to restore from S3 backups.

---

## Prerequisites

1. **Longhorn must be reinstalled** and healthy
2. **S3 backup target must be configured** in Longhorn settings
3. **Backups must exist** in S3 (verify in Longhorn UI → Backup)

---

## Recovery Procedure

### Step 1: List Available Backups

```bash
# Get list of backup volumes
kubectl exec -n longhorn-system $(kubectl get pods -n longhorn-system -l app=longhorn-manager -o jsonpath='{.items[0].metadata.name}') -c longhorn-manager -- \
  curl -s http://longhorn-backend:9500/v1/backupvolumes | jq -r '.data[].name'

# Get latest backup for a specific volume
kubectl exec -n longhorn-system $(kubectl get pods -n longhorn-system -l app=longhorn-manager -o jsonpath='{.items[0].metadata.name}') -c longhorn-manager -- \
  curl -s http://longhorn-backend:9500/v1/backupvolumes/<VOLUME_NAME> | jq -r '.lastBackupName, .lastBackupAt'
```

### Step 2: Create Volume from Backup

```bash
# Create Longhorn volume from S3 backup
kubectl exec -n longhorn-system $(kubectl get pods -n longhorn-system -l app=longhorn-manager -o jsonpath='{.items[0].metadata.name}') -c longhorn-manager -- \
  curl -s -X POST http://longhorn-backend:9500/v1/volumes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "pvc-<APP_NAME>-restored",
    "size": "5368709120",
    "numberOfReplicas": 2,
    "fromBackup": "s3://k8s-backups@us-east-1/?backup=<BACKUP_NAME>&volume=<ORIGINAL_VOLUME_NAME>"
  }'
```

### Step 3: Trigger Restore by Attaching Volume

**CRITICAL**: The restore only happens when the volume is first attached to a pod!

Create a test pod to trigger the restore:

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-restore-pv
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
    volumeHandle: pvc-<APP_NAME>-restored
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-restore-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn
  volumeName: test-restore-pv
---
apiVersion: v1
kind: Pod
metadata:
  name: test-restore-pod
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
      claimName: test-restore-pvc
```

Apply and wait for restore:

```bash
kubectl apply -f test-restore-pod.yaml
sleep 30  # Wait for restore to complete
kubectl exec test-restore-pod -- ls -lah /data/  # Verify data is there
```

### Step 4: Bind Restored Volume to Application

Once data is verified:

```bash
# Clean up test resources
kubectl delete pod test-restore-pod
kubectl delete pvc test-restore-pvc
kubectl delete pv test-restore-pv

# Scale down application
kubectl scale statefulset <APP_NAME> -n <NAMESPACE> --replicas=0

# Delete old PVC (if exists)
kubectl delete pvc <PVC_NAME> -n <NAMESPACE>
kubectl patch pvc <PVC_NAME> -n <NAMESPACE> -p '{"metadata":{"finalizers":null}}' --type=merge

# Create PV and PVC for application
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pvc-<APP_NAME>-restored
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
    volumeHandle: pvc-<APP_NAME>-restored
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: <PVC_NAME>
    namespace: <NAMESPACE>
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <PVC_NAME>
  namespace: <NAMESPACE>
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn
  volumeName: pvc-<APP_NAME>-restored
EOF

# Patch PV to remove UID (if binding fails)
kubectl patch pv pvc-<APP_NAME>-restored -p '{"spec":{"claimRef":{"uid":null,"resourceVersion":null}}}'

# Scale up application
kubectl scale statefulset <APP_NAME> -n <NAMESPACE> --replicas=1

# Delete pod to force remount (if needed)
kubectl delete pod <POD_NAME> -n <NAMESPACE>
```

---

## Automated Recovery Script

See `scripts/restore-longhorn-volume.sh` for automated recovery.

---

## Prevention

1. **Never run `helm uninstall longhorn`** - use ArgoCD sync instead
2. **Always verify backups exist** before making Longhorn changes
3. **Test restore procedure** periodically to ensure backups are valid
4. **Use ArgoCD with selfHeal disabled** for critical infrastructure changes

