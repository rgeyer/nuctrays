# plex

Plex Media Server using `lscr.io/linuxserver/plex`.

## Peculiarities

### `network_mode: host`

Plex uses host networking instead of attaching to a `traefik-*` network. Two consequences:

1. **GDM (LAN discovery) works** across VLANs — GDM uses UDP multicast which Docker's bridge NAT silently drops.
2. **Plex binds to every interface on the host** — including the AREDN mesh interface `eno2`. This is undesirable; see [Host Firewall Rules → Plex](../README.md#plex--block-access-from-aredn-eno2) in the main README for the `nftables` rules that block Plex on `eno2`.

Because there is no Docker network involved, Plex is **not** fronted by Traefik — clients connect directly to `${HOST_IP}:32400`. The `ADVERTISE_IP` env var sets the URL Plex's relay advertises to remote clients.

### Runs as root (`PUID=0` / `PGID=0`)

So Plex can read media files regardless of their owner. To prevent root inside the container from damaging the library, `MEDIA_PATH` is mounted **read-only** (`:ro`). If you later need Plex to write to the library (e.g. for DVR recordings), drop the `:ro` flag and tighten `PUID`/`PGID` to match the file owner.

### `PLEX_CLAIM` is short-lived

Get a fresh token from <https://plex.tv/claim> — it expires in **4 minutes**. Only needed on the first deploy to associate the server with your Plex account; after that the value is ignored.

### Config and media paths live outside `/mnt/.ix-apps`

`PLEX_CONFIG_PATH` and `MEDIA_PATH` are managed externally (typically on a separate dataset). They must exist on the host before deploy, but **no placeholder app is needed** for them since they are not under TrueNAS's app-config tree.

### No Traefik labels

The compose file has no `traefik.*` labels because Plex isn't reachable via Traefik. Don't add any — they would have no effect (Plex isn't on any `traefik-*` network).
