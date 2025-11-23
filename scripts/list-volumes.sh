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
echo "=== Longhorn Volumes with Labels (for UUID volumes) ==="
echo ""

# Get Longhorn volumes with labels
kubectl get volumes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
APP:.metadata.labels.app,\
COMPONENT:.metadata.labels.component,\
SIZE_GB:.spec.size,\
REPLICAS:.spec.numberOfReplicas,\
STATE:.status.state,\
ROBUSTNESS:.status.robustness \
| awk 'NR==1 || /pvc-623a87a9|pvc-6c391b81|pvc-8c3a8756/'

echo ""
echo "=== Volume Identification Guide ==="
echo ""
echo "Human-readable names (13 volumes):"
echo "  - pvc-*-restored → Restored from backup (app name in volume name)"
echo ""
echo "UUID names (3 volumes - monitoring):"
echo "  - pvc-623a87a9-0510-4195-8bec-671f04c9be20 → Alertmanager"
echo "  - pvc-6c391b81-2761-4797-895f-831d23796af5 → Prometheus"
echo "  - pvc-8c3a8756-f6e5-4712-92ab-61521eceb5e9 → Grafana"
echo ""
echo "Manual NFS volumes (3 volumes):"
echo "  - jellyfin-videos → Jellyfin media storage"
echo "  - qbitt-temp → qBittorrent temp downloads"
echo "  - pvc-cb1e2ec1-389e-4acf-a21f-67e5bba4fac8 → MinIO storage"
echo ""

