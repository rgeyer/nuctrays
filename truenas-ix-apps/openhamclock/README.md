# openhamclock

HamClock web UI, exposed simultaneously on all three Traefik instances (private, public, AREDN).

## Peculiarities

### Image is pulled from the private `registry` app

`image: ${REGISTRY_HOST}/openhamclock:latest` — the binary is **not** on Docker Hub. The [`registry`](../registry/) app must be deployed first, and the openhamclock image must have been pushed to it before this stack can start. From a build host:

```bash
docker build -t ${REGISTRY_HOST}/openhamclock:latest .
docker push ${REGISTRY_HOST}/openhamclock:latest
```

(Where the `Dockerfile` lives is outside the scope of this repo.)

### Attached to all three Traefik networks at once

This is the canonical example of **Pattern 2** in the main [`../README.md`](../README.md) (Expose the same port to multiple Traefik instances). One shared `traefik.http.services.openhamclock` definition on port 3000, fronted by three router groups:

- `openhamclock-private` (+ `-private-web` redirect) → `OPENHAMCLOCK_HOST` on `traefik-private`
- `openhamclock-public` (+ `-public-web` redirect) → `OPENHAMCLOCK_HOST` on `traefik-public`
- `openhamclock-aredn` → `OPENHAMCLOCK_AREDN_HOST` on `traefik-aredn` (HTTP only, no redirect)

The private and public routers intentionally share the **same** hostname (`OPENHAMCLOCK_HOST`) — DNS decides which Traefik instance a client hits based on whether it resolves the hostname to `TRAEFIK_PRIVATE_IP` or `TRAEFIK_PUBLIC_IP`. The AREDN router uses a distinct `.local.mesh` hostname.

### UDP port 2237 is published directly on `HOST_IP`

HamClock listens on UDP/2237 for a [secondary control protocol](https://www.clearskyinstitute.com/ham/HamClock/) that does not flow through Traefik. The compose file publishes it explicitly with `${HOST_IP}:2237:2237/udp`, so it's only reachable on the primary LAN IP, not on all interfaces.

### Health check uses `/api/health`

The image must serve `/api/health` on port 3000 for the healthcheck to pass. If you bake a different HamClock build, adjust either the endpoint or the healthcheck command.
