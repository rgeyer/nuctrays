local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local parseYaml = std.native('parseYaml');
local secrets = import 'secrets.libsonnet';

local grao_integration = import 'grafana-agent-operator/integration.libsonnet';

local grafanaAgent = import '0.26/main.libsonnet';
local grafanaAgentIntegration = grafanaAgent.monitoring.v1alpha1.integration;

local clusterRole = k.rbac.v1.clusterRole,
      clusterRoleBinding = k.rbac.v1.clusterRoleBinding,
      configMap = k.core.v1.configMap,
      policyRule = k.rbac.v1.policyRule,
      serviceAccount = k.core.v1.serviceAccount,
      secret = k.core.v1.secret;

local prom = import '0.57/main.libsonnet';
local pm = prom.monitoring.v1.podMonitor;

local k8s_metriclist = 'kube_daemonset_status_number_misscheduled|kubelet_node_name|kubelet_cgroup_manager_duration_seconds_bucket|kube_replicaset_owner|namespace_memory:kube_pod_container_resource_requests:sum|container_cpu_cfs_throttled_periods_total|kube_statefulset_status_replicas_updated|kube_pod_container_status_waiting_reason|kube_statefulset_status_update_revision|container_fs_reads_bytes_total|kube_pod_info|kube_pod_owner|node_namespace_pod_container:container_memory_working_set_bytes|kubelet_runtime_operations_total|kube_job_failed|kubelet_running_pod_count|kubelet_running_containers|node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate|container_network_transmit_packets_dropped_total|cluster:namespace:pod_memory:active:kube_pod_container_resource_limits|process_resident_memory_bytes|namespace_cpu:kube_pod_container_resource_requests:sum|machine_memory_bytes|kube_pod_status_phase|volume_manager_total_volumes|kube_statefulset_status_observed_generation|container_network_transmit_bytes_total|kube_horizontalpodautoscaler_spec_max_replicas|kube_node_spec_taint|kubelet_running_pods|namespace_memory:kube_pod_container_resource_limits:sum|kube_statefulset_status_replicas|kube_horizontalpodautoscaler_spec_min_replicas|kube_statefulset_metadata_generation|container_network_receive_bytes_total|go_goroutines|cluster:namespace:pod_memory:active:kube_pod_container_resource_requests|kube_daemonset_status_updated_number_scheduled|kube_node_status_allocatable|namespace_cpu:kube_pod_container_resource_limits:sum|kube_daemonset_status_current_number_scheduled|kube_deployment_spec_replicas|kubelet_certificate_manager_client_ttl_seconds|container_fs_reads_total|kube_pod_container_resource_requests|container_memory_rss|kube_deployment_metadata_generation|up|kube_resourcequota|node_namespace_pod_container:container_memory_swap|kubelet_pod_worker_duration_seconds_bucket|kubelet_node_config_error|kube_statefulset_status_current_revision|kube_horizontalpodautoscaler_status_current_replicas|container_network_transmit_packets_total|kube_node_status_capacity|container_cpu_cfs_periods_total|process_cpu_seconds_total|cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests|kube_node_info|kubelet_pleg_relist_duration_seconds_count|container_fs_writes_total|container_network_receive_packets_total|kubelet_pod_worker_duration_seconds_count|rest_client_requests_total|kubelet_volume_stats_capacity_bytes|kube_daemonset_status_desired_number_scheduled|container_memory_swap|node_namespace_pod_container:container_memory_cache|node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile|container_memory_working_set_bytes|kubelet_server_expiration_renew_errors|storage_operation_errors_total|kubelet_pleg_relist_duration_seconds_bucket|kube_deployment_status_replicas_updated|kubelet_runtime_operations_errors_total|kubelet_volume_stats_available_bytes|namespace_workload_pod|storage_operation_duration_seconds_count|kube_deployment_status_replicas_available|kube_statefulset_status_replicas_ready|kubernetes_build_info|container_cpu_usage_seconds_total|container_memory_cache|kubelet_volume_stats_inodes_used|kubelet_pleg_relist_interval_seconds_bucket|kubelet_cgroup_manager_duration_seconds_count|kube_deployment_status_observed_generation|kube_daemonset_status_number_available|kube_pod_container_resource_limits|cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits|container_fs_writes_bytes_total|kube_namespace_status_phase|kubelet_volume_stats_inodes|kubelet_certificate_manager_client_expiration_renew_errors|container_network_receive_packets_dropped_total|kubelet_pod_start_duration_seconds_count|kube_horizontalpodautoscaler_status_desired_replicas|kube_statefulset_replicas|kubelet_running_container_count|node_namespace_pod_container:container_memory_rss|kubelet_certificate_manager_server_ttl_seconds|namespace_workload_pod:kube_pod_owner:relabel|kube_job_status_active|kube_job_status_start_time|kube_node_status_condition|kube_namespace_status_phase|container_cpu_usage_seconds_total|kube_pod_status_phase|kube_pod_start_time|kube_pod_container_status_restarts_total|kube_pod_container_info|kube_pod_container_status_waiting_reason|kube_daemonset.*|kube_replicaset.*|kube_statefulset.*|kube_job.*';

