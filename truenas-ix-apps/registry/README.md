# registry

Plain `registry:2` instance used to host custom-built images (currently just [`openhamclock`](../openhamclock/)) that aren't published on Docker Hub.

## Peculiarities

### TLS terminates at Traefik, not in the registry

The `registry:2` container itself speaks plain HTTP on port 5000. TLS is provided by `traefik-private` via the standard `websecure-private` entrypoint + Let's Encrypt cert. This matters because:

- Docker clients **require HTTPS** to push/pull unless the registry hostname is in `insecure-registries`. Since Traefik provides a real Let's Encrypt cert here, no insecure-registry config is needed on clients.
- The compose file deliberately omits a `traefik.http.services.registry.loadbalancer.server.port` label because `registry:2` exposes only port 5000, which Traefik will autodetect. If you swap images, set the port explicitly.

### `REGISTRY_HOST` must be DNS-resolvable to `TRAEFIK_PRIVATE_IP`

Otherwise both the registry's own clients and the `openhamclock` app (which references `${REGISTRY_HOST}/openhamclock:latest`) will fail to pull.

### Deploy before `openhamclock`

`openhamclock` will fail to pull its image if the registry is not running. Order of operations:

1. Deploy `registry`.
2. Push the openhamclock image to it from a build host.
3. Deploy `openhamclock`.

### `REGISTRY_DATA_PATH` must exist on the host

Bind-mounted at `/var/lib/registry`. Create it first:

```bash
mkdir -p /path/to/registry/data
```

If the path doesn't exist Docker will create it as root-owned, which is fine for `registry:2` since it also runs as root by default — but if you ever change the image to one that runs unprivileged, fix ownership accordingly.

### No authentication is configured

Anyone who can reach `TRAEFIK_PRIVATE_IP` can push/pull. Acceptable on a trusted LAN; add `REGISTRY_AUTH=htpasswd` + a volume-mounted htpasswd file before exposing on `traefik-public`.
