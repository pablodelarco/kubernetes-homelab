# Longhorn backups

## Active architecture

```text
Longhorn sync-agent
  -> garage-native-egress Service
  -> HAProxy hostNetwork DaemonSet
  -> Tailscale
  -> Garage native on the NAS RAID1
```

- Production BackupTarget: `garage-native`.
- Production prefix: `s3://k8s-backups@us-east-1/production-v1/`.
- Credentials: `garage-native-credentials` SealedSecret.
- Legacy BackupTarget: `default`; keep it available for historical restores and rollback.
- Compression: LZ4.
- RecurringJob: `default-backup`, daily at 03:00.
- Retention: 4 backups per volume.
- Concurrency: 1.
- Full backup interval: every 7 executions.
- New Longhorn volumes inherit `backupTargetName: garage-native` from the default StorageClass.

## Production acceptance evidence

Validated on 2026-08-31 with Longhorn 1.11.3:

- 17 protected production volumes assigned to `garage-native`.
- Initial round: 17/17 completed in 14m25s, LZ4, zero Job errors.
- Immediate incremental round: 17/17 completed in 3m14s and uploaded 37 MiB of changed data.
- `homepage` production restore: new two-replica PVC became healthy in approximately 83s.
- Deterministic source and restore tree hashes matched.
- Both egress pods remained Ready with zero restarts.

These values are dated evidence, not permanent performance guarantees. Re-check live state before making operational claims.

## Safe rollback

Do not delete either repository during rollback.

1. Confirm no recurring Job or Backup CR is active.
2. Confirm `default` and `garage-native` are both available.
3. Patch only protected production volumes back to `spec.backupTargetName: default`.
4. Change `persistence.backupTargetName` in `custom-values.yaml` back to `default` for future volumes.
5. Commit and push the StorageClass change, then wait for Argo CD `Synced/Healthy`.
6. Run one backup against `default` and verify completion before considering rollback complete.
7. Keep backups created in `garage-native`; do not force-delete Backup CR finalizers.

The pre-cutover volume inventory from the validated migration is stored locally at:

`/home/pablo/.hermes/tmp/garage-native-production-migration-rollback-20260831.json`

Treat that inventory as convenience evidence only. The live `protected` group and PVC ownership are authoritative.

## Routine verification

Before declaring the backup system healthy, verify:

- `garage-native` is available.
- Both `garage-native-egress` pods are Ready.
- All protected volumes point to `garage-native` and are healthy.
- The latest backup for every protected volume is `Completed` within the expected RPO.
- No Backup CR is stuck in `New`, `Pending`, `InProgress` or `Error`.
- At least one periodic restore drill succeeds and its content checksum matches.
- The legacy target remains readable until the rollback window is intentionally closed.
