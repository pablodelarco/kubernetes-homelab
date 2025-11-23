# Volume Mapping - Sun Nov 23 11:15:47 PM CET 2025

## Summary

This document maps PVCs to their underlying PVs/volumes for troubleshooting and disaster recovery.

### Volume Naming Conventions

1. **Restored volumes** (from disaster recovery): `pvc-<app>-restored`
   - Example: `pvc-jackett-restored`, `pvc-home-assistant-restored-v2`
   - These were restored from S3 backups on 2025-11-23

2. **Fresh volumes** (created after disaster): `pvc-<uuid>`
   - Example: `pvc-623a87a9-0510-4195-8bec-671f04c9be20`
   - These are monitoring volumes created fresh (no backup existed)

3. **Manual volumes** (pre-existing): `<app>-<purpose>`
   - Example: `jellyfin-videos`, `qbitt-temp`
   - These are NFS volumes for large media storage

### Backup Status

- ✅ **Restored volumes**: Backed up daily at 3:00 AM, 7-day retention
- ✅ **Monitoring volumes**: Configured for daily backup at 3:00 AM (first backup tonight)
- ❌ **NFS volumes**: Not backed up by Longhorn (minio, jellyfin-videos, qbitt-temp)

---

## Detailed Mapping
NAMESPACE        PVC                                                                                                              VOLUME                                     STORAGECLASS   SIZE
home-assistant   home-assistant-home-assistant-0                                                                                  pvc-home-assistant-restored-v2             longhorn       5Gi
homepage         homepage-logs                                                                                                    pvc-homepage-restored                      longhorn       5Gi
media            bazarr                                                                                                           pvc-bazarr-restored                        longhorn       2Gi
media            jackett                                                                                                          pvc-jackett-restored                       longhorn       5Gi
media            jellyfin-config                                                                                                  pvc-jellyfin-restored                      longhorn       5Gi
media            jellyfin-videos                                                                                                  jellyfin-videos                                           400Gi
media            jellyseerr                                                                                                       pvc-jellyseerr-restored                    longhorn       1Gi
media            qbitt                                                                                                            pvc-qbitt-restored                         longhorn       5Gi
media            qbitt-temp                                                                                                       qbitt-temp                                                400Gi
media            radarr                                                                                                           pvc-radarr-restored                        longhorn       5Gi
media            tdarr-config                                                                                                     pvc-tdarr-config-restored                  longhorn       1Gi
media            tdarr-logs                                                                                                       pvc-tdarr-logs-restored                    longhorn       1Gi
media            tdarr-server                                                                                                     pvc-tdarr-server-restored                  longhorn       10Gi
minio            minio                                                                                                            pvc-cb1e2ec1-389e-4acf-a21f-67e5bba4fac8   nfs            150Gi
monitoring       alertmanager-monitoring-kube-prometheus-alertmanager-db-alertmanager-monitoring-kube-prometheus-alertmanager-0   pvc-623a87a9-0510-4195-8bec-671f04c9be20   longhorn       5Gi
monitoring       monitoring-grafana                                                                                               pvc-8c3a8756-f6e5-4712-92ab-61521eceb5e9   longhorn       8Gi
monitoring       prometheus-monitoring-kube-prometheus-prometheus-db-prometheus-monitoring-kube-prometheus-prometheus-0           pvc-6c391b81-2761-4797-895f-831d23796af5   longhorn       25Gi
opencost         opencost-pvc                                                                                                     pvc-opencost-restored                      longhorn       5Gi
uptime-kuma      uptime-kuma-pvc                                                                                                  pvc-uptime-kuma-restored                   longhorn       5Gi
