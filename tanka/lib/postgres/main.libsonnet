local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local secret = k.core.v1.secret;

{
  secret:
    secret.new('postgres-%s' % $._config.postgres.suffix, {}) +
    secret.withStringData({
      'replication-password': $._config.postgres.replication_password,
      'postgres-password': $._config.postgres.password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  postgres: helm.template('postgres-%s' % $._config.postgres.suffix, '../../charts/postgresql', {
    namespace: $._config.namespace,
    values: {
      architecture: 'replication',
      auth: {
        existingSecret: 'postgres-%s' % $._config.postgres.suffix,
      },
      primary: {
        nodeSelector: {
          'kubernetes.io/hostname': $._config.postgres.hostname,
        },        
        persistence: {
          enabled: false,
          existingClaim: 'postgres-primary-pvc-%s' % $._config.postgres.suffix,
        },
      },
      readReplicas: {
        nodeSelector: {
          'kubernetes.io/hostname': $._config.postgres.replicaHostname,
        },
        persistence: {
          enabled: false,
          // For some reason, the chart does not support 'existingClaim', but does allow a selector for an existing pv ¯\_(ツ)_/¯
          storageClass: 'manual',
          size: '101Gi',
          selector: {
            matchLabels: { reservation: 'postgres-replica-%s' % $._config.postgres.suffix },
          },
        },
      },
    },
  }),
}