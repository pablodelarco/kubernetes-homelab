# Media Server Stack Configuration Guide

This guide explains how to configure and integrate the media server applications (Radarr, Jellyfin, qBittorrent, and Jackett) to work together for automated movie downloading and management.

## Architecture Overview

```
┌─────────────┐
│   Radarr    │ ← Movie management & automation
└──────┬──────┘
       │
       ├──────→ ┌─────────────┐
       │        │   Jackett   │ ← Torrent indexer proxy
       │        └─────────────┘
       │
       ├──────→ ┌─────────────┐
       │        │ qBittorrent │ ← Download client (with VPN)
       │        └─────────────┘
       │
       └──────→ ┌─────────────┐
                │  Jellyfin   │ ← Media streaming
                └─────────────┘
```

## Deployed Applications

| Application | Purpose | Access URL | Port |
|------------|---------|------------|------|
| **Jellyfin** | Media streaming platform | https://jellyfin.tabby-carp.ts.net | 8096 |
| **Radarr** | Movie collection manager | https://radarr.tabby-carp.ts.net | 7878 |
| **qBittorrent** | Download client with VPN | https://qbitt.tabby-carp.ts.net | 8080 |
| **Jackett** | Torrent indexer proxy | https://jackett.tabby-carp.ts.net | 9117 |

## Storage Configuration

### NFS Storage (Synology NAS - 192.168.1.42)
- **Media Storage**: `/volume1/media_player` → 400Gi
  - Mounted in Jellyfin at `/data/videos`
  - Mounted in Radarr at `/movies`
- **Download Storage**: `/volume1/media_player/download` → 400Gi
  - Mounted in qBittorrent at `/downloads`
  - Mounted in Radarr at `/downloads`

### Longhorn Storage (Cluster)
- **Application Configs**: 5Gi per application
  - `jellyfin-config` → Jellyfin configuration
  - `radarr` → Radarr configuration
  - `qbitt` → qBittorrent configuration
  - `jackett` → Jackett configuration

## Integration Configuration

### Step 1: Configure Jackett (Indexer Proxy)

