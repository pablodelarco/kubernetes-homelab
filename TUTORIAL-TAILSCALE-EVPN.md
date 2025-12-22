# OpenNebula Edge Deployment with Tailscale + VXLAN/EVPN

A complete guide to deploying OpenNebula across geographically distributed nodes using Tailscale VPN and VXLAN with EVPN for VM networking. This tutorial follows the official OneDeploy documentation with specific adaptations for Tailscale overlay networks and ARM64 (Raspberry Pi) hosts.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Step 1: Install OneDeploy on Control Node](#step-1-install-onedeploy-on-control-node)
5. [Step 2: Configure Tailscale on All Nodes](#step-2-configure-tailscale-on-all-nodes)
6. [Step 3: Create Inventory File](#step-3-create-inventory-file)
7. [Step 4: Create Ansible Configuration](#step-4-create-ansible-configuration)
8. [Step 5: Verify Connectivity](#step-5-verify-connectivity)
9. [Step 6: Run the Playbooks](#step-6-run-the-playbooks)
10. [Step 7: Fix BGP Listen Range](#step-7-fix-bgp-listen-range)
11. [Step 8: Update VNM Configuration](#step-8-update-vnm-configuration)
12. [Step 9: Configure NAT and Routing](#step-9-configure-nat-and-routing)
13. [Step 10: Enable SSH Access via Tailscale](#step-10-enable-ssh-access-via-tailscale)
14. [Step 11: ARM64-Specific Configuration](#step-11-arm64-specific-configuration)
15. [Step 12: Access Sunstone UI](#step-12-access-sunstone-ui)
16. [Step 13: Verify Installation](#step-13-verify-installation)
17. [Step 14: Deploy a Test VM](#step-14-deploy-a-test-vm)
18. [Troubleshooting](#troubleshooting)
19. [Key Concepts](#key-concepts)
20. [Summary](#summary)

---

## Overview

**OneDeploy** is OpenNebula's official set of Ansible playbooks that allows you to automatically deploy an OpenNebula cloud. This tutorial extends the standard deployment to support:

- **Geographically distributed nodes** connected via Tailscale VPN
- **VXLAN/EVPN networking** (required because Tailscale doesn't support multicast)
- **ARM64 hosts** (Raspberry Pi) with all necessary firmware and driver configurations

### Why Tailscale + EVPN?

Standard VXLAN uses multicast to discover which host has which VM. Tailscale is a Layer 3 VPN that doesn't support multicast. EVPN (Ethernet VPN) solves this by using BGP (Border Gateway Protocol) to distribute MAC/IP information between nodes.

---

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Beelink      │     │  Raspberry Pi   │     │     Worker      │
│  100.113.23.108 │     │  100.105.211.96 │     │  100.96.103.31  │
│                 │     │                 │     │                 │
│  Control Node   │     │  Frontend +     │     │  Worker Node    │
│  BGP Route      │     │  Worker Node    │     │                 │
│  Reflector      │     │                 │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                         Tailscale VPN
                    (100.64.0.0/10 - CGNAT range)
                              │
                    ┌─────────┴─────────┐
                    │   VXLAN Overlay   │
                    │  (10.200.0.0/24)  │
                    │   VM Network      │
                    └───────────────────┘
```

**Components:**

| Node | Role | Tailscale IP |
|------|------|--------------|
| Beelink | Ansible control node + BGP Route Reflector | 100.113.23.108 |
| raspberrypi5 | OpenNebula Frontend + KVM Worker (ARM64) | 100.105.211.96 |
| worker | KVM Worker (ARM64) | 100.96.103.31 |

**Network Layers:**

- **Tailscale (Layer 3)**: Connects all nodes over the internet using WireGuard
- **VXLAN (Layer 2)**: Creates overlay network for VMs (10.200.0.0/24)
- **EVPN/BGP**: Control plane for VXLAN - distributes VM location information
- **FRR**: Free Range Routing daemon that runs BGP on each node

---

## Prerequisites

### Control Node (where you run Ansible)

- Ubuntu 22.04 or 24.04
- Python 3 with pip
- Git
- SSH access to all managed nodes

### Managed Nodes (Frontend and Workers)

- Ubuntu 22.04 or 24.04 with Netplan >= 0.105
- Passwordless SSH login as root from control node
- Tailscale installed and connected
- For ARM64: KVM support enabled in kernel

### Network Requirements

- All nodes must be on the same Tailscale network
- Tailscale IPs are in the 100.64.0.0/10 range (CGNAT)
- A subnet for VMs (e.g., 10.200.0.0/24) - this is virtual, not physical

---

## Step 1: Install OneDeploy on Control Node

On the control node (Beelink in our example):

```bash
# Install required packages
sudo apt update
sudo apt install -y python3-pip pipx git

# Install hatch (Python project manager)
pipx install hatch
pipx ensurepath
source ~/.bashrc

# Clone the one-deploy repository
git clone https://github.com/OpenNebula/one-deploy.git
cd one-deploy

# Install requirements (creates virtual environments)
make requirements

# Verify environments were created
hatch env show

# Enter the virtual environment
hatch shell
```

After entering the environment, your prompt should show `(one-deploy)`:
```
(one-deploy) user@beelink:~/one-deploy$
```

---

## Step 2: Configure Tailscale on All Nodes

Ensure Tailscale is installed and connected on all nodes:

```bash
# On each node (if not already installed)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Verify connectivity
tailscale status
```

Note the Tailscale IP for each node:
```bash
tailscale ip -4
```

---

## Step 3: Create Inventory File

Create the inventory directory and file:

```bash
cd ~/one-deploy
mkdir -p inventory
```

Create `inventory/edge-cluster.yml`:

```yaml
---
all:
  vars:
    ansible_user: root
    one_version: '7.0'
    one_pass: 'your-secure-password-here'
    ensure_hosts: true
    
    # EVPN - CRITICAL for Tailscale (no multicast support)
    features:
      evpn: true
    evpn_if: tailscale0
    
    # Datastore configuration (SSH mode for distributed nodes)
    ds:
      mode: ssh
    
    # VXLAN Virtual Network for VMs
    vn:
      edge_vxlan:
        managed: true
        template:
          VN_MAD: vxlan
          VXLAN_MODE: evpn
          VXLAN_TEP: local_ip
          IP_LINK_CONF: "nolearning=,dstport=4789"
          PHYDEV: tailscale0
          BRIDGE: br-edge
          VLAN_ID: 100
          FILTER_IP_SPOOFING: "NO"
          FILTER_MAC_SPOOFING: "YES"
          GUEST_MTU: 1200
          AR:
            TYPE: IP4
            IP: 10.200.0.10
            SIZE: 100
          NETWORK_ADDRESS: 10.200.0.0
          NETWORK_MASK: 255.255.255.0
          GATEWAY: 10.200.0.1
          DNS: 1.1.1.1

# BGP Route Reflector (separate from frontend/node)
router:
  hosts:
    beelink:
      ansible_host: 100.113.23.108

# OpenNebula Frontend
frontend:
  hosts:
    raspberrypi5:
      ansible_host: 100.105.211.96

# KVM Worker Nodes
node:
  hosts:
    raspberrypi5:
      ansible_host: 100.105.211.96
    worker:
      ansible_host: 100.96.103.31
```

### Key Parameters Explained

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `features.evpn: true` | Enable EVPN | Required for Tailscale (no multicast) |
| `evpn_if: tailscale0` | Tailscale interface | BGP peers over Tailscale IPs |
| `VXLAN_MODE: evpn` | EVPN mode | Use BGP instead of multicast |
| `VXLAN_TEP: local_ip` | Tunnel endpoint | Use Tailscale IP for VTEP |
| `IP_LINK_CONF: "nolearning=,dstport=4789"` | VXLAN options | Disable learning (EVPN handles it), use port 4789 (avoids conflict with K8s CNI on 8472) |
| `GUEST_MTU: 1200` | VM MTU | Reduced for VXLAN+Tailscale overhead |
| `ds.mode: ssh` | Datastore mode | Transfer images via SSH (no shared storage) |

> **Important**: The `router` group must be separate from `frontend`/`node` groups. BGP configuration differs between Route Reflectors and VTEP nodes.

---

## Step 4: Create Ansible Configuration

Create `inventory/ansible.cfg`:

```ini
[defaults]
inventory = ./edge-cluster.yml
gathering = explicit
host_key_checking = false
display_skipped_hosts = true
retry_files_enabled = false
any_errors_fatal = true
stdout_callback = yaml
timeout = 30

[ssh_connection]
pipelining = true
ssh_args = -q -o ControlMaster=auto -o ControlPersist=60s

[privilege_escalation]
become = true
become_user = root
```

---

## Step 5: Verify Connectivity

Test that Ansible can reach all nodes:

```bash
cd ~/one-deploy/inventory
ansible -i edge-cluster.yml all -m ping -b
```

Expected output:
```
beelink | SUCCESS => {
    "ping": "pong"
}
raspberrypi5 | SUCCESS => {
    "ping": "pong"
}
worker | SUCCESS => {
    "ping": "pong"
}
```

If any node fails, verify:
1. SSH keys are set up (`ssh-copy-id root@<node-ip>`)
2. Tailscale is connected on all nodes
3. Firewall allows SSH (port 22)

---

## Step 6: Run the Playbooks

From the `one-deploy` directory:

```bash
cd ~/one-deploy
hatch shell  # if not already in the environment

ansible-playbook -i inventory/edge-cluster.yml playbooks/site.yml -v
```

The deployment takes 10-20 minutes depending on network speed.

Successful output ends with:
```
PLAY RECAP *******************************************************************
beelink        : ok=XX   changed=XX   unreachable=0    failed=0
raspberrypi5   : ok=XX   changed=XX   unreachable=0    failed=0
worker         : ok=XX   changed=XX   unreachable=0    failed=0
```

---

## Step 7: Fix BGP Listen Range

The default BGP configuration uses a narrow IP range. Tailscale uses 100.64.0.0/10 (CGNAT range), so we need to expand it.

On the router node (beelink):

```bash
ssh root@100.113.23.108

# Check current BGP config
vtysh -c "show running-config" | grep -A5 "router bgp"

# Update listen range to include all Tailscale IPs
vtysh -c "configure terminal" \
      -c "router bgp 65000" \
      -c "no bgp listen range 100.113.23.0/24 peer-group ONEEVPN" \
      -c "bgp listen range 100.64.0.0/10 peer-group ONEEVPN" \
      -c "end" \
      -c "write memory"
```

Verify BGP peering:
```bash
vtysh -c "show bgp summary"
```

Expected output - all peers should show `Estab`:
```
Neighbor        V  AS    MsgRcvd  MsgSent  State/PfxRcd
*100.96.103.31  4  65000    100      100    Estab
*100.105.211.96 4  65000    100      100    Estab
```

---

## Step 8: Update VNM Configuration

Update the VXLAN configuration on the frontend:

```bash
ssh root@100.105.211.96

cat > /var/lib/one/remotes/etc/vnm/OpenNebulaNetwork.conf << 'EOF'
:vxlan_mode: evpn
:vxlan_tep: local_ip
:vxlan_mtu: 1500
:vxlan_ttl: 16
:ip_link_conf:
    :nolearning:
    :dstport: 4789
EOF

# Sync configuration to all workers
su - oneadmin -c "onehost sync -f"
```

---

## Step 9: Configure NAT and Routing

VMs need NAT to access the internet. Create a systemd service on **each worker node** that provides:
1. Gateway IP on the bridge
2. NAT (masquerade) for outbound traffic
3. Policy routing to prevent Tailscale from intercepting local VM traffic

### On each worker node:

```bash
# Create the NAT service
cat > /etc/systemd/system/opennebula-nat.service << 'EOF'
[Unit]
Description=OpenNebula NAT and routing for VMs
After=network.target tailscaled.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
  ip addr add 10.200.0.1/24 dev br-edge 2>/dev/null || true; \
  ip rule add to 10.200.0.0/24 lookup main priority 5200 2>/dev/null || true; \
  EXT_IF=$(ip route get 8.8.8.8 | grep -oP "dev \\K\\S+" | head -1); \
  iptables -I FORWARD 1 -i br-edge -o $EXT_IF -s 10.200.0.0/24 -j ACCEPT; \
  iptables -I FORWARD 2 -i $EXT_IF -o br-edge -d 10.200.0.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT; \
  iptables -t nat -C POSTROUTING -s 10.200.0.0/24 -o $EXT_IF -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.200.0.0/24 -o $EXT_IF -j MASQUERADE'

[Install]
WantedBy=multi-user.target
EOF

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-opennebula.conf
sysctl -p /etc/sysctl.d/99-opennebula.conf

# Enable and start the service
systemctl daemon-reload
systemctl enable opennebula-nat.service
systemctl start opennebula-nat.service

# Verify
ip addr show br-edge | grep 10.200.0.1
ip rule list | grep 5200
iptables -t nat -L POSTROUTING -n | grep MASQUERADE
```

### Why the Policy Routing Rule?

When you advertise `10.200.0.0/24` via Tailscale (Step 10), Tailscale adds it to its routing table (table 52) with priority ~5210-5270. Without the priority 5200 rule, even local traffic from the host to VMs would go through Tailscale instead of directly to br-edge.

---

## Step 10: Enable SSH Access via Tailscale

To SSH into VMs from any device on your Tailscale network, advertise the VM subnet:

On the **frontend node**:

```bash
# Advertise the VM subnet
tailscale set --advertise-routes=10.200.0.0/24

# Accept the route in Tailscale admin console or via CLI
# On other Tailscale devices, accept the route:
tailscale set --accept-routes
```

Now you can SSH to VMs from any Tailscale-connected device:
```bash
ssh root@10.200.0.11  # VM IP
```

---

## Step 11: ARM64-Specific Configuration

For Raspberry Pi or other ARM64 hosts, additional configuration is required.

### 11.1 UEFI Firmware (AAVMF)

ARM64 VMs require AAVMF (ARM Architecture Virtual Machine Firmware) instead of OVMF:

```bash
# On each ARM64 worker node
apt install -y qemu-efi-aarch64

# Create symlinks for OpenNebula
ln -sf /usr/share/AAVMF/AAVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd
ln -sf /usr/share/AAVMF/AAVMF_VARS.fd /usr/share/OVMF/OVMF_VARS.fd
```

### 11.2 VM Template Configuration

ARM64 VMs require specific settings. Create or update templates with:

```
# CPU Model (required for ARM64)
CPU_MODEL = [ MODEL="host" ]

# UEFI Firmware
OS = [
  ARCH = "aarch64",
  MACHINE = "virt",
  FIRMWARE = "/usr/share/AAVMF/AAVMF_CODE.fd",
  FIRMWARE_SECURE = "NO"
]

# VNC Keyboard (required for virt machine type)
INPUT = [
  BUS = "usb",
  TYPE = "keyboard"
]

# Graphics
GRAPHICS = [
  LISTEN = "0.0.0.0",
  TYPE = "VNC"
]
```

### 11.3 Update Existing Templates

To update all templates at once:

```bash
ssh root@100.105.211.96
su - oneadmin

# List templates
onetemplate list

# Update a specific template (replace ID)
onetemplate update <ID>
```

Add the ARM64-specific sections above to the template.

---

## Step 12: Access Sunstone UI

Sunstone is OpenNebula's web interface. Access it at:

```
http://<frontend-tailscale-ip>:2616
```

For our setup:
```
http://100.105.211.96:2616
```

Login credentials:
- **Username**: oneadmin
- **Password**: The value you set in `one_pass` in the inventory file

---

## Step 13: Verify Installation

### Check OpenNebula Services

On the frontend:
```bash
ssh root@100.105.211.96
systemctl status opennebula opennebula-sunstone opennebula-scheduler
```

### Check Hosts

```bash
su - oneadmin
onehost list
```

Expected output:
```
  ID NAME            CLUSTER   TVM   ALLOCATED_CPU      ALLOCATED_MEM STAT
   0 raspberrypi5    default     0       0 / 400 (0%)    0K / 7.6G (0%) on
   1 worker          default     0       0 / 400 (0%)    0K / 7.6G (0%) on
```

### Check Virtual Networks

```bash
onevnet list
```

Expected output:
```
  ID USER     GROUP    NAME       CLUSTERS   BRIDGE   STATE    LEASES
   0 oneadmin oneadmin edge_vxlan 0          br-edge  rdy           0
```

### Check BGP/EVPN Status

On the router (beelink):
```bash
vtysh -c "show bgp summary"
vtysh -c "show bgp l2vpn evpn"
```

---

## Step 14: Deploy a Test VM

### 14.1 Download an ARM64 Image

```bash
ssh root@100.105.211.96
su - oneadmin

# Download Ubuntu 22.04 ARM64 cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-arm64.img

# Create OpenNebula image
oneimage create --name "Ubuntu-22.04-ARM64" \
  --path ./jammy-server-cloudimg-arm64.img \
  --datastore default \
  --driver qcow2 \
  --prefix vd
```

Wait for the image to be ready:
```bash
oneimage list
# Wait until STATE is "rdy"
```

### 14.2 Create a VM Template

```bash
cat > /tmp/arm64-template.txt << 'EOF'
NAME = "Ubuntu-ARM64"
CPU = "1"
VCPU = "1"
MEMORY = "1024"

CPU_MODEL = [ MODEL="host" ]

OS = [
  ARCH = "aarch64",
  MACHINE = "virt",
  FIRMWARE = "/usr/share/AAVMF/AAVMF_CODE.fd",
  FIRMWARE_SECURE = "NO"
]

DISK = [
  IMAGE = "Ubuntu-22.04-ARM64",
  DEV_PREFIX = "vd"
]

NIC = [
  NETWORK = "edge_vxlan"
]

INPUT = [
  BUS = "usb",
  TYPE = "keyboard"
]

GRAPHICS = [
  LISTEN = "0.0.0.0",
  TYPE = "VNC"
]

CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]"
]
EOF

onetemplate create /tmp/arm64-template.txt
```

### 14.3 Add Your SSH Key

```bash
# Add your SSH public key to oneadmin user
oneuser update oneadmin
```

Add:
```
SSH_PUBLIC_KEY = "ssh-rsa AAAA... your-key-here"
```

### 14.4 Instantiate the VM

```bash
onetemplate instantiate "Ubuntu-ARM64" --name "test-vm"
```

### 14.5 Monitor VM Status

```bash
onevm list
onevm show <vm-id>
```

Wait for STATE to be `runn` (running).

### 14.6 Connect to the VM

```bash
# Get VM IP
onevm show <vm-id> | grep ETH0_IP

# SSH to VM (from any Tailscale device)
ssh ubuntu@10.200.0.11
```

---

## Troubleshooting

### VM Deployment Fails with "DEPLOY: vxlan: ExitCode: 2"

**Cause**: VXLAN multicast mode doesn't work with Tailscale.

**Solution**: Ensure EVPN mode is configured:
1. Check `VXLAN_MODE: evpn` in the virtual network
2. Verify BGP peering is established: `vtysh -c "show bgp summary"`
3. Check FRR is running on all nodes: `systemctl status frr`

### BGP Peers Not Establishing

**Cause**: Listen range doesn't include Tailscale IPs.

**Solution**: Update BGP listen range (Step 7):
```bash
vtysh -c "configure terminal" \
      -c "router bgp 65000" \
      -c "bgp listen range 100.64.0.0/10 peer-group ONEEVPN" \
      -c "end" \
      -c "write memory"
```

### SSH to VM Times Out (Tailscale Routing Conflict)

**Cause**: Tailscale intercepts traffic to 10.200.0.0/24 when you advertise routes.

**Solution**: Add policy routing rule (included in NAT service):
```bash
ip rule add to 10.200.0.0/24 lookup main priority 5200
```

This rule has higher priority (lower number) than Tailscale's table 52 rules.

### VM Has No Internet Access

**Cause**: NAT not configured or FORWARD rules missing.

**Solution**: Verify NAT service is running:
```bash
systemctl status opennebula-nat.service
iptables -t nat -L POSTROUTING -n | grep MASQUERADE
iptables -L FORWARD -n | grep 10.200.0.0
```

### VNC Keyboard Not Working

**Cause**: ARM64 with `virt` machine type requires virtio keyboard.

**Solution**: Add to VM template:
```
INPUT = [
  BUS = "usb",
  TYPE = "keyboard"
]
```

### VM Fails with "unsupported configuration: NVRAM is not supported"

**Cause**: OVMF_NVRAM pointing to x86 firmware on ARM64.

**Solution**: Remove OVMF_NVRAM from template or point to ARM64 NVRAM:
```
OS = [
  FIRMWARE = "/usr/share/AAVMF/AAVMF_CODE.fd",
  FIRMWARE_SECURE = "NO"
]
```

### VXLAN Port Conflict with Kubernetes

**Cause**: Default VXLAN port 8472 conflicts with Cilium CNI.

**Solution**: Use port 4789 in IP_LINK_CONF:
```
IP_LINK_CONF: "nolearning=,dstport=4789"
```

---

## Key Concepts

### EVPN (Ethernet VPN)

A BGP-based protocol that distributes Layer 2 (MAC addresses) and Layer 3 (IP addresses) information across a network. Required for VXLAN when multicast is not available.

### FRR (Free Range Routing)

Open-source routing software that runs BGP, OSPF, and other protocols. Installed on each node to share EVPN routes.

### Route Reflector

A BGP optimization that reduces the number of peer connections. Instead of full mesh (N×N connections), all nodes peer with the Route Reflector.

### VXLAN (Virtual eXtensible LAN)

Layer 2 overlay network encapsulated in UDP. Creates a virtual switch spanning multiple physical hosts.

### Tailscale

WireGuard-based mesh VPN that creates a secure overlay network. Uses the 100.64.0.0/10 CGNAT range for node IPs.

---

## Summary

| Component | Configuration |
|-----------|---------------|
| OpenNebula Version | 7.0 |
| Deployment Tool | OneDeploy (Ansible) |
| VPN Overlay | Tailscale |
| VM Network | VXLAN with EVPN |
| VXLAN Port | 4789 |
| VM Subnet | 10.200.0.0/24 |
| BGP AS Number | 65000 |
| BGP Listen Range | 100.64.0.0/10 |
| Datastore Mode | SSH |
| ARM64 Firmware | AAVMF |
| Sunstone Port | 2616 |

### Files Created

| File | Location | Purpose |
|------|----------|---------|
| Inventory | `~/one-deploy/inventory/edge-cluster.yml` | Ansible inventory |
| Ansible config | `~/one-deploy/inventory/ansible.cfg` | Ansible settings |
| NAT service | `/etc/systemd/system/opennebula-nat.service` | Persistent NAT/routing |
| VNM config | `/var/lib/one/remotes/etc/vnm/OpenNebulaNetwork.conf` | VXLAN settings |

### Quick Reference Commands

```bash
# Enter OneDeploy environment
cd ~/one-deploy && hatch shell

# Run deployment
ansible-playbook -i inventory/edge-cluster.yml playbooks/site.yml -v

# Check hosts
su - oneadmin -c "onehost list"

# Check VMs
su - oneadmin -c "onevm list"

# Check BGP
vtysh -c "show bgp summary"

# Check NAT
iptables -t nat -L POSTROUTING -n

# Check routing policy
ip rule list | grep 5200
```

---

*Last updated: December 2024*
