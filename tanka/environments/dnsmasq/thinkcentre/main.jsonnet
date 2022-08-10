local dnsmasq = (import 'dnsmasq/main.libsonnet');
local grafanaAgent = import '0.26/main.libsonnet';
local grafanaAgentIntegration = grafanaAgent.monitoring.v1alpha1.integration;

{
  dnsmasq: dnsmasq.new('strm/dnsmasq:latest', 'sharedsvc', '10.43.0.2', '10.43.0.3'),

  ga_dnsmasq1_integration:
    grafanaAgentIntegration.new('dnsmasq1') +
    grafanaAgentIntegration.spec.withName('dnsmasq') +
    grafanaAgentIntegration.spec.type.withUnique(false) +
    grafanaAgentIntegration.metadata.withLabels({agent: 'grafana-agent-metrics'}) +
    grafanaAgentIntegration.spec.withConfig({
      dnsmasq_address: '10.43.0.2:53',
      autoscrape: {
        enable: true,
        metrics_instance: 'grafana-agent/primary-me',
      },
    }),

  ga_dnsmasq2_integration:
    grafanaAgentIntegration.new('dnsmasq2') +
    grafanaAgentIntegration.spec.withName('dnsmasq') +
    grafanaAgentIntegration.spec.type.withUnique(false) +
    grafanaAgentIntegration.metadata.withLabels({agent: 'grafana-agent-metrics'}) +
    grafanaAgentIntegration.spec.withConfig({
      dnsmasq_address: '10.43.0.3:53',
      autoscrape: {
        enable: true,
        metrics_instance: 'grafana-agent/primary-me',
      },
    }),
}
