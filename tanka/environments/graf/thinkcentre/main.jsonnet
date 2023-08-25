local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local secrets = import 'secrets.libsonnet';

local namespace = 'graf';

secrets {
  namespace: k.core.v1.namespace.new(namespace),

  grafana_agent_flow: helm.template('grafana-k8s-monitoring', '../../../charts/k8s-monitoring', {
    namespace: namespace,
    includeCrds: false,  // This is because they're already deployed in grao. Should grao be decommissioned, we'll need to re-add these.
    noHooks: true,
    values: {
      cluster: {
        name: namespace,
      },

      externalServices: {
        prometheus: {
          host: 'https://' + $._config.hosted_grafana_orgs.ryangeyer.hosted_metrics_host,
          basicAuth: {
            username: $._config.hosted_grafana_orgs.ryangeyer.hosted_metrics_tenant,
            password: $._config.hosted_grafana_orgs.ryangeyer.metrics_pub_key,
          },
        },

        loki: {
          host: 'https://' + $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_host,
          basicAuth: {
            username: $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_tenant,
            password: $._config.hosted_grafana_orgs.ryangeyer.metrics_pub_key,
          },
        },
      },

      logs: {
        pod_logs: {
          loggingFormat: 'cri',
        },
      },

      metrics: {
        podMonitors: { enabled: false },
        serviceMonitors: { enabled: false },
      },

      opencost: {
        opencost: {
          exporter: { defaultClusterId: namespace },
          prometheus: {
            external: {
              url: $._config.hosted_grafana_orgs.ryangeyer.hosted_metrics_host,
            },
          },
        },
      },

      'prometheus-operator-crds': {
        enabled: false,
      },

      extraConfig: |||
        prometheus.exporter.mysql "madmysqlprimary" {
          data_source_name = "root:%(mysql_root_password)s@(mysql-mad-primary.mad.svc.cluster.local:3306)/"
        }

        module.git "madmysqlprimary" {
          repository = "https://github.com/grafana/agent-modules.git"
          revision = "0c0de275270f937aaebdbd137bb15dfd768a5b38"
          path = "modules/grafana-cloud/integrations/mysql/module.river"

          arguments {
            instance = "k8s MAD Primary"
            metrics_targets = prometheus.exporter.mysql.madmysqlprimary.targets
            metrics_receiver = [prometheus.remote_write.grafana_cloud_prometheus.receiver]
            logs_receiver = [loki.write.grafana_cloud_loki.receiver]
          }
        }
      ||| % { mysql_root_password: $._config.mysql.root_password },
    },
  }),
}
