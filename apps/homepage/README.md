# 🏠 Homepage Dashboard

A sleek, modern dashboard for accessing all Kubernetes homelab applications.

## � Access

**URL**: http://home.homelab

## 📋 Dashboard Layout

### Services (4 Columns)

| Infrastructure | Media Server | Monitoring | Storage |
|----------------|--------------|------------|---------|
| Home Assistant | Radarr | Grafana | Longhorn |
| ESPHome | Jellyfin | ArgoCD | Minio |
| AdGuard Home | qBittorrent | Uptime Kuma | Synology NAS |

### System Monitoring (Glances Widgets)

- **Beelink (Control Plane)**: CPU & Memory metrics
- **Worker Node**: CPU & Memory metrics

### Quick Links (Bookmarks)

- GitHub Repo (kubernetes-homelab)
- Tailscale Admin
- UGREEN NAS Dashboard
- Jellyseerr

## 🔧 Configuration

### Secrets Required

Create `homepage-secrets` in the `homepage` namespace with these keys:

| Variable | Service | How to Get |
|----------|---------|------------|
| `HOMEPAGE_VAR_ADGUARD_USER` | AdGuard Home | Your AdGuard username |
| `HOMEPAGE_VAR_ADGUARD_PASSWORD` | AdGuard Home | Your AdGuard password |
| `HOMEPAGE_VAR_QBITTORRENT_USER` | qBittorrent | WebUI username |
| `HOMEPAGE_VAR_QBITTORRENT_PASSWORD` | qBittorrent | WebUI password |
| `HOMEPAGE_VAR_UPTIMEKUMA_API_KEY` | Uptime Kuma | Settings → API Keys |
| `HOMEPAGE_VAR_SYNOLOGY_USER` | Synology NAS | DSM username |
| `HOMEPAGE_VAR_SYNOLOGY_PASSWORD` | Synology NAS | DSM password |

### Updating Configuration

```bash
# Edit configuration
vim apps/homepage/custom-values.yaml

# Commit and push (ArgoCD auto-syncs)
git add -A && git commit -m "feat: update homepage" && git push

# Force pod restart if needed
kubectl delete pod -n homepage -l app.kubernetes.io/name=homepage
```

## 🎨 Theme Settings

- **Theme**: Dark
- **Color**: Slate
- **Header Style**: Boxed
- **Status Style**: Dot indicators

## 💾 Storage

Homepage uses a Longhorn PVC for persistent logs:
- **PVC**: `homepage` (5Gi)
- **Mount**: `/app/config/logs`

## 🐛 Troubleshooting

```bash
# Check pod status
kubectl get pods -n homepage

# View logs
kubectl logs -n homepage -l app.kubernetes.io/name=homepage

# Restart pod
kubectl delete pod -n homepage -l app.kubernetes.io/name=homepage
```

## 📚 Resources

- [Homepage Documentation](https://gethomepage.dev/)
- [Widget Documentation](https://gethomepage.dev/widgets/)
- [Dashboard Icons](https://github.com/walkxcode/dashboard-icons)
