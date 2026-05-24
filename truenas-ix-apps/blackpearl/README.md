# blackpearl

VPN-gated media stack: Radarr, Sonarr, Readarr, NZBGet, qBittorrent, Prowlarr, FlareSolverr, and Overseerr — all routed through a NordVPN tunnel provided by a [gluetun](https://github.com/qdm12/gluetun) container.

## Peculiarities

### Deploy `placeholder` under the name `blackpearl` first

The `vpn` container needs `client.ovpn` to exist at
`/mnt/.ix-apps/app_configs/blackpearl/client.ovpn` before it will start, but that directory does not exist until TrueNAS has provisioned the app. Use the **placeholder** app (see main [`../README.md`](../README.md)) to create the directory structure, copy `client.ovpn` in, then replace the placeholder YAML with the real `blackpearl` compose.

### All app containers share the VPN container's network namespace

Every app service uses `network_mode: service:vpn`, which means:

- App containers have **no network interfaces of their own** — they appear on the VPN's `tun0` interface.
- App containers **cannot publish ports**; only the `vpn` container can.
- **All Traefik labels must be on the `vpn` service**, not on the individual app containers. The router rules use `Host(...)` to dispatch, and the `service` definitions use `loadbalancer.server.port=<app-port>` to forward to the right app on `localhost` inside the shared namespace.
- App containers depend on `vpn` being **healthy** (not just started) — the gluetun healthcheck verifies `tun0` is up before allowing app containers to attach.

### gluetun-specific gotchas

- **`DOT: "off"`** — DNS-over-TLS is disabled because it requires bootstrap DNS resolution before the tunnel is up, which can fail on restricted networks.
- **`BLOCK_MALICIOUS: "off"`** — gluetun's built-in blocklists classify some legitimate Usenet providers as malicious. Leave this off.
- **`FIREWALL_OUTBOUND_SUBNETS=${LAN_SUBNETS}`** — without this, Radarr/Sonarr/Overseerr cannot reach Plex (or any LAN host) because gluetun's `FIREWALL=1` drops all non-VPN egress. Set `LAN_SUBNETS` to cover any local subnets the apps need to reach.
- **`VPN_DNS`** — defaults to `1.1.1.1` in `.env.example`. NordVPN's own resolver (`103.86.96.100`) applies content filtering that breaks some Usenet hostnames; queries to Cloudflare/Google still go through the tunnel so privacy is preserved.

### NordVPN credentials are service credentials, not your account login

Get them from <https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/> and put them in `VPN_USER` / `VPN_PASSWORD`. Gluetun overrides the `auth-user-pass` line in `client.ovpn` with these values, so there is no `auth.txt` file to maintain.

### `client.ovpn` source

Download from NordVPN's [server tools](https://nordvpn.com/servers/tools/) — pick a server in the country you set in `VPN_SERVER_COUNTRIES` and grab the OpenVPN UDP or TCP config.

### Config directories must exist before deploy

The host paths in `RADARR_CONFIG_PATH`, `SONARR_CONFIG_PATH`, etc. are bind-mounted; Docker will create them as root-owned empty directories if missing, which usually breaks the LSIO/hotio entrypoints. Pre-create them with the correct owner:

```bash
mkdir -p /path/to/config/{radarr,sonarr,readarr,nzbget,overseerr,qbittorrent,prowlarr}
```

### Lidarr and the speedtest probe are commented out

`hotio/lidarr` was removed from Docker Hub; the service block is left in place (commented) so you can re-enable it against `ghcr.io/hotio/lidarr` when you want music management. The `speedtest` service is similarly stubbed for future Prometheus/Alloy integration.
