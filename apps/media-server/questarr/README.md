# Questarr and dedicated Prowlarr

Questarr v1.5.0 and Prowlarr 2.6.5.5623 share this pod's **dedicated NordVPN** network namespace. The restartable Gluetun init container gates startup; the app containers have no capabilities, UID/GID1000 and read-only roots. DNS is exclusively 127.0.0.1, resolved by Gluetun; outbound IPv4/IPv6 default DROP. No external indexer solver is configured.

- Questarr private access: `http://questarr.homelab:15000/`, authenticated API. Never expose via port80 or the existing Funnel.
- Prowlarr binds **127.0.0.1:9696** only. No Service/Ingress/UI proxy. API requests require its own generated key. Authentication method External is only appropriate because no external UI route exists.
- Prowlarr has a separate 2Gi Longhorn PVC `prowlarr-questarr`, two replicas, `Prune=false`. Never share the productive Prowlarr data volume.
- Upstream Prowlarr explicitly publishes no official Docker image; this uses the LinuxServer publisher image linked by the official Servarr installation guide, fixed to version and OCI digest. The application binary version was authenticated through its API. No custom image build.
- Run the publisher's `/app/prowlarr/bin/Prowlarr -nobrowser -data=/config` directly as UID1000 instead of the s6/root initialization wrapper. Only its dedicated /config and /tmp are writable. Upgrades are GitOps-owned, not self-updates.

## Configuration on the PVCs

The fresh Prowlarr has only LimeTorrents and The Pirate Bay, copied from authenticated read-only configuration of the existing service. It has no applications, download clients or proxies. Its Standard profile explicitly disables RSS and automatic search and enables interactive search only. Questarr's Prowlarr sync points at `http://127.0.0.1:9696`; generated credentials are persisted privately, not in Git. Its two Torznab indexers have no category filter, avoiding the game's nonstandard console mapping being excluded.

Questarr retains `autoSearchEnabled=false`, `autoDownloadEnabled=false`, RSS feeds disabled, no games, no downloaders and no downloads. Do not add qBittorrent, automate or acquire a game without separate authorization. Existing Prowlarr/Byparr and media workloads remain independent and unchanged.

## Verified acceptance

Evidence: `/home/pablo/questarr-prowlarr-evidence-20261026/REPORT.md` (sensitive source configuration and API results only in `private/`, mode0600).

The authenticated Questarr search for `Mario Kart 8 Deluxe Switch` returned one real matching `[Switch NSP] Mario Kart 8 Deluxe` result from The Pirate Bay, confirmed against the dedicated Prowlarr and Torznab response by infohash. LimeTorrents query succeeded but had no matches; 1337x/EZTV/YTS were not imported, and no productive Byparr was used. Advertised seed counts are not contacted peers or content safety proof. Questarr labels the Torznab total peers as leechers (89 seeds + 2 leeches = 91 peers), so use Prowlarr's 2 leechers, not 91.

Lowering only this pod's tun0 caused direct-IP requests in both application containers and direct external DNS to fail closed. Controlled recreation restored NordVPN and retained identical settings, indexers, API key and PVC identities, without rewriting settings after restart. Existing media pod UIDs/restart counters were unchanged. No .torrent file or game payload was downloaded, no result download link was followed, and no magnet was submitted to a client.

For maintenance, retain Gluetun firewall protections, the loopback binding, fixed images, persistent volume identities and manual-only controls. Never relax VPN/DNS or borrow a non-VPN solver to bypass a source failure. The fixed NordVPN hostname may need reviewed maintenance when retired by the provider.
