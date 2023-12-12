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
          // Use a modified version of the helm chart to add relabel configs and pipeline stages
          extraDiscoveryRelabelRules: |||
            rule {
              source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name","__meta_kubernetes_pod_label_app_kubernetes_io_instance","__meta_kubernetes_pod_label_app_kubernetes_io_component"]
              regex = "mysql;mysql-mad;primary"
              target_label = "instance"
              replacement = "k8s MAD primary"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name","__meta_kubernetes_pod_label_app_kubernetes_io_instance","__meta_kubernetes_pod_label_app_kubernetes_io_component"]
              regex = "mysql;mysql-mad;primary"
              target_label = "job"
              replacement = "integrations/mysql"
            }
          |||,
          extraLokiProcessStages: |||
            stage.match {
              selector = "{job=\"integrations/mysql\"}"
              stage.regex {
                expression = "(?P<timestamp>.+) (?P<thread>[\\d]+) \\[(?P<label>.+?)\\]( \\[(?P<err_code>.+?)\\] \\[(?P<subsystem>.+?)\\])? (?P<msg>.+)"
              }
              stage.labels {
                values = {
                  level = "label",
                  err_code = "",
                  subsystem = "",
                }
              }
              stage.drop {
                expression = "^ *$"
                drop_counter_reason = "drop empty lines"
              }
            }
          |||,
        },
        // Rediscover each mysql instance, apply the relabeling and stages, and ship them again. This is equivalent to the operator mode instructions today.
        // extraConfig: |||
        //   // ******************************************************************************************************************************************//
        //   // START: MySQL Integration extra config for the instance named "k8s MAD Primary"                                                            //
        //   // ******************************************************************************************************************************************//
        //   // New relabel for each mysql instance for which we wish to fetch pod logs.
        //   // Appends to the relabeling which was already done by the k8s helm chart discovery relabeling which adds namespace, pod, job, and calculates the pod log path on the host
        //   // Drops all other pods
        //   discovery.relabel "mysqlmadprimary_pod_logs" {
        //     targets = discovery.relabel.pod_logs.output

        //     rule {
        //       source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name","__meta_kubernetes_pod_label_app_kubernetes_io_instance","__meta_kubernetes_pod_label_app_kubernetes_io_component"]
        //       regex = "mysql;mysql-mad;primary"
        //       action = "keep"
        //     }
        //   }
          
        //   // Direct copy/paste duplication of the file match in the k8s helm chart. Needs to be duplicated for each instance, since we're (re) discovering and relabeling for eacn instance.
        //   local.file_match "mysqlmadprimary_pod_logs" {
        //     path_targets = discovery.relabel.mysqlmadprimary_pod_logs.output
        //   }

        //   loki.source.file "mysqlmadprimary_pod_logs" {
        //     targets = local.file_match.mysqlmadprimary_pod_logs.targets
        //     forward_to = [loki.process.mysqlmadprimary_pod_logs.receiver]
        //   }

        //   loki.process "mysqlmadprimary_pod_logs" {
        //     stage.cri {} // Also duplication from the k8s helm chart, but crucially, this is copy/pasted, and might not match the setting in the chart.
        //     forward_to = [module.git.mysqlmadprimary.exports.logs_receiver]
        //   }
          
        //   prometheus.remote_write "blackhole" {}

        //   module.git "mysqlmadprimary" {
        //     repository = "https://github.com/grafana/agent-modules.git"
        //     revision = "0c0de275270f937aaebdbd137bb15dfd768a5b38"
        //     path = "modules/grafana-cloud/integrations/mysql/module.river"

        //     arguments {
        //       instance = "k8s MAD Primary"
        //       metrics_targets = [] // Blank, because this is the logs instance of k8s. This may be an indicator that the module needs to be broken into logs and metrics
        //       metrics_receiver = [prometheus.remote_write.blackhole.receiver]
        //       logs_receiver = [loki.write.grafana_cloud_loki.receiver]
        //     }
        //   }
        //   // ******************************************************************************************************************************************//
        //   // END: MySQL Integration extra config for the instance named "k8s MAD Primary"                                                              //
        //   // ******************************************************************************************************************************************//
        // |||,
        // Partially abandoned intercept approach.
        // extraConfig: |||
        //   loki.write "blackhole" {}

        //   prometheus.remote_write "blackhole" {}

        //   module.git "madmysqlprimary" {
        //     repository = "https://github.com/grafana/agent-modules.git"
        //     revision = "0c0de275270f937aaebdbd137bb15dfd768a5b38"
        //     path = "modules/grafana-cloud/integrations/mysql/module.river"

        //     arguments {
        //       instance = "k8s MAD Primary"
        //       metrics_targets = []
        //       metrics_receiver = [prometheus.remote_write.blackhole.receiver]
        //       logs_receiver = [loki.write.blackhole.receiver]
        //     }
        //   }

        //   discovery.relabel "passthrough" {
        //     targets = discovery.relabel.pod_logs

        //     rule {
        //       source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name","__meta_kubernetes_pod_label_app_kubernetes_io_instance","__meta_kubernetes_pod_label_app_kubernetes_io_component"]
        //       regex = "mysql;mysql-mad;primary"
        //       action = "drop"
        //     }
        //   }

        //   discovery.relabel "filter" {
        //     targets = discovery.relabel.pod_logs

        //     rule {
        //       source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name","__meta_kubernetes_pod_label_app_kubernetes_io_instance","__meta_kubernetes_pod_label_app_kubernetes_io_component"]
        //       regex = "mysql;mysql-mad;primary"
        //       action = "keep"
        //     }
        //   }
        // |||,
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
            metrics_receiver = [prometheus.remote_write.metrics_service.receiver]
            logs_receiver = [loki.write.grafana_cloud_loki.receiver]
          }
        }
      ||| % { mysql_root_password: $._config.mysql.root_password },
    },
  }),
}
