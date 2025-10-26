# Prowlarr Migration Guide

## Why Consider Prowlarr?

**Prowlarr** is a modern indexer manager that serves as a more advanced alternative to Jackett. It's part of the *arr suite (Radarr, Sonarr, etc.) and offers several advantages:

### Advantages of Prowlarr over Jackett:

1. **Centralized Indexer Management**
   - Configure indexers once in Prowlarr
   - Automatically sync to all *arr apps (Radarr, Sonarr, etc.)
   - No need to add indexers individually in each app

2. **Better Integration**
   - Native integration with Radarr, Sonarr, Lidarr, Readarr
   - Automatic API key management
   - Sync indexer settings across all apps

3. **Advanced Features**
   - Built-in indexer statistics and health monitoring
   - Better error handling and retry logic
   - Support for more indexers (including Usenet)
   - Flaresolverr integration for Cloudflare-protected sites

4. **Modern UI**
   - Consistent interface with other *arr apps
   - Better mobile experience
   - More detailed logging and troubleshooting

5. **Active Development**
   - Part of the Servarr suite (actively maintained)
   - Regular updates and new features
   - Better community support

### When to Stick with Jackett:

- You only use Radarr (no Sonarr or other *arr apps)
- You're happy with current setup and don't want to reconfigure
- You use very niche indexers not supported by Prowlarr

## Migration Steps (Optional)

If you decide to migrate from Jackett to Prowlarr, here's how:

### 1. Deploy Prowlarr

Create the following files in `apps/media-server/prowlarr/`:

**prowlarr-pvc.yaml**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prowlarr
  namespace: media
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

**prowlarr-sts.yaml**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prowlarr
  namespace: media
spec:
  serviceName: prowlarr
  replicas: 1
  selector:
    matchLabels:
      app: prowlarr
  template:
    metadata:
      labels:
        app: prowlarr
    spec:
      containers:
        - name: prowlarr
          image: linuxserver/prowlarr:latest
          env:
            - name: PUID
              value: "65534"
            - name: PGID
              value: "65534"
            - name: TZ
              value: "Europe/Madrid"
          volumeMounts:
            - name: config
              mountPath: /config
          ports:
            - containerPort: 9696
          livenessProbe:
            httpGet:
              path: /ping
              port: 9696
            initialDelaySeconds: 60
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ping
              port: 9696
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
      volumes:
        - name: config
          persistentVolumeClaim:
            claimName: prowlarr
```

**prowlarr-svc.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: prowlarr
  namespace: media
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 9696
  selector:
    app: prowlarr
```

**prowlarr-ingress.yaml**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prowlarr
  namespace: media
  annotations:
    tailscale.com/funnel: "true"
spec:
  ingressClassName: tailscale
  rules:
    - host: prowlarr
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prowlarr
                port:
                  number: 80
  tls:
    - hosts:
        - prowlarr
```

### 2. Deploy Prowlarr

```bash
kubectl apply -f apps/media-server/prowlarr/
```

### 3. Configure Prowlarr

1. Access Prowlarr at https://prowlarr.tabby-carp.ts.net
2. Complete initial setup
3. Go to **Settings → Apps**
4. Click **+** to add Radarr:
   - **Sync Level**: Full Sync
   - **Prowlarr Server**: `http://prowlarr.media.svc.cluster.local`
   - **Radarr Server**: `http://radarr.media.svc.cluster.local`
   - **API Key**: (get from Radarr → Settings → General → API Key)
   - Click **Test** then **Save**

### 4. Add Indexers in Prowlarr

1. Go to **Indexers** → **Add Indexer**
2. Add your preferred indexers (same ones you had in Jackett)
3. Prowlarr will automatically sync them to Radarr

### 5. Verify Sync

1. Go to Radarr → Settings → Indexers
2. You should see all indexers from Prowlarr automatically added
3. Test by searching for a movie in Radarr

### 6. Remove Jackett (Optional)

Once you've verified Prowlarr is working:

1. Remove indexers from Radarr that were manually added via Jackett
2. Delete Jackett deployment:
   ```bash
   kubectl delete -f apps/media-server/jackett/
   ```

## Recommendation

**For your current setup**: Since you only have Radarr deployed, **Jackett is perfectly fine**. The benefits of Prowlarr become more apparent when you have multiple *arr applications (Radarr + Sonarr + Lidarr, etc.).

**Consider Prowlarr if**:
- You plan to add Sonarr for TV shows
- You want better indexer management and statistics
- You prefer the modern *arr UI consistency

**Stick with Jackett if**:
- Current setup works well for you
- You only manage movies (Radarr only)
- You don't want to reconfigure everything

## Sonarr Deployment (TV Shows)

If you want to add TV show management, you should deploy Sonarr. Here's a quick overview:

**Sonarr** is like Radarr but for TV shows. It:
- Monitors TV series for new episodes
- Automatically downloads new episodes when they air
- Integrates with the same download client (qBittorrent) and indexers
- Works perfectly alongside Radarr

If you deploy Sonarr, **Prowlarr becomes much more valuable** because you can manage indexers once and sync to both Radarr and Sonarr.

Would you like me to create deployment manifests for Sonarr as well?

