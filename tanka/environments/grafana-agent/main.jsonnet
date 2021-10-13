local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local grafana_agent = import 'github.com/rgeyer/agent/production/tanka/grafana-agent/v1/main.libsonnet';
local ga_scrape_k8s = import 'grafana-agent/v1/internal/kubernetes_instance.libsonnet';

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local loki_config = import 'loki_config.libsonnet';

local deployment = k.apps.v1.deployment;

local static_scrape_configs = {
  host_filter: false,
  name: 'static_scrape_configs',
  scrape_configs: [
    {
      job_name: 'nuctray-eighteen/etcd',
      scheme: 'https',
      static_configs: [{
        targets: ['192.168.42.100:2379', '192.168.42.101:2379', '192.168.42.102:2379'],
      }],
      tls_config: {
        ca_file: '/etc/ssl/etcd/ssl/ca.pem',
        cert_file: '/etc/ssl/etcd/ssl/node-18n1l.pem',
        key_file: '/etc/ssl/etcd/ssl/node-18n1l-key.pem',
        insecure_skip_verify: false
      },
    },
    {
      job_name: 'dragonhouse/cyberpower',
      scheme: 'http',
      static_configs: [{
        targets: ['192.168.42.115:9500'],
      }],
    },
  ],
};

config + secrets {
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
    grafana_agent.withPrometheusInstances(ga_scrape_k8s.newKubernetesScrapeInstance(config=ga_scrape_k8s.kubernetesScrapeInstanceConfig,
    namespace=$._config.kube_state_metrics.namespace) {
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
    }),

  agent_deployment:
    grafana_agent.newDeployment('agent-deployment', $._config.namespace) +
    grafana_agent.withPrometheusConfig({
      wal_directory: '/var/lib/agent/data',
      global: {
        scrape_interval: '15s',
      },
    }) +
    grafana_agent.withPrometheusInstances(static_scrape_configs) +
    grafana_agent.withRemoteWrite($._config.grafana_agent.cortex_remote_write) +
    {
      agent+: {
        agent+: deployment.spec.template.spec.withNodeSelector({etcdnode: "true"}) +
          k.util.hostVolumeMount('ssl', '/etc/ssl/etcd/ssl', '/etc/ssl/etcd/ssl', readOnly=true),
      }
    },
}
