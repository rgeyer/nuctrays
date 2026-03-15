# TrueNAS IX Apps

Docker Compose stacks for TrueNAS 25.10+.

Each subdirectory maps to one TrueNAS custom app. The directory name matches the app name used in the TrueNAS UI.

```
truenas-ix-apps/
  traefik/        ← three Traefik reverse-proxy instances
  blackpearl/     ← VPN-gated media stack (Radarr, Sonarr, etc.)
```

---

## Prerequisites

The following tools must be installed on your **workstation** (the machine you use to work with this repo) before using the render script.

### envsubst

`envsubst` performs the variable substitution that renders template compose files into deployable ones. It is part of the `gettext` package.

**macOS**
```bash
brew install gettext
```

**Ubuntu / Debian**
```bash
sudo apt install gettext-base
```

**Arch Linux**
```bash
sudo pacman -S gettext
```

Verify installation:
```bash
envsubst --version
```

---

## Deployment Approach

### How TrueNAS handles custom apps

TrueNAS 25.10 lets you deploy a custom app via **Apps → Discover Apps → Install via YAML**, which presents a compose YAML editor in the browser. When you save, TrueNAS stores the compose file verbatim at:

```
/mnt/.ix-apps/app_configs/<app-name>/versions/1.0.0/templates/rendered/docker-compose.yaml
```

TrueNAS performs no variable substitution — what you paste is exactly what runs. There is no mechanism for a separate `.env` file. All configuration values must be present in the YAML that is pasted.

### The approach used here

The compose files in this repo use `${VARIABLE}` placeholders throughout — no values are hardcoded. Sensitive values (IPs, credentials, hostnames) live in a local `.env` file that is **never committed** to the repo.

Before deploying to TrueNAS, you run `render.sh` which uses `envsubst` to substitute all `${VAR}` references with your real values and writes the result to a gitignored `.rendered/` directory. You then paste that rendered file into the TrueNAS UI.

```
compose.yaml (template)  +  .env (your values)
         |                        |
         └──────── render.sh ─────┘
                       |
              .rendered/<app>/compose.yaml
                       |
               paste into TrueNAS UI
```

This keeps the repo files clean and portable — no hardcoded values, no credentials in version control — while remaining fully compatible with TrueNAS's paste-based deployment.

---

## One-Time Host Setup

These steps are performed once on the TrueNAS host before deploying any apps.

### 1. Assign the public IP alias

A dedicated IP alias must be added to the LAN interface (`eno1`) for `traefik-public` to bind to. This should be a free address in the same subnet as your LAN.

> **This step has already been completed.**

For reference, the steps were:
- TrueNAS UI → Network → Interfaces → select `eno1` → Edit → Aliases → Add
- IP Address: your chosen public-facing IP, Netmask: `/24`
- Save and Apply Changes

### 2. Enable SSH access

TrueNAS UI → System → Services → enable SSH (you can disable it when not in use).

### 3. Create Docker networks

SSH into TrueNAS and run:

```bash
docker network create traefik-private
docker network create traefik-public
docker network create traefik-aredn
```

These named networks are shared across stacks. `traefik` creates them; all other stacks reference them as `external`.

> **Deploy `traefik` before any other app**, as other stacks depend on these networks existing.

---

## Pre-Deployment: Creating the App Directory

When you deploy an app via the TrueNAS UI, TrueNAS creates the directory structure at:

```
/mnt/.ix-apps/app_configs/<app-name>/versions/1.0.0/templates/rendered/
```

Some apps need files placed in this directory **before** the real app can start — for example, the `blackpearl` stack requires VPN credential files to exist before the `vpn` container will come up successfully. This creates a chicken-and-egg problem: the directory doesn't exist until you deploy the app, but the app needs files in the directory before it can deploy cleanly.

The solution is to deploy the **placeholder app** first. It runs a single `busybox` container that sleeps for 10 minutes and then exits — harmless, and enough to cause TrueNAS to create the full directory structure.

### Using the placeholder

1. Render the placeholder compose file (it has no variables, but the script still works):
   ```bash
   cd truenas-ix-apps
   ./render.sh placeholder
   ```
   Or simply use `placeholder/compose.yaml` directly — there are no `${VAR}` references to substitute.

2. In TrueNAS UI: Apps → Discover Apps → **Install via YAML**
3. Set the application name to the **real name of the app you intend to deploy** (e.g. `blackpearl`)
4. Paste the contents of `placeholder/compose.yaml` into the YAML editor and click **Save**
5. TrueNAS will start the placeholder container and the directory will be created at:
   ```
   /mnt/.ix-apps/app_configs/<app-name>/versions/1.0.0/templates/rendered/
   ```
6. SSH in and perform any pre-deployment steps (place credential files, create subdirectories, etc.)
7. Once ready, edit the app in TrueNAS UI, replace the placeholder YAML with the real rendered compose file, and save

---

## Deploying an App

Follow these steps for each app in this directory. Replace `<app>` with the directory name (e.g. `traefik`, `blackpearl`).

### Step 1 — Create your `.env` file

