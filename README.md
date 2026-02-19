# 🏠 Kubernetes Homelab

Welcome to my Kubernetes Homelab repository! This is where I document my journey with cloud-native technologies and self-hosting applications. This homelab is more than a playground — it's a platform where I explore ideas, automate workflows, and solve complex challenges while having fun.

As a **Cloud Solutions Architect**, Kubernetes is part of my daily toolkit. This homelab represents my passion for learning and experimenting with technology, focusing on scalability, backup strategies, and operational simplicity.

---

## 🚀 Why a Homelab?

1. **Learning by Doing**: By self-hosting, I tackle the complexities of deploying and managing real-world applications.
2. **All-in-One Environment**: This Kubernetes cluster manages all the applications of my home setup, serving as a single, integrated environment for testing, developing, and automating cloud-native workflows.

---

## 🏗️ Architecture

```
                        Tailscale Mesh (WireGuard)
                                  |
                           +-----------+
                           |  AdGuard  |
                           |   DNS     |
                           +-----------+
                                  |
                    +-------------+-------------+
                    |                           |
            +-------+-------+          +--------+--------+
            |   beelink     |          |     worker      |
            | control-plane |          |   worker node   |
            |   N100 16GB   |          |   N100 16GB     |
            +-------+-------+          +--------+--------+
                    |                           |
            ArgoCD, Cert-Manager       Media, Monitoring
            MetalLB, Sealed Secrets    Home Automation
            Cilium Gateway             Longhorn data plane
                    |                           |
                    +--------+  +---------------+
                             |  |
                        +---------+       +-----------+
                        | Longhorn|       | UGREEN &  |
                        | (block) |       | Synology  |
                        +---------+       | NAS (NFS) |
                                          +-----------+
```

---

## 🖥️ Hardware

To keep things simple yet powerful, the homelab runs on two **Beelink Mini S12 Pro** mini PCs — low power consumption (~10W each) and fanless-quiet operation.

| Node | Role | CPU | RAM | Storage |
|------|------|-----|-----|---------|
| beelink | control-plane + worker | Intel N100 (4C/4T) | 16 GB DDR4 | 500 GB NVMe |
| worker | worker | Intel N100 (4C/4T) | 16 GB DDR4 | 500 GB NVMe |

---

## 🔧 Tech Stack

