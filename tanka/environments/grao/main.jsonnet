local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local parseYaml = std.native('parseYaml');
local secrets = import 'secrets.libsonnet';

local clusterRole = k.rbac.v1.clusterRole,
      clusterRoleBinding = k.rbac.v1.clusterRoleBinding,
      policyRule = k.rbac.v1.policyRule,
      serviceAccount = k.core.v1.serviceAccount,
      secret = k.core.v1.secret;

local namespace = 'grao';

local hg_secret(hg_org, namespace) = {
  local sname = '%s-hg-secret' % hg_org.slug,
  hg_secret: secret.new(sname, {}) +
             secret.withStringData({
               metrics_pub_key: hg_org.metrics_pub_key,
               hm_tenant: '%d' % hg_org.hosted_metrics_tenant,
               hl_tenant: '%d' % hg_org.hosted_logs_tenant,
             }) +
             secret.mixin.metadata.withNamespace(namespace),
};

{
  namespace: k.core.v1.namespace.new(namespace),

  hg_secrets: [
    hg_secret(secrets._config.hosted_grafana_orgs[hg_org], namespace)
    for hg_org in std.objectFields(secrets._config.hosted_grafana_orgs)
  ],

  grafana_agent_operator: helm.template('grafana-agent-operator', '../../charts/grafana-agent-operator', {
    namespace: namespace,
    includeCrds: true,
    noHooks: true,
  }),

  // Grafana Agent CR
  ga_sa:
    serviceAccount.new('grao-agent') +
    serviceAccount.metadata.withNamespace(namespace),

  ga_cr:
    clusterRole.new('grao-agent-clusterrole') +
    clusterRole.withRulesMixin([
      policyRule.withApiGroups(['']) +
      policyRule.withResources([
        'nodes',
        'nodes/proxy',
        'nodes/metrics',
        'services',
        'endpoints',
        'pods',
        'events',
      ]) +
      policyRule.withVerbs([
        'get',
        'list',
        'watch',
      ]),

      policyRule.withApiGroups(['networking.k8s.io']) +
      policyRule.withResources(['ingresses']) +
      policyRule.withVerbs([
        'get',
        'list',
        'watch',
      ]),

      policyRule.withNonResourceURLs([
        '/metrics',
        '/metrics/cadvisor',
      ]) +
      policyRule.withVerbs(['get']),
    ]),

  ga_crb:
    clusterRoleBinding.new('grao-agent-clusterrole-binding') +
    clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
    clusterRoleBinding.mixin.roleRef.withKind('ClusterRole') +
    clusterRoleBinding.mixin.roleRef.withName($.ga_cr.metadata.name) +
    clusterRoleBinding.metadata.withNamespace(namespace) +
    clusterRoleBinding.withSubjectsMixin({
      kind: 'ServiceAccount',
      name: $.ga_sa.metadata.name,
      namespace: namespace,
    }),

  ga: {
    apiVersion: 'monitoring.grafana.com/v1alpha1',
    kind: 'GrafanaAgent',
    metadata: {
      name: 'grafana-agent',
      namespace: namespace,
      labels: {
        app: 'grafana-agent',
      },
    },
    spec: {
      image: 'grafana/agent:v0.25.1',
      logLevel: 'info',
      serviceAccountName: $.ga_sa.metadata.name,
      metrics: {
        instanceSelector: {
          matchLabels: {
            agent: 'grafana-agent-metrics',
          },
        },
        externalLabels: {
          cluster: 'grao',
        },
      },
      logs: {
        instanceSelector: {
          matchLabels: {
            agent: 'grafana-agent-logs',
          },
        },
      },
      integrations: {
        namespaceSelector: {},
        selector: {
          matchLabels: {
            agent: 'grafana-agent-integration-singletons',
          },
        },
      },
    },
  },

  // Metrics Instance CR
  ga_metrics_instance: {
    apiVersion: 'monitoring.grafana.com/v1alpha1',
    kind: 'MetricsInstance',
    metadata: {
      name: 'primary-me',
      namespace: namespace,
      labels: { agent: 'grafana-agent-metrics' },
    },
    spec: {
      remoteWrite:
        [
          { url: 'http://cortex.cortex.svc.cluster.local/api/prom/push' },
        ] +
        [
          {
            local hg_org = secrets._config.hosted_grafana_orgs[hg_slug],
            local hg_sname = '%s-hg-secret' % hg_org.slug,
            url: 'https://%s/api/prom/push' % hg_org.hosted_metrics_host,
            basicAuth: {
              username: { name: hg_sname, key: 'hm_tenant' },
              password: { name: hg_sname, key: 'metrics_pub_key' },
            },
          }
          for hg_slug in std.objectFields(secrets._config.hosted_grafana_orgs)
        ],
      serviceMonitorNamespaceSelector: {},
      serviceMonitorSelector: {
        matchLabels: {
          instance: 'primary-me',
        },
      },
      podMonitorNamespaceSelector: {},
      podMonitorSelector: {
        matchLabels: {
          instance: 'primary-me',
        },
      },
      probeNamespaceSelector: {},
      probeSelector: {
        matchLabels: {
          instance: 'primary-me',
        },
      },
    },
  },

  // Logs Instance CR
  ga_logs_instance: {
    apiVersion: 'monitoring.grafana.com/v1alpha1',
    kind: 'LogsInstance',
    metadata: {
      name: 'primary-logs',
      namespace: namespace,
      labels: { agent: 'grafana-agent-logs' },
    },
    spec: {
      clients:
        [
          { url: 'http://loki.loki.svc.cluster.local:3100/loki/api/v1/push' },
        ] +
        [
          {
            local hg_org = secrets._config.hosted_grafana_orgs[hg_slug],
            local hg_sname = '%s-hg-secret' % hg_org.slug,
            url: 'https://%s/loki/api/v1/push' % hg_org.hosted_logs_host,
            basicAuth: {
              username: { name: hg_sname, key: 'hl_tenant' },
              password: { name: hg_sname, key: 'metrics_pub_key' },
            },
            externalLabels: { cluster: 'grao' },
          }
          for hg_slug in std.objectFields(secrets._config.hosted_grafana_orgs)
        ],
      podLogsNamespaceSelector: {},
      podLogsSelector: {
        matchLabels: {
          instance: 'primary-logs',
        },
      },
    },
  },

  // Kubelet Service Monitor CR
  ga_kublet_sm: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'kublet-monitor',
      namespace: namespace,
      labels: { instance: 'primary-me' },
    },
    spec: {
      endpoints: [
        {
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          honorLabels: true,
          interval: '60s',
          metricRelabelings: [
            {
              action: 'keep',
              regex: 'kubelet_cgroup_manager_duration_seconds_count|go_goroutines|kubelet_pod_start_duration_seconds_count|kubelet_runtime_operations_total|kubelet_pleg_relist_duration_seconds_bucket|volume_manager_total_volumes|kubelet_volume_stats_capacity_bytes|container_cpu_usage_seconds_total|container_network_transmit_bytes_total|kubelet_runtime_operations_errors_total|container_network_receive_bytes_total|container_memory_swap|container_network_receive_packets_total|container_cpu_cfs_periods_total|container_cpu_cfs_throttled_periods_total|kubelet_running_pod_count|node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate|container_memory_working_set_bytes|storage_operation_errors_total|kubelet_pleg_relist_duration_seconds_count|kubelet_running_pods|rest_client_request_duration_seconds_bucket|process_resident_memory_bytes|storage_operation_duration_seconds_count|kubelet_running_containers|kubelet_runtime_operations_duration_seconds_bucket|kubelet_node_config_error|kubelet_cgroup_manager_duration_seconds_bucket|kubelet_running_container_count|kubelet_volume_stats_available_bytes|kubelet_volume_stats_inodes|container_memory_rss|kubelet_pod_worker_duration_seconds_count|kubelet_node_name|kubelet_pleg_relist_interval_seconds_bucket|container_network_receive_packets_dropped_total|kubelet_pod_worker_duration_seconds_bucket|container_start_time_seconds|container_network_transmit_packets_dropped_total|process_cpu_seconds_total|storage_operation_duration_seconds_bucket|container_memory_cache|container_network_transmit_packets_total|kubelet_volume_stats_inodes_used|up|rest_client_requests_total',
              sourceLabels: [
                '__name__',
              ],
            },
            {
              action: 'replace',
              targetLabel: 'job',
              replacement: 'integrations/kubernetes/kubelet',
            },
          ],
          port: 'https-metrics',
          relabelings: [
            {
              sourceLabels: [
                '__metrics_path__',
              ],
              targetLabel: 'metrics_path',
            },
          ],
          scheme: 'https',
          tlsConfig: {
            insecureSkipVerify: true,
          },
        },
      ],
      namespaceSelector: {
        matchNames: [
          'default',
        ],
      },
      selector: {
        matchLabels: {
          'app.kubernetes.io/name': 'kubelet',
        },
      },
    },
  },

  //cAdvisor Service Monitor CR
  ga_cadvisor_sm: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      labels: {
        instance: 'primary-me',
      },
      name: 'cadvisor-monitor',
      namespace: namespace,
    },
    spec: {
      endpoints: [
        {
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          honorLabels: true,
          honorTimestamps: false,
          interval: '60s',
          metricRelabelings: [
            {
              action: 'keep',
              regex: 'kubelet_cgroup_manager_duration_seconds_count|go_goroutines|kubelet_pod_start_duration_seconds_count|kubelet_runtime_operations_total|kubelet_pleg_relist_duration_seconds_bucket|volume_manager_total_volumes|kubelet_volume_stats_capacity_bytes|container_cpu_usage_seconds_total|container_network_transmit_bytes_total|kubelet_runtime_operations_errors_total|container_network_receive_bytes_total|container_memory_swap|container_network_receive_packets_total|container_cpu_cfs_periods_total|container_cpu_cfs_throttled_periods_total|kubelet_running_pod_count|node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate|container_memory_working_set_bytes|storage_operation_errors_total|kubelet_pleg_relist_duration_seconds_count|kubelet_running_pods|rest_client_request_duration_seconds_bucket|process_resident_memory_bytes|storage_operation_duration_seconds_count|kubelet_running_containers|kubelet_runtime_operations_duration_seconds_bucket|kubelet_node_config_error|kubelet_cgroup_manager_duration_seconds_bucket|kubelet_running_container_count|kubelet_volume_stats_available_bytes|kubelet_volume_stats_inodes|container_memory_rss|kubelet_pod_worker_duration_seconds_count|kubelet_node_name|kubelet_pleg_relist_interval_seconds_bucket|container_network_receive_packets_dropped_total|kubelet_pod_worker_duration_seconds_bucket|container_start_time_seconds|container_network_transmit_packets_dropped_total|process_cpu_seconds_total|storage_operation_duration_seconds_bucket|container_memory_cache|container_network_transmit_packets_total|kubelet_volume_stats_inodes_used|up|rest_client_requests_total',
              sourceLabels: [
                '__name__',
              ],
            },
            {
              action: 'replace',
              targetLabel: 'job',
              replacement: 'integrations/kubernetes/cadvisor',
            },
          ],
          path: '/metrics/cadvisor',
          port: 'https-metrics',
          relabelings: [
            {
              sourceLabels: [
                '__metrics_path__',
              ],
              targetLabel: 'metrics_path',
            },
          ],
          scheme: 'https',
          tlsConfig: {
            insecureSkipVerify: true,
          },
        },
      ],
      namespaceSelector: {
        matchNames: [
          'default',
        ],
      },
      selector: {
        matchLabels: {
          'app.kubernetes.io/name': 'kubelet',
        },
      },
    },
  },

  // PodLogs CR
  ga_podlogs: {
    apiVersion: 'monitoring.grafana.com/v1alpha1',
    kind: 'PodLogs',
    metadata: {
      labels: {
        instance: 'primary-logs',
      },
      name: 'kubernetes-pods',
      namespace: namespace,
    },
    spec: {
      pipelineStages: [
        {
          cri: {},
        },
      ],
      namespaceSelector: {
        any: true,
      },
      selector: {
        matchLabels: {},
      },
    },
  },

  // Node exporter integration cr
  ga_nodeexporter_integration: {
    apiVersion: 'monitoring.grafana.com/v1alpha1',
    kind: 'Integration',
    metadata: {
      name: 'node-exporter-integration',
      namespace: namespace,
      labels: { agent: 'grafana-agent-integration-singletons' },
    },
    spec: {
      name: 'node_exporter',
      type: {
        allNodes: true,
        unique: true,
      },
      config: {
        autoscrape: {
          enabled: true, // This is redundant, right? Because the default is true
          metrics_instance: 'primary-me',
        },
        rootfs_path: '/host/root',
        sysfs_path: '/host/sys',
        procfs_path: '/host/proc',
      },
      volumes: [
        {
          name: 'rootfs',
          hostPath: {
            path: '/',
            type: '',
          },
        },
        {
          name: 'sysfs',
          hostPath: {
            path: '/sys',
            type: '',
          },
        },
        {
          name: 'procfs',
          hostPath: {
            path: '/proc',
            type: '',
          },
        },
      ],
      volumeMounts: [
        {
          name: 'rootfs',
          mountPath: '/host/root',
        },
        {
          name: 'sysfs',
          mountPath: '/host/sys',
        },
        {
          name: 'procfs',
          mountPath: '/host/proc',
        },
      ],
    },
  },
}