local namespace = 'grafana-agent';

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

secrets {
  namespace: k.core.v1.namespace.new(namespace),

  hg_secrets: [
    hg_secret(secrets._config.hosted_grafana_orgs[hg_org], namespace)
    for hg_org in std.objectFields(secrets._config.hosted_grafana_orgs)
  ],

  grafana_agent_operator: helm.template('grafana-agent-operator', '../../../charts/grafana-agent-operator', {
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
      image: 'grafana/agent:v0.27.1',
      logLevel: 'info',
      serviceAccountName: $.ga_sa.metadata.name,
      enableConfigReadAPI: true,
      metrics: {
        instanceSelector: {
          matchLabels: {
            agent: 'grafana-agent-metrics',
          },
        },
        externalLabels: {
          cluster: 'thinkcentre',
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
            agent: 'grafana-agent-metrics',
          },
        },
      },
    },
  },

  extra_scrape_job_secret:
    secret.new('ga-extra-scrape-jobs', {}) +
    secret.metadata.withNamespace(namespace) +
    secret.withStringData({
      'additionalScrapeConfigs.yaml': (importstr './additionalScrapeConfigs.yaml') % {
        'qnap.rclone.user': $._config.qnap.rclone.user,
        'qnap.rclone.pass': $._config.qnap.rclone.pass,
      },
    }),

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
      additionalScrapeConfigs: {
        name: 'ga-extra-scrape-jobs',
        key: 'additionalScrapeConfigs.yaml',
      },
      remoteWrite:
        // [
        //   { url: 'http://cortex.cortex.svc.cluster.local/api/prom/push' },
        // ] +
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
        // [
        //   { url: 'http://loki.loki.svc.cluster.local:3100/loki/api/v1/push' },
        // ] +
        [
          {
            local hg_org = secrets._config.hosted_grafana_orgs[hg_slug],
            local hg_sname = '%s-hg-secret' % hg_org.slug,
            url: 'https://%s/loki/api/v1/push' % hg_org.hosted_logs_host,
            basicAuth: {
              username: { name: hg_sname, key: 'hl_tenant' },
              password: { name: hg_sname, key: 'metrics_pub_key' },
            },
            externalLabels: { cluster: 'thinkcentre' },
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
              regex: k8s_metriclist,
              sourceLabels: [
                '__name__',
              ],
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
            {
              action: 'replace',
              targetLabel: 'job',
              replacement: 'integrations/kubernetes/kubelet',
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
              regex: k8s_metriclist,
              sourceLabels: [
                '__name__',
              ],
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
            {
              action: 'replace',
              targetLabel: 'job',
              replacement: 'integrations/kubernetes/cadvisor',
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

  // Kube-state-metrics ServiceMonitor CR
  ga_ksm_probe: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      labels: {
        instance: 'primary-me',
      },
      name: 'ksm-monitor',
      namespace: namespace,
    },
    spec: {
      endpoints: [
        {
          honorLabels: true,
          port: 'http-metrics',
          metricRelabelings: [
            {
              action: 'keep',
              regex: k8s_metriclist,
              sourceLabels: [
                '__name__',
              ],
            },
          ],
          relabelings: [
            {
              action: 'replace',
              targetLabel: 'job',
              replacement: 'integrations/kubernetes/kube-state-metrics',
            },
          ],
        },
      ],
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
      selector: {
        matchLabels: {
          'app.kubernetes.io/name': 'kube-state-metrics',
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
      labels: { agent: 'grafana-agent-metrics' },
    },
    spec: {
      name: 'node_exporter',
      type: {
        allNodes: true,
        unique: true,
      },
      config: {
        autoscrape: {
          enable: true,  // This is redundant, right? Because the default is true
          metrics_instance: '%s/primary-me' % namespace,
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

  // K8s eventhandler integration cr
  ga_k8s_events_integration:
    grao_integration.new('eventhandler', false, true) +
    { metadata+: { labels: { agent: 'grafana-agent-metrics' } } } +
    grao_integration.metadata.withNamespace(namespace) +
    grao_integration.spec.withConfig({
      logs_instance: '%s/primary-logs' % namespace,
      cache_path: '/var/lib/grafana-agent/data/eventhandler.cache',  // This should live on a PV, of a statefulset agent
    }),

  // CoreDNS Pod Monitor
  ga_coredns_pm:
    pm.new('coredns') +
    pm.metadata.withLabels({ instance: 'primary-me' }) +
    pm.spec.selector.withMatchLabels({ 'k8s-app': 'kube-dns' }) +
    pm.spec.namespaceSelector.withMatchNames(['kube-system']) +
    pm.spec.withPodMetricsEndpoints([
      pm.spec.podMetricsEndpoints.withHonorLabels(true) +
      pm.spec.podMetricsEndpoints.withPort('metrics') +
      pm.spec.podMetricsEndpoints.withRelabelings([
        pm.spec.podMetricsEndpoints.relabelings.withAction('replace') +
        pm.spec.podMetricsEndpoints.relabelings.withTargetLabel('job') +
        pm.spec.podMetricsEndpoints.relabelings.withReplacement('integrations/coredns'),
      ]),
    ]),

  // agent integration
  ga_agent_integration:
    grafanaAgentIntegration.new('agent') +
    grafanaAgentIntegration.spec.withName('agent') +
    grafanaAgentIntegration.spec.type.withUnique(false) +
    grafanaAgentIntegration.metadata.withLabels({ agent: 'grafana-agent-metrics' }) +
    grafanaAgentIntegration.spec.withConfig({
      autoscrape: {
        enable: true,
        metrics_instance: 'grafana-agent/primary-me',
      },
    }),

  ga_snmp_config:
    configMap.new('grafana-agent-snmp-config') +
    configMap.mixin.metadata.withNamespace(namespace) +
    configMap.withData({ 'snmp.yml': importstr 'snmp/snmp.yml' }),

  // snmp integration
  ga_snmp_integration:
    grafanaAgentIntegration.new('snmp') +
    grafanaAgentIntegration.spec.withName('snmp') +
    grafanaAgentIntegration.spec.type.withUnique(true) +
    grafanaAgentIntegration.metadata.withLabels({ agent: 'grafana-agent-metrics' }) +
    grafanaAgentIntegration.spec.withConfigMaps([
      grafanaAgentIntegration.spec.configMaps.withName('grafana-agent-snmp-config') +
      grafanaAgentIntegration.spec.configMaps.withKey('snmp.yml'),
    ]) +
    grafanaAgentIntegration.spec.withConfig({
      autoscrape: {
        enable: true,
        metrics_instance: 'grafana-agent/primary-me',
      },
      config_file: '/etc/grafana-agent/integrations/configMaps/%s/grafana-agent-snmp-config/snmp.yml' % namespace,
      snmp_targets: [
        {
          name: 'edgerouter-x',
          address: '192.168.1.1',
          module: 'ubnt_router',
          walk_params: 'erx',
        },
      ],
      walk_params: {
        erx: {
          auth: {
            community: 'ubnt',
          },          
        },
      },
    }),
}