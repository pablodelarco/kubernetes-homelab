# Prowlarr Games — dedicated NordVPN search

Private UI: `http://prowlarr-games.homelab:15000/`. Native Forms authentication
is mandatory, including local connections. The random admin credential is kept
only in `/home/pablo/questarr-retirement-evidence-20261026/private/prowlarr-games-admin.json`
(mode0600 under mode0700), not in Git, argv or chat. There is no port80 route,
Ingress, NodePort, LoadBalancer or Funnel exposure. Caddy port15000 accepts only
private/tailnet sources and explicitly rejects unknown/retired hosts.

Prowlarr 2.6.5.5623 uses the same original `media/prowlarr-questarr` PVC and API
key previously used by the retired Questarr sidecar. It runs as UID/GID1000,
read-only root/no capabilities, using the pinned LinuxServer publisher image.
Upstream Servarr does not publish an official Docker image. Gluetun is an
independent restartable init sidecar gating application startup. NordVPN,
DNS127.0.0.1 and IPv4/IPv6 OUTPUT DROP apply to all searches. The dedicated fixed
endpoint `ch352.nordvpn.com` may require reviewed maintenance if NordVPN retires
it. Never relax the firewall, use cluster DNS or borrow the production Byparr.

Two persisted indexers: LimeTorrents and The Pirate Bay. No solver, applications
or download clients configured. Interactive search only; no automatic
acquisition enabled. qBittorrent and the completed single-transfer monitor are
independent, untouched by this migration. This UI searches metadata; it is not
an automatically integrated game manager or permission to acquire other titles.

The old Questarr PVC remains Bound/Retain, unmounted and protected by Prune=false.
It is intentionally not renamed, wiped, copied into this volume or automatically
restarted. Never run two Prowlarr processes against the RWO config volume.

Rollback to the original loopback sidecar was exercised serially before final
retirement. Current acceptance includes real VPN search, direct-IP fail-closed
test with tun0 down, controlled recovery and equal config/key/indexers/PVC UID
after restart without configuration rewrites. Evidence and limits are in
`/home/pablo/questarr-retirement-evidence-20261026/REPORT.md`.
