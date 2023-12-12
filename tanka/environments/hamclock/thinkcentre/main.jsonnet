local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service;

local traefikingress = import 'traefik/ingress.libsonnet';
local traefik = import 'traefik/2.8.0/main.libsonnet';
local tIngress = traefik.traefik.v1alpha1.ingressRoute;

local namespace = 'ham';

{
  container::
    container.new('ft8-hamclock', 'registry.ryangeyer.com/hamclock:latest') +    
    container.withImagePullPolicy('Always') +
    container.withEnv([
      k.core.v1.envVar.new('CALLSIGN', 'KO6CAY'),
      k.core.v1.envVar.new('LOCATOR', 'CM94sq'),
      k.core.v1.envVar.new('LAT', '34.6911213'),
      k.core.v1.envVar.new('LONG', '-120.4653985'),
      k.core.v1.envVar.new('UTC_OFFSET', '-8'),
      k.core.v1.envVar.new('VOACAP_MODE', '13'),  // CW=19 SSB=38 AM=49 WSPR=3 FT8=13 FT4=17
      k.core.v1.envVar.new('VOACAP_POWER', '10'),
      k.core.v1.envVar.new('CALLSIGN_BACKGROUND_COLOR', '0,0,0'),
      k.core.v1.envVar.new('CALLSIGN_BACKGROUND_RAINBOW', '0'),
      k.core.v1.envVar.new('CALLSIGN_COLOR', '123,3,252'),
      k.core.v1.envVar.new('FLRIG_PORT', '12345'),
      k.core.v1.envVar.new('FLRIG_HOST', 'localhost'),
      k.core.v1.envVar.new('USE_FLRIG', '0'),
      k.core.v1.envVar.new('USE_METRIC', '1'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('admin-http', 8080),      
      k.core.v1.containerPort.new('http', 8081),
    ]),

  deployment:
    deployment.new('ft8-hamclock', 1, $.container) +
    deployment.mixin.metadata.withNamespace(namespace),

  service:
    k.util.serviceFor($.deployment) +
    service.mixin.metadata.withNamespace(namespace),

  ingress:
    traefikingress.newIngressRoute('ft8-hamclock', namespace, 'ft8-hamclock.ko6cay.radio', 'ft8-hamclock', 8081, true),

  // hamclock_traefik_replace_path_middleware:
  //   {
  //     apiVersion: 'traefik.containo.us/v1alpha1',
  //     kind: 'Middleware',
  //     metadata: {
  //       name: 'hamclock-replace-path-mw',
  //       labels: {
  //         traefikzone: 'public',
  //       },
  //     },
  //     spec: {
  //       replacePath: { path: '/live.html' },
  //     },
  //   },

  // ingress:
  //   tIngress.new('ft8-hamclock') +
  //   tIngress.metadata.withNamespace(namespace) +
  //   tIngress.metadata.withLabelsMixin({
  //     traefikzone: 'public',
  //   }) +
  //   tIngress.spec.withEntryPoints(['web']) +
  //   tIngress.spec.withRoutes([
  //     tIngress.spec.routes.withKind('Rule') +
  //     tIngress.spec.routes.withMatch('Host(`ft8-hamclock.ko6cay.radio`)') +
  //     tIngress.spec.routes.withMiddlewares(
  //       tIngress.spec.routes.middlewares.withName('redirect-websecure') +
  //       tIngress.spec.routes.middlewares.withNamespace('traefik'),
  //     ) +
  //     tIngress.spec.routes.withServices(
  //       tIngress.spec.routes.services.withName('ft8-hamclock') +
  //       tIngress.spec.routes.services.withPort(8081),
  //     ),
  //   ]),

  // ingresstls:
  //   tIngress.new('ft8-hamclock-tls') +
  //   tIngress.metadata.withNamespace(namespace) +
  //   tIngress.metadata.withLabelsMixin({
  //     traefikzone: 'public',
  //   }) +
  //   tIngress.spec.withEntryPoints(['websecure']) +
  //   tIngress.spec.withRoutes([
  //     tIngress.spec.routes.withKind('Rule') +
  //     tIngress.spec.routes.withMatch('Host(`ft8-hamclock.ko6cay.radio`)') +
  //     tIngress.spec.routes.withMiddlewares(
  //       tIngress.spec.routes.middlewares.withName('hamclock-replace-path-mw') +
  //       tIngress.spec.routes.middlewares.withNamespace(namespace),
  //     ) +
  //     tIngress.spec.routes.withServices(
  //       tIngress.spec.routes.services.withName('ft8-hamclock') +
  //       tIngress.spec.routes.services.withPort(8081),
  //     ),
  //   ]) +
  //   tIngress.spec.tls.withCertResolver('mydnschallenge'),

}
