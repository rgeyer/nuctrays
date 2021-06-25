local k = import 'ksonnet-util/kausal.libsonnet';
local grafana_agent = import 'grafana-agent/v1/main.libsonnet';

local secrets = import 'secrets.json';

local loki_config = import 'loki_config.libsonnet';

local static_scrape_configs = {
  host_filter: false,
  name: 'static_scrape_configs',
  scrape_configs: [
    {
      job_name: 'integration/jenkins',
      metrics_path: '/prometheus',
      static_configs: [{
        targets: ['10.233.106.20:8080'],
      }],
    },
  ],
};

secrets {
  _config+:: {
    namespace: 'grafana-agent',
  },

  namespace: k.core.v1.namespace.new($._config.namespace),
  agent:
    local cluster_label = 'nuctray/eighteen';

    grafana_agent.new('agent', $._config.namespace) +

    # Prometheus Config
    grafana_agent.withPrometheusConfig({
      wal_directory: '/var/lib/agent/data',
      global: {
        scrape_interval: '15s',
        external_labels: {
          cluster: cluster_label,
        },
      },
    }) +
    grafana_agent.withPrometheusInstances(grafana_agent.scrapeInstanceKubernetes {
      scrape_configs: std.map(function(config) config {
        relabel_configs+: [{
          target_label: 'cluster',
          replacement: cluster_label,
        }],
      }, super.scrape_configs),
    }) +
    grafana_agent.withRemoteWrite($._config.grafana_agent.cortex_remote_write) +

    # Loki Config
    grafana_agent.withLokiConfig(loki_config) +
    grafana_agent.withLokiClients(grafana_agent.newLokiClient({
      scheme: 'https',
      hostname: $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_host,
      username: $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_tenant,
      password: $._config.hosted_grafana_orgs.ryangeyer.metrics_pub_key,
      external_labels: {cluster: cluster_label},
    })) +

    # Integration Config
    grafana_agent.withIntegrations({
      node_exporter: {
        enabled: true,
        rootfs_path: '/host/root',
        sysfs_path: '/host/sys',
        procfs_path: '/host/proc',
      },
    }) +
    grafana_agent.integrationsMixin,

  agent_deployment:
    grafana_agent.newDeployment('agent-deployment', $._config.namespace) +
    grafana_agent.withPrometheusConfig({
      wal_directory: '/var/lib/agent/data',
      global: {
        scrape_interval: '15s',
      },
    }) +
    grafana_agent.withPrometheusInstances(static_scrape_configs) +
    grafana_agent.withRemoteWrite($._config.grafana_agent.cortex_remote_write),
}