| Category | Tools |
|----------|-------|
| Platform | K3s |
| GitOps | ArgoCD, ArgoCD Image Updater, Renovate |
| Networking | Cilium (CNI + Gateway API), MetalLB (L2), Tailscale (mesh VPN) |
| Storage | Longhorn (distributed block), Garage (S3-compatible), NFS (NAS) |
| Monitoring | Prometheus, Grafana, Alertmanager, Uptime Kuma, Glances, OpenCost |
| Security | Sealed Secrets, cert-manager (Let's Encrypt), AdGuard Home (DNS) |

---

## 📦 Applications

The homelab runs a variety of applications, deployed using Kubernetes and managed declaratively through GitOps. Some services run on Docker and are exposed through the Kubernetes Gateway API.

### Kubernetes-managed

| App | Category | Description |
|-----|----------|-------------|
| Jellyfin | Media | Media streaming server |
| Radarr | Media | Movie automation |
| Jellyseerr | Media | Media request management |
| qBittorrent | Media | Torrent client |
| Bazarr | Media | Subtitle automation |
| Jackett | Media | Torrent indexer proxy |
| Flaresolverr | Media | Cloudflare bypass for indexers |
| AdGuard Home | Infrastructure | DNS server + ad blocking |
| Homepage | Infrastructure | Homelab dashboard |
| n8n | Automation | Workflow automation |
| Grafana | Monitoring | Dashboards and visualization |
| Prometheus | Monitoring | Metrics collection and alerting |
| Uptime Kuma | Monitoring | Service uptime monitoring |
| Glances | Monitoring | Node system monitoring |
| OpenCost | Monitoring | Kubernetes cost analysis |
| Longhorn | Storage | Distributed block storage |
| Garage | Storage | S3-compatible object storage |
| ArgoCD | Platform | GitOps continuous delivery |
| Renovate | Platform | Dependency update automation |
| Sealed Secrets | Platform | Encrypted secrets in Git |

### Docker-managed (external services via Gateway API)

| App | Category | Description |
|-----|----------|-------------|
| Home Assistant | Home Automation | Smart home control |
| Zigbee2MQTT | Home Automation | Zigbee device bridge |
| ESPHome | Home Automation | IoT device firmware |
| Stremio | Media | Streaming aggregator |

---

## 📂 Repository Structure

```
.
├── apps/                       # Application manifests
│   ├── adguard-home/           #   DNS + ad blocking
│   ├── argocd-image-updater/   #   Container image auto-updates
│   ├── garage/                 #   S3-compatible object storage
│   ├── glances/                #   System monitoring DaemonSet
│   ├── homepage/               #   Dashboard
│   ├── kube-prometheus-stack/  #   Prometheus + Grafana + Alertmanager
│   ├── longhorn/               #   Distributed block storage
│   ├── media-server/           #   Jellyfin, Radarr, Bazarr, qBitt, etc.
│   ├── n8n/                    #   Workflow automation
│   ├── opencost/               #   Cost monitoring
│   ├── renovate/               #   Dependency updates
│   ├── system/                 #   System tuning (inotify, etc.)
│   └── uptime-kuma/            #   Uptime monitoring
├── argocd-apps/                # ArgoCD Application resources
├── cluster/                    # Cluster-wide configuration
│   ├── cert-manager/           #   Let's Encrypt issuers
│   ├── cilium/                 #   CNI configuration
│   ├── cilium-gateway/         #   Gateway API routes
│   ├── sealed-secrets/         #   Sealed Secrets controller
│   ├── metallb-config.yaml     #   Load balancer IP pool
│   ├── namespaces.yaml         #   Namespace definitions
│   └── rbac.yaml               #   RBAC policies
├── docs/                       # Documentation
│   ├── media/                  #   Media stack guides
│   └── capi/                   #   Cluster API references
├── scripts/                    # Operational scripts
│   └── restore/                #   Longhorn backup restore manifests
└── renovate.json               # Renovate bot configuration
```

---

## 🌐 Networking

- **Tailscale** mesh connects both nodes and provides remote access via WireGuard VPN.
- **Cilium** serves as CNI and provides Gateway API for HTTP routing (`.homelab` domains).
- **MetalLB** assigns IPs from a local L2 pool (`10.10.1.230-250`).
- **AdGuard Home** provides DNS resolution for `*.homelab` domains and ad blocking.
- Docker services (Home Assistant, ESPHome, Zigbee2MQTT) are exposed through Kubernetes Gateway API via external Service/Endpoints.

---

## 💾 Backup Strategy

- **Longhorn** snapshots replicate volumes across both nodes.
- **Garage** (S3) stores off-cluster Longhorn backups.
- **UGREEN NAS** provides NFS-mounted media storage.
- **Synology NAS** mirrors critical data as secondary backup.
- Restore manifests in `scripts/restore/` for disaster recovery.

---

## 🔄 GitOps Workflow

```
GitHub repo ──> ArgoCD (auto-sync) ──> Kubernetes cluster
     │                                        │
     ├── Renovate (dependency PRs)            │
     └── Image Updater (new tags) ────────────┘
```

1. All cluster state is declared in this repository.
2. **ArgoCD** watches the repo and auto-syncs changes to the cluster.
3. **ArgoCD Image Updater** detects new container image tags and commits updates.
4. **Renovate** opens PRs for Helm chart and dependency updates.
5. **Sealed Secrets** allows encrypted secrets to be stored safely in Git.

---

## 📈 Goals

- **Deepen Kubernetes Knowledge**: Dive deep into advanced Kubernetes concepts, such as networking, GitOps, and federation.
- **Enhance Resilience**: Design a self-hosted environment with reliable backups and minimal downtime.
- **Share Knowledge**: Document my progress and learnings to help others interested in setting up their own homelab.

---

## 📄 License

See [LICENSE](LICENSE).
