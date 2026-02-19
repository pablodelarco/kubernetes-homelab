# Home Assistant Stack: K8s to Docker Compose Migration

## Overview

Migrate the home automation stack (Home Assistant, ESPHome, Mosquitto) from the Kubernetes cluster to Docker Compose running natively on the **worker** node. A Caddy reverse proxy on port 80 provides clean `ha.homelab` / `esphome.homelab` URLs without port numbers.

### Why

- **Simpler networking** — Native `hostNetwork` without K8s abstractions. mDNS, Matter, Thread, and Zigbee device discovery work out of the box.
- **Native USB access** — No privileged containers or K8s device plugins needed for the ZBT-1 coordinator.
- **Independence from K8s** — Home automation shouldn't go down if the cluster has issues. HA is a critical household service.
- **Clean URLs** — `ha.homelab` on port 80 via Caddy, with DNS rewrites pointing directly to the worker.

### Architecture Before vs After

```
BEFORE:
  Browser → AdGuard DNS → *.homelab → 100.113.23.108 (beelink)
         → Cilium Gateway :80 → HTTPRoute → K8s Service → Pod on worker

AFTER:
  Browser → AdGuard DNS → ha.homelab → 100.96.103.31 (worker)
         → Caddy :80 → localhost:8123 → Home Assistant (Docker)

  Browser → AdGuard DNS → grafana.homelab → 100.113.23.108 (beelink)
         → Cilium Gateway :80 → HTTPRoute → K8s Service (unchanged)
```

---

## Phase 0: Pre-Checks

### 0.1 — Docker Compose on worker

```bash
ssh worker 'docker compose version'
```

If not available:

```bash
ssh worker 'sudo apt-get update && sudo apt-get install -y docker-compose-plugin'
```

### 0.2 — Port 80 availability on worker

```bash
ssh worker 'sudo ss -tlnp | grep :80'
```

If Cilium envoy binds port 80 → Phase 1 is required to free it.

### 0.3 — Longhorn PVC data inspection

```bash
kubectl run pvc-inspect --image=busybox --rm -it --restart=Never \
  --overrides='{
    "spec":{
      "containers":[{"name":"i","image":"busybox",
        "command":["sh","-c","ls -la /data/ && cat /data/.HA_VERSION 2>/dev/null"],
        "volumeMounts":[{"name":"d","mountPath":"/data"}]}],
      "volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"home-assistant-home-assistant-0"}}],
      "nodeSelector":{"kubernetes.io/hostname":"worker"}
    }}' \
  -n home-assistant
```

- If PVC has data (`configuration.yaml`, `.HA_VERSION`, `home-assistant_v2.db`) → migrate in Phase 3.
- If empty or stale → skip data migration.

---

## Phase 1: Free Port 80 on Worker

Cilium Gateway API with `gatewayAPI.hostNetwork.enabled: true` binds port 80 on all nodes via the envoy proxy. We need to restrict it to beelink only.

### Steps

1. Verify the Helm value exists:

   ```bash
   helm show values cilium/cilium | grep -A 20 "^envoy:"
   ```

2. Modify `cluster/cilium/cilium-values-vxlan.yaml` — add envoy nodeSelector:

   ```yaml
   envoy:
     enabled: true
     nodeSelector:
       kubernetes.io/hostname: beelink
   ```

   If `nodeSelector` is not supported, use `affinity` instead:

   ```yaml
   envoy:
     affinity:
       nodeAffinity:
         requiredDuringSchedulingIgnoredDuringExecution:
           nodeSelectorTerms:
             - matchExpressions:
                 - key: kubernetes.io/hostname
                   operator: In
                   values:
                     - beelink
   ```

3. Apply:

   ```bash
   helm upgrade cilium cilium/cilium -n kube-system \
     -f cluster/cilium/cilium-values-vxlan.yaml
   ```

4. Verify:

   ```bash
   # Envoy only on beelink
   kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium-envoy -o wide

   # Port 80 free on worker
   ssh worker 'sudo ss -tlnp | grep :80'

   # Existing services unaffected (DNS points *.homelab to beelink anyway)
   curl -s -o /dev/null -w "%{http_code}" http://grafana.homelab/
   ```

---

## Phase 2: Prepare Docker Compose Stack on Worker

### 2.1 — Directory structure

```bash
ssh worker 'mkdir -p /home/pablo/docker/{homeassistant/config,mosquitto/{config,data,log},esphome/config,caddy/{data,config},code-server/config}'
```

### 2.2 — Environment file

**`/home/pablo/docker/.env`**

```env
TZ=Europe/Madrid
PUID=1000
PGID=1000
HA_CONFIG_PATH=./homeassistant/config
ZIGBEE_DEVICE=/dev/ttyUSB0
```

### 2.3 — Caddy reverse proxy config

**`/home/pablo/docker/caddy/Caddyfile`**

```
ha.homelab, home-assistant.homelab {
    reverse_proxy localhost:8123
}

esphome.homelab {
    reverse_proxy localhost:6052
}
```

