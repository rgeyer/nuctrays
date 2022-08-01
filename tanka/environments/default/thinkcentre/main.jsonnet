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

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local traefikingress = import 'traefik/ingress.libsonnet',
      traefikmiddlewares = import 'traefik/mymiddlewares.libsonnet';

config + secrets {
  _images+:: {
    traefik: 'traefik:2.8',
  },

  // Bootstrap Namespaces
  namespaces: {
    [ns]: k.core.v1.namespace.new(ns)
    for ns in ['sharedsvc', 'ktraefik', 'ptraefik', 'traefik']
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

  traefikrac:: [
    policyRule.withApiGroups(['']) +
    policyRule.withResources(['services', 'endpoints', 'secrets']) +
    policyRule.withVerbs(['get', 'list', 'watch']),

    policyRule.withApiGroups(['extensions', 'networking.k8s.io']) +
    policyRule.withResources(['ingresses', 'ingressclasses']) +
    policyRule.withVerbs(['get', 'list', 'watch']),

    policyRule.withApiGroups(['extensions']) +
    policyRule.withResources(['ingresses/status']) +
    policyRule.withVerbs(['update']),

    policyRule.withApiGroups(['traefik.containo.us']) +
    policyRule.withResources([
      'middlewares',
      'middlewaretcps',
      'ingressroutes',
      'traefikservices',
      'ingressroutetcps',
      'ingressrouteudps',
      'tlsoptions',
      'tlsstores',
      'serverstransports',
    ]) +
    policyRule.withVerbs(['get', 'list', 'watch']),
  ],

  ktraefikrbac: k { _config+:: { namespace: 'ktraefik' } }.util.rbac('ktraefik', $.traefikrac) {
    service_account+: serviceAccount.mixin.metadata.withNamespace('ktraefik'),
  },

  ktraefik_pvc: nfspvc.new(
    'ktraefik',
    $._config.traefik.private.pvc.nfsHost,
    $._config.traefik.private.pvc.nfsPath,
    'ktraefik',
  ),

  ktraefik_container::
    container.new('ktraefik', $._images.traefik) +
    container.withEnvFrom(envFrom.secretRef.withName('certbot-route53')) +
    container.withPorts([
      containerPort.new('web', 80),
      containerPort.new('websecure', 443),
      containerPort.new('metrics', 8080),
    ]) +
    container.withArgsMixin([
      '--api.dashboard=true',
      '--entrypoints.web.Address=:80',
      '--entrypoints.websecure.Address=:443',
      '--providers.kubernetescrd',
      '--providers.kubernetescrd.allowCrossNamespace=true',
      '--certificatesresolvers.mydnschallenge.acme.dnschallenge=true',
      '--certificatesresolvers.mydnschallenge.acme.dnschallenge.provider=route53',
      '--certificatesresolvers.mydnschallenge.acme.email=qwikrex@gmail.com',
      '--certificatesresolvers.mydnschallenge.acme.storage=/etc/traefik/acme/acme.json',
      '--metrics.prometheus=true',
      '--metrics.prometheus.addEntryPointsLabels=true',
      '--metrics.prometheus.addServicesLabels=true',
      // These are implicit, but adding them for the sake of clarity
      '--entrypoints.traefik.Address=:8080',
      '--metrics.prometheus.entryPoint=traefik',
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('ktraefik', '/etc/traefik/acme'),
    ]),

  ktraefik_statefulset:
    statefulSet.new('traefik', 1, $.ktraefik_container) +
    statefulSet.spec.withServiceName('traefik') +
    statefulSet.mixin.metadata.withNamespace('ktraefik') +
    statefulSet.spec.template.metadata.withAnnotations({
      'cni.projectcalico.org/ipAddrs': '["%(ip)s"]' % { ip: '10.43.0.16' },
    }) +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromPersistentVolumeClaim('ktraefik', 'ktraefik-pvc'),
    ]) +
    statefulSet.spec.template.spec.withServiceAccountName('ktraefik'),

  ktraefik_svc:
    k.util.serviceFor($.ktraefik_statefulset) +
    service.mixin.metadata.withNamespace('ktraefik'),

  ktraefikingress: traefikingress.newTraefikServiceIngressRoute('ktraefik', 'ktraefik', 'ktraefik.ryangeyer.com', 'api@internal'),
}
