# 🚀 Kubernetes Homelab - Complete Applications Guide

> **Last Updated:** 2025-11-13  
> **Cluster:** kubernetes-homelab  
> **Nodes:** beelink (100.113.23.108), worker (100.96.103.31)

---

## 📑 Table of Contents

1. [Media Server Stack](#-media-server-stack)
2. [Infrastructure & Management](#-infrastructure--management)
3. [Monitoring & Observability](#-monitoring--observability)
4. [Home Automation](#-home-automation)
5. [Web Applications](#-web-applications)
6. [Background Services](#-background-services)
7. [Access Methods](#-access-methods)
8. [Quick Reference Table](#-quick-reference-table)

---

## 🎬 Media Server Stack

Complete media automation and streaming solution with VPN protection.

### **Jellyfin** - Media Streaming Server
**Purpose:** Stream movies, TV shows, and media content  
**Access:**
- 🌐 Tailscale: `https://jellyfin.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30096` or `http://100.96.103.31:30096`
- 📱 Apps: Available for iOS, Android, Roku, Fire TV, etc.

**Features:**
- Free alternative to Plex/Emby
- Hardware transcoding enabled
- WebSocket support for real-time updates
- Tailscale Funnel enabled (public internet access)

---

### **Radarr** - Movie Management
**Purpose:** Automated movie downloading and organization  
**Access:**
- 🌐 Tailscale: `https://radarr.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30100` or `http://100.96.103.31:30100`

**Features:**
- Automatic movie search and download
- Quality profiles and release monitoring
- Integration with Jackett for indexers
- VPN-protected via Gluetun sidecar

---

### **Sonarr** - TV Show Management
**Purpose:** Automated TV show downloading and organization  
**Access:**
- 🌐 Tailscale: `https://sonarr.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30101` or `http://100.96.103.31:30101`

**Features:**
- Episode tracking and automatic downloads
- Season monitoring
- Integration with Jackett for indexers
- Automatic renaming and organization

---

### **Bazarr** - Subtitle Management
**Purpose:** Automated subtitle downloading for movies and TV shows  
**Access:**
- 🌐 Tailscale: `https://bazarr.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30102` or `http://100.96.103.31:30102`

**Features:**
- Automatic subtitle search and download
- Multiple language support
- Integration with Radarr and Sonarr
- Subtitle synchronization

---

### **Jackett** - Indexer Proxy
**Purpose:** Torrent indexer aggregator for Radarr/Sonarr  
**Access:**
- 🌐 Tailscale: `https://jackett.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30103` or `http://100.96.103.31:30103`

**Features:**
- Unified API for multiple torrent sites
- VPN-protected via Gluetun HTTP proxy
- Automatic indexer updates

---

### **Jellyseerr** - Media Request Management
**Purpose:** User-friendly interface for requesting movies and TV shows  
**Access:**
- 🌐 Tailscale: `https://jellyseerr.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30104` or `http://100.96.103.31:30104`

**Features:**
- Beautiful UI for media requests
- User management and permissions
- Integration with Radarr and Sonarr
- Request approval workflow

---

### **qBittorrent** - Torrent Client
**Purpose:** Download torrents for media content  
**Access:**
- 🌐 Tailscale: `https://qbitt.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30105` or `http://100.96.103.31:30105`

**Features:**
- VPN-protected via Gluetun sidecar
- All traffic routed through VPN
- Automatic torrent management
- Integration with Radarr and Sonarr

---

### **Tdarr** - Media Transcoding
**Purpose:** Automated media file transcoding and optimization  
**Access:**
- 🌐 Tailscale: `https://tdarr.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30106` or `http://100.96.103.31:30106`

**Features:**
- Automated video/audio transcoding
- Hardware acceleration support
- Reduce storage usage
- Optimize files for streaming

---

### **Posterr** - Poster Management
**Purpose:** Automatically download and manage media posters  
**Access:** Internal service (no web UI)

**Features:**
- Automatic poster downloads
- Integration with Jellyfin
- High-quality artwork

---

### **Recyclarr** - Configuration Sync
**Purpose:** Sync TRaSH guides configurations to Radarr/Sonarr  
**Access:** CronJob (runs automatically)

**Features:**
- Automated quality profile updates
- Custom format synchronization
- Best practices from TRaSH guides

---

## 🛠️ Infrastructure & Management

### **ArgoCD** - GitOps Continuous Delivery
**Purpose:** Kubernetes application deployment and management
**Access:**
- 🌐 Tailscale: `https://argocd.tabby-carp.ts.net`
- 🔌 NodePort HTTP: `http://100.113.23.108:31938` or `http://100.96.103.31:31938`
- 🔌 NodePort HTTPS: `http://100.113.23.108:30355` or `http://100.96.103.31:30355`

**Features:**
- GitOps-based deployments
- Automatic synchronization from Git
- Application health monitoring
- Rollback capabilities

**Credentials:** Stored in sealed-secrets

---

### **Longhorn** - Distributed Block Storage
**Purpose:** Persistent storage for Kubernetes workloads  
**Access:**
- 🌐 Tailscale: `https://longhorn.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30300` or `http://100.96.103.31:30300`

**Features:**
- Distributed replicated storage
- Automatic backups to MinIO S3
- Volume snapshots and cloning
- Currently running v1.10.1

**Storage:**
- 19 attached volumes
- 2 replicas per volume
- Backup target: `s3://k8s-backups@us-east-1/`

---

### **MinIO** - S3-Compatible Object Storage
**Purpose:** Backup storage for Longhorn and other services
**Access:**
- 🌐 API: `https://minio.tabby-carp.ts.net`
- 🌐 Console: `https://minio-console.tabby-carp.ts.net`

**Features:**
- S3-compatible API
- Longhorn backup target
- High availability storage
- Web-based management console

**Buckets:**
- `k8s-backups` - Longhorn volume backups

---

### **Sealed Secrets** - Secret Management
**Purpose:** Encrypted secrets stored in Git
**Access:** No web UI (CLI only)

**Features:**
- Encrypt secrets before committing to Git
- Automatic decryption in cluster
- GitOps-friendly secret management

---

### **Renovate** - Dependency Updates
**Purpose:** Automated dependency and version updates
**Access:** CronJob (runs automatically)

**Features:**
- Automatic Helm chart updates
- Docker image updates
- Creates PRs for review
- Configured for Longhorn phased upgrades

**Schedule:** Runs periodically to check for updates

---

### **ArgoCD Image Updater** - Container Image Updates
**Purpose:** Automated container image updates for ArgoCD apps
**Access:** No web UI (automatic service)

**Features:**
- Monitors container registries
- Updates image tags automatically
- Integration with ArgoCD
- Sync interval: 168h (1 week)

---

### **Traefik** - Ingress Controller
**Purpose:** HTTP/HTTPS routing and load balancing
**Access:**
- 🔌 NodePort HTTP: `http://100.113.23.108:30209` or `http://100.96.103.31:30209`
- 🔌 NodePort HTTPS: `http://100.113.23.108:31044` or `http://100.96.103.31:31044`

**Features:**
- Automatic HTTPS with Let's Encrypt
- Tailscale ingress integration
- Dynamic configuration
- WebSocket support

---

## 📊 Monitoring & Observability

### **Grafana** - Metrics Visualization
**Purpose:** Dashboards and metrics visualization
**Access:**
- 🌐 Tailscale: `https://grafana.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30200` or `http://100.96.103.31:30200`

**Features:**
- Pre-built Kubernetes dashboards
- Prometheus data source
- Alerting capabilities
- Custom dashboard creation

**Default Dashboards:**
- Kubernetes cluster monitoring
- Node metrics
- Pod resource usage
- Longhorn storage metrics

---

### **Prometheus** - Metrics Collection
**Purpose:** Time-series metrics database
**Access:** Internal service (accessed via Grafana)

**Features:**
- Automatic service discovery
- Kubernetes metrics collection
- Long-term metrics storage
- PromQL query language

---

### **OpenCost** - Kubernetes Cost Monitoring
**Purpose:** Track and analyze Kubernetes resource costs
**Access:**
- 🌐 Tailscale: `https://opencost.tabby-carp.ts.net`

**Features:**
- Real-time cost monitoring
- Resource allocation tracking
- Cost breakdown by namespace/pod
- Budget alerts

---

### **Uptime Kuma** - Uptime Monitoring
**Purpose:** Monitor service availability and uptime
**Access:**
- 🌐 Tailscale: `https://uptime-kuma.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30500` or `http://100.96.103.31:30500`

**Features:**
- Service health monitoring
- Status page
- Notifications (email, Slack, etc.)
- Response time tracking

---

## 🏠 Home Automation

### **Home Assistant** - Smart Home Hub
**Purpose:** Home automation and IoT device management
**Access:**
- 🌐 Tailscale: `https://home-assistant.tabby-carp.ts.net`
- 🔌 NodePort: `http://100.113.23.108:30400` or `http://100.96.103.31:30400`
- 🔌 Code Server: `http://100.113.23.108:30212` or `http://100.96.103.31:30212`

**Features:**
- Smart home device integration
- Automation rules
- Voice assistant integration
- Mobile app support

**Code Server:** Built-in VS Code for configuration editing

---

### **EMQX** - MQTT Broker
**Purpose:** Message broker for IoT devices
**Access:**
- 🌐 Dashboard: `https://emqx.tabby-carp.ts.net`
- 🔌 MQTT: `100.113.23.108:30486` or `100.96.103.31:30486`
- 🔌 WebSocket: `100.113.23.108:30996` or `100.96.103.31:30996`
- 🔌 Dashboard NodePort: `http://100.113.23.108:31951` or `http://100.96.103.31:31951`

**Features:**
- High-performance MQTT broker
- Web-based dashboard
- Client management
- Message monitoring

**Protocol:** MQTT v3.1.1 and v5.0

---

## 🌐 Web Applications

### **Homepage** - Dashboard
**Purpose:** Unified dashboard for all services
**Access:**
- 🌐 Tailscale: `https://homepage.tabby-carp.ts.net`

**Features:**
- Single pane of glass for all services
- Service status monitoring
- Quick links to all applications
- Customizable widgets

---

### **roomiorentals.com** - Rental Platform
**Purpose:** Room rental web application
**Environments:**

#### **Production**
- 🌐 URL: `https://roomiorentals.com`
- Status: ⚠️ **OAuth Issue** (Supabase project not found)

#### **Staging**
- 🌐 URL: `https://staging.roomiorentals.com`
- Status: ⚠️ **OAuth Issue** (Supabase project not found)

#### **Development**
- 🌐 URL: `https://dev.roomiorentals.com`
- Status: ⚠️ **OAuth Issue** (Supabase project not found)

**Known Issues:**
- Google OAuth login fails (Supabase project `tddfubdbrmcteclrpnfv.supabase.co` does not exist)
- Frontend JavaScript has hardcoded Supabase URL

---

## 🔧 Background Services

### **Cilium** - Container Networking
**Purpose:** Kubernetes networking and security
**Access:** No web UI (system service)

**Features:**
- eBPF-based networking
- Network policies
- Service mesh capabilities
- Hubble observability

---

## 🔐 Access Methods

Your cluster supports **three access methods** for services:

### **1. Tailscale Ingress (Recommended)**
- **URL Pattern:** `https://<service>.tabby-carp.ts.net`
- **Security:** Encrypted via Tailscale mesh VPN
- **Access:** From anywhere on your Tailscale network
- **Funnel:** Jellyfin has public internet access enabled

**Example:** `https://radarr.tabby-carp.ts.net`

---

### **2. NodePort (Direct Node Access)**
- **URL Pattern:** `http://<node-ip>:<nodeport>`
- **Node IPs:**
  - `100.113.23.108` (beelink)
  - `100.96.103.31` (worker)
- **Access:** Direct access to any node in the cluster

**Example:** `http://100.113.23.108:30100` (Radarr on beelink)

---

### **3. Local Network Access (LAN)**
- **URL Pattern:** `http://192.168.1.X:<nodeport>` or `http://<node-local-ip>:<nodeport>`
- **Access:** From local network (192.168.1.x)
- **Note:** All services use NodePort for consistent access across networks

**Example:** `http://192.168.1.232:30400` (Home Assistant via LAN)

---

## 📋 Quick Reference Table

### **Media Services**

| Service | Category | Tailscale URL | NodePort | LoadBalancer |
|---------|----------|---------------|----------|--------------|
| **Jellyfin** | Streaming | `https://jellyfin.tabby-carp.ts.net` | `:30096` | - |
| **Radarr** | Movies | `https://radarr.tabby-carp.ts.net` | `:30100` | - |
| **Sonarr** | TV Shows | `https://sonarr.tabby-carp.ts.net` | `:30101` | - |
| **Bazarr** | Subtitles | `https://bazarr.tabby-carp.ts.net` | `:30102` | - |
| **Jackett** | Indexers | `https://jackett.tabby-carp.ts.net` | `:30103` | - |
| **Jellyseerr** | Requests | `https://jellyseerr.tabby-carp.ts.net` | `:30104` | - |
| **qBittorrent** | Downloads | `https://qbitt.tabby-carp.ts.net` | `:30105` | - |
| **Tdarr** | Transcoding | `https://tdarr.tabby-carp.ts.net` | `:30106` | - |

### **Infrastructure Services**

| Service | Category | Tailscale URL | NodePort |
|---------|----------|---------------|----------|
| **ArgoCD** | GitOps | `https://argocd.tabby-carp.ts.net` | `:31938` (HTTP), `:30355` (HTTPS) |
| **Longhorn** | Storage | `https://longhorn.tabby-carp.ts.net` | `:30300` |
| **MinIO API** | S3 Storage | `https://minio.tabby-carp.ts.net` | - |
| **MinIO Console** | S3 UI | `https://minio-console.tabby-carp.ts.net` | - |
| **Traefik** | Ingress | - | `:30209` (HTTP), `:31044` (HTTPS) |

### **Monitoring Services**

| Service | Category | Tailscale URL | NodePort |
|---------|----------|---------------|----------|
| **Grafana** | Dashboards | `https://grafana.tabby-carp.ts.net` | `:30200` |
| **OpenCost** | Cost Tracking | `https://opencost.tabby-carp.ts.net` | - |
| **Uptime Kuma** | Uptime | `https://uptime-kuma.tabby-carp.ts.net` | `:30500` |

### **Home Automation Services**

| Service | Category | Tailscale URL | NodePort |
|---------|----------|---------------|----------|
| **Home Assistant** | Smart Home | `https://home-assistant.tabby-carp.ts.net` | `:30400` |
| **Home Assistant Code** | Config Editor | - | `:30212` |
| **EMQX Dashboard** | MQTT UI | `https://emqx.tabby-carp.ts.net` | `:31951` |
| **EMQX MQTT** | MQTT Broker | - | `:30486` |
| **EMQX WebSocket** | MQTT WS | - | `:30996` |

### **Web Applications**

| Service | Category | URL | Status |
|---------|----------|-----|--------|
| **Homepage** | Dashboard | `https://homepage.tabby-carp.ts.net` | ✅ Healthy |
| **roomiorentals.com** | Rental Platform | `https://roomiorentals.com` | ⚠️ OAuth Issue |
| **staging.roomiorentals.com** | Staging | `https://staging.roomiorentals.com` | ⚠️ OAuth Issue |
| **dev.roomiorentals.com** | Development | `https://dev.roomiorentals.com` | ⚠️ OAuth Issue |

---

## 🔑 Default Credentials

Most services use credentials stored in Kubernetes Sealed Secrets. To retrieve credentials:

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Get Grafana admin password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Get MinIO credentials
kubectl get secret -n minio minio-credentials -o jsonpath="{.data.accesskey}" | base64 -d
kubectl get secret -n minio minio-credentials -o jsonpath="{.data.secretkey}" | base64 -d
```

---

## 🌐 Network Architecture

### **Cluster Nodes**

| Node | Role | Tailscale IP | Internal IP |
|------|------|--------------|-------------|
| **beelink** | Control Plane + Worker | `100.113.23.108` | `192.168.1.x` |
| **worker** | Worker | `100.96.103.31` | `192.168.1.x` |

### **Network Flow**

```
Internet
   ↓
Tailscale Funnel (Jellyfin only)
   ↓
Tailscale Mesh Network (tabby-carp.ts.net)
   ↓
Traefik Ingress Controller (192.168.1.233)
   ↓
Kubernetes Services
   ↓
Pods (with Cilium networking)
```

### **VPN Architecture (Media Stack)**

```
External Traffic (Radarr, qBittorrent, Jackett)
   ↓
Gluetun VPN Sidecar
   ↓
VPN Server (encrypted tunnel)
   ↓
Internet

Internal Traffic (Jellyfin, Sonarr, etc.)
   ↓
Direct Cluster Network
   ↓
Cilium CNI
```

---

## 📦 Storage Architecture

### **Longhorn Distributed Storage**

- **Total Volumes:** 19 attached, 1 detached
- **Replication:** 2 replicas per volume (across beelink and worker)
- **Backup Target:** MinIO S3 (`s3://k8s-backups@us-east-1/`)
- **Version:** v1.10.1

### **NFS Mounts (Media)**

| Mount Point | Purpose | Source |
|-------------|---------|--------|
| `/data/media` | Media library | Synology NAS `/volume1/media_player` |
| `/data/temp` | Download staging | Synology NAS `/volume1/media_player/temp` |

---

## 🚀 Quick Start Guide

### **Accessing Services**

1. **Join Tailscale Network:**
   - Install Tailscale on your device
   - Join the `tabby-carp` network
   - Access any service via `https://<service>.tabby-carp.ts.net`

2. **Using NodePort (Advanced):**
   ```bash
   # Access Radarr on beelink node
   curl http://100.113.23.108:30100

   # Access Grafana on worker node
   curl http://100.96.103.31:30200
   ```

3. **Local Network Access:**
   ```bash
   # Access ArgoCD
   open http://192.168.1.235

   # Access Home Assistant
   open http://192.168.1.230
   ```

### **Common Tasks**

#### **Request a Movie**
1. Go to `https://jellyseerr.tabby-carp.ts.net`
2. Search for movie
3. Click "Request"
4. Radarr automatically searches and downloads
5. Watch in Jellyfin when ready

#### **Monitor Cluster Health**
1. Go to `https://grafana.tabby-carp.ts.net`
2. View Kubernetes dashboards
3. Check resource usage and alerts

#### **Check Storage**
1. Go to `https://longhorn.tabby-carp.ts.net`
2. View volume health
3. Check backup status

#### **Deploy New Application**
1. Add manifest to Git repository
2. Create ArgoCD Application in `argocd-apps/`
3. Commit and push
4. ArgoCD automatically syncs

---

## 🔧 Troubleshooting

### **Service Not Accessible**

1. **Check Pod Status:**
   ```bash
   kubectl get pods -n <namespace>
   ```

2. **Check Service:**
   ```bash
   kubectl get svc -n <namespace>
   ```

3. **Check Ingress:**
   ```bash
   kubectl get ingress -n <namespace>
   ```

4. **Check ArgoCD Sync:**
   ```bash
   kubectl get applications -n argocd
   ```

### **Storage Issues**

1. **Check Longhorn Volumes:**
   ```bash
   kubectl get volumes -n longhorn-system
   ```

2. **Check PVC Status:**
   ```bash
   kubectl get pvc -n <namespace>
   ```

### **Network Issues**

1. **Check Tailscale Status:**
   ```bash
   kubectl get pods -n kube-system | grep tailscale
   ```

2. **Check Traefik:**
   ```bash
   kubectl get pods -n kube-system | grep traefik
   ```

---

## 📚 Additional Documentation

- **Media Stack Interconnection:** `docs/MEDIA-STACK-INTERCONNECTION.md`
- **API Quick Reference:** `docs/API-QUICK-REFERENCE.md`
- **Simple Workflow Guide:** `docs/SIMPLE-WORKFLOW.md`
- **Longhorn Auto-Update:** `docs/LONGHORN-AUTO-UPDATE.md`

---

## 🎯 Summary

Your Kubernetes homelab cluster runs **27 applications** across **6 categories**:

- **8 Media Services** - Complete media automation stack
- **7 Infrastructure Services** - GitOps, storage, networking
- **3 Monitoring Services** - Metrics, costs, uptime
- **4 Home Automation Services** - Smart home and IoT
- **4 Web Applications** - Dashboard and rental platform
- **1 Background Service** - Networking (Cilium)

**Total Pods Running:** ~50+ pods across all namespaces
**Storage:** 19 Longhorn volumes with 2x replication
**Networking:** Tailscale mesh + Cilium CNI
**GitOps:** Fully automated via ArgoCD

---

**🎉 Happy Homelabbing!**


