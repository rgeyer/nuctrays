local k = import 'ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service;

{
  webhooklogger_container::
    container.new('webhooklogger', 'registry.ryangeyer.com/webhooklogger') +
    container.withPorts([
      containerPort.new('http', 8090),
    ]),

  webhooklogger_deployment:
    deployment.new('webhooklogger', 1, $.webhooklogger_container) +
    deployment.mixin.metadata.withNamespace('mad'),

  webhooklogger_service:
    k.util.serviceFor($.webhooklogger_deployment) +
    service.mixin.metadata.withNamespace('mad'),
}
