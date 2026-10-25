# Private backup and recovery

Run from the portfolio repository root in WSL. A backup contains private inbox data, documents, sessions and credentials. It is excluded from Git and the release ZIP.

```bash
python3 projects/07-automated-career-opportunity-manager/scripts/backup_local.py --verify
```

The script briefly stops only this project's running writers, dumps PostgreSQL, copies `.env`, profile files, n8n data and the synthetic engine data, records SHA-256 checksums, then restarts the services it stopped. Keep Docker running until it finishes. Do not make edits during the backup. The destination is printed without secret values.

Verification checks hashes, restores to a uniquely named temporary database, compares record counts and checks profile SQLite/file integrity. Only that temporary verification database is removed. The live database is never replaced. See [verification evidence](backup-verification.json). This proves data restoration; it does not prove Google's refresh tokens will still be valid on another device.

To verify an existing backup:

```bash
python3 projects/07-automated-career-opportunity-manager/scripts/backup_local.py --verify-existing /absolute/private/backup-folder
```

## Full recovery procedure

Use a separate, clean Docker installation for rehearsal or migration. Do not overwrite a populated workspace. Take and verify a backup of any existing target first. Keep the old device stopped during cutover to avoid two pollers operating on one mailbox.

1. Install the same source/release and Docker versions. Copy the backup privately. Verify the manifest hashes before use.
2. Place the backed-up `.env` at the project root with mode 600. Preserve its database password and n8n encryption key. Do not run setup to generate replacement keys.
3. Start only PostgreSQL with the documented Compose paths and `up -d --wait postgres`. Restore `postgres.dump` using `docker exec -i project07-automated-career-opportunity-manager-postgres-1 pg_restore -U careerflow --no-owner --no-acl --exit-on-error -d careerflow < /absolute/private/backup-folder/postgres.dump`. The target database must be empty; do not use `--clean` against a live workspace.
4. Restore the backup's `profile` contents to `projects/07-automated-career-opportunity-manager/local-data/profile`. Preserve the SQLite file and `files` directory together.
5. Create stopped n8n and engine containers with Compose `--profile automation create n8n engine`. Copy the contents of `n8n-data` into n8n's `/home/node/.n8n` and `synthetic-engine` into engine's `/data` using `docker cp`. Ensure n8n's files are owned by its node user (UID 1000); use a scoped `docker compose ... run --rm --no-deps --user root --entrypoint sh n8n` command to repair ownership before startup if needed.
6. Start the whole stack with the documented Compose command. Sign in, inspect application counts, profile downloads and Connections, then run the isolated backup verification again.
7. Check the Gmail credential locally in n8n. Reconnect if Google requires it. Confirm workflows 06/07 are published and a new intake completion/label timestamp appears. Do not enable polling on both devices.

The automated restore rehearsal covers PostgreSQL and profile integrity. Full replacement-device cutover is an operator procedure and has not been performed against this live installation. Retain multiple private backups on another trusted storage device; a backup on the same disk alone does not protect against disk loss.
