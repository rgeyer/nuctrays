local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local config = import 'config.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service;

local grafanaAgent = import '0.26/main.libsonnet';
local grafanaAgentIntegration = grafanaAgent.monitoring.v1alpha1.integration;

config {
  redis_container::
    container.new('redis', $._images.redis) +
    container.withPorts([
      containerPort.new('redis', 6379),
    ]),

  redis_deployment:
    deployment.new('redis', 1, [$.redis_container]) +
    deployment.mixin.metadata.withNamespace($._config.namespace),

  service:
    k.util.serviceFor($.redis_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),  

  grafanaAgentIntegration:
    grafanaAgentIntegration.new('redis') +
    grafanaAgentIntegration.spec.withName('redis') +
    grafanaAgentIntegration.spec.type.withUnique(false) +
    grafanaAgentIntegration.metadata.withLabels({agent: 'grafana-agent-metrics'}) +
    grafanaAgentIntegration.spec.withConfig({
      redis_addr: 'redis.%s.svc.cluster.local' % $._config.namespace,
      autoscrape: {
        enable: true,
        metrics_instance: 'grafana-agent/primary-me',
      },
    }),
}