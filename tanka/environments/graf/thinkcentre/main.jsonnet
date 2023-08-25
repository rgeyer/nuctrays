local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local secrets = import 'secrets.libsonnet';

local namespace = 'graf';

secrets {
  namespace: k.core.v1.namespace.new(namespace),

  grafana_agent_flow: helm.template('grafana-k8s-monitoring', '../../../charts/k8s-monitoring', {
    namespace: namespace,
    includeCrds: false, // This is because they're already deployed in grao. Should grao be decommissioned, we'll need to re-add these.
    noHooks: true,
    values: {
      cluster: {
        name: namespace,
      },

      externalServices: {
        prometheus: {
          host: $._config.hosted_grafana_orgs.ryangeyer.hosted_metrics_host,
          basic_auth: {
            username: $._config.hosted_grafana_orgs.ryangeyer.hosted_metrics_tenant,
            password: $._config.hosted_grafana_orgs.ryangeyer.metrics_pub_key,
          },
        },

        loki: {
          host: $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_host,
          basic_auth: {
            username: $._config.hosted_grafana_orgs.ryangeyer.hosted_logs_tenant,
            password: $._config.hosted_grafana_orgs.ryangeyer.metrics_pub_key,
          },
        },
      },

      opencost: {
        opencost: {
          exporter: { defaultClusterId: namespace },
          prometheus: {
            external: {
              url: $._config.hosted_grafana_orgs.ryangeyer.hosted_metrics_host
            },
          },
        },
      },

      'prometheus-operator-crds': {
        enabled: false
      },
    },
  }),
}
