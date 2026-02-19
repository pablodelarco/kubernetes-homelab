#!/bin/bash

# Script to add node affinity to all media server applications
# This ensures workloads are balanced across nodes

set -e

echo "🎯 Adding Node Affinity to Media Server Apps"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# List of media server StatefulSets
STATEFULSETS=(
  "jellyfin"
  "radarr"
  "sonarr"
  "tdarr"
  "bazarr"
  "jellyseerr"
  "qbitt"
)

# List of media server Deployments
DEPLOYMENTS=(
  "jackett"
  "cross-seed"
)

echo -e "${YELLOW}Step 1: Adding node affinity to StatefulSets${NC}"
echo ""

for sts in "${STATEFULSETS[@]}"; do
  echo -n "Processing StatefulSet: $sts ... "
  
  # Check if StatefulSet exists
  if kubectl get sts "$sts" -n media &>/dev/null; then
    # Add node affinity patch
    kubectl patch sts "$sts" -n media --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/affinity",
        "value": {
          "nodeAffinity": {
            "preferredDuringSchedulingIgnoredDuringExecution": [
              {
                "weight": 100,
                "preference": {
                  "matchExpressions": [
                    {
                      "key": "node-role.kubernetes.io/control-plane",
                      "operator": "DoesNotExist"
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    ]' 2>/dev/null || echo -e "${YELLOW}(already has affinity)${NC}"
    
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗ (not found)${NC}"
  fi
done

echo ""
echo -e "${YELLOW}Step 2: Adding node affinity to Deployments${NC}"
echo ""

for deploy in "${DEPLOYMENTS[@]}"; do
  echo -n "Processing Deployment: $deploy ... "
  
  # Check if Deployment exists
  if kubectl get deployment "$deploy" -n media &>/dev/null; then
    # Add node affinity patch
    kubectl patch deployment "$deploy" -n media --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/affinity",
        "value": {
          "nodeAffinity": {
            "preferredDuringSchedulingIgnoredDuringExecution": [
              {
                "weight": 100,
                "preference": {
                  "matchExpressions": [
                    {
                      "key": "node-role.kubernetes.io/control-plane",
                      "operator": "DoesNotExist"
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    ]' 2>/dev/null || echo -e "${YELLOW}(already has affinity)${NC}"
    
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗ (not found)${NC}"
  fi
done

echo ""
echo -e "${GREEN}✅ Node affinity added successfully!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Existing pods will NOT be rescheduled automatically."
echo "To apply changes, you need to restart the pods:"
echo ""
echo "  # For StatefulSets:"
echo "  kubectl rollout restart sts <name> -n media"
echo ""
echo "  # For Deployments:"
echo "  kubectl rollout restart deployment <name> -n media"
echo ""
echo "Or delete pods to force rescheduling:"
echo "  kubectl delete pod <pod-name> -n media"
echo ""

