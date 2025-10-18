# Distributed Kubernetes Cluster Setup

This document describes the configuration for running a distributed Kubernetes cluster across Tailscale mesh network.

## Overview

Our cluster uses **VXLAN overlay networking** to enable nodes on different physical networks to communicate as if they were on the same network. This allows for:

- Nodes in different locations (home, cloud, office)
- Secure communication via Tailscale's encrypted mesh
- Geographic distribution for resilience
- Flexible node placement

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Tailscale Mesh Network                    │
│                  (Encrypted, Global, Secure)                 │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  Master (beelink)│         │  Worker          │         │
│  │  100.113.23.108  │◄───────►│  100.96.103.31   │         │
│  │                  │  VXLAN  │                  │         │
│  │  Pod CIDR:       │  Tunnel │  Pod CIDR:       │         │
│  │  10.42.0.0/24    │         │  10.42.1.0/24    │         │
│  └──────────────────┘         └──────────────────┘         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Network Configuration

### IP Ranges

| Network | CIDR | Purpose |
|---------|------|---------|
| Pod Network | `10.42.0.0/16` | Pod IPs across all nodes |
| Service Network | `10.43.0.0/16` | Kubernetes service ClusterIPs |
| Tailscale | `100.64.0.0/10` | Node IPs (CGNAT range) |

### Node Configuration

#### Master Node (beelink)
- **Tailscale IP**: `100.113.23.108`
- **Pod CIDR**: `10.42.0.0/24`
- **Role**: Control plane + worker

#### Worker Node
- **Tailscale IP**: `100.96.103.31`
- **Pod CIDR**: `10.42.1.0/24`
- **Role**: Worker

## Cilium Configuration

Cilium is configured for **VXLAN tunnel mode** to support distributed nodes.

### Key Settings

```yaml
routingMode: tunnel              # Use overlay networking
tunnelProtocol: vxlan            # VXLAN encapsulation
autoDirectNodeRoutes: false      # Don't assume same L2 network
enableIPv4Masquerade: true       # NAT for cross-node traffic
```

### Helm Installation

```bash
helm upgrade cilium cilium/cilium \
  -n kube-system \
  -f cilium-values-vxlan.yaml
```

See `cilium-values-vxlan.yaml` for full configuration.

## K3s Node Configuration

### Master Node

File: `/etc/rancher/k3s/config.yaml`

```yaml
# Master uses Tailscale IP for API server
node-ip: 100.113.23.108
cluster-init: true
disable:
  - traefik  # Using custom ingress
flannel-backend: none  # Using Cilium instead
disable-network-policy: true
```

### Worker Node

File: `/etc/rancher/k3s/config.yaml`

```yaml
# Worker connects to master via Tailscale
server: https://100.113.23.108:6443
token: <K3S_TOKEN>
node-ip: 100.96.103.31  # Worker's Tailscale IP
```

**Important**: The worker MUST use its Tailscale IP (`100.96.103.31`) for the distributed cluster to work with VXLAN.

## VXLAN Details

### Interface

Each node has a `cilium_vxlan` interface:

```bash
# View VXLAN interface
sudo ip -d link show cilium_vxlan
```

Output:
```
cilium_vxlan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1280
    vxlan external id 0 srcport 0 0 dstport 8472
```

### Traffic Flow

1. Pod on master (`10.42.0.x`) sends packet to pod on worker (`10.42.1.x`)
2. Cilium BPF program intercepts packet
3. Packet is encapsulated in VXLAN (UDP port 8472)
4. Outer IP header: `100.113.23.108` → `100.96.103.31`
5. Packet travels through Tailscale (encrypted)
6. Worker receives VXLAN packet
7. Cilium unwraps and delivers to destination pod

### MTU Considerations

- **Standard MTU**: 1500 bytes
- **VXLAN MTU**: 1280 bytes (reduced to fit VXLAN + Tailscale headers)
- **Overhead**: ~220 bytes (VXLAN header + Tailscale/WireGuard encryption)

## Verification

### Check Node IPs

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME      INTERNAL-IP      EXTERNAL-IP
beelink   100.113.23.108   <none>
worker    100.96.103.31    <none>
```

### Check Cilium Status

```bash
kubectl exec -n kube-system cilium-xxxxx -- cilium status | grep Routing
```

Expected output:
```
Routing:  Network: Tunnel [vxlan]   Host: BPF
```

### Test Cross-Node Communication

```bash
# Create test pods on each node
kubectl run test-master --image=nginx --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"beelink"}}}'
kubectl run test-worker --image=nginx --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"worker"}}}'

# Get worker pod IP
WORKER_IP=$(kubectl get pod test-worker -o jsonpath='{.status.podIP}')

# Test connectivity from master pod
kubectl exec test-master -- curl -s -m 5 http://$WORKER_IP

# Cleanup
kubectl delete pod test-master test-worker
```

## Troubleshooting

### Pods can't communicate across nodes

1. Check Cilium is in tunnel mode:
   ```bash
   kubectl exec -n kube-system cilium-xxxxx -- cilium status
   ```

2. Verify VXLAN interface exists:
   ```bash
   sudo ip link show cilium_vxlan
   ```

3. Check Cilium logs:
   ```bash
   kubectl logs -n kube-system -l k8s-app=cilium
   ```

### DNS not working

1. Check CoreDNS pods are running:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   ```

2. Test DNS resolution:
   ```bash
   kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default
   ```

### Node shows wrong IP

If a node shows local IP instead of Tailscale IP:

1. Edit `/etc/rancher/k3s/config.yaml` on the node
2. Set `node-ip: <TAILSCALE_IP>`
3. Restart k3s:
   ```bash
   sudo systemctl restart k3s-agent  # On worker
   sudo systemctl restart k3s        # On master
   ```

## Adding New Nodes

To add a new node to the distributed cluster:

1. Install Tailscale on the new node
2. Get the node's Tailscale IP: `tailscale ip -4`
3. Install k3s agent:
   ```bash
   curl -sfL https://get.k3s.io | K3S_URL=https://100.113.23.108:6443 \
     K3S_TOKEN=<TOKEN> \
     INSTALL_K3S_EXEC="--node-ip <NEW_NODE_TAILSCALE_IP>" \
     sh -
   ```
4. Verify node joined: `kubectl get nodes`

## Maintenance

### Updating Cilium

When updating Cilium, always use the VXLAN values file:

```bash
helm upgrade cilium cilium/cilium \
  -n kube-system \
  -f cilium-values-vxlan.yaml
```

**Never** run `helm upgrade` without the values file, or it will revert to native routing mode!

### Backing Up Configuration

Important files to backup:
- `/etc/rancher/k3s/config.yaml` (on all nodes)
- `cilium-values-vxlan.yaml` (Helm values)
- K3s token: `sudo cat /var/lib/rancher/k3s/server/node-token`

## References

- [Cilium VXLAN Documentation](https://docs.cilium.io/en/stable/network/concepts/routing/#vxlan-overlay)
- [K3s Networking](https://docs.k3s.io/networking)
- [Tailscale Kubernetes Guide](https://tailscale.com/kb/1185/kubernetes)