### 2.4 — Mosquitto config

**`/home/pablo/docker/mosquitto/config/mosquitto.conf`**

```
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest stdout
```

### 2.5 — Docker Compose file

**`/home/pablo/docker/homeassistant-stack.yaml`**

All services use `network_mode: host` — they communicate via localhost.

```yaml
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy/data:/data
      - ./caddy/config:/config

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host
    privileged: true
    environment:
      - TZ=${TZ}
    volumes:
      - ${HA_CONFIG_PATH}:/config
      - /run/dbus:/run/dbus:ro
    depends_on:
      - mosquitto

  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mosquitto
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log

  esphome:
    image: ghcr.io/esphome/esphome
    container_name: esphome
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=${TZ}
      - ESPHOME_DASHBOARD_USE_PING=true
    volumes:
      - ./esphome/config:/config
      - /etc/localtime:/etc/localtime:ro

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    restart: unless-stopped
    profiles:
      - zigbee
    network_mode: host
    environment:
      - TZ=${TZ}
    volumes:
      - ./zigbee2mqtt/data:/app/data
    devices:
      - ${ZIGBEE_DEVICE}:/dev/ttyUSB0
    depends_on:
      - mosquitto

  code-server:
    image: lscr.io/linuxserver/code-server:latest
    container_name: code-server
    restart: unless-stopped
    profiles:
      - dev
    network_mode: host
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - DEFAULT_WORKSPACE=/config
    volumes:
      - ./code-server/config:/config
      - ${HA_CONFIG_PATH}:/config/workspace/homeassistant
      - ./esphome/config:/config/workspace/esphome
```

---

## Phase 3: Data Migration

Skip this phase if Phase 0.3 showed no data in the PVC.

### 3.1 — Disable ArgoCD auto-sync

```bash
kubectl patch application home-assistant -n argocd \
  --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

### 3.2 — Scale down K8s workloads

```bash
kubectl scale statefulset home-assistant -n home-assistant --replicas=0
kubectl scale deployment esphome -n home-assistant --replicas=0
```

### 3.3 — Export Home Assistant data

```bash
kubectl run pvc-copy --image=busybox --restart=Never \
  --overrides='{
    "spec":{
      "containers":[{"name":"c","image":"busybox","command":["sleep","3600"],
        "volumeMounts":[{"name":"d","mountPath":"/data"}]}],
      "volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"home-assistant-home-assistant-0"}}],
      "nodeSelector":{"kubernetes.io/hostname":"worker"}
    }}' \
  -n home-assistant

kubectl wait --for=condition=Ready pod/pvc-copy -n home-assistant --timeout=60s
kubectl exec pvc-copy -n home-assistant -- tar czf /tmp/ha-backup.tar.gz -C /data .
kubectl cp home-assistant/pvc-copy:/tmp/ha-backup.tar.gz /tmp/ha-backup.tar.gz
scp /tmp/ha-backup.tar.gz worker:/tmp/
ssh worker 'tar xzf /tmp/ha-backup.tar.gz -C /home/pablo/docker/homeassistant/config/'
kubectl delete pod pvc-copy -n home-assistant
```

### 3.4 — Export ESPHome data

```bash
kubectl run esphome-copy --image=busybox --restart=Never \
  --overrides='{
    "spec":{
      "containers":[{"name":"c","image":"busybox","command":["sleep","3600"],
        "volumeMounts":[{"name":"d","mountPath":"/data"}]}],
      "volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"esphome"}}],
      "nodeSelector":{"kubernetes.io/hostname":"worker"}
    }}' \
  -n home-assistant

kubectl wait --for=condition=Ready pod/esphome-copy -n home-assistant --timeout=60s
kubectl exec esphome-copy -n home-assistant -- tar czf /tmp/esphome-backup.tar.gz -C /data .
kubectl cp home-assistant/esphome-copy:/tmp/esphome-backup.tar.gz /tmp/esphome-backup.tar.gz
scp /tmp/esphome-backup.tar.gz worker:/tmp/
ssh worker 'tar xzf /tmp/esphome-backup.tar.gz -C /home/pablo/docker/esphome/config/'
kubectl delete pod esphome-copy -n home-assistant
```

### 3.5 — Mosquitto

No data migration needed — K8s deployment uses `emptyDir` (no persistent state).

### 3.6 — Update HA configuration.yaml trusted_proxies

On the worker, edit `/home/pablo/docker/homeassistant/config/configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.0/8          # Localhost (Caddy)
    - 192.168.1.0/24       # Local LAN
    - 100.64.0.0/10        # Tailscale IPv4
    - fd7a:115c:a1e0::/48  # Tailscale IPv6
