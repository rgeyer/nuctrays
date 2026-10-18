# Agent notes: truenas-ix-apps

What an agent needs to know before changing or adding an app here. The [README](README.md) is the human guide; read it and the app's own README first.

## How deployment works

- Each directory is one TrueNAS custom app: a `compose.yaml` template with `${VAR}` placeholders, a `.env.example`, and a README of the app's peculiarities. `render.sh <app>` substitutes the app's `.env` and writes `.rendered/<app>/compose.yaml`, which the user pastes into TrueNAS (Apps → Install via YAML). TrueNAS itself substitutes nothing.
- `.env` files and `.rendered/` hold real values and are gitignored. Never commit them, and keep real values (hostnames, IPs, pool names, credentials) out of templates and READMEs: write `<pool>`, `<truenas-ip>`, and so on.
- When an app's `.env.example` changes, the user's existing `.env` needs the same change, keeping their values. Leave a value empty when it isn't known yet: `render.sh` warns about empty values.
- The `placeholder` app exists only for apps that need files under `/mnt/.ix-apps/app_configs/<app>/` before they start (blackpearl, traefik). An app keeping its data elsewhere doesn't need it.
- Traefik routing follows the README's patterns: the private and public instances share one hostname, with an HTTP router redirecting to HTTPS on each, and AREDN is HTTP only, on its own hostname.

## Where app data lives

- Most apps keep their data on the host under `/mnt/<pool>/dockge/<app>/` (such as `sftpgo/config`, `plex/config`, and `blackpearl/<service>`), set by a `*_PATH` variable in `.env`.
- **rflib is the exception:** its data is in the home directory of its own TrueNAS user (see below), which the user chose on 2026-10-17.

## Which user a container runs as

- Precedent: tautulli runs as `PUID`/`PGID` 1000 (linuxserver.io images), sftpgo's image runs as 1000 (its data is `chown`ed to it), plex and registry run as root, and TrueNAS's own catalog apps run as its shared `apps` user, 568.
- For an app holding anything sensitive, the user prefers a **dedicated TrueNAS user and group** (Credentials → Users: password disabled, shell `nologin`), with the IDs in `.env` and compose's `user:` set from them, rather than root or the shared 568 that every catalog app can use. Don't invent a UID: the user reads it from TrueNAS (`id -u <user>`) after creating the user.

## Custom images

- Images not on a public registry (openhamclock, rflib) are built on the user's workstation and pushed to the `registry` app (`REGISTRY_HOST`, reachable on the LAN through traefik-private, with no authentication). TrueNAS pulls them when the app deploys.
- A Dockerfile, when this repo has one, sits in the app's directory. Build from `truenas-ix-apps`, with the app's directory as the context (`docker build ... rflib/`); from inside the app's directory the context is `.`. `source <app>/.env` first, or `REGISTRY_HOST` is empty and the tag is invalid.

## rflib

[rflib](https://github.com/rgeyer/rflib) is the user's own project: a radio channel library with a web interface. `rflib/README.md` has the details; in short:

- The image is built from rflib's GitHub release (`--build-arg RFLIB_VERSION=vX.Y.Z`), checked against the release's `SHA256SUMS`, on alpine with `wget` (healthcheck) and `sqlite3` (backups).
- It runs `serve --accounts --signup invite --behind-tls`. With `--behind-tls` it trusts `X-Forwarded-For` from anyone, so the compose file must publish no ports: only Traefik may reach it.
- It can't also serve AREDN: that needs `--plain-http`, which excludes `--behind-tls`. AREDN would be a second app with its own database.
- Administration runs in the container: `docker exec rflib rflib user invite` (and `user list`, `role`, `passwd`, `remove`). rflib sends no email.
- Back up with `sqlite3 .backup` on `library.db`, which is safe while rflib runs and covers every account. `rflib export json` covers only the admin's own library, so it isn't a backup of the instance.
- The hosted database is bootstrapped from the user's dev instance (rflib/README.md, "First deploy") with `rflib shared export json`, then `init --no-seed`, `shared import json`, and `seed update`. Shared channels keep their IDs, so built-in list updates still apply.
