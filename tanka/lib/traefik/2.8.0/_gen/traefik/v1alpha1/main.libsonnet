{
  local d = (import 'doc-util/main.libsonnet'),
  '#':: d.pkg(name='v1alpha1', url='', help=''),
  ingressRoute: (import 'ingressRoute.libsonnet'),
  ingressRouteTCP: (import 'ingressRouteTCP.libsonnet'),
  ingressRouteUDP: (import 'ingressRouteUDP.libsonnet'),
  middleware: (import 'middleware.libsonnet'),
  middlewareTCP: (import 'middlewareTCP.libsonnet'),
  serversTransport: (import 'serversTransport.libsonnet'),
  tlsOption: (import 'tlsOption.libsonnet'),
  tlsStore: (import 'tlsStore.libsonnet'),
  traefikService: (import 'traefikService.libsonnet'),
}
