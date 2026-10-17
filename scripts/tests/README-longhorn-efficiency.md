# Longhorn efficiency guardrails

Run `python scripts/test-longhorn-efficiency.py --promtool /path/to/promtool` with PyYAML installed. The runner extracts the current GitOps rule group into a temporary directory and tests synthetic fixtures. It makes no Kubernetes calls.

Two warnings extend the existing `longhorn-alerts` group and existing notification route:

- Prometheus trim/cleanup has no successful execution in 30 hours (30-minute grace), including a newly created job that never succeeded. Existing `KubeJobFailed` covers explicit failures; no duplicate failure rule is added.
- The exact current Prometheus volume consumes more than 8 GiB **per replica** and over four times live PVC filesystem usage for an hour. Both metrics must exist. This is an early amplification warning, not a global storage limit or a deletion policy. The identity is intentionally pinned: review it when the Prometheus PVC is replaced.

A successful Job is not proof of physical reclamation. For an alert, compare filesystem usage with allocated blocks for **both** replica directories, inspect engine snapshot chains, selector membership, rebuild/purge errors and canary logs. Longhorn v1.11.3 recurring trim already requests snapshot purge; the separate cleanup job is conservative but partly redundant. `snapshot-cleanup` and `filesystem-trim` correctly use retain=0; they do not mean delete every valid snapshot. Do not replace them with snapshot-delete.

Keep global `remove-snapshots-during-filesystem-trim=false`, both live Prometheus replicas, protected-app backup membership and retention unchanged. Never delete the current head, replicas, volumes, PVC/PV or NAS backups automatically.

V1 can trim the head and preceding continuously removed/system snapshot chain. A previously trimmed block protected by a valid snapshot, or trimmed while rebuilding, may need one coordinated remount after the blocker is removed. This does **not** justify a daily restart. Ordinary filesystem churn can be reclaimed by later trim without remount; verify physical effects rather than assuming this.

RAM: manager/engine/instance-manager image and actual ownership must all be on a fixed release (v1.11.1+; currently v1.11.3). Check RSS separately from page cache and reclaimable slab; rising cgroup working set alone does not prove the old connection leak. Existing host available-memory/PSI alerts remain authoritative for real pressure; no duplicate memory monitor, forced cache drop, GC job or automatic restart is introduced.

Limitations: daily trim allows up to a day's churn; retention of 12 hours is a TSDB policy, not a strict physical-volume or exact oldest-sample bound. Valid snapshots/manual backups or rebuilding can impede reclaim. Missing/deleted CronJob objects and missing filesystem metrics require the existing target/configuration checks; these two alerts do not prove selector correctness. They send no healthy daily notification.