```

Removed: `10.42.0.0/16` (K8s pod network), `10.43.0.0/16` (K8s services) — no longer needed.

---

## Phase 4: DNS Configuration

Add specific rewrites in AdGuard Home. Specific entries take priority over the `*.homelab` wildcard.

| Domain | Answer |
|--------|--------|
| `ha.homelab` | `100.96.103.31` (worker Tailscale IP) |
| `home-assistant.homelab` | `100.96.103.31` |
| `esphome.homelab` | `100.96.103.31` |

Using the worker's Tailscale IP for consistency with the existing `*.homelab → 100.113.23.108` pattern. Accessible from anywhere on the Tailscale mesh.

### Configure via AdGuard Home UI

Filters → DNS Rewrites → Add DNS Rewrite (one per domain above).

### Verify

```bash
nslookup ha.homelab         # → 100.96.103.31
nslookup esphome.homelab    # → 100.96.103.31
nslookup grafana.homelab    # → 100.113.23.108 (unchanged, wildcard)
```

---

## Phase 5: Deploy and Verify

### 5.1 — Start the stack

```bash
ssh worker 'cd /home/pablo/docker && docker compose -f homeassistant-stack.yaml up -d'
```

### 5.2 — Verify containers

```bash
ssh worker 'docker compose -f homeassistant-stack.yaml ps'
ssh worker 'docker compose -f homeassistant-stack.yaml logs --tail=20'
```

### 5.3 — Verify port bindings

```bash
ssh worker 'sudo ss -tlnp | grep -E ":80 |:8123 |:6052 |:1883 "'
```

### 5.4 — Verify access

```bash
# Via Caddy (clean URLs)
curl -s -o /dev/null -w "%{http_code}" http://ha.homelab/
curl -s -o /dev/null -w "%{http_code}" http://esphome.homelab/

# Existing K8s services still work
curl -s -o /dev/null -w "%{http_code}" http://grafana.homelab/
```

### 5.5 — Reconfigure MQTT in Home Assistant

In HA UI: Settings → Devices & Services → MQTT → Reconfigure:
- **Broker:** `localhost` (was `mosquitto.mosquitto.svc.cluster.local`)
- **Port:** `1883`
- **Username/Password:** empty (anonymous auth)

### Verification checklist

- [ ] `http://ha.homelab/` loads Home Assistant login
- [ ] `http://esphome.homelab/` loads ESPHome dashboard
- [ ] MQTT connected in HA integrations
- [ ] HA automations running
- [ ] K8s services (`grafana.homelab`, `argocd.homelab`, etc.) unaffected
- [ ] Caddy logs clean

---

## Phase 6: Clean Up K8s Resources

Only after Phase 5 is fully verified.

### 6.1 — Delete K8s resources

```bash
# ArgoCD applications (cascading delete removes all managed resources)
kubectl delete application home-assistant -n argocd
kubectl delete application esphome -n argocd

# Mosquitto (no ArgoCD app)
kubectl delete deployment mosquitto -n mosquitto
kubectl delete service mosquitto -n mosquitto
kubectl delete configmap mosquitto-config -n mosquitto
kubectl delete namespace mosquitto
```

### 6.2 — Git changes

**Delete files:**

| File / Directory | Reason |
|------------------|--------|
| `argocd-apps/home-assistant.yaml` | ArgoCD app removed |
| `argocd-apps/esphome.yaml` | ArgoCD app removed |
| `apps/home-assistant/` | K8s manifests/values no longer needed |
| `apps/esphome/` | K8s manifests no longer needed |
| `apps/mosquitto/` | K8s manifests no longer needed |
| `.github/workflows/home-assistant-update-notifier.yaml` | No trigger anymore |
| `restore-home-assistant.yaml` | References deleted PVC |

**Modify files:**

| File | Change |
|------|--------|
| `cluster/cilium-gateway/httproutes-infra.yaml` | Remove `home-assistant` and `esphome` HTTPRoute blocks |
| `apps/homepage/custom-values.yaml` | Update siteMonitor URLs to `http://192.168.1.57:8123` and `:6052` |
| `renovate.json` | Remove HA customManager, registryAliases, and packageRule |
| `restore-all-pv-pvc.yaml` | Remove HA PVC section |

### 6.3 — Longhorn PVCs (after ~1 week of stable operation)

```bash
kubectl delete pvc home-assistant-home-assistant-0 -n home-assistant
kubectl delete pvc esphome -n home-assistant
kubectl delete namespace home-assistant
```

### 6.4 — Commit

```bash
git commit -m "chore: migrate HA stack from K8s to Docker Compose on worker

Home Assistant, ESPHome, and Mosquitto now run via Docker Compose on the
worker node with Caddy as reverse proxy. DNS rewrites in AdGuard point
ha.homelab and esphome.homelab directly to the worker.

Removed: ArgoCD apps, K8s manifests, HTTPRoutes, Renovate rules, GH workflow.
Updated: Homepage siteMonitor URLs, restore manifests."
```

---

## Rollback Plan

If Docker Compose setup fails at any point:

1. Re-enable ArgoCD auto-sync: `kubectl patch application home-assistant -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'`
2. Revert Cilium envoy nodeSelector change
3. Remove DNS rewrites for `ha.homelab` / `esphome.homelab` from AdGuard
4. K8s deployments come back automatically via ArgoCD self-heal
