# Questarr and dedicated Prowlarr

Questarr v1.5.0 and Prowlarr 2.6.5.5623 share this pod's **dedicated NordVPN** network namespace. The restartable Gluetun init container gates startup; the app containers have no capabilities, UID/GID1000 and read-only roots. DNS is exclusively 127.0.0.1, resolved by Gluetun; outbound IPv4/IPv6 default DROP. No external indexer solver is configured.

- Questarr private access: `http://questarr.homelab:15000/`, authenticated API. Never expose via port80 or the existing Funnel.
- Prowlarr binds **127.0.0.1:9696** only. No Service/Ingress/UI proxy. API requests require its own generated key. Authentication method External is only appropriate because no external UI route exists.
- Prowlarr has a separate 2Gi Longhorn PVC `prowlarr-questarr`, two replicas, `Prune=false`. Never share the productive Prowlarr data volume.
- Upstream Prowlarr explicitly publishes no official Docker image; this uses the LinuxServer publisher image linked by the official Servarr installation guide, fixed to version and OCI digest. The application binary version was authenticated through its API. No custom image build.
- Run the publisher's `/app/prowlarr/bin/Prowlarr -nobrowser -data=/config` directly as UID1000 instead of the s6/root initialization wrapper. Only its dedicated /config and /tmp are writable. Upgrades are GitOps-owned, not self-updates.

## Configuration on the PVCs

The fresh Prowlarr has only LimeTorrents and The Pirate Bay, copied from authenticated read-only configuration of the existing service. It has no applications, download clients or proxies. Its Standard profile explicitly disables RSS and automatic search and enables interactive search only. Questarr's Prowlarr sync points at `http://127.0.0.1:9696`; generated credentials are persisted privately, not in Git. Its two Torznab indexers have no category filter, avoiding the game's nonstandard console mapping being excluded.

Questarr retains `autoSearchEnabled=false`, `autoDownloadEnabled=false` and RSS feeds disabled. Following explicit authorization, one manual-only qBittorrent downloader is configured on the Questarr PVC (ID `86ab1830-5913-423b-8b88-e72bddbba4d0`), category `games/switch`, path `/media/games/switch`, `addStopped=true`, `removeCompleted=false`. No global acquisition automation is enabled. IGDB remains unconfigured: a single authorized base-game transfer was submitted directly to qBittorrent after inspecting exact-hash torrent metadata, not registered with invented IGDB data. Existing Prowlarr/Byparr and media workloads remain independent and unchanged.

The dedicated VPN permits only the qBittorrent Service `10.43.204.85/32` and its current `qbitt-0` endpoint `10.42.1.52/32` as local outbound exceptions. Cilium socket-LB rewrites the Service destination before the pod's routes/firewall: Service-only /32 timed out; the exact endpoint /32 was necessary. **If qbitt-0 is recreated with another IP, update only that endpoint /32 through GitOps and re-test the saved downloader.** Do not replace this with cluster/LAN-wide exceptions. The private HTTP client uses qBittorrent's existing trusted-pod whitelist; no credentials were copied and no authentication settings were changed.

## Verified acceptance

Evidence: `/home/pablo/questarr-prowlarr-evidence-20261026/REPORT.md` (sensitive source configuration and API results only in `private/`, mode0600).

The authenticated Questarr search for `Mario Kart 8 Deluxe Switch` returned one real matching `[Switch NSP] Mario Kart 8 Deluxe` result from The Pirate Bay, confirmed against the dedicated Prowlarr and Torznab response by infohash. LimeTorrents query succeeded but had no matches; 1337x/EZTV/YTS were not imported, and no productive Byparr was used. Advertised seed counts are not contacted peers or content safety proof. Questarr labels the Torznab total peers as leechers (89 seeds + 2 leeches = 91 peers), so use Prowlarr's 2 leechers, not 91.

The original installation-only test lowered this pod's tun0 and verified direct-IP requests in both application containers and direct external DNS failed closed. Controlled recreation restored NordVPN and retained identical settings, indexers, API key and PVC identities, without rewriting settings after restart. Existing media pod UIDs/restart counters were unchanged. That test did not download a payload. Later, the separately authorized single transfer is tracked in `/home/pablo/questarr-qbitt-evidence-20261026/REPORT.md` and `transfer-status.json`; base NSP selected, bundled update excluded. No other acquisition is authorized by this configuration.

For maintenance, retain Gluetun firewall protections, the loopback binding, fixed images, persistent volume identities and manual-only controls. Never relax VPN/DNS or borrow a non-VPN solver to bypass a source failure. The fixed NordVPN hostname may need reviewed maintenance when retired by the provider.
