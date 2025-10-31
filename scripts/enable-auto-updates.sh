#!/bin/bash
# Script to add auto-update annotations to ArgoCD applications

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🤖 Enabling Auto-Updates for ArgoCD Applications${NC}"
echo ""

# Function to add annotations to an application
add_annotations() {
    local app_file=$1
    local chart_name=$2
    local version_pattern=$3
    
    echo -e "${YELLOW}Processing: $app_file${NC}"
    
    # Check if annotations already exist
    if grep -q "argocd-image-updater.argoproj.io" "$app_file"; then
        echo "  ⏭️  Annotations already exist, skipping..."
        return
    fi
    
    # Add annotations after metadata: section
    sed -i '/^metadata:/a\  annotations:\n    # Auto-update Helm chart versions\n    argocd-image-updater.argoproj.io/helm-chart: '"$chart_name"'\n    argocd-image-updater.argoproj.io/update-strategy: semver\n    argocd-image-updater.argoproj.io/allow-tags: regexp:'"$version_pattern"'\n    argocd-image-updater.argoproj.io/write-back-method: git' "$app_file"
    
    echo "  ✅ Added auto-update annotations"
}

# Homepage - allow 2.x.x updates
if [ -f "argocd-apps/homepage.yaml" ]; then
    add_annotations "argocd-apps/homepage.yaml" "homepage" "^2\\."
fi

# Longhorn - allow 1.7.x updates (conservative)
if [ -f "argocd-apps/longhorn.yaml" ]; then
    add_annotations "argocd-apps/longhorn.yaml" "longhorn" "^1\\.7\\."
fi

# Kube-Prometheus-Stack - allow 67.x.x updates
if [ -f "argocd-apps/kube-prometheus-stack.yaml" ]; then
    add_annotations "argocd-apps/kube-prometheus-stack.yaml" "kube-prometheus-stack" "^67\\."
fi

# MinIO - allow 5.x.x updates
if [ -f "argocd-apps/minio.yaml" ]; then
    add_annotations "argocd-apps/minio.yaml" "minio" "^5\\."
fi

# Home Assistant - allow 0.2.x updates
if [ -f "argocd-apps/home-assistant.yaml" ]; then
    add_annotations "argocd-apps/home-assistant.yaml" "home-assistant" "^0\\.2\\."
fi

# EMQX - allow 5.x.x updates
if [ -f "argocd-apps/emqx.yaml" ]; then
    add_annotations "argocd-apps/emqx.yaml" "emqx" "^5\\."
fi

# Sealed Secrets - allow 2.x.x updates
if [ -f "argocd-apps/sealed-secrets.yaml" ]; then
    add_annotations "argocd-apps/sealed-secrets.yaml" "sealed-secrets" "^2\\."
fi

# Uptime Kuma - allow any version
if [ -f "argocd-apps/uptime-kuma.yaml" ]; then
    add_annotations "argocd-apps/uptime-kuma.yaml" "uptime-kuma" "^.*"
fi

# Jellyfin - allow any version
if [ -f "argocd-apps/jellyfin.yaml" ]; then
    add_annotations "argocd-apps/jellyfin.yaml" "jellyfin" "^.*"
fi

# Radarr - allow any version
if [ -f "argocd-apps/radarr.yaml" ]; then
    add_annotations "argocd-apps/radarr.yaml" "radarr" "^.*"
fi

# Jackett - allow any version
if [ -f "argocd-apps/jackett.yaml" ]; then
    add_annotations "argocd-apps/jackett.yaml" "jackett" "^.*"
fi

# qBittorrent - allow any version
if [ -f "argocd-apps/qbitt.yaml" ]; then
    add_annotations "argocd-apps/qbitt.yaml" "qbittorrent" "^.*"
fi

# Homarr - allow 1.x.x updates
if [ -f "argocd-apps/homarr.yaml" ]; then
    add_annotations "argocd-apps/homarr.yaml" "homarr" "^1\\."
fi

# OpenCost - allow 2.x.x updates
if [ -f "argocd-apps/opencost.yaml" ]; then
    add_annotations "argocd-apps/opencost.yaml" "opencost" "^2\\."
fi

# n8n - allow 1.x.x updates
if [ -f "argocd-apps/n8n.yaml" ]; then
    add_annotations "argocd-apps/n8n.yaml" "n8n" "^1\\."
fi

echo ""
echo -e "${GREEN}✅ Auto-update annotations added!${NC}"
echo ""
echo "Next steps:"
echo "1. Review the changes: git diff argocd-apps/"
echo "2. Commit and push: git add argocd-apps/ && git commit -m 'feat: Enable auto-updates for applications' && git push"
echo "3. Deploy ArgoCD Image Updater: kubectl apply -f argocd-apps/argocd-image-updater.yaml"
echo "4. Setup Git credentials (see apps/argocd-image-updater/README.md)"

