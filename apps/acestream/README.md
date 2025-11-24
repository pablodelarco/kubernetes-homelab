# Acestream Deployment

## Overview

Acestream is a P2P streaming platform based on BitTorrent technology that allows streaming live video content (especially sports) over the internet.

**Docker Image**: `ghcr.io/martinbjeldbak/acestream-http-proxy:latest`  
**Maintenance Status**: ✅ Actively maintained (last update: Nov 2025)  
**Repository**: https://github.com/martinbjeldbak/acestream-http-proxy

## Access URLs

### Local Network (Best Performance)
- **Beelink**: `http://100.113.23.108:30878`
- **Worker**: `http://100.96.103.31:30878`

### Remote Access (via Tailscale Funnel)
- **HTTPS**: `https://acestream.tabby-carp.ts.net`

## How to Use with Infuse (Apple Devices)

### Step 1: Find Acestream Links

Acestream links are typically shared on:
- Reddit (r/motorsportsstreams, r/soccerstreams, etc.)
- Sports streaming forums
- Acestream link aggregators

Acestream IDs look like this: `94d8c5e1e6f3b8c7a2d9e4f5b6c7d8e9f0a1b2c3`

### Step 2: Convert Acestream ID to HTTP URL

Use one of these formats:

**HLS Format (Recommended for Infuse)**:
```
http://100.96.103.31:30878/ace/manifest.m3u8?id=ACESTREAM_ID
```

**MPEG-TS Format**:
```
http://100.96.103.31:30878/ace/getstream?id=ACESTREAM_ID
```

**Example**:
```
http://100.96.103.31:30878/ace/manifest.m3u8?id=94d8c5e1e6f3b8c7a2d9e4f5b6c7d8e9f0a1b2c3
```

### Step 3: Add to Infuse

1. Open **Infuse** on your Apple device
2. Tap **+** to add a new source
3. Select **Network Share** → **Other**
4. Paste the HTTP URL from Step 2
5. Tap **Save**
6. The stream will start playing with Apple's hardware codecs

### Step 4: Create M3U Playlist (Optional)

For better organization, create an M3U playlist file:

```m3u
#EXTM3U
#EXTINF:-1,Match Name - Channel 1
http://100.96.103.31:30878/ace/manifest.m3u8?id=ACESTREAM_ID_1
#EXTINF:-1,Match Name - Channel 2
http://100.96.103.31:30878/ace/manifest.m3u8?id=ACESTREAM_ID_2
```

Save as `sports.m3u` and add to Infuse as a playlist.

## Remote Access (Away from Home)

When you're away from home, use the Tailscale Funnel URL:

```
https://acestream.tabby-carp.ts.net/ace/manifest.m3u8?id=ACESTREAM_ID
```

## Benefits of Using Infuse with Acestream

✅ **Hardware Decoding**: Apple's VideoToolbox handles H.264/H.265/HEVC  
✅ **Low CPU Usage**: Offloaded to GPU/dedicated video hardware  
✅ **Better Battery Life**: Efficient hardware acceleration  
✅ **Smooth Playback**: Even on older devices  
✅ **HDR Support**: If the stream provides it  
✅ **Dolby Audio**: Infuse supports advanced audio codecs

## Troubleshooting

### Stream Not Loading
- Wait 10-30 seconds for the P2P network to connect
- Check if the Acestream ID is valid
- Try a different Acestream ID

### Buffering Issues
- P2P streaming requires good internet connection (both upload and download)
- More peers = better performance
- Consider using local network access for best performance

### Pod Not Starting
```bash
kubectl logs -n home-assistant -l app=acestream
kubectl describe pod -n home-assistant -l app=acestream
```

## Resource Usage

- **Memory**: 512Mi request, 2Gi limit
- **CPU**: 250m request, 2000m limit
- **Storage**: 10Gi PVC for stream caching

## Legal Notice

⚠️ **Important**: Acestream itself is legal (it's just P2P technology). However, streaming copyrighted content without permission is illegal in most countries. Use Acestream only for legal content (public broadcasts, authorized streams, etc.).

## Technical Details

- **Port**: 6878 (HTTP API)
- **NodePort**: 30878
- **Namespace**: home-assistant
- **Deployment Strategy**: Recreate (required for ReadWriteOnce PVC)
- **Health Checks**: Liveness and readiness probes on `/webui/api/service`

