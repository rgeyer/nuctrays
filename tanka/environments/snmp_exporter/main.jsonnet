local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      configMap = k.core.v1.configMap;

// Note: I'm using default namespace, thus the lack of namespace definitions on all of these.
{
  cm:
    configMap.new('snmp-exporter-config') +
    configMap.withData({
      'snmp.yml': importstr './data/snmp.yml',
    }),

  container::
    container.new('snmp-exporter', 'ricardbejarano/snmp_exporter') +
    container.withArgs(['--config.file=/etc/snmp_exporter/snmp.yml']) +
    container.withPorts([
      containerPort.new('http-metrics', 9116)
    ]),

  deployment:
    deployment.new('snmp-exporter', 1, $.container, podLabels={ name: 'snmp-exporter' }) +
    k.util.configMapVolumeMount($.cm, '/etc/snmp_exporter'),

  service:
    k.util.serviceFor($.deployment)
}
