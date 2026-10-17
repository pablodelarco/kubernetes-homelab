# Prometheus storage policy

Pablo's policy: keep only the current12-hour metrics window, preserve the two live Longhorn replicas, and do not retain additional historical metrics recovery snapshots. This applies ONLY to Prometheus; application/configuration backups and the protected backup group are unchanged.

## Data and cleanup

- Prometheus TSDB retention stays12h with existing size cap27GB, compressed WAL and optimized ingestion.
- Do not shrink/recreate the existing50Gi PVC, delete its head, remove either current replica or manually unlink Longhorn image files.
- The obsolete scheduled August snapshot was explicitly retired using the volume API followed by purge. Ext4 can remember discards: after purge a controlled complete unmount/remount and TRIM may be required to reclaim the coalesced deleted blocks. Preserve data and arrange independent availability recovery during that maintenance.
- Internal removed parent snapshots can remain in the engine chain because they back the live head. They are not usable historical recovery points; cleanup and TRIM should keep their physical footprint bounded.

## Scheduled prevention

The Longhorn chart defines two dedicated jobs, with empty groups and retain0:

- `prometheus-filesystem-trim`: daily00:20 in the Longhorn controller timezone.
- `prometheus-snapshot-cleanup`: daily00:40 in the same timezone.

Neither creates new recovery snapshots. `default-backup` remains unchanged: protected group, retain4, its existing schedule and weekly full-backup interval. No global unmap/snapshot-removal setting or shared StorageClass is changed.

## Existing dynamic PVC selection

Apply native recurring-job labels to the existing Bound PVC, not by importing a controller-owned Volume object or recreating immutable claim templates:

Namespace `monitoring`, PVC `prometheus-monitoring-kube-prometheus-prometheus-db-prometheus-monitoring-kube-prometheus-prometheus-0`, PV/volume `pvc-19489df3-c141-4fb3-906a-388ec4169e93`.

Required PVC labels:

```yaml
recurring-job.longhorn.io/source: enabled
recurring-job.longhorn.io/prometheus-filesystem-trim: enabled
recurring-job.longhorn.io/prometheus-snapshot-cleanup: enabled
```

For this volume remove its obsolete `recurring-job-group.longhorn.io/default` membership and verify no protected or default backup-group selection remains. Never change other PVCs. Longhorn persists the native labels in Kubernetes and propagates selectors from this PVC; the dynamically provisioned claim is intentionally not adopted by another Argo application. If intentionally rebuilding this claim after a disaster, reapply and verify these labels before resuming its maintenance schedule.

Verify the two RecurringJobs and their CronJobs, selectors effective on exactly one volume, no valid old recovery snapshot, two live RW replicas, TSDB12h retained, all expected targets/rules healthy, and measured physical bytes. A successful cleanup does not authorize deleting snapshots of other applications.
