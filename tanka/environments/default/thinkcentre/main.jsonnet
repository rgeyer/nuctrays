local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      envFrom = k.core.v1.envFromSource,
      policyRule = k.rbac.v1.policyRule,
      secret = k.core.v1.secret,
      service = k.core.v1.service,
      serviceAccount = k.core.v1.serviceAccount,
      statefulSet = k.apps.v1.statefulSet,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount;

local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local parseYaml = std.native('parseYaml');

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local traefik = import 'traefik/main.libsonnet',
      traefikingress = import 'traefik/ingress.libsonnet',
      traefikmiddlewares = import 'traefik/mymiddlewares.libsonnet';

local prom = import '0.57/main.libsonnet';
local pm = prom.monitoring.v1.podMonitor;

config + secrets {
  _images+:: {
    traefik: 'traefik:2.8',
    registry: 'registry:2.8.1',
  },

  _config+:: {
    registry:: {
      pvc: {
        nfsHost: '192.168.42.10',
        nfsPath: '/kubestore/registry',
      },
    },
  },

  // Bootstrap Namespaces
  namespaces: {
    [ns]: k.core.v1.namespace.new(ns)
    for ns in ['sharedsvc', 'ktraefik', 'ptraefik', 'traefik', 'mad', 'o11y', 'madasync', 'rdm']
  },

  // Calico static ip pool
  calicostaticpool: {
    apiVersion: 'crd.projectcalico.org/v1',
    kind: 'IPPool',
    metadata: {
      name: 'static',
    },
    spec: {
      blockSize: 26,
      cidr: '10.43.0.0/24',
      ipipMode: 'Never',
      nodeSelector: '!all()',
      vxlanMode: 'Never',
    },
  },

  certbot_secrets: {
    [ns]:
      secret.new('certbot-route53', {}) +
      secret.withStringData({
        AWS_ACCESS_KEY_ID: $._config.certbot.access_key_id,
        AWS_SECRET_ACCESS_KEY: $._config.certbot.secret_access_key,
      }) +
      secret.mixin.metadata.withNamespace(ns)
    for ns in ['ktraefik', 'ptraefik']
  },

  // Traefik begins here.
  // CRDs. I'm cheating a bit here and taking them from the chart
  traefikCrds: {
    ingressRoute: parseYaml(importstr '../../../charts/traefik/crds/ingressroute.yaml'),
    ingressRouteTCP: parseYaml(importstr '../../../charts/traefik/crds/ingressroutetcp.yaml'),
    ingressRouteUDP: parseYaml(importstr '../../../charts/traefik/crds/ingressrouteudp.yaml'),
    middlewares: parseYaml(importstr '../../../charts/traefik/crds/middlewares.yaml'),
    middlewaresTCP: parseYaml(importstr '../../../charts/traefik/crds/middlewarestcp.yaml'),
    serversTransports: parseYaml(importstr '../../../charts/traefik/crds/serverstransports.yaml'),
    tlsOptions: parseYaml(importstr '../../../charts/traefik/crds/tlsoptions.yaml'),
    tlsStores: parseYaml(importstr '../../../charts/traefik/crds/tlsstores.yaml'),
    traefikServices: parseYaml(importstr '../../../charts/traefik/crds/traefikservices.yaml'),
  },

  // My middlewares
  // TODO: This, plus the default ingress routes use the namespace `traefik` for the middleware config location. I think it should probably be in either default, or ktraefik
  traefikredirect: traefikmiddlewares.redirect,

  ktraefik: traefik.new(
    'ktraefik',
    'ktraefik',
    $._images.traefik,
    'ktraefik.ryangeyer.com',
    '10.43.0.16',
    $._config.traefik.private.pvc.nfsHost,
    $._config.traefik.private.pvc.nfsPath,
    'certbot-route53'
  ),

  ptraefik: traefik.new(
    'ptraefik',
    'ptraefik',
    $._images.traefik,
    'ptraefik.ryangeyer.com',
    '10.43.0.17',
    $._config.traefik.public.pvc.nfsHost,
    $._config.traefik.public.pvc.nfsPath,
    'certbot-route53',
    'traefikzone=public',
  ),

  traefikPodMonitor:
    pm.new('traefik') +
    pm.metadata.withLabels({instance: 'primary-me'}) +
    pm.spec.selector.withMatchLabels({name: 'traefik'}) +
    pm.spec.namespaceSelector.withAny(true) +
    pm.spec.withPodMetricsEndpoints([
      pm.spec.podMetricsEndpoints.withHonorLabels(true) +
      pm.spec.podMetricsEndpoints.withPort('http-metrics')
    ]),

  registrypvc:
    nfspvc.new('default', $._config.registry.pvc.nfsHost, $._config.registry.pvc.nfsPath, 'registry'),

  registryContainer::
    container.new('registry', $._images.registry) +
    container.withEnv([
      k.core.v1.envVar.new('REGISTRY_HTTP_DEBUG_PROMETHEUS_ENABLED', 'true'),
      k.core.v1.envVar.new('REGISTRY_HTTP_DEBUG_ADDR', ':5001')
    ]) +
    container.withPorts([
      containerPort.new('registry', 5000),
      containerPort.new('http-metrics', 5001),
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('registry', '/var/lib/registry'),
    ]),

  registryStatefulSet:
    statefulSet.new('registry', 1, $.registryContainer) +
    statefulSet.spec.withServiceName('registry') +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromPersistentVolumeClaim('registry', 'registry-pvc'),
    ]) +
    statefulSet.mixin.metadata.withNamespace('default'),

  registryService:
    k.util.serviceFor($.registryStatefulSet) +
    service.mixin.metadata.withNamespace('default'),

  registryIngress:
    traefikingress.newIngressRoute('registry', 'default', 'registry.ryangeyer.com', 'registry', 5000),

  registryPodMonitor:
    pm.new('registry') +
    pm.metadata.withLabels({instance: 'primary-me'}) +
    pm.spec.selector.withMatchLabels({name: 'registry'}) +
    pm.spec.withPodMetricsEndpoints([
      pm.spec.podMetricsEndpoints.withHonorLabels(true) +
      pm.spec.podMetricsEndpoints.withPort('http-metrics')
    ]),
}
