# Questarr retired — retained recovery data only

Questarr was explicitly uninstalled, not merely scaled down. Its Deployment,
Service, private Caddy route and Argo Application are removed. Do not recreate
Questarr to satisfy an old health check. The old application definitions remain
recoverable through Git history (`7c831b0` and earlier).

The original `media/questarr` PVC is retained without any running consumer;
its PV reclaim policy is Retain and its manifest has Prune=false. Data and
credentials are not authorized for deletion. The independent Prowlarr now lives
in `apps/media-server/prowlarr-games` and exclusively mounts the original
`media/prowlarr-questarr` PVC, without copying or replacing it.

Private authenticated search UI: `http://prowlarr-games.homelab:15000/`.
Do not expose it through port80, ingress or Funnel. Dedicated NordVPN and
loopback DNS protect the entire search path. No download client, application,
solver or automatic acquisition was added to this Prowlarr.

Retirement/rollback/kill-switch/persistence evidence:
`/home/pablo/questarr-retirement-evidence-20261026/REPORT.md`.
Private credentials and consistent backups are outside Git in that evidence
root's protected `private/` directory. The completed single-transfer monitor,
its cron and evidence under `/home/pablo/questarr-qbitt-evidence-20261026` are
preserved independently; retirement does not delete or restart that download.
