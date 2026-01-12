# Kubernetes Homelab - Update Strategy Summary

## Overview
This document outlines the automatic update strategy for all applications in the Kubernetes homelab. We use two complementary tools:
- **Renovate**: For Helm chart version management
- **ArgoCD Image Updater**: For container image updates in raw Kubernetes manifests

---

## 🔵 HELM CHARTS (Renovate)
These apps use external Helm charts. Renovate creates PRs when new chart versions are available.

| App | Chart Repo | Update Strategy | Auto-Merge |
|-----|-----------|-----------------|-----------|
| **Home Assistant** | pajikos.github.io | Patch/Minor/Major | ✅ Yes (immediate) |
| **Homepage** | jameswynn.github.io | Patch/Minor/Major | ✅ Yes (immediate) |
| **ArgoCD Image Updater** | argoproj.github.io | Patch/Minor/Major | ✅ Yes (patch/minor) |
| **Kube Prometheus Stack** | prometheus-community.github.io | Patch/Minor/Major | ✅ Yes (patch/minor) |
| **Longhorn** | charts.longhorn.io | Patch/Minor/Major | ❌ No (manual review) |
| **MinIO** | charts.min.io | Patch/Minor/Major | ✅ Yes (patch/minor) |
| **N8N** | 8gears.container-registry.com | Patch/Minor/Major | ✅ Yes (patch/minor) |
| **OpenCost** | opencost.github.io | Patch/Minor/Major | ✅ Yes (patch/minor) |
| **Renovate** | docs.renovatebot.com | Patch/Minor/Major | ✅ Yes (patch/minor) |
| **Sealed Secrets** | bitnami-labs.github.io | Patch/Minor/Major | ❌ No (manual review) |

---

## 🟢 RAW KUBERNETES MANIFESTS (ArgoCD Image Updater)
These apps use raw K8s manifests from the repo. ArgoCD Image Updater automatically updates image tags and commits to Git.

| App | Container Images | Update Strategy | Auto-Commit |
|-----|-----------------|-----------------|------------|
| **Adguard Home** | adguard/adguardhome | semver | ✅ Yes |
| **Acestream** | ghcr.io/martinbjeldbak/acestream-http-proxy | latest | ✅ Yes |
| **Bazarr** | linuxserver/bazarr | semver | ✅ Yes |
| **ESPHome** | ghcr.io/esphome/esphome | semver | ✅ Yes |
| **Flaresolverr** | ghcr.io/flaresolverr/flaresolverr | semver | ✅ Yes |
| **Jackett** | linuxserver/jackett, ghcr.io/flaresolverr/flaresolverr | semver | ✅ Yes |
| **Jellyseerr** | fallenbagel/jellyseerr | semver | ✅ Yes |
| **qBittorrent** | linuxserver/qbittorrent, qmcgaw/gluetun | semver | ✅ Yes |
| **Radarr** | linuxserver/radarr, qmcgaw/gluetun | semver | ✅ Yes |
| **Scanopy** | ghcr.io/scanopy/scanopy/daemon, server, postgres | latest/semver | ✅ Yes |
| **Speedtest Tracker** | lscr.io/linuxserver/speedtest-tracker | latest | ✅ Yes |
| **Uptime Kuma** | louislam/uptime-kuma | semver | ✅ Yes |

---

## How It Works

### Renovate (Helm Charts)
1. Detects new Helm chart versions
2. Creates a PR with the updated `targetRevision`
3. Auto-merges based on update type (patch/minor auto-merge, major requires review)
4. ArgoCD syncs the new chart version

### ArgoCD Image Updater (Raw K8s)
1. Scans pod specs for image tags
2. Detects new image versions from registries
3. Automatically updates the image tag in YAML
4. Commits changes to Git
5. ArgoCD syncs the updated manifests

---

## Configuration Files
- **Renovate**: `renovate.json` - Helm chart update rules
- **ArgoCD Image Updater**: Pod annotations in each deployment/statefulset
  - `argocd-image-updater.argoproj.io/image-list`
  - `argocd-image-updater.argoproj.io/{image}.update-strategy`

---

## Update Strategies
- **semver**: Semantic versioning (respects major/minor/patch)
- **latest**: Always use the latest available version

