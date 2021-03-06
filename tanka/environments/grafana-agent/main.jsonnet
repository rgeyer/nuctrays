local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local ga_scrape_k8s = import 'grafana-agent/v1/internal/kubernetes_instance.libsonnet';
local grafana_agent = import 'grafana-agent/v1/main.libsonnet';

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
        insecure_skip_verify: false,
      },
    },
    {
      job_name: 'dragonhouse/cyberpower',
      scheme: 'http',
      static_configs: [{
        targets: ['192.168.42.115:9500'],
      }],
    },
    {
      job_name: 'snmp/cisco_switch',
      static_configs: [
        {
          targets: ['192.168.1.161', '196.168.1.2'],
        },
      ],
      metrics_path: '/snmp',
      params: {
        module: ['cisco_switch'],
      },
      relabel_configs: [
        { source_labels: ['__address__'], target_label: '__param_target' },
        { source_labels: ['__param_target'], target_label: 'instance' },
        { target_label: '__address__', replacement: 'snmp-exporter.default.svc.cluster.local:9116' },
      ],
    },
    {
      job_name: 'snmp/edgerouter',
      static_configs: [
        {
          targets: ['192.168.1.1'],
        },
      ],
      metrics_path: '/snmp',
      params: {
        module: ['edgerouter'],
      },
      relabel_configs: [
        { source_labels: ['__address__'], target_label: '__param_target' },
        { source_labels: ['__param_target'], target_label: 'instance' },
        { target_label: '__address__', replacement: 'snmp-exporter.default.svc.cluster.local:9116' },
      ],
    },
    {
      job_name: 'snmp/qnap',
      scrape_interval: '120s',
      scrape_timeout: '60s',
      static_configs: [
        {
          targets: ['192.168.1.10'],
        },
      ],
      metrics_path: '/snmp',
      params: {
        module: ['qnap'],
      },
      relabel_configs: [
        { source_labels: ['__address__'], target_label: '__param_target' },
        { source_labels: ['__param_target'], target_label: 'instance' },
        { target_label: '__address__', replacement: 'snmp-exporter.default.svc.cluster.local:9116' },
      ],
    },
    {
      job_name: 'esphome',
      scheme: 'http',
      static_configs: [
        {
          targets: ['192.168.1.242', '192.168.1.243'],
        },
      ],
    },
    {
      job_name: 'mysqlexporters',
      scheme: 'http',
      static_configs: [
        {
          targets: ['mysql-metrics.mysql.svc.cluster.local:9104'],
        },
      ],
    },
    {
      job_name: 'integrations/kubernetes/kube-state-metrics',
      static_configs: [
        {
          labels: { cluster: 'nuctray/eighteen' },
          targets: ['ksm-kube-state-metrics.default.svc.cluster.local:8080'],
        },
      ],
    },
    {
      job_name: 'qnap/rclone',
      scheme: 'http',
      static_configs: [
        {
          targets: ['192.168.1.10:5572'],
        },
      ],
      basic_auth: {
        username: secrets._config.qnap.rclone.user,
        password: secrets._config.qnap.rclone.pass,
      },
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

    // Metrics Config
    grafana_agent.withMetricsConfig({
      wal_directory: '/var/lib/agent/data',
      global: {
        scrape_interval: '15s',
        external_labels: {
          cluster: cluster_label,
        },
      },
    }) +
    grafana_agent.withMetricsInstances(ga_scrape_k8s.newKubernetesScrapeInstance(config=ga_scrape_k8s.kubernetesScrapeInstanceConfig,
                                                                                 namespace=$._config.kube_state_metrics.namespace) {
      scrape_configs: std.map(function(config) config {
        relabel_configs+: [{
          target_label: 'cluster',
          replacement: cluster_label,
        }],
      }, super.scrape_configs),
    }) +
    grafana_agent.withRemoteWrite($._config.grafana_agent.cortex_remote_write) +

    // Log Config
    grafana_agent.withLogsConfig(loki_config) +
    grafana_agent.withLogsClients([
      // To Grafana Cloud
      grafana_agent.newLogsClient({
        scheme: 'https',
        hostname: $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_host,
        username: $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_tenant,
        password: $._config.hosted_grafana_orgs.ryangeyer.metrics_pub_key,
        external_labels: { cluster: cluster_label },
      }),
      // To nuctray local
      grafana_agent.newLogsClient({
        scheme: 'http',
        hostname: 'loki.loki.svc.cluster.local:3100',
      }),
    ]) +


    // Integration Config
    grafana_agent.withIntegrations({
      node_exporter: {
        enabled: true,
        rootfs_path: '/host/root',
        sysfs_path: '/host/sys',
        procfs_path: '/host/proc',
      },
      redis_exporter: {
        enabled: true,
        redis_addr: 'redis.mad.svc.cluster.local:6379',
      },
    }),

  agent_deployment:
    grafana_agent.newDeployment('agent-deployment', $._config.namespace) +
    grafana_agent.withMetricsConfig({
      wal_directory: '/var/lib/agent/data',
      global: {
        scrape_interval: '15s',
      },
    }) +
    grafana_agent.withMetricsInstances(static_scrape_configs) +
    grafana_agent.withRemoteWrite($._config.grafana_agent.cortex_remote_write) +
    {
      agent+: {
        agent+: deployment.spec.template.spec.withNodeSelector({ etcdnode: 'true' }) +
                k.util.hostVolumeMount('ssl', '/etc/ssl/etcd/ssl', '/etc/ssl/etcd/ssl', readOnly=true),
      },
    }, // +
    // {
    //   config+:: {
    //     server+: {
    //       log_level: 'debug',
    //     },
    //   },
    // },
}
