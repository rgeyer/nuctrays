# rflib

The hosted [rflib](https://github.com/rgeyer/rflib): sign-in with accounts, invite-only sign-up, exposed on `traefik-private` and `traefik-public` under one hostname.

## Peculiarities

### The image is built from rflib's GitHub release

rflib publishes binaries, not images. `Dockerfile` downloads the release's linux binary for the build's architecture, checks it against the release's `SHA256SUMS`, and puts it on `alpine`, with `wget` for the healthcheck and `sqlite3` for backups. Build and push it to the [`registry`](../registry/) app, tagged with the release:

```bash
docker build --build-arg RFLIB_VERSION=v0.1.0 -t ${REGISTRY_HOST}/rflib:v0.1.0 rflib/
docker push ${REGISTRY_HOST}/rflib:v0.1.0
```

For an upgrade, build the new release's tag, set `RFLIB_VERSION` in `.env`, re-render, and redeploy (see **Upgrading**).

### Only Traefik may reach it

rflib runs with `--behind-tls`: its session cookie is sent only over HTTPS, and it takes each client's address from `X-Forwarded-For` to slow repeated failed sign-ins. It trusts that header from whoever connects, so the compose file publishes **no ports**; the container is reachable only on the Traefik networks.

### Not on AREDN

Sign-in over AREDN needs plain HTTP (`--plain-http`), which one rflib can't serve beside `--behind-tls`. An AREDN instance would be a second app with its own database.

### The data directory must be writable by the container's user

The container runs as `RFLIB_UID:RFLIB_GID` (568, TrueNAS's apps user, by default) and keeps `library.db` in `RFLIB_DATA_PATH`:

```bash
mkdir -p /mnt/<pool>/<dataset>/rflib
chown 568:568 /mnt/<pool>/<dataset>/rflib
```

## First deploy: bootstrap the database

The hosted database starts with the shared list from your dev instance: its channels (with their IDs, so built-in lists still update them), organizations, systems, and plans. Channel history starts over, with one revision saying where the list came from. Nobody's own library comes along.

1. **Export the shared list from the dev instance** (on the machine it runs on):

   ```bash
   rflib --db <dev library.db> shared export json --output shared.json
   ```

   Apply any built-in list updates there first (`rflib seed list`), or let step 3 apply them on the hosted copy.

2. **Copy it into the data directory** on TrueNAS:

   ```bash
   scp shared.json root@<truenas-ip>:/mnt/<pool>/<dataset>/rflib/
   ssh root@<truenas-ip> chown 568:568 /mnt/<pool>/<dataset>/rflib/shared.json
   ```

3. **Create the database, import the list, and make the admin**, with the image, before deploying the app (or with it stopped). Over SSH on TrueNAS:

   ```bash
   IMAGE=${REGISTRY_HOST}/rflib:v0.1.0
   DATA=/mnt/<pool>/<dataset>/rflib
   rf() { docker run --rm -it --user 568:568 -v "$DATA":/data "$IMAGE" "$@"; }

   rf init --no-seed                                   # an empty shared list
   rf shared import json /data/shared.json --reason "bootstrap from the dev instance"
   rf seed list                                        # every list up to date, or pending updates
   rf seed update                                      # apply them, and record each list
   rf user add W6FAM --admin                           # asks for the password
   rm "$DATA/shared.json"
   ```

   `seed list` should show each built-in list `up to date` or with pending changes, never `not installed`: that would mean the IDs didn't carry over.

4. **Deploy the app** as in the main [README](../README.md#deploying-an-app), sign in as `W6FAM`, and check the Shared list.

## Invites

Sign-up is invite-only (`RFLIB_SIGNUP=invite`). Each code lets one person register within two weeks:

```bash
docker exec rflib rflib user invite
```

Other administration works the same way, on the running container: `rflib user list`, `role`, `passwd` (rflib sends no email, so a forgotten password is reset here; it signs them out everywhere), and `remove`.

## Backups

The image includes `sqlite3`, whose online backup is safe while rflib runs and covers everything: every account and library, sessions, and the shared list. From TrueNAS, daily (a cron job under System → Advanced → Cron Jobs):

```bash
docker exec rflib sh -c 'mkdir -p /data/backups && sqlite3 /data/library.db ".backup /data/backups/rflib-$(date +%F).db" && find /data/backups -name "rflib-*.db" -mtime +14 -delete'
```

That keeps two weeks beside the database; copy `backups/` somewhere off the TrueNAS too (a replication or cloud sync task on the dataset).

## Upgrading

1. Build and push the new release's image (above).
2. Stop the app, and back up `library.db`.
3. Upgrade the database with the new image: `rf init` (with `IMAGE` set to the new tag). It reports what it changed.
4. Set `RFLIB_VERSION` in `.env`, re-render, paste, and start the app.
5. `docker exec rflib rflib seed list` shows any built-in list changes in the release; apply them with `rflib seed update`.
