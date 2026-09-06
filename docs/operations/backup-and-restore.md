# Backup and Restore

This is an operational runbook for disaster recovery of a Tokko production
deployment. It is provider-neutral: it does not assume any specific hosting
platform, and Tokko does not ship a backup service, scheduler, or admin UI.
Backups are the operator's responsibility, run with standard PostgreSQL and
filesystem tools.

A backup is only proven valid once it has been **restored and checked**. A
`pg_dump` file that exists is not evidence of a working backup.

## 1. What must be backed up (required)

### 1.1 Primary PostgreSQL database — `tokko_production`

This is the most important thing to back up. It holds all business/domain
data, including:

- products and variants
- customers/users
- orders and order items
- inventory movements
- coupons
- the Stripe webhook inbox (`stripe_webhook_events`)
- the durable payment outbox (`order_events`)
- Active Storage **metadata** (blob/attachment records — not the file bytes)

Losing this database means losing the store's transactional history.

### 1.2 Active Storage files

If the deployment uses the default local disk storage service, the files
under:

```text
/rails/storage
```

must be backed up as well. Active Storage records in the primary database
reference blobs by key; a database backup without the matching files (or
files without the matching database) is not a usable backup — restoring one
without the other leaves broken or orphaned attachments.

### 1.3 Secrets and configuration

These must be retained separately, through whatever secret-management
process the operator already uses (password manager, secrets manager, Kamal
secrets, etc.). They are operational prerequisites for restoring — without
them, a restored database is not reachable by a working application.

- `RAILS_MASTER_KEY` (decrypts `config/credentials.yml.enc`)
- database credentials (e.g. `TOKKO_DATABASE_PASSWORD`, host, username)
- Stripe secret key and webhook signing secret
- SMTP credentials
- object-storage credentials, if Active Storage is later moved to S3/GCS/etc.

**Do not** put any of these secrets in the same archive as the database dump
or storage tarball, and never commit them to Git. Back up the data and the
secrets through separate, appropriately access-controlled channels.

## 2. What does not need disaster-recovery backup

### 2.1 Cache — `tokko_production_cache`

Solid Cache data. Purely a cache; the application repopulates it on demand.
Not backed up.

### 2.2 Cable — `tokko_production_cable`

Solid Cable data. Transient Action Cable pub/sub state with no durable
business meaning. Not backed up.

### 2.3 Queue — `tokko_production_queue` (optional)

Solid Queue's own tables (scheduled/enqueued jobs, job history). This is
**optional**, not part of the minimum required backup set.

Tokko's critical recovery path for payments does not depend on the queue
database surviving: Stripe webhook processing is recorded durably in the
primary database (`stripe_webhook_events`, `order_events`), and
`RecoverStaleCheckoutsJob` reconciles stale checkouts directly against Stripe
using primary-database state. If the queue database is lost, that
reconciliation still works once the job is scheduled again.

What you lose if the queue database is not backed up is only the queue's own
bookkeeping — e.g. jobs that were enqueued but not yet run, and job execution
history. Backing it up gives a fuller point-in-time recovery, but it is not a
substitute for, and does not extend, the durability guarantees above. Do not
assume every other background job in the system is automatically recoverable
this way — that depends on each job's own design.

## 3. Creating a backup

### 3.1 Primary database

Use PostgreSQL's custom archive format — it's compressed, supports
selective/parallel restore, and is what `pg_restore` expects.

If your deployment provides `DATABASE_URL` for the primary database:

```bash
pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file=tokko-primary-$(date +%Y%m%d-%H%M%S).dump \
  "$DATABASE_URL"
```

Tokko's default `config/database.yml` configures the production primary
database with discrete connection settings rather than a single URL
(database `tokko_production`, role `tokko`, password from
`TOKKO_DATABASE_PASSWORD`). If that's how your deployment is set up, use the
standard PostgreSQL environment variables instead:

```bash
export PGHOST=...
export PGPORT=5432
export PGUSER=tokko
export PGDATABASE=tokko_production
export PGPASSWORD=...   # see note below

pg_dump --format=custom --no-owner --no-privileges \
  --file=tokko-primary-$(date +%Y%m%d-%H%M%S).dump
```

