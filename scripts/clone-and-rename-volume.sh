#!/bin/bash
set -e

# Script to clone a Longhorn volume and rename it with human-readable name
# This ensures 2 replicas for 2-node cluster

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <namespace> <old-pvc-name> <new-pvc-name> <size>"
    echo "Example: $0 homepage homepage-logs homepage-logs-new 5Gi"
    exit 1
fi

NAMESPACE=$1
OLD_PVC=$2
NEW_PVC=$3
SIZE=$4

echo "=== Volume Cloning and Rename Procedure ==="
echo "Namespace: $NAMESPACE"
echo "Source PVC: $OLD_PVC"
echo "Target PVC: $NEW_PVC"
echo "Size: $SIZE"
echo ""

# Step 1: Create clone PVC with dataSource
echo "Step 1: Creating clone PVC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${NEW_PVC}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  dataSource:
    kind: PersistentVolumeClaim
    name: ${OLD_PVC}
  resources:
    requests:
      storage: ${SIZE}
EOF

echo "✅ Clone PVC created"
echo ""

# Step 2: Wait for PVC to be bound
echo "Step 2: Waiting for PVC to be bound..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/${NEW_PVC} -n ${NAMESPACE} --timeout=60s
echo "✅ PVC bound"
echo ""

# Step 3: Get the volume name
VOLUME_NAME=$(kubectl get pvc ${NEW_PVC} -n ${NAMESPACE} -o jsonpath='{.spec.volumeName}')
echo "Step 3: Volume name: $VOLUME_NAME"
echo ""

# Step 4: Wait for clone to complete
echo "Step 4: Waiting for clone to complete..."
for i in {1..60}; do
    CLONE_STATE=$(kubectl get volumes.longhorn.io ${VOLUME_NAME} -n longhorn-system -o jsonpath='{.status.cloneStatus.state}' 2>/dev/null || echo "")
    if [ "$CLONE_STATE" == "completed" ] || [ "$CLONE_STATE" == "" ]; then
        echo "✅ Clone completed"
        break
    fi
    echo "Clone state: $CLONE_STATE (attempt $i/60)"
    sleep 5
done
echo ""

# Step 5: Fix replica count to 2
echo "Step 5: Setting replica count to 2..."
CURRENT_REPLICAS=$(kubectl get volumes.longhorn.io ${VOLUME_NAME} -n longhorn-system -o jsonpath='{.spec.numberOfReplicas}')
if [ "$CURRENT_REPLICAS" != "2" ]; then
    echo "Current replicas: $CURRENT_REPLICAS, changing to 2..."
    kubectl patch volumes.longhorn.io ${VOLUME_NAME} -n longhorn-system --type=merge -p '{"spec":{"numberOfReplicas":2}}'
    sleep 10
    echo "✅ Replica count set to 2"
else
    echo "✅ Already has 2 replicas"
fi
echo ""

# Step 6: Verify volume is healthy
echo "Step 6: Verifying volume health..."
kubectl get volumes.longhorn.io ${VOLUME_NAME} -n longhorn-system -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.numberOfReplicas,STATE:.status.state,ROBUSTNESS:.status.robustness
echo ""

echo "=== Clone Complete ==="
echo "Next steps:"
echo "1. Scale down the application using $OLD_PVC"
echo "2. Update the application to use $NEW_PVC"
echo "3. Verify the application works with new PVC"
echo "4. Delete old PVC: kubectl delete pvc $OLD_PVC -n $NAMESPACE"
echo "5. Update Git manifests to remove volumeName"

