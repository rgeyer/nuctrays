local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      containerPort = k.core.v1.containerPort,
      service = k.core.v1.service;

local config = import 'config.libsonnet';

local ingress = import 'k8sutils/traefikingress.libsonnet';

local mw = import 'traefik/mymiddlewares.libsonnet';

config + mw {
  _images+:: {
    nginx: 'nginx:1.21',
  },

  _config+:: {
    namespace: 'plainnginx',
  },

  namespace: k.core.v1.namespace.new($._config.namespace),

  nginx_container::
    container.new('nginx', $._images.nginx) +
    container.withPorts([
      containerPort.newNamed(name='http', containerPort=80),
    ]),

  nginx_deployment:
    deployment.new('nginx', 1, $.nginx_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace),

  nginx_service:
    k.util.serviceFor($.nginx_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  nginx_ingress_route:: {
    kind: 'Rule',
    match: 'Host(`madmin.lsmpogo.com`) && PathPrefix(`/atvtest`)',
    services: [{name: 'nginx', port: 80}],
    middlewares: [{name: 'stripprefixes', namespace: 'traefik'}],
  },

  nginx_ingress:
    ingress.new('foobarbaz', ['web', 'websecure'], $.nginx_ingress_route) +
    ingress.withNamespace($._config.namespace) +
    ingress.withLabels({traefikzone: 'public'}),
}
