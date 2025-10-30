# 🏠 Homepage Dashboard

A sleek, modern dashboard for accessing all your Kubernetes homelab applications.

## 🎨 Features

- **Organized Categories**: Applications grouped by function
  - 🎬 Media Server (Jellyfin, Radarr, Jackett, qBittorrent)
  - 📊 Monitoring & Observability (Grafana, Uptime Kuma)
  - 🗄️ Infrastructure & Storage (Longhorn, MinIO)
  - 🏡 Home Automation & IoT (Home Assistant, EMQX)

- **Live Widgets**: Real-time stats from your applications
  - Jellyfin: Now playing, library stats
  - Grafana: Dashboard metrics
  - Radarr: Movie collection stats
  - Kubernetes: Cluster resource usage
  - Longhorn: Storage health

- **Quick Access Bookmarks**: Useful documentation and resources
- **Search Integration**: Google search built-in
- **Dark Theme**: Easy on the eyes

## 🌐 Access

**URL**: https://homepage.tabby-carp.ts.net

## 🔧 Configuration

### API Keys Required

To enable widgets with live data, you need to configure API keys:

#### 1. **Radarr API Key**

```bash
# Get Radarr API key
kubectl exec -n media radarr-0 -- cat /config/config.xml | grep ApiKey

# Update the environment variable in custom-values.yaml
# Replace YOUR_RADARR_API_KEY with the actual key
```

#### 2. **Home Assistant Long-Lived Access Token**

1. Go to Home Assistant: https://home-assistant.tabby-carp.ts.net
2. Click on your profile (bottom left)
3. Scroll down to "Long-Lived Access Tokens"
4. Click "Create Token"
5. Copy the token and update `HOMEPAGE_VAR_HOMEASSISTANT_TOKEN` in custom-values.yaml

#### 3. **Grafana Credentials**

Default credentials are already set:
- Username: `admin`
- Password: `prom-operator`

If you changed the password, update `HOMEPAGE_VAR_GRAFANA_PASSWORD` in custom-values.yaml

#### 4. **Uptime Kuma Slug**

1. Go to Uptime Kuma: https://uptime-kuma.tabby-carp.ts.net
2. Go to Settings → Status Pages
3. Copy the slug from your status page URL
4. Update the `slug` value in the Uptime Kuma widget config

### Updating Configuration

After updating API keys in `apps/homepage/custom-values.yaml`:

```bash
cd /home/pablo/kubernetes/kubernetes-homelab

# Commit changes
git add apps/homepage/custom-values.yaml
git commit -m "feat: Update Homepage API keys"
git push origin main

# ArgoCD will auto-sync and restart the pod
# Or manually sync:
kubectl delete pod -n homepage -l app.kubernetes.io/name=homepage
```

## 📊 Available Widgets

### Currently Configured:
- ✅ Jellyfin (with API key from secret)
- ✅ Kubernetes cluster stats
- ✅ System resources
- ⚠️ Radarr (needs API key)
- ⚠️ Grafana (needs credentials)
- ⚠️ Home Assistant (needs token)
- ⚠️ Uptime Kuma (needs slug)
- ⚠️ Longhorn (auto-discovery)
- ⚠️ EMQX (auto-discovery)
- ⚠️ qBittorrent (auto-discovery)

### Widgets Marked ⚠️ Need Configuration

Follow the API Keys section above to enable these widgets.

## 🎨 Customization

### Change Theme

Edit `apps/homepage/custom-values.yaml`:

```yaml
settings:
  theme: dark  # Options: dark, light
  color: slate  # Options: slate, gray, zinc, neutral, stone, red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose
```

### Add More Services

Add to the `services` section:

```yaml
- Your Category:
    - Your App:
        icon: app-icon.png
        href: https://your-app.tabby-carp.ts.net/
        description: Your app description
        widget:
          type: app-type
          url: https://your-app.tabby-carp.ts.net/
```

### Add More Bookmarks

Add to the `bookmarks` section:

```yaml
- Category Name:
    - Bookmark Name:
        - icon: icon.png
          href: https://example.com
          description: Bookmark description
```

## 🔍 Search Providers

Current: Google

Available options:
- google
- duckduckgo
- bing
- brave
- custom

Change in `widgets` section:

```yaml
- search:
    provider: duckduckgo
    target: _blank
```

## 📱 Layout

The dashboard uses a responsive grid layout:
- **Media Server**: 4 columns (row layout)
- **Monitoring**: 2 columns (row layout)
- **Infrastructure**: 3 columns (row layout)
- **Home Automation**: 2 columns (row layout)

Adjust in the `settings.layout` section.

## 🐛 Troubleshooting

### Widget Not Showing Data

1. Check API key is correct
2. Check the app is accessible from Homepage pod:
   ```bash
   kubectl exec -n homepage deployment/homepage -- wget -O- https://app.tabby-carp.ts.net
   ```
3. Check Homepage logs:
   ```bash
   kubectl logs -n homepage deployment/homepage
   ```

### Dashboard Not Loading

1. Check pod status:
   ```bash
   kubectl get pods -n homepage
   ```
2. Check ingress:
   ```bash
   kubectl get ingress -n homepage
   ```
3. Restart pod:
   ```bash
   kubectl delete pod -n homepage -l app.kubernetes.io/name=homepage
   ```

## 📚 Resources

- [Homepage Documentation](https://gethomepage.dev/)
- [Widget Documentation](https://gethomepage.dev/en/widgets/)
- [Service Icons](https://github.com/walkxcode/dashboard-icons)
- [Community Configs](https://github.com/gethomepage/homepage/discussions)

## 🎯 Next Steps

1. ✅ Access Homepage: https://homepage.tabby-carp.ts.net
2. ⚠️ Configure API keys (see above)
3. 🎨 Customize theme and layout to your preference
4. 📊 Add more widgets as needed
5. 🔖 Add personal bookmarks

Enjoy your sleek homelab dashboard! 🚀

