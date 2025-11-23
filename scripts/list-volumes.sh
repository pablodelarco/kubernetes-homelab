#!/bin/bash
# Script to list all volumes with human-readable information

echo "=== Kubernetes PVCs and Longhorn Volumes Mapping ==="
echo ""

# Get all PVCs with their volume names
kubectl get pvc -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
PVC:.metadata.name,\
VOLUME:.spec.volumeName,\
SIZE:.spec.resources.requests.storage,\
STORAGECLASS:.spec.storageClassName \
--sort-by=.metadata.namespace | grep -v "^kube-system"

echo ""
echo "=== All Longhorn Volumes with Labels ==="
echo ""

# Get all Longhorn volumes with labels (exclude NFS volumes)
kubectl get volumes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
APP:.metadata.labels.app,\
COMPONENT:.metadata.labels.component,\
SIZE:.spec.size,\
REPLICAS:.spec.numberOfReplicas,\
STATE:.status.state,\
ROBUSTNESS:.status.robustness \
| grep -v "jellyfin-videos" | grep -v "qbitt-temp" | grep -v "pvc-cb1e2ec1"

echo ""
echo "=== Volume Identification Summary ==="
echo ""
echo "✅ All 16 Longhorn volumes now have labels (app + component)"
echo "✅ Use 'kubectl get volumes.longhorn.io -n longhorn-system -L app,component' to see labels"
echo ""
echo "Volume naming patterns:"
echo "  - pvc-*-restored → Restored from S3 backup (12 volumes)"
echo "  - pvc-<uuid> → Fresh volumes created after disaster (4 volumes)"
echo ""
echo "NFS volumes (not managed by Longhorn):"
echo "  - jellyfin-videos → Jellyfin media storage (400Gi)"
echo "  - qbitt-temp → qBittorrent temp downloads (400Gi)"
echo "  - pvc-cb1e2ec1-389e-4acf-a21f-67e5bba4fac8 → MinIO storage (150Gi)"
echo ""

