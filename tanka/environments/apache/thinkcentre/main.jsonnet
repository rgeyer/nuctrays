local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      containerPort = k.core.v1.containerPort,
      service = k.core.v1.service;

local grafanaAgent = import '0.26/main.libsonnet';
local grafanaAgentIntegration = grafanaAgent.monitoring.v1alpha1.integration;

{
  container::
    container.new('apache', 'httpd:2.4') +
    container.withCommand(['bash', '-c']) +
    container.withArgs([|||
      cat << EOF >> /usr/local/apache2/conf/httpd.conf
      <Location "/server-status">
          SetHandler server-status
          # Require host example.com
      </Location>
      EOF

      httpd-foreground
    |||]) +
    container.withPorts([
      containerPort.new('http', 80),
    ]),

  deployment:
    deployment.new('apache', 1, $.container),

  service:
    k.util.serviceFor($.deployment),

  grafanaAgentIntegration:
    grafanaAgentIntegration.new('apache-test') +
    grafanaAgentIntegration.spec.withName('apache_http') +
    grafanaAgentIntegration.spec.type.withUnique(false) +
    grafanaAgentIntegration.metadata.withLabels({agent: 'grafana-agent-metrics'}) +
    grafanaAgentIntegration.spec.withConfig({
      instance: 'apache.default.svc.cluster.local', # If this is not provided, the integration fails with a nil pointer ref
      scrape_uri: 'http://apache.default.svc.cluster.local/server-status?auto',
      autoscrape: {
        enable: true,
        metrics_instance: 'grafana-agent/primary-me',
      },
    }),
}
