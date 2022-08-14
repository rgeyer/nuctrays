local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment;

local prom = import '0.57/main.libsonnet';
local pm = prom.monitoring.v1.podMonitor;

{
  newContainer(image='jraviles/prometheus_speedtest:latest'):: {
    container::
      container.new('speedtest', image) +
      container.withPorts([
        containerPort.new('http', 9516),
      ]) +
      container.livenessProbe.withFailureThreshold(3) +
      container.livenessProbe.httpGet.withPort('http') +
      container.livenessProbe.httpGet.withPath('/') +
      container.livenessProbe.httpGet.withScheme('HTTP') +
      container.readinessProbe.withFailureThreshold(1) +
      container.readinessProbe.httpGet.withPort('http') +
      container.readinessProbe.httpGet.withPath('/') +
      container.readinessProbe.httpGet.withScheme('HTTP'),
  },

  newDeployment(image='jraviles/prometheus_speedtest:latest', namespace):: {
    namespace:: namespace,

    deployment:
      deployment.new('speedtest', 1, $.newContainer(image).container) +
      deployment.metadata.withNamespace(namespace),
  },

  withGrafanaAgentPodMonitor():: {
    local this = self,

    podMonitor:
      pm.new('speedtest') +
      pm.metadata.withLabels({ instance: 'primary-me' }) +
      pm.spec.selector.withMatchLabels({ name: 'speedtest' }) +
      pm.spec.namespaceSelector.withMatchNames([this.namespace]) +
      pm.spec.withPodMetricsEndpoints([
        pm.spec.podMetricsEndpoints.withHonorLabels(true) +
        pm.spec.podMetricsEndpoints.withPort('http') +
        pm.spec.podMetricsEndpoints.withPath('/probe') +
        pm.spec.podMetricsEndpoints.withInterval('10m') +
        pm.spec.podMetricsEndpoints.withScrapeTimeout('2m'),
      ]),
  },
}
