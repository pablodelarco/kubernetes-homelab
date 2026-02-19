#!/bin/bash

# Comprehensive Workload Balancing Script
# This script balances workloads across control-plane and worker nodes

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Kubernetes Workload Balancing Tool          ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo ""

# Function to show current status
show_status() {
  echo -e "${YELLOW}📊 Current Node Status:${NC}"
  echo ""
  kubectl top nodes
  echo ""
  
  echo -e "${YELLOW}📦 Pod Distribution:${NC}"
  echo ""
  echo "Pods on beelink (control-plane):"
  kubectl get pods -A -o wide --no-headers | grep beelink | wc -l
  echo ""
  echo "Pods on worker:"
  kubectl get pods -A -o wide --no-headers | grep worker | wc -l
  echo ""
  
  echo -e "${YELLOW}🎬 Media Namespace Distribution:${NC}"
  kubectl get pods -n media -o wide
  echo ""
}

# Function to taint control-plane
taint_control_plane() {
  echo -e "${YELLOW}Step 1: Tainting Control-Plane Node${NC}"
  echo "This will prevent new pods from scheduling on beelink"
  echo ""
  
  read -p "Do you want to taint the control-plane node? (y/n) " -n 1 -r
  echo ""
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -n "Adding taint to beelink ... "
    kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule --overwrite 2>/dev/null || true
    echo -e "${GREEN}✓${NC}"
    echo ""
  else
    echo -e "${YELLOW}Skipped${NC}"
    echo ""
  fi
}

# Function to add node affinity to media apps
add_media_affinity() {
  echo -e "${YELLOW}Step 2: Adding Node Affinity to Media Apps${NC}"
  echo "This will make media apps prefer the worker node"
  echo ""
  
  read -p "Do you want to add node affinity to media apps? (y/n) " -n 1 -r
  echo ""
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash "$(dirname "$0")/apply-node-affinity.sh"
  else
    echo -e "${YELLOW}Skipped${NC}"
    echo ""
  fi
}

# Function to migrate pods
migrate_pods() {
  echo -e "${YELLOW}Step 3: Migrating Pods to Worker Node${NC}"
  echo "This will restart media pods to apply new affinity rules"
  echo ""
  
  read -p "Do you want to migrate media pods now? (y/n) " -n 1 -r
  echo ""
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Restarting media server pods..."
    echo ""
    
    # Restart StatefulSets
    for sts in jellyfin radarr sonarr tdarr bazarr jellyseerr qbitt; do
      if kubectl get sts "$sts" -n media &>/dev/null; then
        echo -n "Restarting $sts ... "
        kubectl rollout restart sts "$sts" -n media &>/dev/null
        echo -e "${GREEN}✓${NC}"
      fi
    done
    
    # Restart Deployments
    for deploy in jackett cross-seed; do
      if kubectl get deployment "$deploy" -n media &>/dev/null; then
        echo -n "Restarting $deploy ... "
        kubectl rollout restart deployment "$deploy" -n media &>/dev/null
        echo -e "${GREEN}✓${NC}"
      fi
    done
    
    echo ""
    echo -e "${GREEN}✅ Migration initiated!${NC}"
    echo ""
    echo "Waiting for pods to restart (this may take a few minutes)..."
    sleep 10
    echo ""
  else
    echo -e "${YELLOW}Skipped${NC}"
    echo ""
  fi
}

# Function to add tolerations to critical infrastructure
add_critical_tolerations() {
  echo -e "${YELLOW}Step 4: Adding Tolerations to Critical Infrastructure${NC}"
  echo "This allows critical infrastructure to run on control-plane"
  echo ""
  
  read -p "Do you want to add tolerations to ArgoCD? (y/n) " -n 1 -r
  echo ""
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Adding tolerations to ArgoCD components..."
    
    # ArgoCD components
    for component in application-controller repo-server server dex-server redis applicationset-controller; do
      if kubectl get deployment "argocd-$component" -n argocd &>/dev/null; then
        echo -n "Patching argocd-$component ... "
        kubectl patch deployment "argocd-$component" -n argocd --type='json' -p='[
          {
            "op": "add",
            "path": "/spec/template/spec/tolerations",
            "value": [
              {
                "key": "node-role.kubernetes.io/control-plane",
                "operator": "Exists",
                "effect": "NoSchedule"
              }
            ]
          }
        ]' 2>/dev/null || echo -e "${YELLOW}(already has tolerations)${NC}"
        echo -e "${GREEN}✓${NC}"
      fi
    done
    
    # ArgoCD StatefulSet (application-controller)
    if kubectl get sts "argocd-application-controller" -n argocd &>/dev/null; then
      echo -n "Patching argocd-application-controller (StatefulSet) ... "
      kubectl patch sts "argocd-application-controller" -n argocd --type='json' -p='[
        {
          "op": "add",
          "path": "/spec/template/spec/tolerations",
          "value": [
            {
              "key": "node-role.kubernetes.io/control-plane",
              "operator": "Exists",
              "effect": "NoSchedule"
            }
          ]
        }
      ]' 2>/dev/null || echo -e "${YELLOW}(already has tolerations)${NC}"
      echo -e "${GREEN}✓${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Tolerations added!${NC}"
    echo ""
  else
    echo -e "${YELLOW}Skipped${NC}"
    echo ""
  fi
}

# Main menu
main_menu() {
  echo -e "${BLUE}What would you like to do?${NC}"
  echo ""
  echo "1) Show current status"
  echo "2) Full automatic balancing (recommended)"
  echo "3) Taint control-plane only"
  echo "4) Add node affinity to media apps only"
  echo "5) Migrate pods only"
  echo "6) Add tolerations to critical infrastructure"
  echo "7) Rollback (remove taint)"
  echo "8) Exit"
  echo ""
  read -p "Enter your choice (1-8): " choice
  echo ""
  
  case $choice in
    1)
      show_status
      echo ""
      main_menu
      ;;
    2)
      show_status
      taint_control_plane
      add_media_affinity
      add_critical_tolerations
      migrate_pods
      echo ""
      echo -e "${GREEN}✅ Full balancing complete!${NC}"
      echo ""
      show_status
      ;;
    3)
      taint_control_plane
      main_menu
      ;;
    4)
      add_media_affinity
      main_menu
      ;;
    5)
      migrate_pods
      main_menu
      ;;
    6)
      add_critical_tolerations
      main_menu
      ;;
    7)
      echo -e "${YELLOW}Removing taint from control-plane...${NC}"
      kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
      echo -e "${GREEN}✓ Taint removed${NC}"
      echo ""
      main_menu
      ;;
    8)
      echo -e "${GREEN}Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid choice${NC}"
      echo ""
      main_menu
      ;;
  esac
}

# Start
show_status
main_menu

