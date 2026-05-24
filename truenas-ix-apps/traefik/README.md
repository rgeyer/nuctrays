# traefik

Three Traefik reverse-proxy instances running side-by-side, one per Docker network.

| Instance | Network | Entrypoints | Binds to | Purpose |
|---|---|---|---|---|
| `traefik-private` | `traefik-private` | `web-private` (80), `websecure-private` (443) | `TRAEFIK_PRIVATE_IP` | LAN-only services |
| `traefik-public` | `traefik-public` | `web-public` (80), `websecure-public` (443) | `TRAEFIK_PUBLIC_IP` | Internet-facing services |
| `traefik-aredn` | `traefik-aredn` | `web-aredn` (80) | `TRAEFIK_AREDN_IP` | AREDN mesh (HTTP only) |

See the main [`../README.md`](../README.md) — sections **Traefik: How Service Discovery Works**, **HTTP → HTTPS redirect middleware**, and the three exposure patterns — for the labels services must set on themselves.

## Peculiarities

### Deploy this app first

`traefik`'s compose file is what **creates** the `traefik-private`, `traefik-public`, and `traefik-aredn` Docker networks. Every other app in this repo references them as `external: true`, so they must exist before any other app is deployed.

If you previously created the networks manually with `docker network create`, that is fine — compose will adopt them.

### Public IP alias must exist before deploy

`traefik-public` binds directly to `TRAEFIK_PUBLIC_IP`, which must be configured as an alias on `eno1` first. See the **One-Time Host Setup → Assign the public IP alias** section in the main README.

### ACME storage files must be pre-created with mode 0600

Traefik refuses to start if the `acme.json` file is world-readable. Create both files before first deploy:

```bash
touch /mnt/.ix-apps/app_configs/traefik/acme-private.json
touch /mnt/.ix-apps/app_configs/traefik/acme-public.json
chmod 600 /mnt/.ix-apps/app_configs/traefik/acme-*.json
```

Because these paths live under `/mnt/.ix-apps/app_configs/traefik/` (not under the usual `versions/1.0.0/templates/rendered/`), you do **not** need to deploy the placeholder app first — the parent directory can be created directly with `mkdir -p`.

### Route53 DNS-01 challenge

Both `traefik-private` and `traefik-public` use the Let's Encrypt DNS-01 challenge via AWS Route53. The AWS IAM credentials in `.env` need permission to create/delete `TXT` records on the relevant hosted zone(s). The `traefik-aredn` instance has no TLS resolver — AREDN mesh traffic is HTTP only.

### Redirect middlewares are defined on the Traefik containers themselves

`redirect-to-https-private` and `redirect-to-https-public` are declared as labels on the `traefik-private` and `traefik-public` containers (not in a separate file). Services reference them as `redirect-to-https-private@docker` / `redirect-to-https-public@docker` — the `@docker` suffix is required so Traefik knows to resolve the middleware against the Docker provider rather than the current compose file.

### `--api.insecure=true` exposes the dashboard on :8080

Each instance publishes its dashboard on port 8080 of its bound IP. This is convenient for debugging but means anyone who can reach the IP can reach the dashboard. Treat the bound IPs accordingly (the public IP dashboard in particular is reachable from the internet — consider firewalling 8080 externally or disabling `--api.insecure` once stable).
