local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service;

local traefikingress = import 'traefik/ingress.libsonnet';
local traefik = import 'traefik/2.8.0/main.libsonnet';
local tIngress = traefik.traefik.v1alpha1.ingressRoute;

local namespace = 'hackathon202408';

{

  namespace:
    k.core.v1.namespace.new(namespace),

  container::
    container.new('hackathon202408', 'registry.ryangeyer.com/grafana-health:latest') +    
    container.withImagePullPolicy('Always') +
    container.withArgs(['-b', '0.0.0.0:8080', '-s', '/tmp']) +
    container.withPorts([
      k.core.v1.containerPort.new('http', 8080),
    ]),

  deployment:
    deployment.new('hackathon202408', 1, $.container) +
    deployment.mixin.metadata.withNamespace(namespace),

  service:
    k.util.serviceFor($.deployment) +
    service.mixin.metadata.withNamespace(namespace),

  ingress:
    traefikingress.newIngressRoute('hackathon202408', namespace, 'hackathon202408.ryangeyer.com', 'hackathon202408', 8080, true),
}
