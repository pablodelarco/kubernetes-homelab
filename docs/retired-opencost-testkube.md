# Retired: OpenCost and Testkube

Pablo requested retirement on 2026-10-17. Do not redeploy either application from historical restore scripts without a new decision.

## OpenCost

The Argo Application and active values file were removed; historical Git revisions retain both. The OpenCost HTTPRoute was removed from the gateway source. Delete the former chart's runtime ServiceMonitor, Deployment, Service, nginx ConfigMap and app-specific service account / cluster RBAC after the parent Application reconciles. The former Application has no cascading finalizer: removing it alone does not remove its runtime resources.

Preserve namespace, PVC `opencost-pvc`, its Retain PV and Longhorn volume. This retirement does not authorize deleting stored data or purging backups. Historical restore documents remain historical, not current deployment inventory.

## Testkube

Neither Testkube release is managed by the current app-of-apps tree. Retire Helm releases `testkube-homelab` and `testkube` in namespace `testkube`; keep Helm history. The legacy backend chart templates its CRDs as ordinary resources: a plain uninstall would delete saved workflow definitions.

Before uninstalling the backend, use the same pinned chart 2.13.1 with a post-renderer to add `helm.sh/resource-policy: keep` to the 15 CRDs and two explicitly rendered PVCs; preserve the live zero replica counts of its three Deployments and NATS StatefulSet. Verify the new stored manifest protects exactly those resources before uninstall. Do not rely on adding annotations only to live resources, because Helm uninstall filters the stored manifest. Skip delete hooks.

Keep all three PVCs, Retain PVs, their Longhorn volumes, namespaces, workflow/template CRs and Helm history. Private local recovery exports contain original manifests/values and must not be published or attached to Telegram. They live outside Git, under the operator's protected retirement recovery directory.

## Safety and verification

- No PVC/PV/Longhorn volume/snapshot/backup deletion is in scope.
- No automatic image pruning or cloud-account deletion is in scope.
- Verify zero OpenCost/Testkube Pods/Deployments/StatefulSets, both Helm releases uninstalled, no OpenCost scrape target or Argo re-creation, and unchanged PVC/PV identities and saved CR identities.
- Verify monitoring remains healthy and Home Assistant's independent MQTT node metrics remain available.