Avoid typing the password directly on the command line where it can end up
in shell history or `ps` output. Prefer exporting `PGPASSWORD` from a
credential you pull from your secrets store at run time, or use a
[`.pgpass`](https://www.postgresql.org/docs/current/libpq-pgpass.html) file
with restrictive permissions.

Do not hard-code any real Tokko production credential in scripts, cron
entries, or this documentation — the values above are placeholders.

The production image already includes `postgresql-client`, so `pg_dump` and
`pg_restore` are available in the running container if you prefer to back up
from inside it (e.g. via `kamal app exec`).

### 3.2 Active Storage files (local disk)

For a plain local-disk deployment:

```bash
tar -czf tokko-storage-$(date +%Y%m%d-%H%M%S).tar.gz /path/to/tokko_storage
```

For Kamal/Docker volume deployments, the actual host path backing the
`tokko_storage` volume depends on your Docker/Kamal configuration and host —
there is no single fixed path to document here. Locate it with
`docker volume inspect tokko_storage` (or your platform's equivalent) and
back up that path, or back up the volume directly with your platform's
volume tooling.

Any of the following are reasonable ways to do this — Tokko does not depend
on any particular one:

- host-level filesystem snapshots
- Docker/Kamal volume backup tooling
- `rsync`, `restic`, or `borg`
- infrastructure-provider disk/volume snapshots

If Active Storage is reconfigured to use S3, GCS, or another object store,
local volume backup is no longer relevant — rely on that provider's
versioning and backup/lifecycle features instead.

## 4. Backup verification

Do not treat a `pg_dump` exit code of 0 as proof of a valid backup. Verify at
two levels.

### 4.1 Archive structural check (necessary, not sufficient)

```bash
pg_restore --list tokko-primary.dump > /dev/null
echo $?
```

A zero exit status only proves the archive file is well-formed and
readable by `pg_restore`. **It does not prove the application can actually
recover from it** — it doesn't touch the data, the schema compatibility, or
whether the dump is even from the right database.

### 4.2 Restore drill (required for real verification)

Restore into a disposable, throwaway database — never into production:

```bash
createdb tokko_restore_test

pg_restore \
  --no-owner \
  --no-privileges \
  --dbname=tokko_restore_test \
  tokko-primary.dump
```

Then spot-check that the data you expect is actually there, e.g.:

```sql
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM inventory_movements;
SELECT COUNT(*) FROM stripe_webhook_events;
SELECT COUNT(*) FROM order_events;
```

There's no specific row count to expect here — these are sanity checks that
tables exist, are populated, and the restore didn't silently fail or
truncate, not an assertion about a particular count.

Clean up afterward:

```bash
dropdb tokko_restore_test
```

**Never point `pg_restore --dbname` at the live production database.**
Restoring into an existing database can overwrite or conflict with live
data. Always restore into a freshly created, empty database — for a drill
that's a throwaway database you drop afterward; for a real recovery that's a
new production database you cut over to only once it's verified (see
below).

## 5. Production restore procedure

This is a conservative sequence for recovering a lost or corrupted
production environment. It intentionally restores into a fresh, empty
database rather than overwriting a possibly-still-live one.

1. Stop incoming traffic / put the application in maintenance mode.
2. Stop background workers (Solid Queue).
3. Prepare a new, empty PostgreSQL primary database.
4. Restore the primary database into it:
   ```bash
   pg_restore \
     --no-owner \
     --no-privileges \
     --dbname=<new-empty-database> \
     tokko-primary.dump
   ```
5. Restore the Active Storage files to the path/volume the application will
   read from.
6. Restore or otherwise provide `RAILS_MASTER_KEY` and the rest of the
   secrets/environment listed in section 1.3 — the application cannot boot
   or decrypt credentials without them.
7. Point the deployment's database configuration at the restored database,
   and run any database preparation/migration step required by the
   currently deployed code version (e.g. `bin/rails db:prepare`), in case
   the backup predates the running release.
8. Start the application.
9. Start background workers.
10. Verify application health (it boots, responds, admin dashboard loads).
11. Verify business data: spot-check recent products, orders, and inventory
    levels look correct.
12. Verify pending Stripe/outbox reconciliation: confirm
    `stripe_webhook_events` and `order_events` are being processed as
    expected, and that `RecoverStaleCheckoutsJob` runs cleanly against
    current Stripe state.

Only cut real traffic over to the restored environment after these checks
pass.

## 6. Consistency between database and storage backups

Because the database backup and the Active Storage file backup are captured
by separate commands, they are not perfectly atomic with each other — there
is a small window where one could reflect a slightly different point in time
than the other. For Tokko's typical usage this is usually an acceptable risk
(at worst, a very recently uploaded file references a blob row that hasn't
made it into the archive yet, or vice versa).

For higher-volume production systems where this window matters more, prefer
an infrastructure- or provider-level coordinated snapshot (e.g. snapshotting
the database and the storage volume together) over relying on the timing of
two independent manual commands. Tokko does not attempt to solve distributed
snapshot consistency itself — that's an infrastructure concern, not an
application one.

## 7. Retention (example guidance, not a hard-coded policy)

Pick a retention schedule that matches your own risk tolerance and storage
budget. A common starting point:

```text
daily backups:   keep 7 days
weekly backups:  keep 4 weeks
monthly backups: keep 3–12 months
```

Whatever schedule you choose, keep at least one backup copy off the
application server itself — a backup that lives only on the machine it's
protecting against doesn't survive that machine's loss.

This document does not implement or schedule retention; that's left to your
platform's backup/snapshot tooling or a simple external cron/CI schedule of
your choosing.