1. Access Jackett at https://jackett.tabby-carp.ts.net
2. Click "Add indexer" and add your preferred torrent indexers (e.g., 1337x, RARBG, The Pirate Bay)
3. Copy the **API Key** from the top-right corner (you'll need this for Radarr)
4. Note the **Jackett URL**: `http://jackett.media.svc.cluster.local`

### Step 2: Configure qBittorrent (Download Client)

1. Access qBittorrent at https://qbitt.tabby-carp.ts.net
2. Default credentials (first login):
   - Username: `admin`
   - Password: Check the logs: `kubectl logs -n media qbitt-0 -c qbitt | grep password`
3. **Important Settings**:
   - Go to **Tools → Options → Downloads**
     - Set "Default Save Path": `/downloads/complete`
     - Set "Keep incomplete torrents in": `/downloads/incomplete`
   - Go to **Tools → Options → Web UI**
     - Enable "Bypass authentication for clients on localhost"
     - Enable "Bypass authentication for clients in whitelisted IP subnets"
     - Add subnet: `10.43.0.0/16` (Kubernetes service network)
4. Note the **qBittorrent URL**: `http://qbitt.media.svc.cluster.local`

### Step 3: Configure Radarr (Movie Manager)

1. Access Radarr at https://radarr.tabby-carp.ts.net
2. Complete the initial setup wizard

#### 3.1 Add Download Client (qBittorrent)
1. Go to **Settings → Download Clients**
2. Click the **+** button and select **qBittorrent**
3. Configure:
   - **Name**: qBittorrent
   - **Host**: `qbitt.media.svc.cluster.local`
   - **Port**: `80`
   - **Username**: `admin`
   - **Password**: (your qBittorrent password)
   - **Category**: `radarr` (optional, helps organize downloads)
4. Click **Test** to verify connection
5. Click **Save**

#### 3.2 Add Indexers (via Jackett)
1. Go to **Settings → Indexers**
2. Click the **+** button and select **Torznab → Custom**
3. For each indexer in Jackett:
   - **Name**: (indexer name, e.g., "1337x")
   - **URL**: `http://jackett.media.svc.cluster.local/api/v2.0/indexers/[indexer-id]/results/torznab/`
     - Get the full URL from Jackett by clicking "Copy Torznab Feed" for each indexer
   - **API Key**: (your Jackett API key)
   - **Categories**: `2000,2010,2020,2030,2040,2045,2050,2060,2070,2080` (Movies)
4. Click **Test** to verify connection
5. Click **Save**
6. Repeat for all indexers you want to use

#### 3.3 Configure Media Management
1. Go to **Settings → Media Management**
2. Enable **Rename Movies**
3. Set **Movie Folder Format**: `{Movie Title} ({Release Year})`
4. Set **Movie File Format**: `{Movie Title} ({Release Year}) - {Quality Full}`
5. Enable **Create empty movie folders**
6. Set **Root Folders**: Click **Add Root Folder** → `/movies`
7. Click **Save**

### Step 4: Configure Jellyfin (Media Server)

1. Access Jellyfin at https://jellyfin.tabby-carp.ts.net
2. Complete the initial setup wizard
3. Add a **Media Library**:
   - Click **Add Media Library**
   - **Content type**: Movies
   - **Display name**: Movies
   - **Folders**: Click **+** and add `/data/videos`
   - Click **OK**
4. Configure **Library Settings**:
   - Enable **Automatically refresh metadata from the internet**
   - Set preferred metadata language and country
5. Click **Save**

## Workflow: How It Works

1. **Add a Movie in Radarr**:
   - Search for a movie and click "Add Movie"
   - Select quality profile and root folder (`/movies`)
   - Click "Add Movie"

2. **Radarr Searches for the Movie**:
   - Radarr queries all configured indexers via Jackett
   - Finds the best release based on your quality settings

3. **Download via qBittorrent**:
   - Radarr sends the torrent to qBittorrent
   - qBittorrent downloads via VPN (NordVPN through Gluetun)
   - Files are saved to `/downloads/complete/radarr/`

4. **Import to Media Library**:
   - When download completes, Radarr moves/copies the file to `/movies/Movie Title (Year)/`
   - Radarr renames the file according to your naming scheme

5. **Jellyfin Detects New Media**:
   - Jellyfin automatically scans `/data/videos` (which maps to `/movies`)
   - New movie appears in your Jellyfin library
   - Metadata and artwork are downloaded automatically

## Troubleshooting

### Radarr can't connect to qBittorrent
- Verify qBittorrent is running: `kubectl get pods -n media`
- Check qBittorrent logs: `kubectl logs -n media qbitt-0 -c qbitt`
- Ensure the subnet `10.43.0.0/16` is whitelisted in qBittorrent Web UI settings

### Radarr can't find any releases
- Verify Jackett is running and indexers are configured
- Test indexers in Jackett by searching for a movie
- Check Radarr logs: `kubectl logs -n media radarr-0`
- Verify the Jackett API key is correct in Radarr

### Downloads not appearing in Jellyfin
- Check that the file was moved to `/movies` in Radarr → Activity → Queue
- Verify the path mapping: Radarr's `/movies` = Jellyfin's `/data/videos`
- Manually trigger a library scan in Jellyfin: Dashboard → Libraries → Scan All Libraries

### VPN not working
- Check Gluetun logs: `kubectl logs -n media qbitt-0 -c gluetun`
- Verify NordVPN credentials in secret: `kubectl get secret -n media nordvpn-secrets -o yaml`
- Test VPN connection: Access qBittorrent and check the IP address shown

## Maintenance

### Update Applications
```bash
# Update Radarr
kubectl rollout restart statefulset/radarr -n media

# Update Jellyfin
kubectl rollout restart statefulset/jellyfin -n media

# Update qBittorrent (with VPN)
kubectl rollout restart statefulset/qbitt -n media

# Update Jackett
kubectl rollout restart deployment/jackett -n media
```

### Check Application Status
```bash
# View all media server pods
kubectl get pods -n media

# View services and their IPs
kubectl get svc -n media

# View persistent volumes
kubectl get pvc,pv -n media
```

### Backup Configuration
All application configurations are stored in Longhorn PVCs. Use Longhorn's backup feature to create snapshots:
1. Access Longhorn UI at https://longhorn.tabby-carp.ts.net
2. Navigate to Volume → Select volume → Create Snapshot
3. Create Backup from snapshot to external storage (if configured)

## Security Notes

- **VPN Protection**: qBittorrent traffic is routed through NordVPN via Gluetun sidecar
- **Tailscale Access**: All applications are accessible only via Tailscale network (with Funnel enabled for external access)
- **No Public IPs**: Services use ClusterIP, exposed only through Tailscale ingress
- **Secrets Management**: VPN credentials stored in Kubernetes secrets

## Future Enhancements

Consider adding:
- **Sonarr**: For TV show management (similar to Radarr but for series)
- **Prowlarr**: Modern alternative to Jackett with better indexer management
- **Bazarr**: Subtitle management for movies and TV shows
- **Overseerr/Jellyseerr**: Request management system for users

## References

- [Radarr Documentation](https://wiki.servarr.com/radarr)
- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [qBittorrent Documentation](https://github.com/qbittorrent/qBittorrent/wiki)
- [Jackett Documentation](https://github.com/Jackett/Jackett)
- [Gluetun VPN Documentation](https://github.com/qdm12/gluetun)

