#!/bin/bash
set -e

# Media Server Stack Deployment Script (GitOps/ArgoCD)
# This script helps you sync the media server stack via ArgoCD

echo "=========================================="
echo "Media Server Stack - GitOps Deployment"
echo "=========================================="
echo ""
echo "NOTE: This cluster uses ArgoCD for GitOps deployments."
echo "Changes should be committed to Git and synced via ArgoCD."
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Function to check ArgoCD app sync status
check_argocd_app() {
    local app_name=$1
    if kubectl get application -n argocd "$app_name" &> /dev/null; then
        local sync_status=$(kubectl get application -n argocd "$app_name" -o jsonpath='{.status.sync.status}')
        local health_status=$(kubectl get application -n argocd "$app_name" -o jsonpath='{.status.health.status}')
        echo "  - $app_name: Sync=$sync_status, Health=$health_status"
    else
        echo "  - $app_name: NOT FOUND"
    fi
}

echo "=========================================="
echo "Current ArgoCD Application Status"
echo "=========================================="
echo ""
check_argocd_app "jellyfin"
check_argocd_app "radarr"
check_argocd_app "qbitt"
check_argocd_app "jackett"

echo ""
echo "=========================================="
echo "GitOps Deployment Options"
echo "=========================================="
echo ""
echo "Choose your deployment method:"
echo ""
echo "1. GitOps (Recommended) - Commit and push changes, ArgoCD will sync automatically"
echo "2. Manual ArgoCD Sync - Trigger ArgoCD sync without waiting for auto-sync"
echo "3. Direct kubectl apply - Bypass ArgoCD (NOT recommended for GitOps)"
echo ""
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo ""
        print_status "GitOps workflow selected"
        echo ""
        echo "To deploy via GitOps:"
        echo "1. Commit your changes: git add apps/media-server/"
        echo "2. Commit: git commit -m 'Update media server configurations'"
        echo "3. Push: git push origin main"
        echo "4. ArgoCD will automatically sync within 3 minutes"
        echo ""
        echo "Or manually trigger sync:"
        echo "  argocd app sync jellyfin radarr qbitt jackett"
        echo ""
        exit 0
        ;;
    2)
        echo ""
        print_status "Triggering ArgoCD sync..."
        echo ""

        if command -v argocd &> /dev/null; then
            argocd app sync jellyfin --prune
            argocd app sync radarr --prune
            argocd app sync qbitt --prune
            argocd app sync jackett --prune
        else
            print_warning "argocd CLI not found. Using kubectl instead..."
            kubectl patch application jellyfin -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}' --type merge
            kubectl patch application radarr -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}' --type merge
            kubectl patch application qbitt -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}' --type merge
            kubectl patch application jackett -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}' --type merge
        fi
        ;;
    3)
        echo ""
        print_warning "Direct kubectl apply selected (bypasses ArgoCD)"
        print_warning "This may cause drift between Git and cluster state!"
        echo ""
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Aborted."
            exit 0
        fi

        echo ""
        print_status "Applying configurations directly..."
        echo ""

        # Apply all configurations
        kubectl apply -k jellyfin/
        kubectl apply -k radarr/
        kubectl apply -k qbitt/
        kubectl apply -k jackett/
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Waiting for Pods to be Ready"
echo "=========================================="
echo ""

print_warning "Waiting for pods to be ready (this may take a few minutes)..."
echo ""

# Wait for each pod to be ready
kubectl wait --for=condition=ready pod -l app=jellyfin -n media --timeout=300s || print_warning "Jellyfin pod not ready yet"
kubectl wait --for=condition=ready pod -l app=radarr -n media --timeout=300s || print_warning "Radarr pod not ready yet"
kubectl wait --for=condition=ready pod -l app=qbitt -n media --timeout=300s || print_warning "qBittorrent pod not ready yet"
kubectl wait --for=condition=ready pod -l app=jackett -n media --timeout=300s || print_warning "Jackett pod not ready yet"

echo ""
echo "=========================================="
echo "Deployment Status"
echo "=========================================="
echo ""

# Show pod status
kubectl get pods -n media

echo ""
echo "=========================================="
echo "Service Status"
echo "=========================================="
echo ""

# Show service status
kubectl get svc -n media

echo ""
echo "=========================================="
echo "Ingress Status"
echo "=========================================="
echo ""

# Show ingress status
kubectl get ingress -n media

echo ""
echo "=========================================="
echo "Access URLs"
echo "=========================================="
echo ""

print_status "Jellyfin:     https://jellyfin.tabby-carp.ts.net"
print_status "Radarr:       https://radarr.tabby-carp.ts.net"
print_status "qBittorrent:  https://qbitt.tabby-carp.ts.net"
print_status "Jackett:      https://jackett.tabby-carp.ts.net"

echo ""
echo "=========================================="
echo "ArgoCD Application Status (After Sync)"
echo "=========================================="
echo ""
check_argocd_app "jellyfin"
check_argocd_app "radarr"
check_argocd_app "qbitt"
check_argocd_app "jackett"

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""

print_warning "1. Configure Jackett: Add your preferred torrent indexers"
print_warning "2. Configure qBittorrent: Set download paths and whitelist Kubernetes subnet"
print_warning "3. Configure Radarr: Add qBittorrent as download client and Jackett indexers"
print_warning "4. Configure Jellyfin: Add media library pointing to /data/videos"
echo ""
print_status "For detailed configuration instructions, see: apps/media-server/README.md"

echo ""
echo "=========================================="
echo "GitOps Deployment Complete!"
echo "=========================================="
echo ""
print_status "Remember: All future changes should be committed to Git!"
print_status "ArgoCD will automatically sync changes from the main branch."