Copy the example file and fill in all values:

```bash
cp truenas-ix-apps/<app>/.env.example truenas-ix-apps/<app>/.env
# edit truenas-ix-apps/<app>/.env and fill in every variable
```

The `.env` file is gitignored and will never be committed.

### Step 2 — Render the compose file

From the repo root:

```bash
cd truenas-ix-apps
./render.sh <app>
```

The script will warn you if any variables are still empty, and will write the rendered file to `.rendered/<app>/compose.yaml`.

### Step 3 — Review the rendered output

Open `.rendered/<app>/compose.yaml` and confirm all values look correct before pasting.

### Step 4 — Deploy in TrueNAS UI

1. TrueNAS UI → Apps → Discover Apps → **Install via YAML**
2. Set the application name to exactly match the directory name (e.g. `traefik`)
3. Paste the contents of `.rendered/<app>/compose.yaml` into the YAML editor
4. Click **Save**

### Step 5 — blackpearl only: place VPN credentials

The VPN credentials cannot be inlined into the compose file — they must be placed as files on the TrueNAS host. If you used the placeholder app to pre-create the directory (recommended), SSH in and place the files:

```bash
mkdir -p /mnt/.ix-apps/app_configs/blackpearl/versions/1.0.0/templates/rendered/vpn

# From your workstation, copy the NordVPN config and credentials:
scp client.ovpn admin@<truenas-ip>:/mnt/.ix-apps/app_configs/blackpearl/versions/1.0.0/templates/rendered/vpn/client.ovpn
scp auth.txt    admin@<truenas-ip>:/mnt/.ix-apps/app_configs/blackpearl/versions/1.0.0/templates/rendered/vpn/auth.txt
```

See `blackpearl/vpn/client.ovpn` and `blackpearl/vpn/auth.txt` in this repo for format instructions.

### Step 6 — blackpearl only: create config directories

Create the host paths used for app config volumes:

```bash
ssh admin@<truenas-ip>
mkdir -p <your-config-paths-from-.env>
```

The exact paths are whatever you set for `RADARR_CONFIG_PATH`, `SONARR_CONFIG_PATH`, etc. in your `.env`.

---

## Updating Compose Files

After changing a `compose.yaml` template in this repo:

1. Re-run `./render.sh <app>` to regenerate the rendered file
2. In TrueNAS UI: Apps → select the app → Edit → paste the updated rendered YAML → Save

The `.env` file is unaffected by UI edits.

---

## Traefik: How Service Discovery Works

There are three Traefik instances, each watching a distinct Docker network and using unique entrypoint names:

| Instance | Network | HTTP entrypoint | HTTPS entrypoint | IP | Accessible from |
|---|---|---|---|---|---|
| `traefik-private` | `traefik-private` | `web-private` | `websecure-private` | `TRAEFIK_PRIVATE_IP` | Local LAN |
| `traefik-public` | `traefik-public` | `web-public` | `websecure-public` | `TRAEFIK_PUBLIC_IP` | Internet |
| `traefik-aredn` | `traefik-aredn` | `web-aredn` | — (HTTP only) | `TRAEFIK_AREDN_IP` | AREDN mesh |

### How isolation works

Two things control which Traefik instance exposes a service:

1. **Network membership** — a container must be attached to a Traefik instance's network for that instance to see it at all. A container not on `traefik-private`'s network is completely invisible to it.
2. **Entrypoint name** — a router is only activated by the Traefik instance that owns a matching entrypoint name.

Entrypoint names are **unique per instance** (`web-private`, `web-public`, `web-aredn`) so there is no ambiguity even if a container is attached to multiple networks. The router name suffix (e.g. `-private`, `-aredn`) is a **human convention only** — Traefik ignores the router name itself.

All instances run with `--providers.docker.exposedByDefault=false`, so every service must explicitly opt in with `traefik.enable=true`.

### Pattern 1 — Expose to one Traefik instance only

Attach the container to one network and define one router using that instance's entrypoint:

```yaml
# In the service's networks section:
networks:
  - traefik-private

# In the service's labels:
labels:
  - traefik.enable=true
  - traefik.http.routers.myapp-private.rule=Host(`myapp.example.com`)
  - traefik.http.routers.myapp-private.entrypoints=websecure-private
  - traefik.http.routers.myapp-private.tls.certresolver=mydnschallenge
  - traefik.http.routers.myapp-private.service=myapp
  - traefik.http.services.myapp.loadbalancer.server.port=8080
```

### Pattern 2 — Expose the same port to multiple Traefik instances

Attach the container to multiple networks, define one router per instance, and point both at a shared service definition:

```yaml
networks:
  - traefik-private
  - traefik-aredn

labels:
  - traefik.enable=true

  # Private — HTTPS
  - traefik.http.routers.myapp-private.rule=Host(`myapp.example.com`)
  - traefik.http.routers.myapp-private.entrypoints=websecure-private
  - traefik.http.routers.myapp-private.tls.certresolver=mydnschallenge
  - traefik.http.routers.myapp-private.service=myapp

  # AREDN — HTTP
  - traefik.http.routers.myapp-aredn.rule=Host(`myapp.mesh.local`)
  - traefik.http.routers.myapp-aredn.entrypoints=web-aredn
  - traefik.http.routers.myapp-aredn.service=myapp

  # Shared service definition — one port, used by both routers above
  - traefik.http.services.myapp.loadbalancer.server.port=8080
```

