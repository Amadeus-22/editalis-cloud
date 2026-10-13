# Runbook

One section per alert in `monitoring/rules.yaml`, then the restore procedure.
Commands assume `kubectl` pointed at the cluster and the namespace `editalis`.

## API unavailable

**Alerts:** `EditalisApiUnavailable` (no pod ready), `EditalisApiDegraded` (fewer than requested).

1. `kubectl -n editalis get pods -l app.kubernetes.io/component=api` — are pods crashing, pending or not ready?
2. Not ready: `kubectl -n editalis describe pod <pod>` and look at the probe failures. The probes call `/health`.
3. Crashing: `kubectl -n editalis logs <pod> --previous`. A database connection error points at the secret or at RDS, not at the application.
4. Pending: `kubectl -n editalis describe pod <pod>` shows the scheduling reason; on a single node this is almost always memory.
5. If the last release caused it, revert the commit that changed `gitops/editalis.yaml`. Argo CD rolls back on its own.

## Worker down

**Alert:** `EditalisWorkerDown`. No notices are collected or delivered while it fires.

1. `kubectl -n editalis logs deploy/editalis-worker --tail=100`.
2. The pipeline is idempotent: restarting the worker cannot duplicate deliveries. `kubectl -n editalis rollout restart deploy/editalis-worker` is safe.
3. One failing source is not a reason for this alert; the worker skips a failing source and continues.

## Pod restarting

**Alert:** `EditalisPodRestarting`.

1. `kubectl -n editalis get pods` and check the `RESTARTS` column and the last state: `kubectl -n editalis describe pod <pod>`.
2. `OOMKilled` means the memory limit is too low for the workload; raise it in the chart values, through Git.
3. Otherwise read the previous container's logs for the exit reason.

## Migration failed

**Alert:** `EditalisMigrationFailed`. The new version did not roll out; the old pods keep serving.

1. `kubectl -n editalis logs job/editalis-migrate`.
2. Fix the migration in the application repository and release again. Do not edit the database by hand to make a migration pass.
3. If the migration applied partly, restore from the last backup (below) before retrying.

## Backup failed

**Alerts:** `EditalisBackupFailed`, `EditalisBackupTooOld` (no success in 36 hours).

1. `kubectl -n editalis get jobs` and `kubectl -n editalis logs job/<backup-job>`.
2. Common causes: the volume is full (`pg_dump` cannot write), or the database rejected the connection.
3. Run one by hand after fixing: `kubectl -n editalis create job --from=cronjob/editalis-backup backup-manual`.

## Restoring the database

The backup is a `pg_dump` custom-format file. Restoring replaces the current contents.

1. Stop writers: `kubectl -n editalis scale deploy/editalis-worker deploy/editalis-api --replicas=0`.
2. Pick the dump (`ls` on the backup volume, or `aws s3 ls s3://<bucket>/postgres/`).
3. `DATABASE_URL=... ./scripts/pg-restore.sh /backup/editalis-<stamp>.dump`
4. Check a few counts against what you expect, then scale the deployments back up. With Argo CD's self-heal on, scaling back happens by itself once you stop holding it.

RDS also keeps automated snapshots with point-in-time recovery for 7 days; use
those when the whole instance is lost rather than the data inside it.

### The drill

`make drill` runs this procedure against a throwaway database and fails unless
the restored data has the same row counts and checksum as the original and the
unique constraint is back. Last run: 5,000 subscribers and 20,000 deliveries,
restored identically.
