# sftpgo

Multi-user WebDAV server ([SFTPGo](https://github.com/drakkan/sftpgo)) exposed on `traefik-private` only. Designed as a target for ShareX screenshot uploads, with new users added at runtime through the SFTPGo admin UI — no compose edits required to onboard another client.

## Peculiarities

### Two hostnames, two ports, one container

SFTPGo serves the admin/web UI and the WebDAV endpoint on different internal ports. Following **Pattern 3** in the [main README](../README.md) (different ports per Traefik router), the compose file defines two named services pointing at the same container:

| Hostname | Traefik service | Container port | Purpose |
|---|---|---|---|
| `${SFTPGO_WEBDAV_HOST}` | `sftpgo-webdav-svc` | 10080 | WebDAV (used by ShareX) |
| `${SFTPGO_ADMIN_HOST}`  | `sftpgo-admin-svc`  | 8080  | Admin & web-client UI |

Keeping the two surfaces on distinct hostnames lets WebDAV live at the URL root, which avoids the well-known fragility of WebDAV behind path prefixes.

### Authentication lives inside SFTPGo, not Traefik

WebDAV requires its own `Authorization` header; layering a Traefik basic-auth middleware on top would double-prompt and break PROPFIND. SFTPGo has a real multi-user backend — each user has their own credentials and virtual filesystem root — so Traefik just does HTTPS termination and routing.

### SFTP and FTP listeners are disabled

`SFTPGO_SFTPD__BINDINGS__0__PORT=0` and `SFTPGO_FTPD__BINDINGS__0__PORT=0` turn off the TCP listeners. If you ever want SFTP, set the port back (e.g. `2022`) and publish it on `${HOST_IP}` in the `ports:` section.

### Trusted proxy

`SFTPGO_HTTPD__BINDINGS__0__PROXY_ALLOWED` and `SFTPGO_WEBDAVD__BINDINGS__0__PROXY_ALLOWED` are set to the `traefik-private` docker subnet so SFTPGo will honour the `X-Forwarded-*` headers Traefik adds — without this, every connection appears to come from the Traefik container IP, which makes audit logs and connection-rate limits useless.

Find the value with:

```bash
docker network inspect traefik-private | grep Subnet
```

## Pre-deployment

1. **Pick a dataset on TrueNAS** and create two subdirectories — one for SFTPGo's own state (SQLite DB, host keys), one for the user data root. SFTPGo runs as UID/GID `1000` inside the container, so both must be writable by that owner:

   ```bash
   ssh root@<truenas-ip>
   mkdir -p /mnt/<pool>/<dataset>/sftpgo/config /mnt/<pool>/<dataset>/sftpgo/data
   chown -R 1000:1000 /mnt/<pool>/<dataset>/sftpgo
   ```

   Put these paths into `SFTPGO_CONFIG_PATH` and `SFTPGO_DATA_PATH` in your `.env`.

2. **Add LAN DNS records** for both `SFTPGO_WEBDAV_HOST` and `SFTPGO_ADMIN_HOST` pointing at `TRAEFIK_PRIVATE_IP`. Public DNS is not required (the cert uses Route53 DNS-01, which works regardless of where the record points).

3. **Get the traefik-private subnet** (see command above) and paste it into `TRAEFIK_PRIVATE_SUBNET`.

4. **Render and deploy** following the standard workflow in the [main README](../README.md):

   ```bash
   cd truenas-ix-apps
   ./render.sh sftpgo
   # paste .rendered/sftpgo/compose.yaml into TrueNAS UI → Install via YAML
   ```

## First-run admin setup

On first start the SQLite DB has no admin accounts, so SFTPGo enables a one-time setup wizard. Browse to:

```
https://${SFTPGO_ADMIN_HOST}/web/admin/setup
```

(Visiting the root will redirect there automatically.) Fill in the username and password — that becomes the first admin. The setup endpoint disappears the moment an admin exists, so the form is only reachable on the LAN for the few seconds between deploy and your first visit.

If you ever need to recreate the wizard, stop the stack, delete (or move aside) the file `sftpgo.db` inside `${SFTPGO_CONFIG_PATH}`, and restart.

## Adding a user (per ShareX install)

In the admin UI: **Users → Add**. Minimum settings that work:

- **Username** — e.g. `ryan-sharex`.
- **Password** — generate a long random one; this is what ShareX sends.
- **Home dir** — `/srv/sftpgo/data/ryan-sharex` (SFTPGo will create the directory on first login).
- **Permissions** — at least `list`, `download`, `upload`, `create_dirs`. For ShareX-only credentials, leaving `delete`/`overwrite` off is reasonable.
- **Allowed protocols** — `HTTP` is sufficient for WebDAV; uncheck `SSH` and `FTP` to lock the account down.

Repeat for each ShareX install — no repo or compose changes needed.

## ShareX configuration

ShareX has native WebDAV support; no Custom Uploader required.

**Destinations → Destination settings → File uploaders → WebDAV**, then:

- **Host**: `https://${SFTPGO_WEBDAV_HOST}`
- **Port**: `443`
- **Username**: the SFTPGo username you created above
- **Password**: that user's password
- **Path**: `/` (or a subfolder like `/screenshots` — created automatically on first upload if `create_dirs` is granted)
- **URL**: leave blank, or set to `https://${SFTPGO_WEBDAV_HOST}` if you want the clipboard link to point at the file (it will be auth-protected, so the link is only useful to you).

Then **Destinations → File uploader → WebDAV** and capture a screenshot to test. The file should appear under `${SFTPGO_DATA_PATH}/<username>/` on the TrueNAS host.

## Verification

```bash
# Admin UI reachable
curl -kI https://${SFTPGO_ADMIN_HOST}      # expect 200 (or 302 to /web/admin/...)

# WebDAV PROPFIND on a user root
curl -u <user>:<pass> -X PROPFIND -H 'Depth: 0' https://${SFTPGO_WEBDAV_HOST}/
# expect: HTTP/1.1 207 Multi-Status with an XML body
```