### HTTP → HTTPS redirect middleware

The `traefik-private` and `traefik-public` instances each define a named redirect middleware on their own container:

| Instance | Middleware name |
|---|---|
| `traefik-private` | `redirect-to-https-private` |
| `traefik-public` | `redirect-to-https-public` |

This is opt-in per service. When a service wants to enforce HTTPS, it defines **two routers** for the relevant instance: one on the `web-*` entrypoint that applies the redirect middleware, and one on the `websecure-*` entrypoint that serves TLS traffic. Services that intentionally serve only HTTP (e.g. AREDN mesh apps) simply omit both the `web-*` router and the middleware entirely.

```yaml
labels:
  - traefik.enable=true
  - traefik.http.services.myapp.loadbalancer.server.port=8080

  # HTTP router — redirects to HTTPS
  - traefik.http.routers.myapp-private-web.rule=Host(`myapp.example.com`)
  - traefik.http.routers.myapp-private-web.entrypoints=web-private
  - traefik.http.routers.myapp-private-web.middlewares=redirect-to-https-private@docker
  - traefik.http.routers.myapp-private-web.service=myapp

  # HTTPS router — serves traffic
  - traefik.http.routers.myapp-private.rule=Host(`myapp.example.com`)
  - traefik.http.routers.myapp-private.entrypoints=websecure-private
  - traefik.http.routers.myapp-private.tls.certresolver=mydnschallenge
  - traefik.http.routers.myapp-private.service=myapp
```

The `@docker` suffix in the middleware reference tells Traefik to look for the middleware in the Docker provider, which is where it is defined (on the Traefik container's own labels). Without the suffix Traefik would look in the same compose file — the suffix makes the cross-container reference explicit and unambiguous.

### Pattern 3 — Expose different ports to different Traefik instances

Define a separate named service per instance, each with its own port:

```yaml
labels:
  - traefik.enable=true

  - traefik.http.routers.myapp-private.entrypoints=websecure-private
  - traefik.http.routers.myapp-private.service=myapp-private-svc
  - traefik.http.services.myapp-private-svc.loadbalancer.server.port=8080

  - traefik.http.routers.myapp-aredn.entrypoints=web-aredn
  - traefik.http.routers.myapp-aredn.service=myapp-aredn-svc
  - traefik.http.services.myapp-aredn-svc.loadbalancer.server.port=9090
```

### Note on VPN-gated services (blackpearl)

Because all blackpearl app containers share the `vpn` container's network namespace, **all Traefik labels must be placed on the `vpn` service**, not on the individual app containers. The `vpn` service is the container Traefik can reach; you reference the app's port explicitly in the service definition.

---

## Security Notes

- `.env` files contain credentials and must never be committed to the repo — they are listed in `.gitignore`
- `blackpearl/vpn/client.ovpn` and `blackpearl/vpn/auth.txt` are also excluded from the repo
- The `vpn` container runs with `FIREWALL=1` which drops all non-VPN outbound traffic from the pod — app containers cannot reach the internet except through the NordVPN tunnel
- Traefik instances only bind to specific IPs, not `0.0.0.0`, limiting exposure to the intended network interface

---

## Host Firewall Rules

Some apps use `network_mode: host` which bypasses Docker's network isolation and binds directly to all host interfaces. For these apps, use `nftables` rules on the TrueNAS host to restrict which interfaces can reach the service.

### Plex — block access from AREDN (`eno2`)

Plex uses `network_mode: host` to support GDM multicast discovery across VLANs. This means it also listens on the AREDN mesh interface (`eno2`), which is undesirable. Block inbound Plex traffic on that interface:

```bash
# Block inbound Plex traffic (TCP + UDP) arriving on the AREDN interface
nft add rule inet filter input iifname "eno2" tcp dport { 32400, 32469, 8324 } drop
nft add rule inet filter input iifname "eno2" udp dport { 32400, 32410, 32412, 32413, 32414, 1900 } drop
```

**Making the rules persistent across reboots:**

TrueNAS does not persist ad-hoc `nft` commands across reboots. To make these rules survive restarts, save them to a file and add a startup script:

```bash
# Save the current ruleset
nft list ruleset > /mnt/.ix-apps/nftables-custom.conf

# Create a startup init script (TrueNAS Scale uses systemd)
cat <<'EOF' > /etc/systemd/system/nftables-custom.service
[Unit]
Description=Custom nftables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/nft -f /mnt/.ix-apps/nftables-custom.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nftables-custom
```

> **Note:** TrueNAS system updates may overwrite files outside of `/mnt`. Storing the rules file under `/mnt/.ix-apps/` ensures it survives updates. Verify after any major TrueNAS upgrade that the service unit is still present.
